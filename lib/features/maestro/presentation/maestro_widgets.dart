import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/strings.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'maestro_providers.dart';
import 'maestro_sheet.dart';

const _pink = Color(0xFFFF5C9C);
const _violet = Color(0xFF8B5CF6);

/// By Chip's name in his chat: "Upgrade Chip" for a player who could join
/// Chip Maestro (opens it), a Maestro badge for a member. Nothing for a
/// guest, who saves their account first.
class MaestroPill extends ConsumerWidget {
  const MaestroPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isAnonymousProvider)) return const SizedBox.shrink();
    final member = ref.watch(maestroProvider).valueOrNull?.active ?? false;
    final label = member ? strings.maestroBadge : strings.maestroUpgradeChip;
    return Semantics(
      button: true,
      label: member ? strings.maestroChipMaestro : strings.maestroUpgradeChip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          showMaestroSheet(context);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: member
                ? null
                : const LinearGradient(colors: [_pink, _violet]),
            color: member ? _pink.withValues(alpha: 0.16) : null,
            border: member
                ? Border.all(color: _pink.withValues(alpha: 0.5))
                : null,
            boxShadow: member
                ? null
                : [
                    BoxShadow(
                      color: _pink.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                member ? Icons.brush_rounded : Icons.auto_awesome_rounded,
                size: 14,
                color: member ? AppColors.readable(_pink) : Colors.white,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: member ? AppColors.readable(_pink) : Colors.white,
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

/// A slim card at the top of the store: what Chip Maestro brings, and the
/// way in. Only for players who could join (not guests, not members).
class MaestroStrip extends ConsumerWidget {
  const MaestroStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isAnonymousProvider)) return const SizedBox.shrink();
    final status = ref.watch(maestroProvider).valueOrNull;
    if (status == null || status.active) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showMaestroSheet(context),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  _pink.withValues(alpha: 0.22),
                  _violet.withValues(alpha: 0.18),
                ],
              ),
              border: Border.all(color: _pink.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_pink, _violet]),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.maestroChipMaestro,
                        style: AppTextStyles.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        strings.maestroStripText,
                        style: AppTextStyles.body(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
