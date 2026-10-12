import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/utopia_icons.dart';
import 'providers/coin_balance_provider.dart';

/// A player's coins under their name in a game, rounded ("2.4M"), when they
/// show them. Nothing at all for hidden coins, bots and friends on the same
/// phone. Pops in once it's known.
class PlayerCoins extends ConsumerWidget {
  const PlayerCoins({super.key, required this.userId, this.size = 11});

  final String? userId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    final coins = id == null
        ? null
        : ref.watch(publicCoinsProvider(id)).valueOrNull;
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      alignment: Alignment.centerLeft,
      child: coins == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.monetization_on_rounded,
                    size: size + 2,
                    color: AppColors.coinGold,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    formatCoinsShort(coins),
                    style: AppTextStyles.body(
                      fontSize: size,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
