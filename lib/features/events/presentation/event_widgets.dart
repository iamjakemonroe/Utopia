import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../../core/widgets/utopia_world.dart';
import '../../auras/data/aura_repository.dart';
import '../../auras/domain/aura.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../store/presentation/theme_teleport.dart';
import '../domain/game_event.dart';
import 'events_controller.dart';

/// Each season's color.
Color seasonColor(String season) => switch (season) {
  'halloween' => const Color(0xFFF2761A),
  'weekly' => AppColors.coinGold,
  _ => AppColors.accent,
};

/// On home: each event on now (a seasonal one, then the week's quests),
/// what's next to earn and how close the player is. Tap for the whole of
/// it.
class EventCard extends ConsumerWidget {
  const EventCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider).onHome;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Column(
        children: [
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _Card(event: event),
            ),
          if (events.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// One event's card on its own (home lays them out side by side on a
/// tablet).
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event});

  final GameEvent event;

  @override
  Widget build(BuildContext context) => _Card(event: event);
}

class _Card extends StatelessWidget {
  const _Card({required this.event});

  final GameEvent event;

  @override
  Widget build(BuildContext context) {
    final color = seasonColor(event.season);
    final next = event.next;
    return PopCard(
      borderRadius: 24,
      tint: color,
      glow: color,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => showEventSheet(context, event.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                RewardPreview(reward: next ?? event.rewards.last, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              event.isWeekly
                                  ? event.title
                                  : '${event.title} event',
                              style: AppTextStyles.display(fontSize: 17),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Pill(text: event.timeLeft, color: color),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        next == null
                            ? event.isWeekly
                                  ? 'All done this week. New quests on Monday.'
                                  : 'You earned everything. Yours every ${event.title}.'
                            : _nextLine(event, next),
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (next != null) ...[
                        const SizedBox(height: 8),
                        _Bar(value: _progress(event, next), color: color),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
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

/// "Play 4 more games for Jack's Lantern, free".
String _nextLine(GameEvent event, EventReward next) {
  final games = (next.games - event.games).clamp(0, 999);
  final days = (next.days - event.days).clamp(0, 999);
  final parts = [
    if (games > 0) 'play $games more game${games == 1 ? '' : 's'}',
    if (days > 0) 'come by on $days more day${days == 1 ? '' : 's'}',
  ];
  final what = parts.join(' and ');
  return '${what[0].toUpperCase()}${what.substring(1)} for ${next.name}'
      '${next.isCoins ? '.' : ', free.'}';
}

double _progress(GameEvent event, EventReward reward) {
  final total = reward.games + reward.days;
  if (total == 0) return 1;
  final done =
      event.games.clamp(0, reward.games) + event.days.clamp(0, reward.days);
  return done / total;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: AppTextStyles.body(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ),
    );
  }
}

/// A reward at a glance: a frame on the player's own picture, or a small
/// living window onto a world.
class RewardPreview extends ConsumerWidget {
  const RewardPreview({super.key, required this.reward, this.size = 64});

  final EventReward reward;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reward.isCoins) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.coinGold.withValues(alpha: 0.35),
              AppColors.coinGold.withValues(alpha: 0.05),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: CoinIcon(size: size * 0.62),
      );
    }
    if (reward.isWorld) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: SizedBox.square(
          dimension: size,
          child: UtopiaWorld(style: UtopiaThemes.byId(reward.itemId).world),
        ),
      );
    }
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: UserAvatar.fromProfile(
          profile,
          fallbackInitial: '?',
          radius: size * 0.32,
          aura: reward.itemId,
        ),
      ),
    );
  }
}

/// The whole event: every reward, what earns it and how close they are.
Future<void> showEventSheet(BuildContext context, String eventId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EventSheet(eventId: eventId),
  );
}

class _EventSheet extends ConsumerWidget {
  const _EventSheet({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref
        .watch(eventsProvider)
        .events
        .where((e) => e.id == eventId)
        .firstOrNull;
    if (event == null) return const SizedBox.shrink();
    final color = seasonColor(event.season);
    return _SheetFrame(
      color: color,
      children: [
        Text(event.title, style: AppTextStyles.display(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          event.isWeekly
              ? 'Coins for playing, new every Monday. ${event.timeLeft}.'
              : 'Earn these free by playing. They stay yours, and come back '
                    'every ${event.title}. ${event.timeLeft}.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final reward in event.rewards) ...[
          _RewardRow(event: event, reward: reward, color: color),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_esports_rounded,
              size: 15,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Every game counts: online, with friends, or against Chip '
                'and Robo.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RewardRow extends ConsumerWidget {
  const _RewardRow({
    required this.event,
    required this.reward,
    required this.color,
  });

  final GameEvent event;
  final EventReward reward;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopCard(
      borderRadius: 20,
      tint: reward.earned ? AppColors.success : color,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          RewardPreview(reward: reward, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.name, style: AppTextStyles.display(fontSize: 17)),
                Text(
                  switch (reward.kind) {
                    RewardKind.world => 'World',
                    RewardKind.aura => 'Frame',
                    RewardKind.coins => 'Coins',
                  },
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (reward.earned && reward.isCoins)
                  _Pill(text: 'Collected', color: AppColors.success)
                else if (reward.earned)
                  _UseButton(reward: reward)
                else ...[
                  if (reward.games > 0)
                    _Task(
                      label: 'Play ${reward.games} games',
                      done: event.games,
                      of: reward.games,
                      color: color,
                    ),
                  if (reward.days > 0) ...[
                    const SizedBox(height: 4),
                    _Task(
                      label: 'Come by on ${reward.days} days',
                      done: event.days,
                      of: reward.days,
                      color: color,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Task extends StatelessWidget {
  const _Task({
    required this.label,
    required this.done,
    required this.of,
    required this.color,
  });

  final String label;
  final int done;
  final int of;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final n = done.clamp(0, of);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$n/$of',
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: n >= of ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        _Bar(value: n / of, color: n >= of ? AppColors.success : color),
      ],
    );
  }
}

/// Put an earned frame on, or travel to an earned world.
class _UseButton extends ConsumerWidget {
  const _UseButton({required this.reward, this.big = false});

  final EventReward reward;
  final bool big;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    // Already in that world, or already wearing that frame.
    final here = reward.isWorld
        ? ref.watch(themeControllerProvider).id == reward.itemId
        : me != null &&
              activeAura(ref.watch(profileByIdProvider(me)).valueOrNull) ==
                  reward.itemId;
    final label = reward.isWorld
        ? (here ? "You're here" : 'Travel there')
        : (here ? 'Wearing it' : 'Wear it');
    Future<void> use() async {
      if (reward.isWorld) {
        if (here) return;
        Navigator.of(context).pop();
        ref
            .read(themeTeleportProvider.notifier)
            .travelTo(UtopiaThemes.byId(reward.itemId));
        return;
      }
      if (here) return;
      try {
        await ref.read(auraRepositoryProvider).equip(reward.itemId);
        if (me != null) ref.invalidate(profileByIdProvider(me));
        ref.read(gameAudioProvider).play(Sfx.reaction);
        if (context.mounted) {
          showUtopiaToast(
            context,
            "You're wearing ${reward.name}.",
            kind: ToastKind.success,
          );
        }
      } catch (_) {
        if (context.mounted) {
          showUtopiaToast(
            context,
            "Couldn't put it on. Try again?",
            kind: ToastKind.error,
          );
        }
      }
    }

    if (big) {
      return PrimaryButton(label: label, onPressed: here ? null : use);
    }
    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        onPressed: here ? null : use,
        icon: Icon(
          reward.isWorld ? Icons.public_rounded : Icons.auto_awesome_rounded,
          size: 16,
        ),
        label: Text(label),
      ),
    );
  }
}

/// Just earned: a celebration with the reward, and a button to use it.
Future<void> showEarnedSheet(BuildContext context, List<EventReward> earned) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SheetFrame(
      color: AppColors.coinGold,
      confetti: true,
      children: [
        Text(
          earned.every((r) => r.isCoins) ? 'Quest complete!' : 'Unlocked!',
          style: AppTextStyles.display(fontSize: 30),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final reward in earned) ...[
          RewardPreview(reward: reward, size: 110),
          const SizedBox(height: AppSpacing.sm),
          Text(
            reward.isCoins ? '+${reward.name}' : reward.name,
            style: AppTextStyles.display(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            switch (reward.kind) {
              RewardKind.world =>
                "A new world, yours for good. It's open whenever its "
                    'season is on.',
              RewardKind.aura =>
                'A new frame, yours for good. You can wear it whenever '
                    'its season is on.',
              RewardKind.coins =>
                "Added to your coins. Keep playing: "
                    "there's more this week.",
            },
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!reward.isCoins) _UseButton(reward: reward, big: true),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.color,
    required this.children,
    this.confetti = false,
  });

  final Color color;
  final List<Widget> children;
  final bool confetti;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.background],
        ),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      child: Stack(
        children: [
          SafeArea(
            top: false,
            child: SingleChildScrollView(
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
                  ...children,
                ],
              ),
            ),
          ),
          if (confetti)
            const Positioned.fill(
              child: IgnorePointer(child: ConfettiBurst(pieces: 80)),
            ),
        ],
      ),
    );
  }
}

/// At the top of the store while an event is on: its items aren't for
/// sale, they're earned by playing.
class EventStoreBanner extends ConsumerWidget {
  const EventStoreBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref
        .watch(eventsProvider)
        .events
        .where((e) => !e.isWeekly)
        .firstOrNull;
    if (event == null) return const SizedBox.shrink();
    final color = seasonColor(event.season);
    final names = [for (final r in event.rewards) r.name];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: PopCard(
        borderRadius: 22,
        tint: color,
        glow: color,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => showEventSheet(context, event.id),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  RewardPreview(reward: event.rewards.last, size: 48),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${event.title} event · ${event.timeLeft}',
                          style: AppTextStyles.display(fontSize: 15),
                        ),
                        Text(
                          event.allEarned
                              ? 'You earned ${names.join(' and ')}. Enjoy!'
                              : 'Earn ${names.join(' and ')} free, just by playing.',
                          style: AppTextStyles.body(
                            fontSize: 12,
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
      ),
    );
  }
}
