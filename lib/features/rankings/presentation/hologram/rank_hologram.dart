import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/rankings_repository.dart';
import '../../domain/rank_insights.dart';
import '../../domain/ranking.dart';
import '../rankings_widgets.dart';
import 'hologram_painters.dart';
import 'reveal.dart';

/// The player's stats as a hologram: projected up from a glowing disc,
/// alive with their tier's aura (bronze dust, liquid silver, golden fire,
/// drifting diamonds, Legend's lightning), and showing everything worth
/// knowing from the games they've played.
Future<void> showRankHologram(
  BuildContext context, {
  required String game,
  required int rating,
  int? place,
  List<int> line = const [],
}) {
  final container = ProviderScope.containerOf(context);
  // A soft power-up as it projects; the readouts then make their own
  // sounds as they come up (see _In and _CountUp).
  container.read(gameAudioProvider).play(Sfx.holoOn);
  HapticFeedback.mediumImpact();
  container.invalidate(rankInsightsProvider(game));
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0xD8050310),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, _, _) =>
        _RankHologram(game: game, rating: rating, place: place, line: line),
  );
}

class _RankHologram extends ConsumerStatefulWidget {
  const _RankHologram({
    required this.game,
    required this.rating,
    required this.place,
    required this.line,
  });

  final String game;
  final int rating;
  final int? place;
  final List<int> line;

  @override
  ConsumerState<_RankHologram> createState() => _RankHologramState();
}

class _RankHologramState extends ConsumerState<_RankHologram>
    with TickerProviderStateMixin {
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((elapsed) {
    _clock.value = elapsed.inMicroseconds / 1e6;
    _thunder();
  });

  /// The tier's aura, far off, under the hologram while it's open.
  AmbientLoop? _aura;
  RankTier? _auraTier;

  /// Legend: the next big strike to thunder for.
  int _strike = 0;
  RankTier _tier = RankTier.bronze;

  /// Legend's thunder, on the beat of its big strikes (the flash and the
  /// boom together: the painter draws from the same clock).
  void _thunder() {
    if (_tier != RankTier.legend) return;
    final t = _clock.value;
    while (legendStrikeAt(_strike) <= t) {
      // Only if it's just struck (not caught up after a pause).
      if (t - legendStrikeAt(_strike) < 0.25) {
        ref
            .read(gameAudioProvider)
            .play(
              const [Sfx.hwThunder1, Sfx.hwThunder2, Sfx.hwThunder3][_strike %
                  3],
              volume: 0.8,
            );
      }
      _strike++;
    }
  }

  /// The aura's sound for [tier], started (or changed) once it's known.
  void _playAura(RankTier tier) {
    if (_auraTier == tier) return;
    _auraTier = tier;
    _aura?.stop();
    final sfx = switch (tier) {
      RankTier.bronze => Sfx.holoAmbBronze,
      RankTier.silver => Sfx.holoAmbSilver,
      RankTier.gold => Sfx.holoAmbGold,
      RankTier.diamond => Sfx.holoAmbDiamond,
      RankTier.legend => Sfx.holoAmbLegend,
    };
    // Far off: barely there under the readout (a quarter of what it was
    // at first, which still sounded too near).
    _aura = ref.read(gameAudioProvider).startAmbient(sfx, volume: 0.075);
  }

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Turned-down motion: the hologram, still.
    if (MediaQuery.disableAnimationsOf(context)) {
      _ticker.stop();
      _reveal.value = 1;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _aura?.stop();
    _ticker.dispose();
    _reveal.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(rankInsightsProvider(widget.game));
    final rating = insights.valueOrNull?.rating ?? widget.rating;
    final tier = _tier = RankTier.of(rating);
    if (_auraTier != tier) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playAura(tier);
      });
    }
    return LayoutBuilder(
      builder: (context, c) {
        final pad = MediaQuery.paddingOf(context);
        final width = math.min(440.0, c.maxWidth - 36);
        final projectorY = c.maxHeight - pad.bottom - 40;
        final bottom = projectorY - 64;
        final top = math.max(
          pad.top + 20,
          bottom - math.min(740.0, c.maxHeight * 0.82),
        );
        final panel = Rect.fromLTRB(
          (c.maxWidth - width) / 2,
          top,
          (c.maxWidth + width) / 2,
          bottom,
        );
        final stage = HoloStage(
          panel: panel,
          projector: Offset(c.maxWidth / 2, projectorY),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: HoloBackPainter(
                      tier: tier,
                      stage: stage,
                      clock: _clock,
                      reveal: _reveal,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: panel,
              child: AnimatedBuilder(
                animation: _reveal,
                builder: (context, child) {
                  final v = Curves.easeOutCubic.transform(_reveal.value);
                  return Opacity(
                    opacity: v,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(1, 0.04 + 0.96 * v, 1),
                      child: child,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Material(
                    type: MaterialType.transparency,
                    child: _Readout(
                      tier: tier,
                      game: widget.game,
                      rating: rating,
                      place: widget.place,
                      line: widget.line,
                      insights: insights,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: HoloFrontPainter(
                    tier: tier,
                    stage: stage,
                    clock: _clock,
                    reveal: _reveal,
                  ),
                ),
              ),
            ),
            Positioned(
              left: panel.right - 50,
              top: panel.top + 6,
              child: IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close_rounded, color: _hi(tier)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The tier's color, lit up a little (for text on the dark glass).
Color _hi(RankTier tier) => Color.lerp(tier.color, Colors.white, 0.25)!;

/// What the hologram says.
class _Readout extends StatefulWidget {
  const _Readout({
    required this.tier,
    required this.game,
    required this.rating,
    required this.place,
    required this.line,
    required this.insights,
  });

  final RankTier tier;
  final String game;
  final int rating;
  final int? place;
  final List<int> line;
  final AsyncValue<RankInsights> insights;

  @override
  State<_Readout> createState() => _ReadoutState();
}

class _ReadoutState extends State<_Readout> {
  /// Each readout comes up as it comes into view, scrolled to or not.
  final _reveals = ReadoutReveals();

  @override
  void dispose() {
    _reveals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _Readout(:tier, :game, :rating, :place, :line, :insights) = widget;
    final i = insights.valueOrNull;
    final sections = <Widget>[
      _Header(tier: tier, game: game, rating: rating, place: place, i: i),
      _NextTier(tier: tier, rating: rating),
      if (i == null)
        insights.hasError
            ? _Note(
                tier: tier,
                text: "COULDN'T REACH YOUR STATS. CLOSE AND TRY AGAIN.",
              )
            : _Note(tier: tier, text: 'SCANNING YOUR GAMES…')
      else if (i.games == 0)
        _Note(
          tier: tier,
          text:
              'YOUR HOLOGRAM FILLS IN AS YOU PLAY RATED '
              '${rankedGameName(game).toUpperCase()} GAMES.',
        )
      else ...[
        if (line.length >= 2) _Trend(tier: tier, line: line, i: i),
        _Record(tier: tier, i: i),
        _Tiles(tier: tier, i: i),
        if (i.boardGame && i.games > 0) _Sides(tier: tier, i: i),
        if (i.boardGame && i.winsBy.isNotEmpty)
          _Breakdown(tier: tier, title: 'HOW YOU WIN', counts: i.winsBy),
        if (i.boardGame && i.lossesBy.isNotEmpty)
          _Breakdown(tier: tier, title: 'HOW YOU LOSE', counts: i.lossesBy),
        if (i.bestWin case final p?)
          _Person(
            tier: tier,
            title: 'BEST WIN',
            person: p,
            detail: 'Rated ${p.rating} when you beat them',
          ),
        if (i.rival case final p?)
          _Person(
            tier: tier,
            title: 'YOUR RIVAL',
            person: p,
            detail: '${p.games} games · you won ${p.wins}, lost ${p.losses}',
          ),
        if (i.nemesis case final p?)
          _Person(
            tier: tier,
            title: 'YOUR NEMESIS',
            person: p,
            detail: 'Beat you ${p.losses} times',
          ),
        if (i.since case final since?)
          _Note(
            tier: tier,
            text:
                'RATED ${rankedGameName(game).toUpperCase()} SINCE '
                '${_date(since).toUpperCase()}',
            small: true,
          ),
      ],
    ];
    // Fading out at the bottom: there's more below.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.9, 1],
      ).createShader(bounds),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _reveals.look();
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
          children: [
            for (final (n, s) in sections.indexed)
              RevealOnView(
                index: n,
                reveals: _reveals,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: s,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

TextStyle _label(RankTier tier) => AppTextStyles.body(
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  color: _hi(tier),
).copyWith(letterSpacing: 2);

TextStyle _value(RankTier tier, double size, {Color color = Colors.white}) =>
    AppTextStyles.display(fontSize: size, color: color).copyWith(
      shadows: [
        Shadow(color: tier.color.withValues(alpha: 0.9), blurRadius: 12),
        Shadow(color: tier.color.withValues(alpha: 0.5), blurRadius: 3),
      ],
    );

TextStyle _small(RankTier tier) => AppTextStyles.body(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Colors.white.withValues(alpha: 0.72),
);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _date(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _signed(int n) => n > 0 ? '+$n' : '$n';

/// A box of glass in the hologram.
class _Glass extends StatelessWidget {
  const _Glass({required this.tier, required this.child});

  final RankTier tier;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: tier.color.withValues(alpha: 0.07),
      border: Border.all(color: tier.color.withValues(alpha: 0.38), width: 1.2),
    ),
    child: child,
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tier,
    required this.game,
    required this.rating,
    required this.place,
    required this.i,
  });

  final RankTier tier;
  final String game;
  final int rating;
  final int? place;
  final RankInsights? i;

  @override
  Widget build(BuildContext context) {
    final games = i?.games ?? 0;
    final where = [
      if (i?.topPercent case final top?)
        'Top $top% of ${i!.ranked} ranked players',
      if (place != null) '#$place on the board',
      if (i != null && games < kGamesToRank)
        '${kGamesToRank - games} more rated game${kGamesToRank - games == 1 ? '' : 's'} to be ranked',
    ];
    return Row(
      children: [
        TierEmblem(tier: tier, size: 74),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tier.label.toUpperCase()} · ${rankedGameName(game).toUpperCase()}',
                style: _label(tier),
              ),
              // Counting up as the header comes on, ticking like a counter.
              Grow(
                to: rating.toDouble(),
                duration: const Duration(milliseconds: 1300),
                ticks: 28,
                tickVolume: 0.45,
                builder: (context, v) =>
                    Text('${v.round()}', style: _value(tier, 46)),
              ),
              for (final line in where) Text(line, style: _small(tier)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextTier extends StatelessWidget {
  const _NextTier({required this.tier, required this.rating});

  final RankTier tier;
  final int rating;

  @override
  Widget build(BuildContext context) {
    final next = tier.next;
    final progress = next == null
        ? 1.0
        : ((rating - tier.from) / (next.from - tier.from)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                next == null
                    ? 'THE TOP TIER'
                    : '${next.from - rating} TO ${next.label.toUpperCase()}',
                style: _label(tier),
              ),
            ),
            if (next != null) TierEmblem(tier: next, size: 22, dim: true),
          ],
        ),
        const SizedBox(height: 6),
        _HoloBar(tier: tier, value: progress),
      ],
    );
  }
}

class _HoloBar extends StatelessWidget {
  const _HoloBar({required this.tier, required this.value});

  final RankTier tier;
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = tier.color;
    return Grow(
      to: value,
      duration: const Duration(milliseconds: 1100),
      builder: (context, v) => Container(
        height: 9,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: [
                  c.withValues(alpha: 0.6),
                  Color.lerp(c, Colors.white, 0.4)!,
                ],
              ),
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.tier, required this.text, this.small = false});

  final RankTier tier;
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: small ? 0 : 18),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: _label(tier).copyWith(fontSize: small ? 10 : 12),
    ),
  );
}

class _Trend extends StatelessWidget {
  const _Trend({required this.tier, required this.line, required this.i});

  final RankTier tier;
  final List<int> line;
  final RankInsights i;

  @override
  Widget build(BuildContext context) {
    Widget move(int n, String when) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _signed(n),
            style: _value(
              tier,
              16,
              color: n >= 0 ? const Color(0xFF6CFFB0) : const Color(0xFFFF8A8A),
            ),
          ),
          TextSpan(text: '  $when', style: _label(tier)),
        ],
      ),
    );
    return _Glass(
      tier: tier,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RATING', style: _label(tier)),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            width: double.infinity,
            child: Grow(
              to: 1,
              duration: const Duration(milliseconds: 1200),
              builder: (context, v) => CustomPaint(
                painter: _SparkPainter(line: line, color: tier.color, drawn: v),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [move(i.week, 'THIS WEEK'), move(i.month, 'THIS MONTH')],
          ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.line, required this.color, required this.drawn});

  final List<int> line;
  final Color color;
  final double drawn;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = line.reduce(math.min).toDouble();
    final hi = line.reduce(math.max).toDouble();
    final span = math.max(1.0, hi - lo);
    final points = [
      for (var k = 0; k < line.length; k++)
        Offset(
          size.width * k / (line.length - 1),
          size.height - 4 - (size.height - 8) * (line[k] - lo) / span,
        ),
    ];
    final shown = math.max(2, (points.length * drawn).ceil());
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.take(shown).skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final area = Path.from(path)
      ..lineTo(points[shown - 1].dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    for (final (width, alpha, c) in [
      (7.0, 0.25, color),
      (2.4, 1.0, Color.lerp(color, Colors.white, 0.35)!),
    ]) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = c.withValues(alpha: alpha),
      );
    }
    canvas.drawCircle(points[shown - 1], 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.drawn != drawn || old.line != line || old.color != color;
}

class _Record extends StatelessWidget {
  const _Record({required this.tier, required this.i});

  final RankTier tier;
  final RankInsights i;

  @override
  Widget build(BuildContext context) {
    Widget count(String label, int n, Color color) => Expanded(
      child: Column(
        children: [
          Text('$n', style: _value(tier, 24, color: color)),
          Text(label, style: _label(tier)),
        ],
      ),
    );
    return _Glass(
      tier: tier,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 92,
            child: Grow(
              to: i.winRate,
              duration: const Duration(milliseconds: 1300),
              ticks: 14,
              tickVolume: 0.35,
              builder: (context, v) => CustomPaint(
                painter: _RingPainter(value: v, color: tier.color),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(v * 100).round()}%', style: _value(tier, 22)),
                      Text('WON', style: _label(tier).copyWith(fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          count(
            i.boardGame ? 'WINS' : 'FIRSTS',
            i.wins,
            const Color(0xFF6CFFB0),
          ),
          count('LOSSES', i.losses, const Color(0xFFFF8A8A)),
          if (i.boardGame) count('DRAWS', i.draws, Colors.white),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = Colors.white.withValues(alpha: 0.08),
    );
    final arc = Rect.fromCircle(center: c, radius: r);
    for (final (width, alpha) in const [(13.0, 0.22), (7.0, 1.0)]) {
      canvas.drawArc(
        arc,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.tier, required this.i});

  final RankTier tier;
  final RankInsights i;

  @override
  Widget build(BuildContext context) {
    final kind = switch (i.streakKind) {
      'W' => i.boardGame ? 'WINS' : 'FIRSTS',
      'L' => 'LOSSES',
      'D' => 'DRAWS',
      _ => '',
    };
    final tiles = <(String, String, String?)>[
      ('PEAK', '${i.best}', i.peakAt == null ? null : 'on ${_date(i.peakAt!)}'),
      (
        'STREAK NOW',
        i.streak == 0 ? '—' : '${i.streak} $kind',
        'Best: ${i.bestStreak} ${i.boardGame ? 'wins' : 'firsts'} in a row',
      ),
      ('BIGGEST CLIMB', _signed(i.biggestGain), 'in one game'),
      ('THIS WEEK', '${i.gamesThisWeek}', 'rated games'),
      if (i.boardGame && i.averageOpponent != null)
        ('AVERAGE OPPONENT', '${i.averageOpponent}', 'rating'),
      if (i.boardGame && i.clock != null)
        ('USUAL CLOCK', i.clock!, 'minutes + seconds a move'),
      if (i.boardGame && i.fastestWin != null)
        ('FASTEST WIN', '${i.fastestWin}', 'moves'),
      if (i.boardGame && i.averageMoves != null)
        ('AVERAGE GAME', '${i.averageMoves}', 'moves'),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, value, sub) in tiles)
              SizedBox(
                width: w,
                child: _Glass(
                  tier: tier,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: _label(tier).copyWith(fontSize: 9.5)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(value, style: _value(tier, 22)),
                      ),
                      if (sub != null)
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _small(tier).copyWith(fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Sides extends StatelessWidget {
  const _Sides({required this.tier, required this.i});

  final RankTier tier;
  final RankInsights i;

  @override
  Widget build(BuildContext context) {
    final chess = i.game == 'chess';
    Widget side(String name, ({int games, int wins}) s, Color dot) {
      final rate = s.games == 0 ? 0.0 : s.wins / s.games;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dot,
                    border: Border.all(color: tier.color, width: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(name, style: _label(tier)),
                const Spacer(),
                Text(
                  s.games == 0
                      ? 'no games yet'
                      : '${s.wins} of ${s.games} won · ${(rate * 100).round()}%',
                  style: _small(tier),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _HoloBar(tier: tier, value: rate),
          ],
        ),
      );
    }

    return _Glass(
      tier: tier,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chess ? 'WHITE OR BLACK' : 'DARK OR LIGHT', style: _label(tier)),
          // In checkers, dark (player_white) moves first.
          side(
            chess ? 'AS WHITE' : 'AS DARK',
            i.asWhite,
            chess ? Colors.white : const Color(0xFF2A2440),
          ),
          side(
            chess ? 'AS BLACK' : 'AS LIGHT',
            i.asBlack,
            chess ? const Color(0xFF15102A) : const Color(0xFFF4E9D8),
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.tier,
    required this.title,
    required this.counts,
  });

  final RankTier tier;
  final String title;
  final Map<String, int> counts;

  static const _names = {
    'checkmate': 'Checkmate',
    'resignation': 'Resigned',
    'timeout': 'On time',
    'win': 'Out of moves',
    'stalemate': 'Stalemate',
    'draw': 'Draw',
  };

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (sum, e) => sum + e.value);
    final shades = [
      Color.lerp(tier.color, Colors.white, 0.45)!,
      tier.color,
      Color.lerp(tier.color, Colors.black, 0.35)!,
      Colors.white.withValues(alpha: 0.5),
    ];
    return _Glass(
      tier: tier,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _label(tier)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final (k, e) in entries.indexed)
                    Expanded(
                      flex: e.value,
                      child: Container(color: shades[k % shades.length]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final (k, e) in entries.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: shades[k % shades.length],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_names[e.key] ?? 'Other'} · '
                      '${(e.value * 100 / total).round()}%',
                      style: _small(tier),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({
    required this.tier,
    required this.title,
    required this.person,
    required this.detail,
  });

  final RankTier tier;
  final String title;
  final InsightPerson person;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final name = profileDisplayName(person.profile, person.id);
    return _Glass(
      tier: tier,
      child: Row(
        children: [
          UserAvatar.fromProfile(
            person.profile,
            fallbackInitial: name,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _label(tier).copyWith(fontSize: 9.5)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _value(tier, 17),
                      ),
                    ),
                    if (person.house) ...[
                      const SizedBox(width: 6),
                      const HouseTag(),
                    ],
                  ],
                ),
                Text(detail, style: _small(tier)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
