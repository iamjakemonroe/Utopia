import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_tick.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auras/presentation/mythic_badge.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/providers/friends_providers.dart';
import '../domain/ranking.dart';
import 'hologram/rank_hologram.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../l10n/strings.dart';

/// Medal colors for the top three.
const kGoldMedal = AppColors.coinGold;
const kSilverMedal = Color(0xFFCAD5E6);
const kBronzeMedal = Color(0xFFD9935A);

Color? medalFor(int place) => switch (place) {
  1 => kGoldMedal,
  2 => kSilverMedal,
  3 => kBronzeMedal,
  _ => null,
};

// ── the tier badge ─────────────────────────────────────────────────────────

/// A tier's badge: a glossy hexagon in its color, with one to three stars
/// (Bronze to Gold), a diamond, or Legend's bolt, with lightning crackling
/// around it (like Mythic auras).
class TierEmblem extends StatelessWidget {
  const TierEmblem({
    super.key,
    required this.tier,
    this.size = 64,
    this.dim = false,
  });

  final RankTier tier;
  final double size;

  /// Not reached yet: faded.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    // Legend crackles (big enough to see it; the tiny ones in lists stay
    // still).
    if (!dim && tier == RankTier.legend && size >= 22) {
      return _Crackling(
        size: size,
        color: tier.color,
        mark: Center(child: _mark()),
      );
    }
    final emblem = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _EmblemPainter(tier.color, glow: !dim),
        child: Center(child: _mark()),
      ),
    );
    return dim ? Opacity(opacity: 0.32, child: emblem) : emblem;
  }

  Widget _mark() {
    const white = Colors.white;
    return switch (tier) {
      RankTier.diamond => Icon(
        Icons.diamond_rounded,
        size: size * 0.44,
        color: white,
      ),
      RankTier.legend => Icon(
        Icons.bolt_rounded,
        size: size * 0.52,
        color: white,
        shadows: [Shadow(color: kMythicRed, blurRadius: size * 0.12)],
      ),
      _ => Padding(
        padding: EdgeInsets.only(top: size * 0.02),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i <= tier.index; i++)
              Icon(
                Icons.star_rounded,
                size: size * const [0.44, 0.3, 0.23][tier.index],
                color: white,
              ),
          ],
        ),
      ),
    };
  }
}

/// Lightning jumping around [child], and a glow that flashes with it.
class _Crackling extends StatefulWidget {
  const _Crackling({
    required this.size,
    required this.color,
    required this.mark,
  });

  final double size;
  final Color color;
  final Widget mark;

  @override
  State<_Crackling> createState() => _CracklingState();
}

class _CracklingState extends State<_Crackling>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      ambientTick((e) => _t.value = e.inMicroseconds / 1e6),
    )..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return ValueListenableBuilder<double>(
      valueListenable: _t,
      builder: (context, t, mark) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _EmblemPainter(
            widget.color,
            glow: true,
            flash: mythicFlash(t),
          ),
          foregroundPainter: CracklePainter(t: t, scale: size * 0.42),
          child: mark,
        ),
      ),
      child: widget.mark,
    );
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.color, {required this.glow, this.flash = 0});

  final Color color;
  final bool glow;

  /// 0 to 1: the glow flaring with a lightning flash.
  final double flash;

  static Path hexagon(Offset c, double r) {
    final path = Path();
    for (var k = 0; k < 6; k++) {
      final a = -math.pi / 2 + k * math.pi / 3;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final outer = hexagon(c, r * 0.94);
    if (glow) {
      canvas.drawPath(
        outer,
        Paint()
          ..color = color.withValues(alpha: 0.55 + 0.45 * flash)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            r * (0.18 + 0.22 * flash),
          ),
      );
    }
    final bounds = Rect.fromCircle(center: c, radius: r);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.5)!,
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
          stops: const [0, 0.5, 1],
        ).createShader(bounds),
    );
    // A gloss over the top half.
    canvas.save();
    canvas.clipPath(outer);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, -r * 0.55),
        width: r * 2.2,
        height: r * 1.1,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();
    canvas.drawPath(
      hexagon(c, r * 0.76),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(color, Colors.black, 0.45)!,
    );
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) =>
      old.color != color || old.glow != glow || old.flash != flash;
}

// ── numbers ────────────────────────────────────────────────────────────────

/// [value], counting up to it (and on to the next, when it changes).
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value * 0.85, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// "+45 this week", up or down.
class TrendChip extends StatelessWidget {
  const TrendChip(this.delta, {super.key});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final up = delta > 0;
    final color = up ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            strings.rankingsThisWeek(up ? '+' : '', delta),
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── the rating line ────────────────────────────────────────────────────────

/// The player's rating over their last games, as a line.
class RatingSparkline extends StatelessWidget {
  const RatingSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 58,
  });

  final List<int> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _SparkPainter(values, color, t),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.reveal);

  final List<int> values;
  final Color color;

  /// How much of the line is drawn, 0 to 1 (it draws itself in).
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.reduce(math.min).toDouble();
    var hi = values.reduce(math.max).toDouble();
    if (hi - lo < 20) {
      final mid = (hi + lo) / 2;
      lo = mid - 10;
      hi = mid + 10;
    }
    const pad = 6.0;
    Offset at(int i) => Offset(
      pad + (size.width - 2 * pad) * i / (values.length - 1),
      pad + (size.height - 2 * pad) * (1 - (values[i] - lo) / (hi - lo)),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = at(i - 1);
      final b = at(i);
      final mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));
    final fill = Path.from(line)
      ..lineTo(at(values.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
    if (reveal > 0.98) {
      final last = at(values.length - 1);
      canvas.drawCircle(last, 6, Paint()..color = Colors.white);
      canvas.drawCircle(last, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.reveal != reveal || old.color != color || old.values != values;
}

// ── the tier ladder ────────────────────────────────────────────────────────

/// Every tier in a row, the ones reached lit up, with the player's spot
/// along the track and how far it is to the next.
class TierLadder extends StatelessWidget {
  const TierLadder({super.key, required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final tier = RankTier.of(rating);
    final next = tier.next;
    final pos = ladderPosition(rating);
    const tiers = RankTier.values;
    const badge = 34.0;
    const slot = 58.0;

    return PopCard(
      borderRadius: 22,
      depth: 2,
      borderWidth: 1.2,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final track = c.maxWidth - slot;
              double x(double f) => slot / 2 + track * f;
              return SizedBox(
                height: 80,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: x(0),
                      width: track,
                      top: badge / 2 - 2,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Positioned(
                      left: x(0),
                      width: track * pos,
                      top: badge / 2 - 2,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: [
                              for (final t in tiers.take(tier.index + 1))
                                t.color,
                              if (tier.index == 0) tier.color,
                            ],
                          ),
                        ),
                      ),
                    ),
                    for (final t in tiers)
                      Positioned(
                        left: x(t.index / (tiers.length - 1)) - slot / 2,
                        width: slot,
                        top: 0,
                        child: Column(
                          children: [
                            TierEmblem(
                              tier: t,
                              size: badge,
                              dim: rating < t.from,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.label,
                              style: AppTextStyles.body(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: t == tier
                                    ? AppColors.readable(t.color)
                                    : AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              t.from == 0 ? strings.rankingsStart : '${t.from}',
                              style: AppTextStyles.body(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // The player, between the badges (on one, its badge
                    // lit up says so already).
                    if (((pos * (tiers.length - 1)) -
                                (pos * (tiers.length - 1)).round())
                            .abs() >
                        0.06)
                      Positioned(
                        left: x(pos) - 7,
                        top: badge / 2 - 7,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: tier.color, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: tier.color.withValues(alpha: 0.8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Text(
            next == null
                ? strings.rankingsYouReALegendThe
                : strings.rankingsMoreRatingToReach(
                    next.from - rating,
                    next.label,
                  ),
            style: AppTextStyles.body(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── the podium ─────────────────────────────────────────────────────────────

/// The top three on their steps: first in the middle and highest, with a
/// crown. Open steps wait for someone to take them.
class Podium extends StatelessWidget {
  const Podium({
    super.key,
    required this.top,
    required this.myId,
    required this.onTap,
  });

  final List<BoardEntry> top;
  final String? myId;
  final ValueChanged<BoardEntry> onTap;

  @override
  Widget build(BuildContext context) {
    Widget step(int i, int place, double height, int delay) {
      final e = i < top.length ? top[i] : null;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: e == null ? null : () => onTap(e),
          child: _Step(
            entry: e,
            place: place,
            height: height,
            delay: delay,
            me: e != null && e.userId == myId,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        step(1, 2, 84, 150),
        const SizedBox(width: 6),
        step(0, 1, 116, 0),
        const SizedBox(width: 6),
        step(2, 3, 64, 300),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.entry,
    required this.place,
    required this.height,
    required this.delay,
    this.me = false,
  });

  final BoardEntry? entry;
  final int place;
  final double height;
  final int delay;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final medal = medalFor(place)!;
    final e = entry;
    final radius = place == 1 ? 34.0 : 27.0;
    final name = e == null
        ? strings.rankingsOpenSpot
        : me
        ? strings.rankingsYou
        : profileDisplayName(e.profile, e.userId);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 650 + delay),
      curve: Interval(delay / (650 + delay), 1, curve: Curves.easeOutBack),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 40),
          child: child,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (place == 1)
            const SizedBox(
              width: 34,
              height: 22,
              child: CustomPaint(painter: _CrownPainter()),
            ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: medal, width: 3),
              boxShadow: [
                BoxShadow(
                  color: medal.withValues(alpha: 0.55),
                  blurRadius: place == 1 ? 18 : 10,
                ),
              ],
            ),
            child: e == null
                ? CircleAvatar(
                    radius: radius,
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    child: Icon(
                      Icons.question_mark_rounded,
                      color: AppColors.textSecondary,
                      size: radius,
                    ),
                  )
                : UserAvatar.fromProfile(
                    e.profile,
                    fallbackInitial: name,
                    radius: radius,
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: e == null ? AppColors.textSecondary : null,
            ),
          ),
          if (e != null && e.house)
            const Padding(
              padding: EdgeInsets.only(top: 2, bottom: 2),
              child: HouseTag(),
            ),
          if (e != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TierEmblem(tier: RankTier.of(e.rating), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${e.rating}',
                  style: AppTextStyles.display(
                    fontSize: 16,
                    color: AppColors.readable(RankTier.of(e.rating).color),
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 19),
          const SizedBox(height: 6),
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(medal, Colors.white, 0.25)!,
                  Color.lerp(
                    medal,
                    Colors.black,
                    0.35,
                  )!.withValues(alpha: 0.85),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 2,
                ),
              ),
              boxShadow: me
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.6),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$place',
              style:
                  AppTextStyles.display(
                    fontSize: place == 1 ? 38 : 30,
                    color: Colors.white,
                  ).copyWith(
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A little gold crown for first place.
class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final crown = Path()
      ..moveTo(w * 0.08, h * 0.9)
      ..lineTo(w * 0.02, h * 0.25)
      ..lineTo(w * 0.3, h * 0.55)
      ..lineTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.7, h * 0.55)
      ..lineTo(w * 0.98, h * 0.25)
      ..lineTo(w * 0.92, h * 0.9)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.coinGoldBright, AppColors.coinGold],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF9A6A00),
    );
    for (final x in [0.02, 0.5, 0.98]) {
      canvas.drawCircle(
        Offset(w * x, x == 0.5 ? h * 0.05 : h * 0.25),
        2.5,
        Paint()..color = AppColors.coinGoldBright,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── a row on the board ─────────────────────────────────────────────────────

class BoardRow extends StatelessWidget {
  const BoardRow({
    super.key,
    required this.entry,
    required this.me,
    required this.index,
    required this.onTap,
  });

  final BoardEntry entry;
  final bool me;

  /// Its position in the list, for the entrance stagger.
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tier = RankTier.of(entry.rating);
    final name = me
        ? strings.rankingsYou
        : profileDisplayName(entry.profile, entry.userId);
    final delay = math.min(index, 10) * 40;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay),
      curve: Interval(delay / (380 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: PopCard(
          borderRadius: 18,
          depth: 2,
          borderWidth: me ? 2 : 1.2,
          tint: me ? AppColors.accent : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '#${entry.place}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w800,
                    color: me ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              UserAvatar.fromProfile(
                entry.profile,
                fallbackInitial: name,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (entry.house) ...[
                          const SizedBox(width: 6),
                          const HouseTag(),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        TierEmblem(tier: tier, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          strings.rankingsGames(tier.label, entry.games),
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${entry.rating}',
                style: AppTextStyles.display(
                  fontSize: 20,
                  color: AppColors.readable(tier.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marks one of Utopia's house players on a board.
class HouseTag extends StatelessWidget {
  const HouseTag({super.key, this.big = false});

  /// "House player", for their card; otherwise just "House".
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 13.0 : 10.5;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 10 : 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy_rounded,
            size: size + 2,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 3),
          Text(
            big ? strings.rankingsHousePlayer : strings.rankingsHouse,
            style: AppTextStyles.body(
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The player's own place, pinned to the bottom when they're further down
/// than the board shows.
class MeBar extends StatelessWidget {
  const MeBar({
    super.key,
    required this.place,
    required this.rating,
    required this.profile,
  });

  final int place;
  final int rating;
  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final tier = RankTier.of(rating);
    return PopCard(
      borderRadius: 20,
      tint: AppColors.accent,
      glow: AppColors.accent,
      borderWidth: 2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text('#$place', style: AppTextStyles.display(fontSize: 20)),
          const SizedBox(width: 12),
          UserAvatar.fromProfile(profile, fallbackInitial: 'Y', radius: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.rankingsYou,
              style: AppTextStyles.body(fontWeight: FontWeight.w800),
            ),
          ),
          TierEmblem(tier: tier, size: 24),
          const SizedBox(width: 6),
          Text(
            '$rating',
            style: AppTextStyles.display(
              fontSize: 20,
              color: AppColors.readable(tier.color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── sheets ─────────────────────────────────────────────────────────────────

/// A player from the board: their tier, rating and place, and a way to add
/// them as a friend.
Future<void> showBoardPlayer(
  BuildContext context, {
  required BoardEntry entry,
  required String game,
  required String gameName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _BoardPlayerSheet(entry: entry, game: game, gameName: gameName),
  );
}

final _friendshipProvider = FutureProvider.autoDispose
    .family<FriendshipStatus, String>((ref, userId) {
      final me = ref.watch(currentUserProvider)?.id;
      if (me == null) return FriendshipStatus.none;
      if (me == userId) return FriendshipStatus.self;
      return ref.watch(friendRepositoryProvider).friendshipStatus(me, userId);
    });

class _BoardPlayerSheet extends ConsumerStatefulWidget {
  const _BoardPlayerSheet({
    required this.entry,
    required this.game,
    required this.gameName,
  });

  final BoardEntry entry;
  final String game;
  final String gameName;

  @override
  ConsumerState<_BoardPlayerSheet> createState() => _BoardPlayerSheetState();
}

class _BoardPlayerSheetState extends ConsumerState<_BoardPlayerSheet> {
  bool _sending = false;

  Future<void> _add() async {
    setState(() => _sending = true);
    try {
      // Sending to someone who already asked accepts their request.
      await ref
          .read(friendRepositoryProvider)
          .sendFriendRequest(widget.entry.userId);
      ref.read(gameAudioProvider).play(Sfx.reaction);
      ref.invalidate(_friendshipProvider(widget.entry.userId));
    } catch (_) {
      if (mounted) {
        showUtopiaToast(
          context,
          strings.rankingsCouldnTSendTheRequest,
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final tier = RankTier.of(e.rating);
    final name = profileDisplayName(e.profile, e.userId);
    final username = e.profile['username'] as String?;
    final isGuest = ref.watch(isAnonymousProvider);
    final status = ref.watch(_friendshipProvider(e.userId)).valueOrNull;
    // Their hologram, unless they keep their stats to themselves.
    final showsStats =
        ref.watch(profileByIdProvider(e.userId)).valueOrNull?['show_stats'] !=
        false;
    final self = status == FriendshipStatus.self;

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.display(fontSize: 22)),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: PopCard(
          borderRadius: 28,
          tint: tier.color,
          glow: tier.color,
          sheet: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar.fromProfile(
                    e.profile,
                    fallbackInitial: name,
                    radius: 40,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(name, style: AppTextStyles.display(fontSize: 22)),
                  if (username != null)
                    Text(
                      '@$username',
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                  if (e.house) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const HouseTag(big: true),
                    const SizedBox(height: 6),
                    Text(
                      strings.rankingsOneOfUtopiaSHouse,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TierEmblem(tier: tier, size: 40),
                      const SizedBox(width: 8),
                      Text(
                        '${tier.label} in ${widget.gameName}',
                        style: AppTextStyles.body(
                          fontWeight: FontWeight.w800,
                          color: AppColors.readable(tier.color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      stat('${e.rating}', strings.rankingsRating),
                      stat('#${e.place}', strings.rankingsPlace),
                      stat('${e.games}', strings.rankingsRatedGames),
                    ],
                  ),
                  if (status != null &&
                      status != FriendshipStatus.self &&
                      !isGuest &&
                      !e.house) ...[
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: switch (status) {
                        FriendshipStatus.friends => strings.rankingsFriends,
                        FriendshipStatus.requested =>
                          strings.rankingsRequestSent,
                        FriendshipStatus.incoming =>
                          strings.rankingsAcceptFriendRequest,
                        _ => strings.rankingsAddFriend,
                      },
                      color: AppColors.success,
                      onPressed:
                          _sending ||
                              status == FriendshipStatus.friends ||
                              status == FriendshipStatus.requested
                          ? null
                          : _add,
                    ),
                  ],
                ],
              ),
              // Their stats as a hologram, the way their own shows them.
              if (showsStats)
                Positioned(
                  top: -10,
                  right: -10,
                  child: IconButton(
                    tooltip: self
                        ? strings.rankingsSeeMyStats
                        : strings.rankingsSeeTheirStats,
                    onPressed: () => showRankHologram(
                      context,
                      game: widget.game,
                      rating: e.rating,
                      place: e.place,
                      user: self ? null : e.userId,
                      name: self ? null : name,
                    ),
                    icon: Icon(
                      Icons.query_stats_rounded,
                      color: AppColors.readable(tier.color),
                      size: 26,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How rankings work: the tiers, and what moves a rating.
Future<void> showTierGuide(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: PopCard(
          borderRadius: 28,
          sheet: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.rankingsHowRankingsWork,
                style: AppTextStyles.display(fontSize: 22),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.rankingsEveryoneStartsAt1000In(kGamesToRank),
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final t in RankTier.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      TierEmblem(tier: t, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.label,
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w800,
                            color: AppColors.readable(t.color),
                          ),
                        ),
                      ),
                      Text(
                        switch (t.next) {
                          final n? =>
                            '${t.from == 0 ? 'Up' : t.from} to ${n.from - 1}',
                          null => strings.rankingsAndUp(t.from),
                        },
                        style: AppTextStyles.body(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                strings.rankingsTheSameTwoPlayersCount,
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
