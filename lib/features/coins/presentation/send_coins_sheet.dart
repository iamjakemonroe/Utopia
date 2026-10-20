import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bouncy_dialog.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../data/coin_gift_repository.dart';
import '../../../core/platform/keyboard.dart';

/// Who a gift goes to.
typedef GiftFriend = ({
  String id,
  String name,
  String? avatarUrl,
  String? avatarKind,
  int? avatarSeed,
});

/// Send some coins to [friend]: how many (a few quick amounts, or any),
/// what today's limits leave, and a last "sure?" before it goes. Says
/// plainly when they can't send yet, and why.
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

class _SendCoinsSheetState extends ConsumerState<_SendCoinsSheet> {
  static const _quick = [100, 500, 1000, 5000, 10000, 50000];

  /// This gift's key: a retry after a dropped connection sends nothing
  /// twice.
  final _key = newGiftKey();
  final _custom = TextEditingController();
  int _coins = 100;

  /// Whether [_coins] has been fitted to what they can send.
  bool _fitted = false;
  bool _typing = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String get _name => widget.friend.name;

  Future<void> _send(GiftAllowance allow) async {
    final coins = _coins;
    final sure = await confirmBouncy(
      context: context,
      title: 'Send ${formatCoins(coins)} coins?',
      message: '$_name gets them straight away. A gift can’t be undone.',
      confirmLabel: 'Send',
      hero: const CoinIcon(size: 48),
      audio: ref.read(gameAudioProvider),
    );
    if (!sure || !mounted) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(coinGiftRepositoryProvider)
          .send(to: widget.friend.id, coins: coins, key: _key);
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _sending = false;
          _error = _why(result.why, allow);
        });
        ref.invalidate(giftAllowanceProvider(widget.friend.id));
        return;
      }
      HapticFeedback.mediumImpact();
      ref.read(gameAudioProvider).play(Sfx.purchase);
      Navigator.of(context).pop();
      showUtopiaToast(
        context,
        'Sent ${formatCoins(coins)} coins to $_name',
        kind: ToastKind.success,
        icon: Icons.redeem_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = friendlyError(
          e,
          fallback: "Couldn't send them. Try again (it won't send twice).",
        );
      });
    }
  }

  /// What sets today's most, when it's one of the safety rules.
  String? _limitNote(GiftAllowance allow) => switch (allow.limitedBy) {
    'friend' =>
      "You and $_name are new friends: up to "
          '${formatCoins(allow.friendLimit ?? 0)} a day for their first '
          'few days.',
    'share' =>
      'Up to ${allow.share == 50 ? 'half' : '${allow.share}%'} of your coins '
          'a day, so they can never all go at once.',
    'young' =>
      'Up to ${formatCoins(allow.dailyCap ?? 0)} a day until your account '
          'is a month old.',
    _ => null,
  };

  /// Why a gift couldn't go, in plain words.
  String _why(String? why, GiftAllowance allow) => switch (why) {
    'self' ||
    'nobody' ||
    'not_friends' => 'You can only send coins to friends.',
    'house' => "House players can't take gifts.",
    'amount' =>
      'A gift is ${formatCoins(allow.min)} to ${formatCoins(allow.max)} coins.',
    'daily_send' =>
      allow.young
          ? 'Up to ${formatCoins(allow.dailyCap ?? 0)} a day until your '
                'account is a month old.'
          : "That's more than you can send today.",
    'share' =>
      'You can send up to ${allow.share == 50 ? 'half' : '${allow.share}%'} '
          'of your coins a day.',
    'new_friend' =>
      "You're new friends: up to ${formatCoins(allow.friendLimit ?? 0)} a "
          'day for now.',
    'balance' => "You don't have that many coins.",
    'held' =>
      'Coins bought in the last ${allow.holdDays} days can’t be sent yet.',
    'daily_receive' => "$_name can't take more gifts today. Try tomorrow.",
    'guest' => 'Save your account to send coins.',
    'new' => 'You can send coins once your account is a week old.',
    'off' => 'Sending coins is paused right now. Try again later.',
    _ => "Couldn't send them. Try again.",
  };

  @override
  Widget build(BuildContext context) {
    final allowance = ref.watch(giftAllowanceProvider(widget.friend.id));
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
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
                            'Send coins',
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
                    value.ok ? _picker(value) : _cant(value),
                  AsyncError() => _message(
                    "Couldn't check what you can send. Try again.",
                    action: (
                      'Try again',
                      () {
                        ref.invalidate(giftAllowanceProvider(widget.friend.id));
                      },
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
    );
  }

  /// They can't send yet: why, and what to do.
  Widget _cant(GiftAllowance allow) {
    switch (allow.why) {
      case 'guest':
        return _message(
          'Save your account to send coins to friends. It keeps your '
          'coins safe too.',
          action: (
            'Save my account',
            () {
              Navigator.of(context).pop();
              context.push('/auth/link');
            },
          ),
        );
      case 'new':
        final ready = allow.readyAt;
        final days = ready == null
            ? 7
            : (ready.difference(DateTime.now()).inHours / 24).ceil();
        return _message(
          'You can send coins once your account is a week old: '
          '${days <= 1 ? 'tomorrow' : 'in $days days'}. It keeps everyone’s '
          'coins safe.',
        );
      default:
        return _message('Sending coins is paused right now. Try again later.');
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
        _coins = _quick.lastWhere((q) => q <= most, orElse: () => allow.min);
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
              label: 'Other',
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
              LengthLimitingTextInputFormatter(6),
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
              ? (allow.giftsLeft <= 0 || allow.leftToday < allow.min
                    ? "You've sent all you can today. More tomorrow."
                    : "You don't have coins you can send right now.")
              : 'You have ${formatCoins(allow.balance)} · up to '
                    '${formatCoins(most)} today',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        if (_limitNote(allow) case final note?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              note,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (allow.held > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${formatCoins(allow.held)} bought in the last '
              '${allow.holdDays} days can be sent after that.',
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
          label: valid ? 'Send ${formatCoins(_coins)} coins' : 'Send coins',
          isLoading: _sending,
          onPressed: valid && !_sending ? () => _send(allow) : null,
        ),
        const SizedBox(height: 6),
        Text(
          'Friends only · a gift can’t be undone',
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
