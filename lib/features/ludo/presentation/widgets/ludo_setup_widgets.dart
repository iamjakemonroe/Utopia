import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/ludo_engine.dart';
import 'ludo_pieces.dart';
import '../../../../core/widgets/ambient_tick.dart';

/// Entry amounts offered for Ludo (0 is free).
const List<int> kLudoEntries = [0, 25, 50, 100, 250, 500];

/// The colors a table of [players] plays with, in seat order (matches
/// _ludo_colors on the server).
List<LudoColor> ludoSeatColors(int players) => switch (players) {
  2 => const [LudoColor.red, LudoColor.yellow],
  3 => const [LudoColor.red, LudoColor.green, LudoColor.yellow],
  4 => const [LudoColor.red, LudoColor.green, LudoColor.yellow, LudoColor.blue],
  5 => const [
    LudoColor.red,
    LudoColor.orange,
    LudoColor.yellow,
    LudoColor.green,
    LudoColor.blue,
  ],
  _ => const [
    LudoColor.red,
    LudoColor.orange,
    LudoColor.yellow,
    LudoColor.green,
    LudoColor.blue,
    LudoColor.purple,
  ],
};

/// Picks how many players: each option shows that many tokens standing
/// together, bobbing when selected.
class PlayerCountPicker extends StatefulWidget {
  const PlayerCountPicker({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<int> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<PlayerCountPicker> createState() => _PlayerCountPickerState();
}

class _PlayerCountPickerState extends State<PlayerCountPicker>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Started here: a lazy field would only be created (and started)
    // on first use, which for a ticker is never.
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
    return Row(
      children: [
        for (final (i, n) in widget.options.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onChanged(n),
              child: AnimatedScale(
                scale: n == widget.value ? 1 : 0.92,
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: widget.options.length > 3 ? 84 : 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: n == widget.value
                          ? [
                              Color.lerp(AppColors.accent, Colors.white, 0.25)!,
                              AppColors.accent,
                            ]
                          : [AppColors.surfaceElevated, AppColors.surface],
                    ),
                    border: Border.all(
                      color: n == widget.value
                          ? AppColors.goldBorderBright
                          : AppColors.glowRing.withValues(alpha: 0.35),
                      width: n == widget.value ? 2.2 : 1.2,
                    ),
                    boxShadow: n == widget.value
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.45),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _t,
                          builder: (context, t, _) => _TokenCluster(
                            colors: ludoSeatColors(n),
                            t: t,
                            bouncing: n == widget.value,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '$n',
                          style: AppTextStyles.display(
                            fontSize: 18,
                            color: n == widget.value
                                ? AppColors.onAccent
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TokenCluster extends StatelessWidget {
  const _TokenCluster({
    required this.colors,
    required this.t,
    required this.bouncing,
  });

  final List<LudoColor> colors;
  final double t;
  final bool bouncing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = colors.length;
        final w = (c.maxWidth * 0.8 / (n * 0.62 + 0.38)).clamp(10.0, 24.0);
        final h = w * LudoTokenPainter.aspect;
        final step = w * 0.62;
        final total = step * (n - 1) + w;
        final left0 = (c.maxWidth - total) / 2;
        return Stack(
          children: [
            for (var i = 0; i < n; i++)
              Positioned(
                left: left0 + i * step,
                top:
                    c.maxHeight -
                    h -
                    2 -
                    (bouncing ? 5 * (0.5 + 0.5 * _wave(t * 4 - i * 0.8)) : 0),
                width: w,
                height: h,
                child: CustomPaint(
                  painter: LudoTokenPainter(
                    setId: 'classic',
                    color: colors[i],
                    t: t + i,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static double _wave(double x) {
    final s = x - x.floorToDouble();
    return s < 0.5 ? 1 - (2 * s - 1) * (2 * s - 1) : 0;
  }
}
