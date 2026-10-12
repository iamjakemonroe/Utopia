import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/entry_selector.dart';
import '../../../../core/widgets/outlined_heading.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../chat/domain/voice_note.dart';
import '../../../chat/presentation/chat_sticker.dart';
import '../../../chat/presentation/voice_notes.dart';
import '../../domain/time_control.dart';

/// The parts of a live board game's screen that chess and checkers share:
/// the chat button, a player's chat bubble and clock, the strip of moves,
/// and the result card.

class MatchChatButton extends StatelessWidget {
  const MatchChatButton({super.key, required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Chat',
          icon: const Icon(Icons.chat_bubble_rounded),
          onPressed: onTap,
        ),
        if (unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: AppTextStyles.body(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// What a player just said, inside their bar: a line of text, a sticker,
/// or a voice note (tap to play).
class SpeechPill extends StatelessWidget {
  const SpeechPill({super.key, required this.kind, required this.body});

  final String kind;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (kind == 'voice') {
      final note = VoiceNote.parse(body);
      if (note != null) return VoiceSpeechChip(note: note);
    }
    if (kind == 'emote' || isChatSticker(body)) {
      return ChatSticker(id: body, size: 30);
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
      ),
      child: Text(
        body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.faceInk,
        ),
      ),
    );
  }
}

/// A player's clock. Lit while it's running; red and pulsing under ten
/// seconds.
class ClockPill extends StatefulWidget {
  const ClockPill({super.key, required this.msLeft, required this.running});

  final int Function() msLeft;
  final bool running;

  @override
  State<ClockPill> createState() => _ClockPillState();
}

class _ClockPillState extends State<ClockPill>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Started here: a lazy field would only be created (and started)
    // on first use, which for a ticker is never.
    _ticker = createTicker((_) => _sync());
    if (widget.running) _ticker.start();
  }

  late int _ms = widget.msLeft();

  /// Rebuilds only when the time on the pill (or the last-seconds pulse)
  /// would actually change.
  void _sync() {
    final ms = widget.msLeft();
    final low = ms < 10000;
    final changed = low
        ? ms ~/ 33 != _ms ~/ 33
        : formatClock(ms) != formatClock(_ms);
    if (changed || (low != (_ms < 10000))) {
      setState(() => _ms = ms);
    } else {
      _ms = ms;
    }
  }

  @override
  void didUpdateWidget(covariant ClockPill old) {
    super.didUpdateWidget(old);
    // A stopped clock doesn't change: no need to watch it.
    if (widget.running && !_ticker.isActive) _ticker.start();
    if (!widget.running && _ticker.isActive) _ticker.stop();
    _ms = widget.msLeft();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final low = _ms < 10000;
    final beat = low && widget.running ? 1 - (_ms % 1000) / 1000 : 0.0;
    final bg = widget.running
        ? (low
              ? Color.lerp(const Color(0xFFFF4D5E), Colors.white, 0.2 * beat)!
              : Colors.white)
        : Colors.black.withValues(alpha: 0.28);
    final fg = widget.running
        ? (low ? Colors.white : const Color(0xFF1B1433))
        : (low ? const Color(0xFFFF8A95) : AppColors.textSecondary);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: widget.running
            ? [
                BoxShadow(
                  color: (low ? const Color(0xFFFF4D5E) : Colors.white)
                      .withValues(alpha: 0.35 + 0.3 * beat),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.running) ...[
            Icon(Icons.timer_rounded, size: 15, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            formatClock(_ms),
            style: AppTextStyles.display(
              fontSize: 19,
              color: fg,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// The game's moves in a strip, with buttons to step back and forward
/// through them. Tap a move to jump straight to it.
class MoveStrip extends StatefulWidget {
  const MoveStrip({
    super.key,
    required this.labels,
    required this.displayPly,
    required this.reviewing,
    required this.onBack,
    required this.onForward,
    required this.onJump,
  });

  /// Each move's notation, oldest first.
  final List<String> labels;

  /// Moves shown on the board (0 is the start).
  final int displayPly;

  /// Looking back rather than following live.
  final bool reviewing;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final ValueChanged<int> onJump;

  @override
  State<MoveStrip> createState() => _MoveStripState();
}

class _MoveStripState extends State<MoveStrip> {
  final _current = GlobalKey();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _follow(animate: false);
  }

  @override
  void didUpdateWidget(covariant MoveStrip old) {
    super.didUpdateWidget(old);
    if (old.displayPly != widget.displayPly ||
        old.labels.length != widget.labels.length) {
      _follow();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the move on the board in view.
  void _follow({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _current.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: animate ? const Duration(milliseconds: 260) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ply = widget.displayPly;
    final history = widget.labels;
    final canBack = ply > 0;
    final canForward = widget.reviewing && ply < history.length;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        color: AppColors.surface.withValues(alpha: 0.88),
        border: Border.all(
          color: (widget.reviewing ? AppColors.sky : AppColors.glowRing)
              .withValues(alpha: 0.5),
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous move',
            enabled: canBack,
            onTap: widget.onBack,
            onLongPress: () => widget.onJump(0),
          ),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'Moves will show up here',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    children: [
                      _MoveChip(
                        key: ply == 0 ? _current : null,
                        label: 'Start',
                        selected: ply == 0,
                        onTap: () => widget.onJump(0),
                      ),
                      for (final (i, label) in history.indexed)
                        _MoveChip(
                          key: ply == i + 1 ? _current : null,
                          number: i.isEven ? '${i ~/ 2 + 1}.' : null,
                          label: label,
                          selected: ply == i + 1,
                          latest: i == history.length - 1,
                          onTap: () => widget.onJump(i + 1),
                        ),
                    ],
                  ),
          ),
          _StepButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next move',
            enabled: canForward,
            onTap: widget.onForward,
            onLongPress: () => widget.onJump(history.length),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    colors: [
                      Color.lerp(AppColors.accent, Colors.white, 0.3)!,
                      AppColors.accent,
                    ],
                  )
                : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: enabled
                  ? AppColors.goldBorder
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.4,
            ),
          ),
          child: Icon(
            icon,
            size: 26,
            color: enabled ? Colors.white : Colors.white24,
          ),
        ),
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  const _MoveChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.number,
    this.latest = false,
  });

  final String? number;
  final String label;
  final bool selected;
  final bool latest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (number != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 2),
                child: Text(
                  number!,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: selected
                    ? AppColors.coinGold
                    : latest
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: Text(
                label,
                style: AppTextStyles.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.faceInk : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Under the board once the game is over and the result card is put away.
class AfterGameBar extends StatelessWidget {
  const AfterGameBar({
    super.key,
    required this.won,
    required this.onResult,
    required this.playAgainRoute,
  });

  final bool won;
  final VoidCallback onResult;

  /// The game's lobby.
  final String playAgainRoute;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(
            label: won ? 'Your win' : 'Result',
            color: won ? AppColors.coinGold : AppColors.accent,
            onPressed: onResult,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: PrimaryButton(
            label: 'Play again',
            color: AppColors.success,
            onPressed: () => context.go(playAgainRoute),
          ),
        ),
      ],
    );
  }
}

/// The end of the game: who won and how, both players face to face with a
/// crown on the winner, the prize counting up, and what to do next.
class MatchResultCard extends ConsumerStatefulWidget {
  const MatchResultCard({
    super.key,
    required this.result,
    required this.winnerId,
    required this.settled,
    required this.disputed,
    required this.stake,
    required this.myId,
    required this.opponentId,
    required this.onReview,
    required this.playAgainRoute,
    this.describe,
  });

  /// How it ended: 'resignation', 'timeout', 'aborted', 'draw', or the
  /// game's own words ('checkmate', 'win', ...).
  final String? result;
  final String? winnerId;

  /// False until the server confirms the result (prizes are paid then).
  final bool settled;

  /// The two players reported different results.
  final bool disputed;
  final int stake;

  /// The line under the title for the game's own results, given whether
  /// this player won; null falls back to the shared ones.
  final String? Function(String? result, bool won)? describe;
  final String playAgainRoute;
  final String? myId;
  final String? opponentId;
  final VoidCallback onReview;

  @override
  ConsumerState<MatchResultCard> createState() => _MatchResultCardState();
}

class _MatchResultCardState extends ConsumerState<MatchResultCard>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _enter.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.myId;
    final stake = widget.stake;
    final winnerId = widget.winnerId;
    final aborted = widget.result == 'aborted';
    final iWon = winnerId != null && winnerId == myId;
    final iLost = winnerId != null && !iWon;
    final disputed = widget.disputed;
    final glow = iWon
        ? AppColors.coinGold
        : iLost
        ? AppColors.error
        : AppColors.sky;

    final title = disputed
        ? 'Under review'
        : aborted
        ? 'Called off'
        : iWon
        ? 'Victory!'
        : iLost
        ? 'Defeat'
        : 'Draw';
    final subtitle = switch (widget.result) {
      _ when disputed =>
        "You and your opponent reported different results. We'll sort it out.",
      final r when widget.describe?.call(r, iWon) != null => widget.describe!(
        r,
        iWon,
      )!,
      'resignation' => iWon ? 'Your opponent resigned.' : 'You resigned.',
      'draw' => 'Nobody can win from here.',
      'timeout' => iWon ? 'Their clock ran out.' : 'Your clock ran out.',
      'aborted' =>
        stake > 0
            ? "A first move didn't come in time. Your coins are back."
            : "A first move didn't come in time.",
      _ => '',
    };
    final prize = prizeFor(stake, 2);
    final showPrize = stake > 0 && !aborted && !disputed;

    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final t = _enter.value;
        final fade = Curves.easeOut.transform((t * 2).clamp(0.0, 1.0));
        final pop = Curves.elasticOut.transform(t);
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: widget.onReview,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6 * fade, sigmaY: 6 * fade),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.55 * fade),
                ),
              ),
            ),
            Center(
              child: Opacity(
                opacity: fade,
                child: Transform.scale(scale: 0.6 + 0.4 * pop, child: child),
              ),
            ),
          ],
        );
      },
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: PopCard(
              borderRadius: 32,
              tint: glow,
              glow: glow,
              borderWidth: 2.4,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _spin,
                          builder: (context, _) => CustomPaint(
                            size: const Size(200, 150),
                            painter: _RaysPainter(
                              turn: _spin.value,
                              color: glow,
                              bright: iWon,
                            ),
                          ),
                        ),
                        _Duel(
                          myId: myId,
                          opponentId: widget.opponentId,
                          winnerId: winnerId,
                        ),
                      ],
                    ),
                  ),
                  OutlinedHeading(
                    title,
                    fontSize: 34,
                    fillColor: iWon ? AppColors.coinGoldBright : Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  if (showPrize) ...[
                    const SizedBox(height: AppSpacing.md),
                    if (!widget.settled)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const UtopiaLoader(size: 22),
                          const SizedBox(width: 8),
                          Text(
                            iWon ? 'Sending your prize' : 'Wrapping up',
                            style: AppTextStyles.body(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    else if (iWon || iLost)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.black.withValues(alpha: 0.25),
                            border: Border.all(
                              color:
                                  (iWon ? AppColors.success : AppColors.error)
                                      .withValues(alpha: 0.6),
                            ),
                          ),
                          child: CoinAmount(
                            ((iWon ? prize : stake) * v).round(),
                            prefix: iWon ? '+' : '-',
                            size: 22,
                            color: iWon ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Home',
                          onPressed: () => context.go('/home'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Play again',
                          color: AppColors.success,
                          onPressed: () => context.go(widget.playAgainRoute),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: widget.onReview,
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Review the game'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Both players side by side; the winner gets a crown and stands a little
/// taller.
class _Duel extends ConsumerWidget {
  const _Duel({
    required this.myId,
    required this.opponentId,
    required this.winnerId,
  });

  final String? myId;
  final String? opponentId;
  final String? winnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget player(String? id, bool me) {
      final profile = id == null
          ? null
          : ref.watch(profileByIdProvider(id)).valueOrNull;
      final name = me
          ? 'You'
          : id == null
          ? 'Opponent'
          : profileDisplayName(profile, id);
      final won = winnerId != null && winnerId == id;
      final lost = winnerId != null && !won;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.translate(
          offset: Offset(0, won ? -10 * v : 0),
          child: Transform.scale(scale: won ? 1 + 0.12 * v : 1, child: child),
        ),
        child: Opacity(
          opacity: lost ? 0.7 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 22,
                child: won ? const CrownIcon(size: 26) : null,
              ),
              UserAvatar.fromProfile(
                profile,
                fallbackInitial: name,
                radius: 30,
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 90,
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        player(myId, true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            'vs',
            style: AppTextStyles.display(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        player(opponentId, false),
      ],
    );
  }
}

/// Slow-turning rays behind the players: golden for a win, soft otherwise.
class _RaysPainter extends CustomPainter {
  _RaysPainter({required this.turn, required this.color, required this.bright});

  final double turn;
  final Color color;
  final bool bright;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide * 0.62;
    const rays = 14;
    for (var i = 0; i < rays; i++) {
      final a = turn * 2 * math.pi + i * 2 * math.pi / rays;
      const w = math.pi / rays * 0.5;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - w) * r, c.dy + math.sin(a - w) * r)
        ..lineTo(c.dx + math.cos(a + w) * r, c.dy + math.sin(a + w) * r)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: bright ? 0.55 : 0.25),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    canvas.drawCircle(
      c,
      r * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: bright ? 0.45 : 0.2),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.45)),
    );
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) =>
      old.turn != turn || old.color != color || old.bright != bright;
}
