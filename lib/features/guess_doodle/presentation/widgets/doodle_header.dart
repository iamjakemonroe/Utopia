import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/doodle_game.dart';
import 'doodle_chat.dart';

/// Seconds left until [endsAt] on the server's clock, as a ring that
/// drains, going red for the last ten.
class DoodleTimer extends StatefulWidget {
  const DoodleTimer({
    super.key,
    required this.endsAt,
    required this.total,
    required this.offset,
    this.size = 46,
    this.onSecond,
  });

  final DateTime? endsAt;
  final int total;

  /// Server clock minus this phone's.
  final Duration offset;
  final double size;

  /// Called as each of the last seconds starts, with the seconds left.
  final ValueChanged<int>? onSecond;

  @override
  State<DoodleTimer> createState() => _DoodleTimerState();
}

class _DoodleTimerState extends State<DoodleTimer> {
  Timer? _timer;
  int _lastSecond = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {});
      final left = _left.inMilliseconds;
      final second = (left / 1000).ceil();
      if (second != _lastSecond && left > 0) {
        _lastSecond = second;
        widget.onSecond?.call(second);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _left {
    final end = widget.endsAt;
    if (end == null) return Duration.zero;
    final left = end.difference(DateTime.now().add(widget.offset));
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final seconds = (left.inMilliseconds / 1000).ceil();
    final fraction = widget.total <= 0
        ? 0.0
        : (left.inMilliseconds / (widget.total * 1000)).clamp(0.0, 1.0);
    final urgent = seconds <= 10 && widget.endsAt != null;
    final color = urgent ? AppColors.error : AppColors.coinGold;
    final pulse = urgent
        ? 1 + 0.06 * math.sin(DateTime.now().millisecondsSinceEpoch / 90)
        : 1.0;
    return Transform.scale(
      scale: pulse,
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _RingPainter(fraction, color),
          child: Center(
            child: Text(
              widget.endsAt == null ? '' : '$seconds',
              style: AppTextStyles.display(
                fontSize: widget.size * 0.36,
                color: urgent ? AppColors.error : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    canvas.drawCircle(c, r + 2, Paint()..color = Colors.black38);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: 0.15),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// What the word looks like from here: blanks for guessers (hint letters
/// pop in as they're shown), the word for the drawer and anyone who's
/// guessed it, gold once the turn's over.
class DoodleWordBar extends StatelessWidget {
  const DoodleWordBar({
    super.key,
    required this.mask,
    required this.word,
    required this.revealed,
    required this.guessed,
    required this.drawing,
  });

  final String? mask;

  /// Known to this player: they're drawing it, or guessed it.
  final String? word;

  /// The turn's over and this was the word.
  final String? revealed;
  final bool guessed;

  /// This player is the drawer.
  final bool drawing;

  @override
  Widget build(BuildContext context) {
    final content = _content();
    if (content == null) return const SizedBox.shrink();
    // On a soft plate, so it reads over any world.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: content,
    );
  }

  Widget? _content() {
    final shown = revealed ?? word;
    if (shown != null) {
      final color = revealed != null
          ? AppColors.coinGold
          : guessed
          ? const Color(0xFF6BF0B0)
          : Colors.white;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (drawing && revealed == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Draw',
                style: AppTextStyles.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (guessed && revealed == null)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Color(0xFF6BF0B0),
              ),
            ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(shown),
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: Text(
                  shown.toUpperCase(),
                  style: AppTextStyles.display(
                    fontSize: 24,
                    color: color,
                  ).copyWith(letterSpacing: 3),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final m = mask;
    if (m == null) return null;
    final words = maskWords(m);
    final letters = words.fold<int>(0, (n, w) => n + w.length);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var w = 0; w < words.length; w++) ...[
                  if (w > 0) const SizedBox(width: 14),
                  for (final ch in words[w]) _Blank(letter: ch),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          words.length == 1 ? '$letters' : words.map((w) => w.length).join(' '),
          style: AppTextStyles.body(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Blank extends StatelessWidget {
  const _Blank({required this.letter});

  final String? letter;

  @override
  Widget build(BuildContext context) {
    final l = letter;
    return Container(
      width: 20,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: l == null
                ? Colors.white.withValues(alpha: 0.7)
                : AppColors.coinGold,
            width: 3,
          ),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (child, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
          child: child,
        ),
        child: l == null || l == '-'
            ? Text(
                l ?? '',
                key: ValueKey('blank$l'),
                style: AppTextStyles.display(fontSize: 18),
              )
            : Text(
                l.toUpperCase(),
                key: ValueKey(l),
                style: AppTextStyles.display(
                  fontSize: 20,
                  color: AppColors.coinGold,
                ),
              ),
      ),
    );
  }
}

/// Everyone playing, in drawing order: the drawer wears a brush, those
/// who've guessed a check, the leader a crown; points pop up as they land.
class DoodlePlayersStrip extends ConsumerWidget {
  const DoodlePlayersStrip({
    super.key,
    required this.players,
    required this.game,
    required this.me,
    required this.colorOf,
  });

  final List<DoodlePlayer> players;
  final DoodleGame game;
  final String? me;
  final Color Function(String? userId) colorOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = players.fold<int>(0, (m, p) => math.max(m, p.score));
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: players.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final p = players[i];
          return _PlayerChip(
            key: ValueKey(p.userId),
            player: p,
            name: doodleName(ref, p.userId, me),
            profile: ref.watch(profileByIdProvider(p.userId)).valueOrNull,
            color: colorOf(p.userId),
            drawing: game.drawerId == p.userId && game.playing,
            guessed: p.guessedTurn == game.turn && game.playing,
            leading: top > 0 && p.score == top,
            host: !game.isPublic && game.hostId == p.userId,
          );
        },
      ),
    );
  }
}

class _PlayerChip extends StatefulWidget {
  const _PlayerChip({
    super.key,
    required this.player,
    required this.name,
    required this.profile,
    required this.color,
    required this.drawing,
    required this.guessed,
    required this.leading,
    required this.host,
  });

  final DoodlePlayer player;
  final String name;
  final Map<String, dynamic>? profile;
  final Color color;
  final bool drawing;
  final bool guessed;
  final bool leading;
  final bool host;

  @override
  State<_PlayerChip> createState() => _PlayerChipState();
}

class _PlayerChipState extends State<_PlayerChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gain = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  int _gained = 0;

  @override
  void didUpdateWidget(covariant _PlayerChip old) {
    super.didUpdateWidget(old);
    final diff = widget.player.score - old.player.score;
    if (diff > 0) {
      _gained = diff;
      _gain.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _gain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.guessed
                      ? const Color(0xFF2FD98E)
                      : widget.drawing
                      ? AppColors.coinGold
                      : widget.color,
                  boxShadow: widget.drawing || widget.guessed
                      ? [
                          BoxShadow(
                            color:
                                (widget.guessed
                                        ? const Color(0xFF2FD98E)
                                        : AppColors.coinGold)
                                    .withValues(alpha: 0.6),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: UserAvatar.fromProfile(
                  widget.profile,
                  fallbackInitial: widget.name.isEmpty ? '?' : widget.name[0],
                  radius: 19,
                  showAura: false,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Text(
                  '${widget.player.score}',
                  key: ValueKey(widget.player.score),
                  style: AppTextStyles.body(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.coinGold,
                  ),
                ),
              ),
            ],
          ),
          if (widget.drawing)
            const Positioned(
              right: 4,
              top: 0,
              child: _Badge(
                icon: Icons.brush_rounded,
                color: Color(0xFFFFB020),
              ),
            )
          else if (widget.guessed)
            const Positioned(
              right: 4,
              top: 0,
              child: _Badge(
                icon: Icons.check_rounded,
                color: Color(0xFF2FD98E),
              ),
            ),
          if (widget.leading)
            const Positioned(
              left: 4,
              top: -2,
              child: _Badge(
                icon: Icons.emoji_events_rounded,
                color: Color(0xFFFFC94D),
              ),
            )
          else if (widget.host)
            const Positioned(
              left: 4,
              top: -2,
              child: _Badge(icon: Icons.star_rounded, color: Color(0xFF7B5CFF)),
            ),
          AnimatedBuilder(
            animation: _gain,
            builder: (context, _) {
              final v = _gain.value;
              if (v == 0 || v == 1) return const SizedBox.shrink();
              return Positioned(
                top: 6 - 26 * Curves.easeOut.transform(v),
                child: Opacity(
                  opacity: v < 0.7 ? 1 : 1 - (v - 0.7) / 0.3,
                  child: Text(
                    '+$_gained',
                    style: AppTextStyles.display(
                      fontSize: 15,
                      color: const Color(0xFF6BF0B0),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(icon, size: 11, color: Colors.white),
    );
  }
}
