import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../theme/app_text_styles.dart';

/// Under a player at the table whose turns are being played for them while
/// they're away (their time ran out): they're still in the game.
class AwayMark extends StatelessWidget {
  const AwayMark({super.key});

  static const _color = Color(0xFFFF4D5E);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.hourglass_bottom_rounded, size: 11, color: _color),
      const SizedBox(width: 2),
      Text(
        strings.seatAway,
        style: AppTextStyles.body(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    ],
  );
}
