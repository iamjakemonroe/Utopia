import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/coin_gift_repository.dart';

/// What's wrong with [pin] as a gift PIN, in plain words (the server
/// checks the same): null when it'll do.
String? giftPinProblem(String pin) {
  if (!RegExp(r'^\d{4}$').hasMatch(pin)) return 'Four digits, please.';
  if (RegExp(r'^(\d)\1{3}$').hasMatch(pin) ||
      '0123456789'.contains(pin) ||
      '9876543210'.contains(pin)) {
    return "That one's too easy to guess. Try another.";
  }
  return null;
}

/// How long a lock has left, in words: "in 12 minutes".
String lockedFor(DateTime until) {
  final minutes = until.difference(DateTime.now()).inSeconds / 60;
  if (minutes <= 1) return 'in a minute';
  return 'in ${minutes.ceil()} minutes';
}

/// What the server said about a PIN, in plain words.
String giftPinWhy(GiftResult result) => switch (result.why) {
  'wrong_pin' => switch (result.triesLeft) {
    1 => 'Wrong PIN. One more try before gifts lock for a while.',
    final n? => 'Wrong PIN. $n tries left.',
    _ => 'Wrong PIN.',
  },
  'locked' =>
    'Too many wrong tries. Try again '
        '${result.lockedUntil == null ? 'later' : lockedFor(result.lockedUntil!)}, '
        'or reset your PIN.',
  'weak' => "That one's too easy to guess. Try another.",
  'format' => 'Four digits, please.',
  'guest' => 'Save your account first: gifts are for accounts.',
  'verify' => 'That took a while. Send yourself a new code.',
  'no_pin' => 'Choose a gift PIN first.',
  _ => "Couldn't do that. Try again.",
};

/// "j•••@gmail.com": enough to know which email, no more.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return '${email[0]}${'•' * math.min(5, math.max(2, at - 1))}'
      '${email.substring(at)}';
}

/// A gift PIN's keypad: dots that fill as the digits go in, and the
/// digits on the screen itself (no keyboard to wait for, on any phone or
/// in a browser; a computer's keys work too). Calls [onDone] with the
/// [length] digits; each new [errorCount] shakes the dots and clears them.
class GiftPinPad extends StatefulWidget {
  const GiftPinPad({
    super.key,
    required this.title,
    this.subtitle,
    required this.onDone,
    this.length = 4,
    this.error,
    this.errorCount = 0,
    this.busy = false,
    this.enabled = true,
    this.extra,
  });

  final String title;
  final String? subtitle;
  final ValueChanged<String> onDone;
  final int length;
  final String? error;
  final int errorCount;

  /// Waiting on the server: the dots stay full, keys rest.
  final bool busy;

  /// Off while gifts are locked.
  final bool enabled;

  /// Under the keys: "Forgot PIN?" and the like.
  final Widget? extra;

  @override
  State<GiftPinPad> createState() => _GiftPinPadState();
}

class _GiftPinPadState extends State<GiftPinPad>
    with SingleTickerProviderStateMixin {
  String _entry = '';
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant GiftPinPad old) {
    super.didUpdateWidget(old);
    if (widget.errorCount != old.errorCount) {
      _entry = '';
      _shake.forward(from: 0);
      HapticFeedback.heavyImpact();
    } else if (old.busy && !widget.busy) {
      _entry = '';
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _live => widget.enabled && !widget.busy;

  void _press(String digit) {
    if (!_live || _entry.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _entry += digit);
    if (_entry.length == widget.length) {
      final pin = _entry;
      // A beat with every dot full before it goes.
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted && _entry == pin) widget.onDone(pin);
      });
    }
  }

  void _back() {
    if (!_live || _entry.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = event.character;
    if (ch != null && RegExp(r'^\d$').hasMatch(ch)) {
      _press(ch);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(fontSize: 21),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value),
                0,
              ),
              child: child,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _entry.length || widget.busy
                          ? AppColors.coinGold
                          : Colors.transparent,
                      border: Border.all(
                        color: widget.error != null && _entry.isEmpty
                            ? AppColors.error
                            : AppColors.textSecondary.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: Center(
              child: widget.busy
                  ? const UtopiaLoader(size: 26)
                  : widget.error == null
                  ? null
                  : Text(
                      widget.error!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.readable(AppColors.error),
                      ),
                    ),
            ),
          ),
          Opacity(
            opacity: widget.enabled ? 1 : 0.35,
            child: Column(
              children: [
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['', '0', '<'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final k in row)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: k.isEmpty
                                ? const SizedBox.square(dimension: 64)
                                : _Key(
                                    label: k,
                                    onTap: k == '<' ? _back : () => _press(k),
                                  ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (widget.extra != null) widget.extra!,
        ],
      ),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final back = widget.label == '<';
    return Semantics(
      button: true,
      label: back ? 'Delete' : widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: back
                  ? Colors.transparent
                  : AppColors.textPrimary.withValues(
                      alpha: _down ? 0.16 : 0.07,
                    ),
              border: back
                  ? null
                  : Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.14),
                    ),
            ),
            child: back
                ? Icon(
                    Icons.backspace_outlined,
                    color: AppColors.textSecondary,
                    size: 24,
                  )
                : Text(
                    widget.label,
                    style: AppTextStyles.display(fontSize: 26),
                  ),
          ),
        ),
      ),
    );
  }
}

/// What a PIN flow is for.
enum GiftPinGoal {
  /// A first PIN: choose one, then again.
  set,

  /// The current one, then a new one twice.
  change,

  /// Forgotten: a code from their email, then a new one twice.
  reset,
}

/// Setting, changing or resetting the gift PIN, a step at a time. Calls
/// [onDone] with the new PIN once the server has it.
class GiftPinFlow extends ConsumerStatefulWidget {
  const GiftPinFlow({
    super.key,
    required this.goal,
    required this.onDone,
    this.firstTitle,
    this.firstSubtitle,
  });

  final GiftPinGoal goal;
  final ValueChanged<String> onDone;

  /// In place of "Choose a gift PIN" (when it's asked for on a first gift).
  final String? firstTitle;
  final String? firstSubtitle;

  @override
  ConsumerState<GiftPinFlow> createState() => _GiftPinFlowState();
}

enum _Step { intro, code, current, choose, again }

class _GiftPinFlowState extends ConsumerState<GiftPinFlow> {
  late _Step _step = switch (widget.goal) {
    GiftPinGoal.set => _Step.choose,
    GiftPinGoal.change => _Step.current,
    GiftPinGoal.reset => _Step.intro,
  };
  String? _current;
  String? _chosen;
  String? _error;
  int _errors = 0;
  bool _busy = false;

  /// When a new code can be sent (the server allows one a minute).
  DateTime? _resendAt;
  Timer? _resendTick;

  @override
  void dispose() {
    _resendTick?.cancel();
    super.dispose();
  }

  CoinGiftRepository get _repo => ref.read(coinGiftRepositoryProvider);

  String? get _email => ref.read(currentUserProvider)?.email;

  void _fail(String message, {_Step? to}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
      _errors++;
      if (to != null) _step = to;
    });
  }

  void _go(_Step step) => setState(() {
    _step = step;
    _error = null;
  });

  Future<void> _sendCode() async {
    final email = _email;
    if (email == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.sendPinResetCode(email);
      if (!mounted) return;
      _resendAt = DateTime.now().add(const Duration(seconds: 60));
      _resendTick?.cancel();
      _resendTick = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() {});
        if (DateTime.now().isAfter(_resendAt!)) t.cancel();
      });
      setState(() {
        _busy = false;
        _step = _Step.code;
      });
    } catch (e) {
      _fail(
        friendlyError(
          e,
          fallback: "Couldn't send the code. Try again in a minute.",
        ),
      );
    }
  }

  Future<void> _checkCode(String code) async {
    final email = _email;
    if (email == null) return;
    setState(() => _busy = true);
    try {
      await _repo.verifyPinResetCode(email, code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = null;
        _step = _Step.choose;
      });
    } catch (_) {
      _fail("That code didn't work. Check it, or send a new one.");
    }
  }

  void _chooseFirst(String pin) {
    final problem = giftPinProblem(pin);
    if (problem != null) return _fail(problem);
    _chosen = pin;
    _go(_Step.again);
  }

  Future<void> _confirm(String pin) async {
    if (pin != _chosen) {
      return _fail("Those didn't match. Choose one again.", to: _Step.choose);
    }
    setState(() => _busy = true);
    try {
      final result = widget.goal == GiftPinGoal.reset
          ? await _repo.resetPin(pin)
          : await _repo.setPin(pin, current: _current);
      if (!mounted) return;
      if (result.ok) {
        HapticFeedback.mediumImpact();
        ref.invalidate(giftPinStatusProvider);
        widget.onDone(pin);
        return;
      }
      _fail(
        giftPinWhy(result),
        to: switch (result.why) {
          'wrong_pin' || 'locked' => _Step.current,
          'verify' => _Step.intro,
          _ => _Step.choose,
        },
      );
    } catch (e) {
      _fail(friendlyError(e, fallback: "Couldn't save it. Try again."));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(_step), child: _body()),
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.intro:
        final email = _email;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_unread_rounded,
              size: 46,
              color: AppColors.readable(AppColors.coinGold),
            ),
            const SizedBox(height: 10),
            Text(
              'Forgot your PIN?',
              textAlign: TextAlign.center,
              style: AppTextStyles.display(fontSize: 21),
            ),
            const SizedBox(height: 6),
            Text(
              email == null
                  ? 'Your account has no email for a code. Ask us through '
                        'Report a bug and we\'ll help.'
                  : "We'll email a code to ${maskEmail(email)} to check "
                        "it's you. Then choose a new PIN.",
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.readable(AppColors.error),
                ),
              ),
            ],
            if (email != null) ...[
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Email me a code',
                isLoading: _busy,
                onPressed: _busy ? null : _sendCode,
              ),
            ],
          ],
        );
      case _Step.code:
        final wait = _resendAt == null
            ? 0
            : _resendAt!.difference(DateTime.now()).inSeconds;
        return GiftPinPad(
          key: const ValueKey('code'),
          title: 'Enter the code',
          subtitle: 'The 6 digits we sent to ${maskEmail(_email ?? '')}',
          length: 6,
          busy: _busy,
          error: _error,
          errorCount: _errors,
          onDone: _checkCode,
          extra: TextButton(
            onPressed: wait > 0 || _busy ? null : _sendCode,
            child: Text(
              wait > 0 ? 'Send a new code in ${wait}s' : 'Send a new code',
            ),
          ),
        );
      case _Step.current:
        return GiftPinPad(
          key: const ValueKey('current'),
          title: 'Your current PIN',
          subtitle: 'Then choose a new one',
          error: _error,
          errorCount: _errors,
          onDone: (pin) {
            _current = pin;
            _go(_Step.choose);
          },
        );
      case _Step.choose:
        return GiftPinPad(
          key: const ValueKey('choose'),
          title:
              widget.firstTitle ??
              (widget.goal == GiftPinGoal.set
                  ? 'Choose a gift PIN'
                  : 'Choose a new PIN'),
          subtitle:
              widget.firstSubtitle ??
              "4 digits you'll enter for every gift. Keep it to yourself.",
          error: _error,
          errorCount: _errors,
          onDone: _chooseFirst,
        );
      case _Step.again:
        return GiftPinPad(
          key: const ValueKey('again'),
          title: 'Enter it again',
          subtitle: 'Just to be sure',
          busy: _busy,
          error: _error,
          errorCount: _errors,
          onDone: _confirm,
        );
    }
  }
}

/// The gift PIN from Settings: set one, change it, or reset a forgotten
/// one.
Future<void> showGiftPinSheet(BuildContext context) {
  ProviderScope.containerOf(context).read(gameAudioProvider).play(Sfx.drawer);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GiftPinSheet(),
  );
}

class _GiftPinSheet extends ConsumerStatefulWidget {
  const _GiftPinSheet();

  @override
  ConsumerState<_GiftPinSheet> createState() => _GiftPinSheetState();
}

class _GiftPinSheetState extends ConsumerState<_GiftPinSheet> {
  GiftPinGoal? _goal;

  void _done(String _) {
    final changed = _goal != GiftPinGoal.set;
    Navigator.of(context).pop();
    showUtopiaToast(
      context,
      changed ? 'New gift PIN saved' : 'Gift PIN set',
      kind: ToastKind.success,
      icon: Icons.lock_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(giftPinStatusProvider);
    final guest = ref.watch(isAnonymousProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: PopCard(
            borderRadius: 28,
            tint: AppColors.coinGold,
            glow: AppColors.coinGold,
            sheet: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: _goal != null
                  ? GiftPinFlow(goal: _goal!, onDone: _done)
                  : guest
                  ? _note(
                      'Save your account to send coins to friends, and give '
                      'your gifts a PIN.',
                    )
                  : switch (status) {
                      AsyncData(:final value) => _menu(value),
                      AsyncError() => _note(
                        "Couldn't check your PIN. Try again.",
                      ),
                      _ => const SizedBox(
                        height: 120,
                        child: Center(child: UtopiaLoader(size: 40)),
                      ),
                    },
            ),
          ),
        ),
      ),
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.body(color: AppColors.textSecondary),
    ),
  );

  Widget _menu(GiftPinStatus status) {
    final locked = status.lockedUntil;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          status.set ? Icons.lock_rounded : Icons.lock_open_rounded,
          size: 44,
          color: AppColors.readable(AppColors.coinGold),
        ),
        const SizedBox(height: 8),
        Text(
          'Gift PIN',
          textAlign: TextAlign.center,
          style: AppTextStyles.display(fontSize: 22),
        ),
        const SizedBox(height: 6),
        Text(
          status.set
              ? 'Every coin gift asks for it, so only you can send your coins.'
              : "You don't have one yet. You'll choose one before your first "
                    'gift, or choose it now.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        if (locked != null) ...[
          const SizedBox(height: 8),
          Text(
            'Locked after too many wrong tries: open again '
            '${lockedFor(locked)}, or reset it.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.readable(AppColors.error),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (!status.set)
          PrimaryButton(
            label: 'Choose a PIN',
            onPressed: () => setState(() => _goal = GiftPinGoal.set),
          )
        else ...[
          PrimaryButton(
            label: 'Change PIN',
            onPressed: locked != null
                ? null
                : () => setState(() => _goal = GiftPinGoal.change),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => _goal = GiftPinGoal.reset),
            child: const Text('Forgot PIN?'),
          ),
        ],
      ],
    );
  }
}
