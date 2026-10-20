import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/notifications/local_notifications.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/router/app_router.dart';
import '../../../core/settings/gameplay_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../chess/domain/time_control.dart';
import '../../friends/presentation/providers/friends_providers.dart';
import '../data/notification_repository.dart';
import 'answer_buttons.dart';
import 'notification_actions.dart';

/// How a notification reads: a line about who did what, a second line,
/// and its icon and color.
class NotificationLook {
  const NotificationLook(this.title, this.subtitle, this.icon, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// Who news from Utopia itself (a report fixed) comes from: Chip.
  static const utopia = <String, dynamic>{
    'display_name': 'Utopia',
    'avatar_kind': 'chip',
  };

  static NotificationLook of(AppNotification n, String name) {
    switch (n.kind) {
      case 'friend_request':
        return NotificationLook(
          '$name wants to be friends',
          'Accept and you can challenge each other any time.',
          Icons.person_add_alt_1_rounded,
          AppColors.sky,
        );
      case 'friend_accepted':
        return NotificationLook(
          '$name accepted your request',
          "You're friends now. Send a challenge!",
          Icons.people_rounded,
          AppColors.success,
        );
      case 'game_invite':
        final time = TimeControl(
          (n.data['minutes'] as num?)?.toInt() ?? 10,
          (n.data['increment'] as num?)?.toInt() ?? 0,
        );
        final stake = (n.data['stake'] as num?)?.toInt() ?? 0;
        final checkers = n.data['game'] == 'checkers';
        return NotificationLook(
          '$name challenged you',
          '${checkers ? 'Checkers' : 'Chess'} · ${time.label} · ${stake == 0 ? 'Free' : '${formatCoins(stake)} coin entry'}',
          checkers ? Icons.blur_circular_rounded : Icons.extension_rounded,
          AppColors.coinGold,
        );
      case 'friend_birthday':
        return NotificationLook(
          "It's $name's birthday!",
          'Wish them a happy birthday.',
          Icons.cake_rounded,
          const Color(0xFFFF6FAE),
        );
      case 'coin_gift':
        final coins = (n.data['coins'] as num?)?.toInt() ?? 0;
        return NotificationLook(
          '$name sent you ${formatCoins(coins)} coins',
          'A gift. They’re in your coins now.',
          Icons.redeem_rounded,
          AppColors.coinGold,
        );
      case 'report_update':
        final fixed = n.data['status'] == 'fixed';
        final idea = n.data['idea'] == true;
        final note = n.data['note'] as String?;
        return NotificationLook(
          fixed
              ? (idea ? 'Your idea is in Utopia!' : 'Your report is fixed!')
              : (idea ? 'About your idea' : 'About your report'),
          note != null && note.isNotEmpty ? note : 'Thanks for telling us.',
          idea ? Icons.lightbulb_rounded : Icons.build_circle_rounded,
          fixed ? AppColors.success : AppColors.sky,
        );
      case 'birthday_wish':
        return NotificationLook(
          '$name wished you a happy birthday!',
          'Have a wonderful day.',
          Icons.celebration_rounded,
          const Color(0xFFFFD166),
        );
      default:
        return NotificationLook(
          name,
          '',
          Icons.notifications_rounded,
          AppColors.accent,
        );
    }
  }
}

/// Watches the player's notifications for the whole session. A new one pops
/// up as a banner over whatever screen they're on (a game included), with
/// its answer buttons right there; while the app is in the background it
/// becomes a phone notification instead. Also looks after the reminders
/// and opens whatever a tapped phone notification points at.
class NotificationCenter extends ConsumerStatefulWidget {
  const NotificationCenter({super.key});

  @override
  ConsumerState<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends ConsumerState<NotificationCenter>
    with WidgetsBindingObserver {
  /// The newest notification already there when we started watching:
  /// older ones are history, not news.
  int? _baseline;
  final List<AppNotification> _queue = [];
  AppNotification? _showing;
  Timer? _hide;
  bool _askedPermission = false;
  AppLifecycleState _life = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocalNotifications.instance.tapped.addListener(_onTapped);
    LocalNotifications.instance.init().then((_) {
      _onTapped();
      _reschedule();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalNotifications.instance.tapped.removeListener(_onTapped);
    _hide?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _life = state;
    // Reminders count from the last time the app was used.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      _reschedule();
    }
  }

  void _reschedule() {
    final signedIn = ref.read(currentUserProvider) != null;
    LocalNotifications.instance.scheduleReminders(
      enabled: signedIn && ref.read(gameplaySettingsProvider).reminders,
    );
  }

  /// A phone notification was tapped: open what it points at, once the
  /// app is past its intro.
  void _onTapped() {
    final route = LocalNotifications.instance.tapped.value;
    if (route == null) return;
    LocalNotifications.instance.tapped.value = null;
    final router = ref.read(goRouterProvider);
    void go() {
      final at = currentPath(router);
      if (at == '/splash') {
        Future.delayed(const Duration(milliseconds: 700), go);
        return;
      }
      if (at != route) router.push(route);
    }

    go();
  }

  void _onNotifications(List<AppNotification> list) {
    final newest = list.isEmpty ? 0 : list.first.id;
    final baseline = _baseline;
    if (baseline == null) {
      _baseline = newest;
      _maybeAskPermission();
      return;
    }
    final fresh = [
      for (final n in list.reversed)
        if (n.id > baseline && n.unread) n,
    ];
    if (newest > baseline) _baseline = newest;
    if (fresh.isEmpty) return;

    // Friend lists and requests have moved on.
    final me = ref.read(currentUserProvider)?.id;
    if (me != null) {
      ref.read(friendsPopupControllerProvider(me).notifier).refresh();
    }

    final inFront = _life == AppLifecycleState.resumed;
    for (final n in fresh) {
      if (inFront) {
        _queue.add(n);
      } else {
        _systemNotify(n);
      }
    }
    if (inFront) _next();
  }

  Future<void> _systemNotify(AppNotification n) async {
    final actor = n.actorId;
    var name = 'Someone';
    if (actor != null) {
      try {
        final profile = await ref
            .read(profileRepositoryProvider)
            .fetchById(actor);
        name = profileDisplayName(profile, actor);
      } catch (_) {}
    }
    final look = NotificationLook.of(n, name);
    LocalNotifications.instance.show(
      id: n.id % 100000,
      title: look.title,
      body: look.subtitle,
      route: '/notifications',
    );
  }

  /// Asks for permission to notify once, on the home screen (never in the
  /// middle of a game), for accounts friends can find.
  void _maybeAskPermission() {
    if (_askedPermission) return;
    _askedPermission = true;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool('notif.asked') ?? false) return;
    void ask() {
      if (!mounted || ref.read(isAnonymousProvider)) return;
      final at = currentPath(ref.read(goRouterProvider));
      if (at != '/home') {
        Future.delayed(const Duration(seconds: 5), ask);
        return;
      }
      prefs.setBool('notif.asked', true);
      LocalNotifications.instance.requestPermission();
    }

    Future.delayed(const Duration(seconds: 3), ask);
  }

  void _next() {
    if (_showing != null || _queue.isEmpty || !mounted) return;
    final n = _queue.removeAt(0);
    setState(() => _showing = n);
    HapticFeedback.mediumImpact();
    ref.read(gameAudioProvider).play(Sfx.reaction);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 7), _dismiss);
  }

  void _dismiss() {
    _hide?.cancel();
    if (!mounted) return;
    setState(() => _showing = null);
    // Let the banner slide away before the next one.
    Future.delayed(const Duration(milliseconds: 380), _next);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationsProvider, (_, next) {
      final list = next.valueOrNull;
      if (list != null) _onNotifications(list);
    });
    // Signed out and in again: start fresh.
    ref.listen(currentUserProvider.select((u) => u?.id), (prev, next) {
      if (prev != next) {
        _baseline = null;
        _queue.clear();
        _askedPermission = false;
        if (_showing != null) setState(() => _showing = null);
        _reschedule();
      }
    });
    ref.listen(gameplaySettingsProvider.select((s) => s.reminders), (_, _) {
      _reschedule();
    });

    final top = MediaQuery.paddingOf(context).top;
    final n = _showing;
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 380),
          curve: n == null ? Curves.easeInCubic : Curves.easeOutBack,
          left: 10,
          right: 10,
          top: n == null ? -180 : top + 6,
          child: n == null
              ? const SizedBox.shrink()
              : _Banner(
                  key: ValueKey(n.id),
                  notification: n,
                  onClose: _dismiss,
                  onOpen: () {
                    _dismiss();
                    markNotificationsRead(ref, [n.id]);
                    ref.read(goRouterProvider).push('/notifications');
                  },
                ),
        ),
      ],
    );
  }
}

class _Banner extends ConsumerStatefulWidget {
  const _Banner({
    super.key,
    required this.notification,
    required this.onClose,
    required this.onOpen,
  });

  final AppNotification notification;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  ConsumerState<_Banner> createState() => _BannerState();
}

class _BannerState extends ConsumerState<_Banner> {
  bool _busy = false;

  Future<void> _answer(bool accept) async {
    final n = widget.notification;
    final ref0 = n.refId;
    if (ref0 == null) return;
    setState(() => _busy = true);
    if (n.kind == 'friend_request') {
      await answerFriendRequest(
        ref,
        requestId: ref0,
        fromId: n.actorId,
        accept: accept,
      );
    } else if (n.kind == 'game_invite') {
      await answerGameInvite(
        ref,
        inviteId: ref0,
        stake: (n.data['stake'] as num?)?.toInt() ?? 0,
        accept: accept,
        game: n.data['game'] as String?,
      );
    }
    markNotificationsRead(ref, [n.id]);
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final actor = n.actorId;
    final fromUtopia = n.kind == 'report_update';
    final profile = fromUtopia
        ? NotificationLook.utopia
        : actor == null
        ? null
        : ref.watch(profileByIdProvider(actor)).valueOrNull;
    final name = fromUtopia
        ? 'Utopia'
        : actor == null
        ? 'Someone'
        : profileDisplayName(profile, actor);
    final look = NotificationLook.of(n, name);
    final answerable = n.kind == 'friend_request' || n.kind == 'game_invite';

    return Material(
      type: MaterialType.transparency,
      child: Dismissible(
        key: ValueKey('banner-${n.id}'),
        direction: DismissDirection.up,
        onDismissed: (_) => widget.onClose(),
        child: GestureDetector(
          onTap: widget.onOpen,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    look.color.withValues(alpha: 0.22),
                    AppColors.surfaceElevated,
                  ),
                  AppColors.surface,
                ],
              ),
              border: Border.all(
                color: look.color.withValues(alpha: 0.8),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: look.color.withValues(alpha: 0.4),
                  blurRadius: 18,
                ),
                const BoxShadow(color: Color(0x66000000), blurRadius: 12),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar.fromProfile(
                          profile,
                          fallbackInitial: name,
                          radius: 22,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: look.color,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              look.icon,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            look.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            look.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                if (answerable) ...[
                  const SizedBox(height: 8),
                  AnswerButtons(
                    busy: _busy,
                    acceptLabel: n.kind == 'game_invite' ? 'Play' : 'Accept',
                    onDecline: () => _answer(false),
                    onAccept: () => _answer(true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
