import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../../l10n/strings.dart';

/// The four games fanned out like a hand of cards, each its living
/// diorama from the home screen: dealt in one after another, then floating
/// gently, each on its own beat.
class GameFan extends StatefulWidget {
  const GameFan({super.key, required this.height});

  /// The whole fan's height; the cards are a little shorter, so the outer
  /// ones can sit lower, along an arc.
  final double height;

  @override
  State<GameFan> createState() => _GameFanState();
}

class _GameFanState extends State<GameFan> with TickerProviderStateMixin {
  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  /// The home screen's games and colors (chess wears the world's accent).
  static List<(GameKind, String, Color)> get _games => [
    (GameKind.chess, strings.gameFanChess, AppColors.accent),
    (GameKind.ludo, strings.gameFanLudo, AppColors.mint),
    (GameKind.checkers, strings.gameFanCheckers, AppColors.coral),
    (GameKind.doodle, strings.gameFanDoodle, Color(0xFFFF5C9C)),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: dealt and still.
    if (MediaQuery.disableAnimationsOf(context)) {
      _deal.value = 1;
      _float.stop();
    }
  }

  @override
  void dispose() {
    _deal.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final fan = _Fan.fit(c.maxWidth, widget.height);
        return SizedBox(
          // As tall as the fan, so it sits centered where it's put.
          height: math.min(widget.height, fan.extent + 8),
          child: AnimatedBuilder(
            animation: Listenable.merge([_deal, _float]),
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                for (final (i, (game, title, color)) in _games.indexed)
                  _placed(i, fan, game, title, color),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placed(int i, _Fan fan, GameKind game, String title, Color color) {
    // -1.5 to 1.5, left to right.
    final k = i - 1.5;
    final start = i * 0.12;
    final dealt = Curves.easeOutBack.transform(
      ((_deal.value - start) / 0.6).clamp(0.0, 1.0),
    );
    final bob = math.sin(_float.value * 2 * math.pi + i * 1.4) * 3;
    return Transform.translate(
      offset: Offset(0, 6 + bob + (1 - dealt) * widget.height * 0.5),
      // Turned about a point below the cards, the way a hand is held:
      // the tops spread wider than the bottoms.
      child: Transform.rotate(
        angle: k * fan.step * dealt,
        origin: Offset(0, fan.height / 2 + fan.pivot),
        child: Opacity(
          opacity: dealt.clamp(0.0, 1.0),
          child: _FanCard(
            game: game,
            title: title,
            color: color,
            width: fan.width,
            height: fan.height,
            // The next card covers this one's right side: its name stays
            // in the part that shows.
            labelWidth: i == _games.length - 1 ? fan.width : fan.showing,
          ),
        ),
      ),
    );
  }
}

/// How big the cards are and how far apart they turn, to fit [width] and
/// [height] with every name showing.
class _Fan {
  _Fan(this.width, this.height, this.pivot, this.step);

  final double width;
  final double height;

  /// How far below the cards they turn about.
  final double pivot;

  /// The turn from one card to the next, in radians.
  final double step;

  /// How much of a card's top shows past the next one.
  double get showing => (pivot + height) * step;

  /// How tall the fan is: the outer cards turn down a little.
  double get extent {
    final turn = step * 1.5;
    return height +
        (pivot + height) * (1 - math.cos(turn)) +
        width / 2 * math.sin(turn);
  }

  factory _Fan.fit(double maxWidth, double maxHeight) {
    var height = math.min(maxHeight - 40, 210.0);
    for (var tries = 0; ; tries++) {
      final width = height * 0.7;
      final pivot = height * 1.3;
      final reach = pivot + height;
      // Wide enough apart for a name, and no wider than the screen.
      final least = width * 0.62 / reach;
      final room = (maxWidth / 2 - width / 2 - 6) / reach;
      final most = room >= 1 ? 0.3 : math.asin(room.clamp(0.0, 1.0)) / 1.5;
      if (least <= most || tries == 6) {
        return _Fan(
          width,
          height,
          pivot,
          math.min(most, math.max(least, 0.15)),
        );
      }
      height *= 0.9;
    }
  }
}

/// One game's card: a strip with its name over its diorama.
class _FanCard extends StatelessWidget {
  const _FanCard({
    required this.game,
    required this.title,
    required this.color,
    required this.width,
    required this.height,
    required this.labelWidth,
  });

  final GameKind game;
  final String title;
  final Color color;
  final double width;
  final double height;

  /// How much of the strip shows, from the left.
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final radius = width * 0.16;
    final strip = height * 0.19;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2),
        child: Column(
          children: [
            Container(
              height: strip,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, Colors.white, 0.12)!, color],
                ),
              ),
              child: SizedBox(
                width: math.min(labelWidth, width) - 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style:
                          AppTextStyles.display(
                            fontSize: strip * 0.52,
                            color: Colors.white,
                          ).copyWith(
                            shadows: const [
                              Shadow(color: Color(0x66000000), blurRadius: 3),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GameSceneArt(game: game, height: height - strip - 4),
            ),
          ],
        ),
      ),
    );
  }
}
