import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../coins/presentation/player_coins.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/countdown_border.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../domain/ludo_engine.dart';
import '../../../chat/domain/voice_note.dart';
import '../../../chat/presentation/chat_sticker.dart';
import 'ludo_pieces.dart';
import '../../../chat/presentation/voice_notes.dart';

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
        ? 'You'
        : (userId == null ? 'Open seat' : profileDisplayName(profile, userId!));
    final seat = ludoColorPalette[color]!;

    final avatar = GestureDetector(
      onTap: userId == null ? null : onAvatarTap,
      child: _AvatarFrame(
        color: seat,
        active: isTurn && !left,
        dim: left,
        winner: winner,
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

    final diceSlot = SizedBox(
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
            if (left)
              Text(
                'Left',
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
                // Missed turns: three and they're out.
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 11,
                      color: i < missedTurns
                          ? const Color(0xFFFF4D5E)
                          : AppColors.textSecondary.withValues(alpha: 0.35),
                    ),
                  ),
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        panel,
        if (speech != null)
          Positioned(
            left: mirrored ? null : 0,
            right: mirrored ? 0 : null,
            bottom: 70,
            child: _SpeechBubble(text: speech!, mirrored: mirrored),
          ),
      ],
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
    this.msLeft,
    this.totalMs = 15000,
    this.onWarnSecond,
  });

  final Color color;
  final bool active;
  final bool dim;
  final bool winner;
  final Widget child;
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
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.mirrored});

  final String text;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(
        scale: v,
        alignment: mirrored ? Alignment.bottomRight : Alignment.bottomLeft,
        child: child,
      ),
      child: VoiceNote.isVoice(text)
          ? (VoiceNote.parse(text) == null
                ? const SizedBox.shrink()
                : VoiceSpeechChip(note: VoiceNote.parse(text)!))
          : isChatSticker(text)
          ? ChatSticker(id: text, size: 48)
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(mirrored ? 14 : 2),
                    bottomRight: Radius.circular(mirrored ? 2 : 14),
                  ),
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
            ),
    );
  }
}
