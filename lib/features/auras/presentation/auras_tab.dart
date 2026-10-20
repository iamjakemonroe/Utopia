import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/aura_repository.dart';
import '../domain/aura.dart';
import 'aura_sheet.dart';
import 'mythic_badge.dart';
import '../../events/presentation/event_widgets.dart';
import '../../../core/layout/responsive.dart';

/// The aura shop: what you're wearing now, then every aura by tier, each
/// shown live around your own picture.
class AurasTab extends ConsumerWidget {
  const AurasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    final name = me == null ? 'You' : profileDisplayName(profile, me);
    final wearing = Aura.byId(activeAura(profile));
    final until = DateTime.tryParse(
      profile?['aura_expires_at'] as String? ?? '',
    );
    final prices = ref.watch(auraPricesProvider).valueOrNull;
    final mine = ref.watch(myAurasProvider).valueOrNull ?? const {};

    const pad = EdgeInsets.symmetric(horizontal: AppSpacing.md);
    // Slivers, so only the cards on screen are built and animating.
    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverToBoxAdapter(child: EventStoreBanner()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: PopCard(
              borderRadius: 26,
              tint: wearing?.color,
              glow: wearing?.color,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 104,
                    child: Center(
                      child: UserAvatar.fromProfile(
                        profile,
                        fallbackInitial: name,
                        radius: 38,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wearing == null ? 'No aura yet' : wearing.name,
                          style: AppTextStyles.display(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          wearing == null
                              ? 'Wear one and everyone sees it around your picture, in every game.'
                              : 'Wearing now · ${auraTimeLeft(until!)}',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final tier in AuraTier.values.reversed) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  if (tier == AuraTier.mythic)
                    const MythicLightning(fontSize: 20)
                  else ...[
                    Icon(tier.icon, size: 20, color: tier.color),
                    const SizedBox(width: 8),
                    Text(
                      tier.title,
                      style: AppTextStyles.display(fontSize: 18),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'from ',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  CoinAmount(
                    auraPrice(
                      prices,
                      Aura.all.firstWhere((a) => a.tier == tier),
                      AuraLength.week,
                    ),
                    size: 13,
                    color: AppColors.readable(AppColors.coinGoldBright),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: pad,
            sliver: SliverGrid.count(
              crossAxisCount: context.gridColumns(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.82,
              children: [
                for (final aura in Aura.all.where(
                  (a) =>
                      a.tier == tier &&
                      (!a.notSold ||
                          (mine[a.id]?.isAfter(DateTime.now()) ?? false)),
                ))
                  _AuraCard(
                    aura: aura,
                    profile: profile,
                    name: name,
                    price: auraPrice(prices, aura, AuraLength.week),
                    ownedUntil: mine[aura.id],
                    wearing: wearing?.id == aura.id,
                  ),
              ],
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }
}

class _AuraCard extends StatelessWidget {
  const _AuraCard({
    required this.aura,
    required this.profile,
    required this.name,
    required this.price,
    required this.ownedUntil,
    required this.wearing,
  });

  final Aura aura;
  final Map<String, dynamic>? profile;
  final String name;
  final int price;
  final DateTime? ownedUntil;
  final bool wearing;

  @override
  Widget build(BuildContext context) {
    final owned = ownedUntil != null && ownedUntil!.isAfter(DateTime.now());
    return GestureDetector(
      onTap: () => showAuraSheet(context, aura),
      child: PopCard(
        borderRadius: 22,
        glow: wearing ? AppColors.success : aura.color,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AuraStage(
                        color: aura.color,
                        child: UserAvatar.fromProfile(
                          profile,
                          fallbackInitial: name,
                          radius: 30,
                          aura: aura.id,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: TierChip(tier: aura.tier, small: true),
                    ),
                    if (owned)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.success,
                          ),
                          child: Text(
                            wearing ? 'Wearing' : 'Owned',
                            style: AppTextStyles.body(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aura.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  owned
                      ? Text(
                          auraTimeLeft(ownedUntil!),
                          style: AppTextStyles.body(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.readable(AppColors.success),
                          ),
                        )
                      : Row(
                          children: [
                            Text(
                              'from ',
                              style: AppTextStyles.body(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            CoinAmount(
                              price,
                              size: 12,
                              color: AppColors.readable(
                                AppColors.coinGoldBright,
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
