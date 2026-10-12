import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'utopia_icons.dart';

/// The house cut taken from a prize pool, in basis points (see
/// commission_bps on the match tables).
const int kCommissionBps = 500;

/// What the winner of a game with this [entry] and [players] receives.
int prizeFor(int entry, int players) {
  final pot = entry * players;
  return pot - (pot * kCommissionBps) ~/ 10000;
}

/// Picks how many coins each player puts in: free, or a coin amount. Each
/// option is a bubble that springs when chosen, and the line underneath
/// shows what the winner takes home.
class EntrySelector extends StatelessWidget {
  const EntrySelector({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.players,
  });

  /// Entry amounts; 0 means a free game.
  final List<int> options;
  final int value;
  final ValueChanged<int> onChanged;

  /// How many players will pay in, for the prize line.
  final int players;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final amount = options[i];
              final selected = amount == value;
              return GestureDetector(
                onTap: () => onChanged(amount),
                child: AnimatedScale(
                  scale: selected ? 1 : 0.9,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.elasticOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: selected
                            ? [
                                Color.lerp(
                                  AppColors.accent,
                                  Colors.white,
                                  0.25,
                                )!,
                                AppColors.accent,
                              ]
                            : [AppColors.surfaceElevated, AppColors.surface],
                      ),
                      border: Border.all(
                        color: selected
                            ? AppColors.goldBorderBright
                            : AppColors.glowRing.withValues(alpha: 0.35),
                        width: selected ? 2.2 : 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (amount == 0)
                          Icon(
                            Icons.favorite_rounded,
                            color: selected ? Colors.white : AppColors.coral,
                            size: 22,
                          )
                        else
                          const CoinIcon(size: 22),
                        const SizedBox(height: 3),
                        Text(
                          amount == 0 ? 'Free' : formatCoins(amount),
                          style: AppTextStyles.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: value == 0
              ? Row(
                  key: const ValueKey(0),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sentiment_very_satisfied_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Just for fun',
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: ValueKey(value),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Winner gets ',
                      style: AppTextStyles.body(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    CoinAmount(
                      prizeFor(value, players),
                      size: 15,
                      color: AppColors.goldBorderBright,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
