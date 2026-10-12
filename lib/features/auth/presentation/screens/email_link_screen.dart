import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../store/presentation/theme_teleport.dart';
import '../../../../core/widgets/confetti_burst.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_world.dart';

class EmailLinkScreen extends ConsumerStatefulWidget {
  const EmailLinkScreen({super.key});

  @override
  ConsumerState<EmailLinkScreen> createState() => _EmailLinkScreenState();
}

enum _Step { enterEmail, enterCode, done }

class _EmailLinkScreenState extends ConsumerState<EmailLinkScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  _Step _step = _Step.enterEmail;
  bool _isLinking = false;
  bool _isLoading = false;
  String? _error;

  /// True when an anonymous (guest) user tried to save their account with
  /// an email that's already registered to a different account. Supabase
  /// correctly refuses to *link* it (that would silently merge two
  /// separate identities), but the guest still needs a way forward instead
  /// of a dead-end error — see [_loginWithExistingAccountInstead].
  bool _emailBelongsToAnotherAccount = false;

  @override
  void dispose() {
    _cooldown?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    final isAnonymous = ref.read(isAnonymousProvider);
    setState(() {
      _isLoading = true;
      _isLinking = isAnonymous;
      _error = null;
      _emailBelongsToAnotherAccount = false;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      if (isAnonymous) {
        await repo.linkEmail(email);
      } else {
        await repo.signInWithEmailOtp(email);
      }
      if (mounted) setState(() => _step = _Step.enterCode);
    } catch (e) {
      debugPrint('send code failed (isLinking=$isAnonymous): $e');
      setState(() => _error = _messageFor(e, wasLinking: isAnonymous));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// A guest hit `email_exists` trying to save their account — instead of
  /// leaving them stuck, send a normal sign-in code for the *existing*
  /// account. They'll be logged into that account (guest coins on the
  /// abandoned anonymous session are not carried over — Supabase has no
  /// way to merge two already-separate identities), which is what the
  /// person almost certainly wants: to get back into the account they
  /// already have, not to stay locked out of it.
  Future<void> _loginWithExistingAccountInstead() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _emailBelongsToAnotherAccount = false;
      _isLinking = false;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithEmailOtp(_emailController.text.trim());
      if (mounted) setState(() => _step = _Step.enterCode);
    } catch (e) {
      debugPrint('login-instead failed: $e');
      setState(() => _error = _messageFor(e, wasLinking: false));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps the handful of failures users actually hit to plain language,
  /// instead of one generic message that hides what's actually wrong
  /// (rate-limited vs. a real delivery failure vs. an already-registered
  /// email all need different next steps). Checked against the base
  /// [AuthException] — `code`/`statusCode` live there, but which concrete
  /// subclass shows up varies (e.g. a mid-send failure surfaces as
  /// [AuthRetryableFetchException], not [AuthApiException]), so narrowing
  /// to one subclass would silently miss real cases.
  String _messageFor(Object e, {required bool wasLinking}) {
    if (e is AuthException) {
      if (e.code == 'email_exists' && wasLinking) {
        _emailBelongsToAnotherAccount = true;
        return 'That email already has an account.';
      }
      if (e.code == 'over_email_send_rate_limit') {
        return 'Too many code requests. Wait a few minutes and try again.';
      }
      if (e.statusCode == '500') {
        return 'We couldn\'t send that email right now. Try again shortly.';
      }
    }
    return "Couldn't send a code. Check the address and try again.";
  }

  Future<void> _verifyCode() async {
    // A code works once: never send it twice (the tiles auto-submit, and a
    // second tap on Verify used to come back as "that code didn't work").
    if (_isLoading || _step == _Step.done) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code from your email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      if (_isLinking) {
        await repo.verifyLinkOtp(email: email, token: code);
      } else {
        await repo.verifySignInOtp(email: email, token: code);
      }
      if (!mounted) return;
      _cooldown?.cancel();
      HapticFeedback.mediumImpact();
      ref.read(gameAudioProvider).play(Sfx.purchase);
      setState(() {
        _step = _Step.done;
        _isLoading = false;
      });
      // A moment to enjoy it, then Chip carries them home through the
      // portal, the same trip as changing worlds. Home appears under the
      // flash.
      final router = GoRouter.of(context);
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        final teleporting = ref
            .read(themeTeleportProvider.notifier)
            .welcome(
              ref.read(themeControllerProvider),
              atFlash: () => router.go('/home'),
            );
        if (!teleporting) router.go('/home');
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'That code didn\'t work. Try again.';
          _isLoading = false;
        });
      }
    }
  }

  Timer? _cooldown;
  int _resendIn = 0;

  void _startCooldown() {
    _cooldown?.cancel();
    setState(() => _resendIn = 60);
    _cooldown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final codeStep = _step == _Step.enterCode;
    final done = _step == _Step.done;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RiseIn(
                  child: Center(
                    child: AuthHero(
                      size: 110,
                      mood: done
                          ? BuddyMood.happy
                          : codeStep
                          ? BuddyMood.excited
                          : BuddyMood.thinking,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    done
                        ? (_isLinking ? 'Account saved!' : "You're in!")
                        : codeStep
                        ? 'Check your email'
                        : (ref.watch(isAnonymousProvider)
                              ? 'Save your account'
                              : 'Welcome to Utopia'),
                    key: ValueKey(_step),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  done
                      ? (_isLinking
                            ? 'Your coins and worlds are safe on any phone now.'
                            : 'Signed in as ${_emailController.text.trim()}')
                      : codeStep
                      ? 'We sent a code to ${_emailController.text.trim()}'
                      : "Enter your email and we'll send you a code.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                RiseIn(
                  delay: 0.2,
                  child: GlassPanel(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0.15, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Column(
                          key: ValueKey(_step),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (done) const _Verified(),
                            if (!codeStep && !done) ..._buildEmailStep(),
                            if (codeStep) ..._buildCodeStep(),
                            if (_error != null && !done) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                _error!,
                                style: const TextStyle(color: AppColors.error),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (_emailBelongsToAnotherAccount) ...[
                              const SizedBox(height: AppSpacing.sm),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : _loginWithExistingAccountInstead,
                                child: const Text(
                                  'Log in with this email instead',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmailStep() {
    return [
      UtopiaTextField(
        controller: _emailController,
        icon: Icons.mail_rounded,
        hint: 'you@example.com',
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        onSubmitted: (_) => _sendCode(),
      ),
      const SizedBox(height: AppSpacing.lg),
      PrimaryButton(
        label: 'Send code',
        isLoading: _isLoading,
        onPressed: () async {
          await _sendCode();
          if (mounted && _step == _Step.enterCode) _startCooldown();
        },
      ),
    ];
  }

  List<Widget> _buildCodeStep() {
    return [
      CodeTilesInput(
        controller: _codeController,
        length: 8,
        onCompleted: (_) => _verifyCode(),
      ),
      const SizedBox(height: AppSpacing.lg),
      PrimaryButton(
        label: 'Verify',
        isLoading: _isLoading,
        onPressed: _isLoading ? null : _verifyCode,
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                    _codeController.clear();
                    _step = _Step.enterEmail;
                  }),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Change email'),
          ),
          TextButton.icon(
            onPressed: _isLoading || _resendIn > 0
                ? null
                : () async {
                    await _sendCode();
                    if (mounted) _startCooldown();
                  },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(_resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend'),
          ),
        ],
      ),
    ];
  }
}

/// The code worked: a check pops in with a ring bursting around it,
/// confetti falls, and a little bar fills while we head home.
class _Verified extends StatelessWidget {
  const _Verified();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: ConfettiBurst(pieces: 60)),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            builder: (context, t, _) {
              final pop = Curves.elasticOut.transform(t);
              final ring = Curves.easeOut.transform(t);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 70 + 40 * ring,
                          height: 70 + 40 * ring,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.success.withValues(
                                alpha: 1 - ring,
                              ),
                              width: 4,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: pop,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-0.3, -0.4),
                                colors: [
                                  Color.lerp(
                                    AppColors.success,
                                    Colors.white,
                                    0.4,
                                  )!,
                                  AppColors.success,
                                ],
                              ),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 22,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Opening the portal',
                    style: AppTextStyles.body(
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 140,
                      height: 6,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1300),
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
