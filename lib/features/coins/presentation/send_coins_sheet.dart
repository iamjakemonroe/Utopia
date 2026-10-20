import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../data/coin_gift_repository.dart';
import 'gift_pin.dart';
import '../../../core/platform/keyboard.dart';
import '../../../l10n/strings.dart';

/// Who a gift goes to.
typedef GiftFriend = ({
  String id,
  String name,
  String? avatarUrl,
  String? avatarKind,
  int? avatarSeed,
});

/// Send some coins to [friend]: how many (a few quick amounts, or any),
/// then the gift PIN (chosen right there the first time), which sends it.
/// Says plainly when they can't send, and why.
Future<void> showSendCoinsSheet(BuildContext context, GiftFriend friend) {
  ProviderScope.containerOf(context).read(gameAudioProvider).play(Sfx.drawer);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SendCoinsSheet(friend: friend),
  );
}

class _SendCoinsSheet extends ConsumerStatefulWidget {
  const _SendCoinsSheet({required this.friend});

  final GiftFriend friend;

  @override
  ConsumerState<_SendCoinsSheet> createState() => _SendCoinsSheetState();
}

/// Where the gift is: choosing how many, then the PIN (or choosing one,
/// or a new one for a forgotten one).
enum _Step { amount, pin, choosePin, resetPin }

class _SendCoinsSheetState extends ConsumerState<_SendCoinsSheet> {
  static const _quick = [100, 500, 1000, 5000, 10000, 50000];

  /// This gift's key: a retry after a dropped connection sends nothing
  /// twice.
  final _key = newGiftKey();
  final _custom = TextEditingController();
  int _coins = 100;
  _Step _step = _Step.amount;

  /// Whether [_coins] has been fitted to what they can send.
  bool _fitted = false;
  bool _typing = false;
  bool _sending = false;
  String? _error;

  /// The PIN pad's error, and how many there have been (each shakes it).
  String? _pinError;
  int _pinErrors = 0;
  DateTime? _lockedUntil;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String get _name => widget.friend.name;

  /// On to the PIN: the one they have, or choosing one first.
  void _continue(GiftAllowance allow) {
    final locked = allow.pinLockedUntil;
    setState(() {
      _error = null;
      _pinError = null;
      _lockedUntil = locked != null && locked.isAfter(DateTime.now())
          ? locked
          : null;
      if (_lockedUntil != null) {
        _pinError = giftPinWhy(
          GiftResult(ok: false, why: 'locked', lockedUntil: _lockedUntil),
        );
      }
      _step = allow.pinSet ? _Step.pin : _Step.choosePin;
    });
  }

  Future<void> _sendWith(String pin) async {
    final coins = _coins;
    setState(() {
      _sending = true;
      _pinError = null;
    });
    try {
      final result = await ref
          .read(coinGiftRepositoryProvider)
          .send(to: widget.friend.id, coins: coins, key: _key, pin: pin);
      if (!mounted) return;
      if (result.ok) {
        HapticFeedback.mediumImpact();
        ref.read(gameAudioProvider).play(Sfx.coinsOut);
        Navigator.of(context).pop();
        showUtopiaToast(
          context,
          strings.sendCoinsSentCoinsTo(formatCoins(coins), _name),
          kind: ToastKind.success,
          icon: Icons.redeem_rounded,
        );
        return;
      }
      setState(() {
        _sending = false;
        switch (result.why) {
          case 'wrong_pin' || 'locked':
            _step = _Step.pin;
            _pinError = giftPinWhy(result);
            _pinErrors++;
            if (result.why == 'locked') _lockedUntil = result.lockedUntil;
          case 'no_pin':
            _step = _Step.choosePin;
          default:
            _step = _Step.amount;
            _error = _why(result.why);
        }
      });
      if (result.why != 'wrong_pin') ref.invalidate(giftAllowanceProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _step = _Step.pin;
        _pinError = friendlyError(
          e,
          fallback: strings.sendCoinsCouldnTSendThemTry,
        );
        _pinErrors++;
      });
    }
  }

  /// Why a gift couldn't go, in plain words.
  String _why(String? why) => switch (why) {
    'self' || 'nobody' || 'not_friends' => strings.sendCoinsYouCanOnlySendCoins,
    'house' => strings.sendCoinsHousePlayersCanTTake,
    'amount' => strings.sendCoinsChooseHowManyToSend,
    'balance' => strings.sendCoinsYouDonTHaveThat,
    'held' => strings.sendCoinsCoinsBoughtInTheLast,
    'guest' => strings.sendCoinsSaveYourAccountToSend,
    'off' => strings.sendCoinsSendingCoinsIsPausedRight,
    _ => strings.sendCoinsCouldnTSendThemTry2,
  };

  @override
  Widget build(BuildContext context) {
    final allowance = ref.watch(giftAllowanceProvider);
    final f = widget.friend;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: PopCard(
            borderRadius: 28,
            tint: AppColors.coinGold,
            glow: AppColors.coinGold,
            sheet: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (_step != _Step.amount)
                        IconButton(
                          tooltip: strings.sendCoinsBack,
                          onPressed: _sending
                              ? null
                              : () => setState(() => _step = _Step.amount),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          UserAvatar(
                            avatarUrl: f.avatarUrl,
                            avatarKind: f.avatarKind,
                            avatarSeed: f.avatarSeed,
                            fallbackInitial: f.name,
                            radius: 26,
                          ),
                          const Positioned(
                            right: -6,
                            bottom: -4,
                            child: CoinIcon(size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _step == _Step.amount
                                  ? strings.sendCoinsSendCoins
                                  : strings.sendCoinsSend(formatCoins(_coins)),
                              style: AppTextStyles.display(fontSize: 22),
                            ),
                            Text(
                              'to $_name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  switch (allowance) {
                    AsyncData(:final value) =>
                      !value.ok ? _cant(value) : _stepBody(value),
                    AsyncError() => _message(
                      strings.sendCoinsCouldnTCheckWhatYou,
                      action: (
                        strings.sendCoinsTryAgain,
                        () => ref.invalidate(giftAllowanceProvider),
                      ),
                    ),
                    _ => const SizedBox(
                      height: 160,
                      child: Center(child: UtopiaLoader(size: 40)),
                    ),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(GiftAllowance allow) => switch (_step) {
    _Step.amount => _picker(allow),
    _Step.pin => GiftPinPad(
      key: const ValueKey('pin'),
      title: strings.sendCoinsEnterYourGiftPin,
      subtitle: strings.sendCoinsGetsThemStraightAwayA(_name),
      busy: _sending,
      enabled: _lockedUntil == null || _lockedUntil!.isBefore(DateTime.now()),
      error: _pinError,
      errorCount: _pinErrors,
      onDone: _sendWith,
      extra: TextButton(
        onPressed: _sending
            ? null
            : () => setState(() {
                _pinError = null;
                _step = _Step.resetPin;
              }),
        child: Text(strings.sendCoinsForgotPin),
      ),
    ),
    _Step.choosePin => GiftPinFlow(
      key: const ValueKey('choose'),
      goal: GiftPinGoal.set,
      firstTitle: strings.sendCoinsChooseAGiftPin,
      firstSubtitle: strings.sendCoinsGiftsNeedOneSoOnly,
      onDone: _sendWith,
    ),
    _Step.resetPin => GiftPinFlow(
      key: const ValueKey('reset'),
      goal: GiftPinGoal.reset,
      onDone: _sendWith,
    ),
  };

  /// They can't send: why, and what to do.
  Widget _cant(GiftAllowance allow) {
    switch (allow.why) {
      case 'guest':
        return _message(
          strings.sendCoinsSaveYourAccountToSend2,
          action: (
            strings.sendCoinsSaveMyAccount,
            () {
              Navigator.of(context).pop();
              context.push('/auth/link');
            },
          ),
        );
      default:
        return _message(strings.sendCoinsSendingCoinsIsPausedRight);
    }
  }

  Widget _message(String text, {(String, VoidCallback)? action}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        if (action != null) ...[
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: action.$1, onPressed: action.$2),
        ],
      ],
    );
  }

  /// How many to send, and the button.
  Widget _picker(GiftAllowance allow) {
    final most = allow.most;
    if (!_fitted) {
      // Opens on an amount they can send: 100, or the most that fits.
      _fitted = true;
      if (_coins > most) {
        _coins = _quick.lastWhere((q) => q <= most, orElse: () => most);
      }
    }
    final valid = _coins >= allow.min && _coins <= most;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 34),
              const SizedBox(width: 10),
              Text(
                formatCoins(_coins),
                style: AppTextStyles.display(
                  fontSize: 44,
                  color: AppColors.readable(
                    valid ? AppColors.coinGoldBright : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amount in _quick)
              _Chip(
                label: formatCoins(amount),
                on: !_typing && _coins == amount,
                enabled: amount <= most,
                onTap: () => setState(() {
                  _typing = false;
                  _coins = amount;
                  _error = null;
                }),
              ),
            _Chip(
              label: strings.sendCoinsOther,
              on: _typing,
              enabled: most >= allow.min,
              onTap: () => setState(() {
                _typing = true;
                _custom.text = '$_coins';
                _error = null;
              }),
            ),
          ],
        ),
        if (_typing) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _custom,
            // (Not in a browser: the tap on Other can't open its keyboard.)
            autofocus: canFocusWithoutTap,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            textAlign: TextAlign.center,
            style: AppTextStyles.display(fontSize: 22),
            decoration: InputDecoration(
              hintText: '${allow.min} to $most',
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() {
              _coins = int.tryParse(v) ?? 0;
              _error = null;
            }),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          most < allow.min
              ? strings.sendCoinsYouDonTHaveCoins
              : strings.sendCoinsYouHaveYouCanSend(
                  formatCoins(allow.balance),
                  formatCoins(most),
                ),
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        if (allow.held > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              strings.sendCoinsBoughtInTheLastDays(
                formatCoins(allow.held),
                allow.holdDays,
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: valid
              ? strings.sendCoinsSendCoins2(formatCoins(_coins))
              : strings.sendCoinsSendCoins,
          onPressed: valid ? () => _continue(allow) : null,
        ),
        const SizedBox(height: 6),
        Text(
          allow.pinSet
              ? strings.sendCoinsFriendsOnlyYourGiftPin
              : strings.sendCoinsFriendsOnlyYouLlChoose,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: on
                ? AppColors.coinGold
                : AppColors.textPrimary.withValues(alpha: 0.08),
            border: Border.all(
              color: on
                  ? AppColors.coinGoldBright
                  : AppColors.textPrimary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body(
              fontWeight: FontWeight.w800,
              color: on ? const Color(0xFF3A2400) : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
