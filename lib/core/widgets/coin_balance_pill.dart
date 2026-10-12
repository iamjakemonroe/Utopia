import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/coins/presentation/providers/coin_balance_provider.dart';
import '../../features/store/presentation/coin_shop.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'utopia_icons.dart';

/// The player's coins, live from the server, with a "+" that opens the coin
/// shop. The number rolls to its new value and the pill gives a little hop
/// whenever it changes.
class CoinBalancePill extends ConsumerWidget {
  const CoinBalancePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(coinBalanceProvider);

    return Semantics(
      button: true,
      label: 'Coins. Tap to get more.',
      child: GestureDetector(
        onTap: () => showCoinShop(context),
        child: Container(
          height: 38,
          padding: const EdgeInsets.only(left: 6, right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            color: Colors.black.withValues(alpha: 0.32),
            border: Border.all(
              color: AppColors.coinGold.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 24),
              const SizedBox(width: 6),
              balance.when(
                data: (value) => _RollingCount(value: value),
                loading: () => SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.coinGold,
                  ),
                ),
                error: (_, _) => Icon(
                  Icons.cloud_off_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    colors: [Color(0xFF8BF5C2), Color(0xFF1FB877)],
                  ),
                  border: Border.all(color: Colors.white70, width: 1.2),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RollingCount extends StatefulWidget {
  const _RollingCount({required this.value});

  final int value;

  @override
  State<_RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<_RollingCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late int _from = widget.value;

  @override
  void didUpdateWidget(_RollingCount old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _shown;
      _c.forward(from: 0);
    }
  }

  int get _shown {
    final t = Curves.easeOutCubic.transform(_c.value);
    return (_from + (widget.value - _from) * t).round();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final hop = _c.isAnimating ? (1 - _c.value) * 0.18 : 0.0;
        return Transform.scale(
          scale: 1 + hop,
          child: Text(
            formatCoins(_shown),
            style: AppTextStyles.body(
              fontWeight: FontWeight.w900,
              color: AppColors.coinGoldBright,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        );
      },
    );
  }
}
