import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/strings.dart';

/// A gift's note, as a little quote: on the way out (before the PIN) and
/// when it arrives (in the notifications).
class GiftNote extends StatelessWidget {
  const GiftNote(this.note, {super.key, this.maxLines});

  final String note;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.readable(AppColors.coinGold);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.coinGold.withValues(
          alpha: AppColors.light ? 0.12 : 0.1,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, size: 16, color: gold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              note,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              semanticsLabel: strings.giftNoteTheirNote(note),
              style: AppTextStyles.body(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
