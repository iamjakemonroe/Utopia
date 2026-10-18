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
    final price = controller.maestroPrice;
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
                  'Chip Maestro',
                  style: AppTextStyles.display(fontSize: 28),
                ),
                const SizedBox(height: 4),
                Text(
                  member
                      ? "You're a Chip Maestro. Chip is your artist."
                      : 'Chip becomes your own artist.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _Perk(
                  icon: Icons.auto_awesome_rounded,
                  color: Color(0xFFFF5C9C),
                  text:
                      '$kMaestroPortraitsPerMonth real portraits a month: anyone, from a photo or a famous name, looking just like them',
                ),
                const _Perk(
                  icon: Icons.palette_rounded,
                  color: Color(0xFF4DA3FF),
                  text: 'Color with Chip all day long',
                ),
                const _Perk(
                  icon: Icons.brush_rounded,
                  color: Color(0xFF3DDC97),
                  text: "10 of Chip's own drawings a day instead of 4",
                ),
                const _Perk(
                  icon: Icons.face_retouching_natural_rounded,
                  color: Color(0xFFFFB020),
                  text:
                      "Chip's artist look, and the Maestro frame for your picture",
                ),
                const SizedBox(height: AppSpacing.lg),
                if (member && status != null)
                  _MemberCard(status: status, onManage: _manage)
                else ...[
                  PrimaryButton(
                    label: !Env.realMoneyStore
                        ? 'Coming soon'
                        : price == null
                        ? 'Join Chip Maestro'
                        : 'Join for $price a month',
                    isLoading: busy,
                    onPressed: !Env.realMoneyStore || busy
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            controller.buyMaestro();
                          },
                  ),
                  if (status?.freePortrait ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Not sure yet? Your first real portrait is free.',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (Env.realMoneyStore)
                    TextButton(
                      onPressed: controller.restore,
                      child: Text(
                        'Restore purchases',
                        style: AppTextStyles.body(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Renews every month until you cancel. Cancel any time in your '
                  '${!kIsWeb && Platform.isIOS ? 'App Store' : 'Google Play'} settings, at '
                  'least a day before it renews.',
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
                        'Terms of Use',
                        style: AppTextStyles.body(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _open(_privacyUrl),
                      child: Text(
                        'Privacy Policy',
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

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: AppTextStyles.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
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
            '${status.left} real portraits left this month',
            style: AppTextStyles.display(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            status.autoRenew ? 'Renews on $when' : 'Ends on $when',
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onManage,
            child: Text(
              'Manage your plan',
              style: AppTextStyles.body(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
