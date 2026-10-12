import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../domain/chess_engine.dart';
import '../../domain/chess_types.dart';
import 'chess_piece_art.dart';
import 'chess_piece_styles.dart';

/// Bottom sheet for choosing a promotion piece. Presented modally and
/// non-dismissible-by-tap-outside (a pending promotion is a real decision,
/// not something to lose by fat-fingering the scrim).
Future<PieceType?> showPromotionSheet(
  BuildContext context,
  PieceColor color, {
  String? pieceSet,
}) {
  return showModalBottomSheet<PieceType>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: PopCard(
          borderRadius: 28,
          sheet: true,
          blur: 20,
          glow: AppColors.accentSecondary,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Promote your pawn',
                    style: AppTextStyles.display(fontSize: 20),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: promotionChoices.map((type) {
                      return _PromotionOption(
                        type: type,
                        finish: ChessPieceStyle.byId(pieceSet).of(color),
                        character: ChessPieceStyle.byId(pieceSet).character,
                        onTap: () => Navigator.of(context).pop(type),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PromotionOption extends StatelessWidget {
  const _PromotionOption({
    required this.type,
    required this.finish,
    this.character = ChessCharacter.none,
    required this.onTap,
  });

  final PieceType type;
  final ChessPieceFinish finish;
  final ChessCharacter character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: PopCard(
        borderRadius: 18,
        blur: 8,
        tint: AppColors.accent,
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            // Ready for its new job.
            child: ChessPieceArt(
              type: type,
              finish: finish,
              size: 52,
              character: character,
              mood: PieceMood.happy,
            ),
          ),
        ),
      ),
    );
  }
}
