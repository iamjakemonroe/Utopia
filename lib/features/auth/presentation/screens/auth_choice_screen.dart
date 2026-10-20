import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/outlined_heading.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../store/presentation/theme_teleport.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_world.dart';
import '../widgets/game_fan.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../l10n/strings.dart';

const _privacyUrl = 'https://utopia.kaivon.app/privacy';

/// Entry point for signed-out users: play immediately as a guest, or go
/// straight to email sign-in/sign-up. The games fan out between, so it's
/// clear at a glance what's inside. Either way Chip carries them into
/// their world through the portal, and home appears under its flash.
class AuthChoiceScreen extends ConsumerStatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  ConsumerState<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends ConsumerState<AuthChoiceScreen> {
  bool _isSigningInAsGuest = false;
  String? _error;

  Future<void> _playAsGuest() async {
    setState(() {
      _isSigningInAsGuest = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    // Chip carries them in through the portal, the same trip as email
    // sign-in: the screen holds still until the trip's flash, and home
    // appears under it.
    SignInTrip.holding = true;
    try {
      await ref.read(authRepositoryProvider).signInAnonymously();
      final teleporting = ref
          .read(themeTeleportProvider.notifier)
          .welcome(
            ref.read(themeControllerProvider),
            atFlash: () {
              SignInTrip.holding = false;
              router.go('/home');
            },
          );
      if (!teleporting) {
        SignInTrip.holding = false;
        router.go('/home');
      }
    } catch (e) {
      SignInTrip.holding = false;
      debugPrint('signInAnonymously failed: $e');
      if (mounted) {
        setState(() => _error = strings.authChoiceCouldnTStartAGuest);
      }
    } finally {
      if (mounted) setState(() => _isSigningInAsGuest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = context.readablePadding(
                maxWidth: 520,
                min: AppSpacing.lg,
                top: AppSpacing.sm,
                bottom: AppSpacing.xs,
              );
              final compact = constraints.maxHeight < 720;
              // Tall enough (and text not enlarged much): the games fan
              // out between the title and the buttons. Otherwise it all
              // scrolls, without them.
              final roomy =
                  constraints.maxHeight >= 640 &&
                  MediaQuery.textScalerOf(context).scale(16) <= 18.5;
              if (!roomy) {
                return SingleChildScrollView(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _title(compact: true),
                      const SizedBox(height: AppSpacing.xl),
                      _actions(),
                    ],
                  ),
                );
              }
              return Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _title(compact: compact),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final height = math.min(c.maxHeight - 24, 236.0);
                          if (height < 110) return const SizedBox.shrink();
                          return Center(
                            child: RiseIn(
                              delay: 0.3,
                              child: GameFan(height: height),
                            ),
                          );
                        },
                      ),
                    ),
                    _actions(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Chip at the gateway, the name, and what Utopia is.
  Widget _title({required bool compact}) {
    return Column(
      children: [
        SizedBox(height: compact ? 0 : AppSpacing.sm),
        RiseIn(
          child: Center(child: AuthHero(size: compact ? 96 : 116)),
        ),
        RiseIn(
          delay: 0.12,
          child: Center(
            child: OutlinedHeading(
              strings.authChoiceUtopia,
              fontSize: compact ? 50 : 60,
            ),
          ),
        ),
        const SizedBox(height: 2),
        RiseIn(
          delay: 0.2,
          child: Text(
            strings.authChoiceGamesWithFriendsInA,
            textAlign: TextAlign.center,
            style:
                AppTextStyles.body(
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onWorld,
                ).copyWith(
                  height: 1.3,
                  shadows: const [
                    Shadow(color: Color(0xCC000000), blurRadius: 10),
                    Shadow(color: Color(0x88000000), blurRadius: 3),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  /// Play straight away, or sign in; and the privacy policy.
  Widget _actions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RiseIn(
          delay: 0.45,
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: strings.authChoicePlayNow,
                  isLoading: _isSigningInAsGuest,
                  onPressed: _playAsGuest,
                ),
                const SizedBox(height: AppSpacing.sm),
                _GlassButton(
                  icon: Icons.mail_rounded,
                  label: strings.authChoiceLogInOrSignUp,
                  onTap: () => context.push('/auth/link'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 15,
                      color: AppColors.coinGold,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        strings.authChoiceNoAccountNeededSaveIt,
                        style: AppTextStyles.body(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        RiseIn(
          delay: 0.55,
          child: Center(
            child: TextButton(
              onPressed: () => launchUrl(
                Uri.parse(_privacyUrl),
                mode: LaunchMode.externalApplication,
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onWorld.withValues(alpha: 0.75),
                minimumSize: const Size(0, 36),
                textStyle: AppTextStyles.body(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(strings.authChoicePrivacyPolicy),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: StadiumBorder(
        side: BorderSide(color: AppColors.goldBorder, width: 1.6),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.goldBorderBright),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.body(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
