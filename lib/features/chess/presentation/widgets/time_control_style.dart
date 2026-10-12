import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/time_control.dart';

/// Entry amounts offered for chess games (0 is free).
const List<int> kChessEntries = [0, 25, 50, 100, 250, 500];

IconData speedIcon(ChessSpeed speed) => switch (speed) {
  ChessSpeed.bullet => Icons.bolt_rounded,
  ChessSpeed.blitz => Icons.local_fire_department_rounded,
  ChessSpeed.rapid => Icons.timer_rounded,
  ChessSpeed.classical => Icons.hourglass_bottom_rounded,
};

Color speedColor(ChessSpeed speed) => switch (speed) {
  ChessSpeed.bullet => const Color(0xFFFFD447),
  ChessSpeed.blitz => const Color(0xFFFF8A3D),
  ChessSpeed.rapid => const Color(0xFF3DDC97),
  ChessSpeed.classical => const Color(0xFF9B8CFF),
};

/// Every time control as a grid of springy tiles: the speed's icon, the
/// minutes, and the increment if there is one. The selected tile's speed
/// is named underneath.
class TimeControlPicker extends StatelessWidget {
  const TimeControlPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TimeControl value;
  final ValueChanged<TimeControl> onChanged;

  @override
  Widget build(BuildContext context) {
    final speed = value.speed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.92,
          children: [
            for (final tc in TimeControl.all)
              _TimeTile(
                control: tc,
                selected: tc == value,
                onTap: () => onChanged(tc),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(
            key: ValueKey(value),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(speedIcon(speed), size: 18, color: speedColor(speed)),
              const SizedBox(width: 6),
              Text(
                speed.title,
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w800,
                  color: speedColor(speed),
                ),
              ),
              Text(
                value.increment == 0
                    ? '  ·  ${value.minutes} min each'
                    : '  ·  ${value.minutes} min  +${value.increment}s a move',
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.control,
    required this.selected,
    required this.onTap,
  });

  final TimeControl control;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = speedColor(control.speed);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.92,
        duration: const Duration(milliseconds: 420),
        curve: Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? [Color.lerp(tint, Colors.white, 0.3)!, tint]
                  : [AppColors.surfaceElevated, AppColors.surface],
            ),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.8)
                  : tint.withValues(alpha: 0.35),
              width: selected ? 2.2 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.5),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                speedIcon(control.speed),
                size: 18,
                color: selected ? Colors.white : tint,
              ),
              Text(
                '${control.minutes}',
                style: AppTextStyles.display(
                  fontSize: 24,
                  color: selected
                      ? const Color(0xFF1B1433)
                      : AppColors.textPrimary,
                ),
              ),
              Text(
                control.increment == 0 ? 'min' : '+${control.increment}s',
                style: AppTextStyles.body(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? const Color(0xFF1B1433).withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
