import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coins/presentation/player_coins.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/away_mark.dart';
import '../../../../core/widgets/countdown_border.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../domain/ludo_engine.dart';
import '../../../chat/domain/voice_note.dart';
import '../../../chat/presentation/chat_sticker.dart';
import 'ludo_pieces.dart';
import '../../../chat/presentation/voice_notes.dart';
import '../../../../core/widgets/frame_island.dart';
import '../../../../l10n/strings.dart';

/// One player's corner of the table: their avatar framed in their color, a
/// "tokens home" counter, the die when it's their turn, and their latest
/// chat line popping up as a speech bubble. Tapping the avatar opens their
/// player card.
class LudoSeatPanel extends ConsumerWidget {
  const LudoSeatPanel({
    super.key,
    required this.color,
    required this.userId,
    required this.isMe,
    required this.isTurn,
    required this.left,
    required this.home,
    required this.onAvatarTap,
    this.dice,
    this.speech,
    this.mirrored = false,
    this.winner = false,
    this.place,
    this.msLeft,
    this.totalMs = 15000,
    this.missedTurns = 0,
    this.onWarnSecond,
  });

  final LudoColor color;
  final String? userId;
  final bool isMe;
  final bool isTurn;
  final bool left;

  /// Tokens this player has brought home.
  final int home;
  final VoidCallback onAvatarTap;

  /// The die, when it's this seat's turn.
  final Widget? dice;

  /// A recent chat message to show as a speech bubble.
  final String? speech;

  /// Right-hand panels put the die on the inside, toward the board.
  final bool mirrored;
  final bool winner;

  /// This player's finishing place, once all four of their pieces are home.
  final int? place;

  /// The turn timer while it's this seat's turn (drawn around the avatar).
  final int? Function()? msLeft;
  final int totalMs;

  /// Turns in a row this player has let run out (three and they're out).
  final int missedTurns;
  final ValueChanged<int>? onWarnSecond;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = userId == null
        ? null
        : ref.watch(profileByIdProvider(userId!)).valueOrNull;
    final name = isMe
        ? strings.ludoSeatPanelYou
        : (userId == null
              ? strings.ludoSeatPanelOpenSeat
              : profileDisplayName(profile, userId!));
    final seat = ludoColorPalette[color]!;

    final avatar = GestureDetector(
      onTap: userId == null ? null : onAvatarTap,
      child: _AvatarFrame(
        color: seat,
        active: isTurn && !left,
        dim: left && place == null,
        winner: winner || place == 1,
        place: place,
        msLeft: isTurn && !left ? msLeft : null,
        totalMs: totalMs,
        onWarnSecond: onWarnSecond,
        child: UserAvatar.fromProfile(
          profile,
          fallbackInitial: name,
          radius: 22,
        ),
      ),
    );

    final diceSlot = _SpeechAnchor(
      speech: speech,
      mirrored: mirrored,
      passTaps: dice != null,
      child: SizedBox(
        width: 64,
        height: 64,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.elasticOut,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: dice == null
              ? const SizedBox.shrink(key: ValueKey('none'))
              : KeyedSubtree(key: const ValueKey('dice'), child: dice!),
        ),
      ),
    );

    final label = Column(
      crossAxisAlignment: mirrored
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: left ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        PlayerCoins(userId: userId, size: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (place != null) ...[
              // Finished: their place, in its medal's color.
              Icon(
                Icons.emoji_events_rounded,
                size: 13,
                color: (kPlaceMedals[place] ?? kPlaceMedals[3]!)[1],
              ),
              const SizedBox(width: 2),
              Text(
                placeLabel(place!),
                style: AppTextStyles.body(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: (kPlaceMedals[place] ?? kPlaceMedals[3]!)[1],
                ),
              ),
            ] else if (left)
              Text(
                strings.ludoSeatPanelLeft,
                style: AppTextStyles.body(fontSize: 11, color: AppColors.error),
              )
            else ...[
              Icon(Icons.home_rounded, size: 13, color: seat),
              const SizedBox(width: 2),
              Text(
                '$home/4',
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              if (missedTurns > 0) ...[
                const SizedBox(width: 6),
                // Their time ran out: their turns are played for them.
                const AwayMark(),
              ],
            ],
          ],
        ),
      ],
    );

    final panel = Column(
      crossAxisAlignment: mirrored
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: mirrored ? [diceSlot, avatar] : [avatar, diceSlot],
        ),
        const SizedBox(height: 2),
        SizedBox(width: 110, child: label),
      ],
    );

    return panel;
  }
}

/// The die's slot, with the player's latest chat line popping up over it:
/// its tail toward the avatar, reaching in toward the board. Drawn above
/// the whole table, so a neighbouring seat never covers it; taps go
/// through it to the die while there is one.
class _SpeechAnchor extends StatefulWidget {
  const _SpeechAnchor({
    required this.speech,
    required this.mirrored,
    required this.passTaps,
    required this.child,
  });

  final String? speech;
  final bool mirrored;
  final bool passTaps;
  final Widget child;

  @override
  State<_SpeechAnchor> createState() => _SpeechAnchorState();
}

class _SpeechAnchorState extends State<_SpeechAnchor> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  @override
  void initState() {
    super.initState();
    _portal.show();
  }

  @override
  Widget build(BuildContext context) {
    final speech = widget.speech;
    final side = widget.mirrored ? Alignment.centerRight : Alignment.centerLeft;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => speech == null
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.topLeft,
              child: CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: side,
                followerAnchor: side,
                offset: Offset(widget.mirrored ? 6 : -6, 0),
                child: IgnorePointer(
                  ignoring: widget.passTaps,
                  child: _SpeechBubble(text: speech, mirrored: widget.mirrored),
                ),
              ),
            ),
      child: CompositedTransformTarget(link: _link, child: widget.child),
    );
  }
}

class _AvatarFrame extends StatefulWidget {
  const _AvatarFrame({
    required this.color,
    required this.active,
    required this.dim,
    required this.winner,
    required this.child,
    this.place,
    this.msLeft,
    this.totalMs = 15000,
    this.onWarnSecond,
  });

  final Color color;
  final bool active;
  final bool dim;
  final bool winner;
  final Widget child;
  final int? place;
  final int? Function()? msLeft;
  final int totalMs;
  final ValueChanged<int>? onWarnSecond;

  @override
  State<_AvatarFrame> createState() => _AvatarFrameState();
}

class _AvatarFrameState extends State<_AvatarFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  /// The light chasing round the frame and its pulse only show on the
  /// seat whose turn it is: the others hold still, and ask for no frames.
  void _spinWhileActive() {
    if (widget.active && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.active && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _spinWhileActive();
  }

  @override
  void didUpdateWidget(covariant _AvatarFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _spinWhileActive();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Built again every frame on the seat whose turn it is (see
    // FrameIsland).
    return FrameIsland(
      size: const Size.square(56),
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, child) {
          final pulse = widget.active
              ? 0.5 + 0.5 * math.sin(_spin.value * 2 * math.pi * 2)
              : 0.0;
          final timed = widget.active && widget.msLeft != null;
          final frame = Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              // A light chasing around the frame while it's their turn
              // (or, with a turn timer, the timer itself is the border).
              gradient: widget.active && !timed
                  ? SweepGradient(
                      colors: [
                        widget.color,
                        Colors.white,
                        widget.color,
                        widget.color,
                      ],
                      stops: const [0.0, 0.12, 0.3, 1.0],
                      transform: GradientRotation(_spin.value * 2 * math.pi),
                    )
                  : null,
              color: timed
                  ? widget.color.withValues(alpha: 0.35)
                  : widget.active
                  ? null
                  : widget.color.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.25 + 0.45 * pulse),
                  blurRadius: 6 + 10 * pulse,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: AppColors.surface,
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  child!,
                  if (widget.winner)
                    const Positioned(top: -18, child: CrownIcon(size: 22)),
                  if (widget.place != null && widget.place! > 1)
                    Positioned(
                      top: -12,
                      right: -12,
                      child: _PlaceMedal(place: widget.place!),
                    ),
                ],
              ),
            ),
          );
          return Opacity(
            opacity: widget.dim ? 0.45 : 1,
            child: timed
                ? CountdownBorder(
                    msLeft: widget.msLeft!,
                    totalMs: widget.totalMs,
                    color: Color.lerp(widget.color, Colors.white, 0.2)!,
                    borderRadius: 18,
                    strokeWidth: 4,
                    onWarnSecond: widget.onWarnSecond,
                    child: frame,
                  )
                : frame,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A medal with the place on it, popping onto the avatar of someone who's
/// just finished (first place gets the crown instead).
class _PlaceMedal extends StatelessWidget {
  const _PlaceMedal({required this.place});

  final int place;

  @override
  Widget build(BuildContext context) {
    final medal = kPlaceMedals[place];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: medal ?? [Colors.white24, Colors.white12],
          ),
          border: Border.all(color: Colors.white, width: 1.4),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
        ),
        child: Text(
          '$place',
          style: AppTextStyles.display(
            fontSize: 12,
            color: medal == null ? AppColors.textPrimary : AppColors.faceInk,
          ),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.mirrored});

  final String text;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final voice = VoiceNote.isVoice(text) ? VoiceNote.parse(text) : null;
    Widget bubble = voice != null
        ? VoiceSpeechChip(note: voice)
        : VoiceNote.isVoice(text)
        ? const SizedBox.shrink()
        : isChatSticker(text)
        ? ChatSticker(id: text, size: 48)
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x55000000), blurRadius: 6),
                ],
              ),
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.faceInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
    // A white bubble (a line, a voice note) points at the avatar.
    if (voice != null || !isChatSticker(text)) {
      final tail = CustomPaint(
        size: const Size(7, 12),
        painter: _TailPainter(mirrored: mirrored),
      );
      bubble = Row(
        mainAxisSize: MainAxisSize.min,
        children: mirrored ? [bubble, tail] : [tail, bubble],
      );
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(
        scale: v,
        alignment: mirrored ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
      child: bubble,
    );
  }
}

/// A speech bubble's tail: a small white point, toward the avatar.
class _TailPainter extends CustomPainter {
  const _TailPainter({required this.mirrored});

  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = mirrored ? size.width : 0.0;
    final base = mirrored ? -1.0 : size.width + 1;
    canvas.drawPath(
      Path()
        ..moveTo(base, 0)
        ..lineTo(tip, size.height / 2)
        ..lineTo(base, size.height)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.mirrored != mirrored;
}
