import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_toast.dart';
import 'providers/coin_balance_provider.dart';

/// What each day of a streak pays (day seven, and every day after, pays the
/// most). The server decides; this is only for showing the row of days.
const kDailyRewards = [500, 750, 1000, 1250, 1500, 2000, 3000];

/// Shows today's daily reward, if there's one to claim. Returns false when
/// the server couldn't be asked (offline, still connecting), so the caller
/// can try again later.
Future<bool> showDailyRewardIfReady(BuildContext context, WidgetRef ref) async {
  final ({bool claimable, int streak, int coins}) status;
  try {
    status = await ref.read(coinRepositoryProvider).dailyRewardStatus();
  } catch (_) {
    return false;
  }
  if (!status.claimable || !context.mounted) return true;
  ref.read(gameAudioProvider).play(Sfx.drawer);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        DailyRewardSheet(streak: status.streak, coins: status.coins),
  );
  return true;
}

/// Today's reward: Chip, the streak's seven days (done ones ticked, today
/// pulsing), and a big button to claim it, which bursts into confetti and
/// counts the coins in.
class DailyRewardSheet extends ConsumerStatefulWidget {
  const DailyRewardSheet({
    super.key,
    required this.streak,
    required this.coins,
  });

  final int streak;
  final int coins;

  @override
  ConsumerState<DailyRewardSheet> createState() => _DailyRewardSheetState();
}

class _DailyRewardSheetState extends ConsumerState<DailyRewardSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  bool _claiming = false;
  int? _claimed;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_claiming || _claimed != null) return;
    setState(() => _claiming = true);
    final ({int coins, int streak}) reward;
    try {
      reward = await ref.read(coinRepositoryProvider).claimDailyReward();
    } catch (e) {
      if (!mounted) return;
      if ('$e'.contains('already claimed')) {
        Navigator.of(context).maybePop();
        return;
      }
      setState(() => _claiming = false);
      showUtopiaToast(
        context,
        "Couldn't claim it just now. Try again.",
        kind: ToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _claiming = false;
      _claimed = reward.coins;
    });
    // The coins are in: sound and feel are extras that must never undo that.
    HapticFeedback.heavyImpact();
    try {
      ref.read(gameAudioProvider).play(Sfx.purchase);
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.streak.clamp(1, 7);
    final claimed = _claimed;
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.background],
        ),
        border: Border(top: BorderSide(color: AppColors.goldBorder, width: 2)),
      ),
      child: Stack(
        children: [
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                10,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CoinBuddy(
                    mood: claimed == null ? BuddyMood.excited : BuddyMood.happy,
                    size: 96,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Daily reward',
                    style: AppTextStyles.display(fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.streak <= 1
                        ? 'Come back every day: the reward grows with your streak.'
                        : 'Day ${widget.streak} in a row. Keep it going!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      for (var d = 1; d <= 7; d++)
                        Expanded(
                          child: _Day(
                            day: d,
                            coins: kDailyRewards[d - 1],
                            done: d < today || (d == today && claimed != null),
                            today: d == today,
                            pulse: _pulse,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.elasticOut,
                    transitionBuilder: (child, a) =>
                        ScaleTransition(scale: a, child: child),
                    child: claimed == null
                        ? PrimaryButton(
                            key: const ValueKey('claim'),
                            label: 'Claim ${formatCoins(widget.coins)} coins',
                            isLoading: _claiming,
                            onPressed: _claim,
                          )
                        : Row(
                            key: const ValueKey('done'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.monetization_on_rounded,
                                color: AppColors.coinGold,
                                size: 34,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+${formatCoins(claimed)}',
                                style: AppTextStyles.display(
                                  fontSize: 34,
                                  color: AppColors.coinGoldBright,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (claimed != null)
            const Positioned.fill(child: IgnorePointer(child: ConfettiBurst())),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.coins,
    required this.done,
    required this.today,
    required this.pulse,
  });

  final int day;
  final int coins;
  final bool done;
  final bool today;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = today && !done ? pulse.value : 0.0;
        return Column(
          children: [
            Transform.scale(
              scale: today && !done ? 1 + 0.08 * glow : 1,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.success
                      : today
                      ? AppColors.coinGold
                      : AppColors.surface,
                  border: Border.all(
                    color: today
                        ? AppColors.coinGoldBright
                        : AppColors.glowRing,
                    width: today ? 2.5 : 1.2,
                  ),
                  boxShadow: today && !done
                      ? [
                          BoxShadow(
                            color: AppColors.coinGold.withValues(
                              alpha: 0.3 + 0.4 * glow,
                            ),
                            blurRadius: 10 + 8 * glow,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 22,
                        )
                      : Text(
                          day == 7 ? '7+' : '$day',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: today
                                ? const Color(0xFF3A2400)
                                : AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCoinsShort(coins),
              style: AppTextStyles.body(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: today ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }
}
