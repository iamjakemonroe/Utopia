import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../l10n/strings.dart';

enum ToastKind { info, success, warning, error }

OverlayEntry? _current;
Timer? _timer;

/// A small bubble that bounces down from the top of the screen and floats
/// away on its own. One at a time: a new toast replaces the last.
void showUtopiaToast(
  BuildContext context,
  String message, {
  IconData? icon,
  ToastKind kind = ToastKind.info,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _timer?.cancel();
  _current?.remove();

  final color = switch (kind) {
    ToastKind.info => AppColors.accent,
    ToastKind.success => AppColors.success,
    ToastKind.warning => const Color(0xFFFFB020),
    ToastKind.error => AppColors.error,
  };
  final glyph =
      icon ??
      switch (kind) {
        ToastKind.info => Icons.auto_awesome_rounded,
        ToastKind.success => Icons.check_circle_rounded,
        ToastKind.warning => Icons.hourglass_bottom_rounded,
        ToastKind.error => Icons.cloud_off_rounded,
      };

  final key = GlobalKey<_ToastState>();
  final entry = OverlayEntry(
    builder: (context) =>
        _Toast(key: key, message: message, icon: glyph, color: color),
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(duration, () async {
    await key.currentState?.dismiss();
    if (_current == entry) {
      entry.remove();
      _current = null;
    }
  });
}

/// Server and network errors in words a player can use.
String friendlyError(
  Object error, {
  String fallback = 'Something went wrong. Try again.',
}) {
  final text = error.toString().toLowerCase();
  if (text.contains('insufficient balance') ||
      text.contains('enough balance')) {
    return strings.utopiaToastYouDonTHaveEnough;
  }
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network') ||
      text.contains('connection')) {
    return strings.utopiaToastCanTReachUtopiaRight;
  }
  if (text.contains('challenge already answered')) {
    return strings.utopiaToastTooLateTheyAlreadyAnswered;
  }
  if (text.contains('challenge expired')) {
    return strings.utopiaToastThatChallengeRanOutThey;
  }
  if (text.contains('challenger away')) {
    return strings.utopiaToastTheyVeSteppedAwaySo;
  }
  if (text.contains('room is full')) {
    return strings.utopiaToastThatRoomIsAlreadyFull;
  }
  if (text.contains('room not found') || text.contains('no such room')) {
    return strings.utopiaToastWeCouldnTFindA;
  }
  if (text.contains('already started')) {
    return strings.utopiaToastThatGameHasAlreadyStarted;
  }
  if (text.contains('username must')) {
    return strings.utopiaToastUse3To20Letters;
  }
  if (text.contains('username') && text.contains('taken')) {
    return strings.utopiaToastThatNameIsTakenTry;
  }
  if (text.contains('duplicate key') && text.contains('username')) {
    return strings.utopiaToastThatNameIsTakenTry;
  }
  return fallback;
}

class _Toast extends StatefulWidget {
  const _Toast({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    reverseDuration: const Duration(milliseconds: 260),
  )..forward();

  Future<void> dismiss() async {
    if (!mounted) return;
    await _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 10;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final v = _c.status == AnimationStatus.reverse
                ? Curves.easeIn.transform(_c.value)
                : Curves.elasticOut.transform(_c.value);
            return Opacity(
              opacity: _c.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -40 * (1 - v)),
                child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
              ),
            );
          },
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.surfaceElevated, AppColors.surface],
                  ),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.7),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                    const BoxShadow(color: Color(0x55000000), blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.4),
                          colors: [
                            Color.lerp(widget.color, Colors.white, 0.45)!,
                            widget.color,
                          ],
                        ),
                      ),
                      child: Icon(widget.icon, size: 17, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: AppTextStyles.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
