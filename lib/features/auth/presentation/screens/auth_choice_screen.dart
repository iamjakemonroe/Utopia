import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/outlined_heading.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_world.dart';

/// Entry point for signed-out users: play immediately as a guest, or go
/// straight to email sign-in/sign-up. The router's redirect moves the user
/// to `/home` automatically once either path produces a session.
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
    try {
      await ref.read(authRepositoryProvider).signInAnonymously();
      // Navigation happens via the router's redirect once the auth state
      // stream emits the new session.
    } catch (e) {
      debugPrint('signInAnonymously failed: $e');
      setState(() => _error = "Couldn't start a guest game. Try again.");
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
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.md * 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          const RiseIn(child: Center(child: AuthHero())),
                          const SizedBox(height: AppSpacing.sm),
                          const RiseIn(
                            delay: 0.15,
                            child: Center(
                              child: OutlinedHeading('Utopia', fontSize: 56),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          RiseIn(
                            delay: 0.25,
                            child: Text(
                              'Games with friends, in a world that feels alive.',
                              textAlign: TextAlign.center,
                              style:
                                  AppTextStyles.body(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ).copyWith(
                                    shadows: const [
                                      Shadow(
                                        color: Color(0xCC000000),
                                        blurRadius: 10,
                                      ),
                                      Shadow(
                                        color: Color(0x88000000),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      RiseIn(
                        delay: 0.4,
                        child: GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PrimaryButton(
                                label: 'Play now',
                                isLoading: _isSigningInAsGuest,
                                onPressed: _playAsGuest,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _GlassButton(
                                icon: Icons.mail_rounded,
                                label: 'Log in or sign up',
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
                                  Text(
                                    'No account needed. Save it any time.',
                                    style: AppTextStyles.body(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
