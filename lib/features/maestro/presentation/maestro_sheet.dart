import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/config/env.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../store/presentation/store_controller.dart';
import '../data/maestro_repository.dart';
import 'maestro_providers.dart';
import '../../../l10n/strings.dart';

/// Where the plan's small print points.
const _termsUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const _privacyUrl = 'https://utopia.kaivon.app/privacy.html';

/// Opens Chip Maestro: what the plan gives, and joining (or, for members,
/// where their plan stands).
Future<void> showMaestroSheet(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  container.read(gameAudioProvider).play(Sfx.drawer);
  container.invalidate(maestroProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MaestroSheet(),
  );
}

class _MaestroSheet extends ConsumerWidget {
  const _MaestroSheet();

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  /// The store's own page for managing (or cancelling) the subscription.
  Future<void> _manage() => _open(
    !kIsWeb && Platform.isIOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions'
              '?sku=$kMaestroProductId&package=com.iamjakemonroe.utopia',
  );

  /// On the web: cancelling the plan bought here, once they're sure.
  Future<void> _cancelOnWeb(
    BuildContext context,
    WidgetRef ref,
    MaestroStatus status,
  ) async {
    final until = status.until?.toLocal();
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.maestroCancelTitle),
        content: Text(
          strings.maestroCancelBody(
            until == null ? '' : '${until.day}/${until.month}/${until.year}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.maestroKeepMyPlan),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.maestroCancelPlan),
          ),
        ],
      ),
    );
    if (sure == true) {
      await ref.read(storeControllerProvider.notifier).cancelWebMaestro();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(maestroProvider).valueOrNull;
    final store = ref.watch(storeControllerProvider);
    final controller = ref.read(storeControllerProvider.notifier);
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    final name = profile?['display_name'] as String? ?? 'U';
    final member = status?.active ?? false;
    final price = kIsWeb ? store.webMaestroPrice : controller.maestroPrice;
    // In a browser the price comes with the shop's: until it has, the
    // button waits (no label changing under the player's finger), and
    // with payments off there's nothing to buy yet.
    final waiting = kIsWeb && !store.loaded;
    final canBuy = kIsWeb ? waiting || price != null : Env.realMoneyStore;
    final busy = store.busyProduct == kMaestroProductId;

    ref.listen(storeControllerProvider.select((s) => s.message), (_, next) {
      if (next == null) return;
      showUtopiaToast(context, next);
      controller.clearMessage();
    });

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceElevated, AppColors.background],
          ),
          border: const Border(
            top: BorderSide(color: Color(0xFFFF5C9C), width: 2),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              10,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CoinBuddy(
                      mood: BuddyMood.excited,
                      size: 104,
                      beret: true,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    UserAvatar.fromProfile(
                      profile,
                      fallbackInitial: name,
                      radius: 34,
                      aura: 'maestro',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  strings.maestroChipMaestro,
                  style: AppTextStyles.display(fontSize: 28),
                ),
                const SizedBox(height: 4),
                Text(
                  member
                      ? strings.maestroYouReAChipMaestro
                      : strings.maestroChipAtHisBest,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Compare(member: member),
                const SizedBox(height: AppSpacing.lg),
                if (member && status != null)
                  _MemberCard(
                    status: status,
                    onManage: kIsWeb
                        ? () => _cancelOnWeb(context, ref, status)
                        : _manage,
                  )
                else ...[
                  PrimaryButton(
                    label: !canBuy
                        ? strings.maestroComingSoon
                        : price == null
                        ? strings.maestroJoinChipMaestro
                        : strings.maestroJoinForAMonth(price),
                    isLoading: busy || waiting,
                    onPressed: !canBuy || busy || waiting
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            controller.buyMaestro();
                          },
                  ),
                  if (status?.freePortrait ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      strings.maestroNotSureYetYourFirst,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (Env.realMoneyStore && !kIsWeb)
                    TextButton(
                      onPressed: controller.restore,
                      child: Text(
                        strings.maestroRestorePurchases,
                        style: AppTextStyles.body(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  kIsWeb
                      ? strings.maestroRenewsOnTheWeb
                      : strings.maestroRenewsEveryMonthUntilYou(
                          Platform.isIOS
                              ? strings.maestroAppStore
                              : strings.maestroGooglePlay,
                        ),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _open(_termsUrl),
                      child: Text(
                        strings.maestroTermsOfUse,
                        style: AppTextStyles.body(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _open(_privacyUrl),
                      child: Text(
                        strings.maestroPrivacyPolicy,
                        style: AppTextStyles.body(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Free next to Chip Maestro, row by row, the Maestro column lit up.
class _Compare extends StatelessWidget {
  const _Compare({required this.member});

  /// Already a member: the Maestro column is theirs.
  final bool member;

  static const _pink = Color(0xFFFF5C9C);

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String, String)>[
      (
        Icons.chat_bubble_rounded,
        strings.maestroCompareChats,
        '$kChipChatsFree',
        '$kChipChatsMaestro',
      ),
      (
        Icons.psychology_rounded,
        strings.maestroCompareBrain,
        strings.maestroCompareBrainFree,
        strings.maestroCompareBrainMaestro,
      ),
      (
        Icons.draw_rounded,
        strings.maestroCompareDrawings,
        '$kChipDrawsFree',
        '$kChipDrawsMaestro',
      ),
      (
        Icons.palette_rounded,
        strings.maestroCompareColoring,
        '$kChipPaintsFree',
        '$kChipPaintsMaestro',
      ),
      (
        Icons.auto_awesome_rounded,
        strings.maestroComparePortraits,
        strings.maestroComparePortraitsFree,
        strings.maestroComparePortraitsMaestro(kMaestroPortraitsPerMonth),
      ),
      (
        Icons.face_retouching_natural_rounded,
        strings.maestroCompareLook,
        '–',
        '✓',
      ),
    ];
    final line = AppColors.textSecondary.withValues(alpha: 0.18);
    Widget cell(String text, {required bool maestro, bool head = false}) =>
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            fontSize: head ? 12.5 : 13.5,
            fontWeight: maestro || head ? FontWeight.w900 : FontWeight.w600,
            color: maestro
                ? AppColors.readable(_pink)
                : AppColors.textSecondary,
          ),
        );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        color: AppColors.surface.withValues(alpha: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The Maestro column, lit.
          Positioned.fill(
            child: Row(
              children: [
                const Spacer(flex: 10),
                const Spacer(flex: 5),
                Expanded(
                  flex: 6,
                  child: Container(color: _pink.withValues(alpha: 0.1)),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 0, 8),
                child: Row(
                  children: [
                    const Spacer(flex: 10),
                    Expanded(
                      flex: 5,
                      child: cell(
                        strings.maestroCompareFree,
                        maestro: false,
                        head: true,
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: cell(
                        member
                            ? strings.maestroCompareYours
                            : strings.maestroBadge,
                        maestro: true,
                        head: true,
                      ),
                    ),
                  ],
                ),
              ),
              for (final (icon, label, free, maestro) in rows)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 9, 0, 9),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 10,
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 17,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                style: AppTextStyles.body(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(flex: 5, child: cell(free, maestro: false)),
                      Expanded(flex: 6, child: cell(maestro, maestro: true)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Where a member's plan stands, and the way to change it.
class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.status, required this.onManage});

  final MaestroStatus status;
  final VoidCallback onManage;

  static final _months = [
    'Jan',
    strings.maestroFeb,
    strings.maestroMar,
    strings.maestroApr,
    strings.maestroMay,
    strings.maestroJun,
    strings.maestroJul,
    strings.maestroAug,
    strings.maestroSep,
    strings.maestroOct,
    strings.maestroNov,
    strings.maestroDec,
  ];

  @override
  Widget build(BuildContext context) {
    final until = status.until?.toLocal();
    final when = until == null
        ? ''
        : '${until.day} ${_months[until.month - 1]}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFFF5C9C).withValues(alpha: 0.12),
        border: Border.all(
          color: const Color(0xFFFF5C9C).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Text(
            strings.maestroRealPortraitsLeftThisMonth(status.left),
            style: AppTextStyles.display(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            status.autoRenew
                ? strings.maestroRenewsOn(when)
                : strings.maestroEndsOn(when),
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onManage,
            child: Text(
              strings.maestroManageYourPlan,
              style: AppTextStyles.body(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
