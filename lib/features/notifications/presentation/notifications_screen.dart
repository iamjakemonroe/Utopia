import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/arrive.dart';
import '../../../core/widgets/back_to_home.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../chess/presentation/controllers/chess_match_controller.dart';
import '../../friends/presentation/providers/friends_providers.dart';
import '../../friends/presentation/widgets/friends_popup.dart';
import '../data/notification_repository.dart';
import 'answer_buttons.dart';
import 'notification_actions.dart';
import 'notification_center.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/bots/bots.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../../core/layout/responsive.dart';
import '../../../l10n/strings.dart';
import '../../coins/presentation/gift_note.dart';

/// The people in the notifications, [ids] joined by commas, fetched at
/// once: each row asking for its own went to the server once a row, and
/// each answer laid the list out again as the screen opened.
final _actorsProvider = FutureProvider.autoDispose
    .family<Map<String, Map<String, dynamic>>, String>((ref, ids) async {
      if (ids.isEmpty) return const {};
      final rows = await ref
          .watch(profileRepositoryProvider)
          .fetchByIds(ids.split(','));
      return {for (final r in rows) r['id'] as String: r};
    });

/// Everything that's happened: friend requests (answer them right here),
/// requests accepted, and challenges. Opening it marks everything read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Timer? _markRead;

  @override
  void initState() {
    super.initState();
    final me = ref.read(currentUserProvider)?.id;
    if (me != null) {
      ref.read(friendsPopupControllerProvider(me).notifier).refresh();
    }
    // Long enough to see what's new before the dots go.
    _markRead = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) markNotificationsRead(ref);
    });
  }

  @override
  void dispose() {
    _markRead?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.id;
    final notifications = ref.watch(notificationsProvider);
    final friends = me == null
        ? null
        : ref.watch(friendsPopupControllerProvider(me));
    final invites = me == null
        ? const <Map<String, dynamic>>[]
        : ref.watch(incomingInvitesProvider(me)).valueOrNull ?? const [];
    final pendingInvites = {
      for (final i in invites)
        if (i['status'] == 'pending') i['id'] as String,
    };
    final pendingRequests = {
      for (final r in friends?.incomingRequests ?? const []) r['id'] as String,
    };

    final list = notifications.valueOrNull ?? const <AppNotification>[];
    final actorIds = {
      for (final n in list)
        if (n.actorId != null &&
            n.kind != 'report_update' &&
            !isBotId(n.actorId))
          n.actorId!,
    }.toList()..sort();
    final actors = ref.watch(_actorsProvider(actorIds.join(','))).valueOrNull;
    final now = DateTime.now();
    final today = [
      for (final n in list)
        if (now.difference(n.createdAt) < const Duration(hours: 24)) n,
    ];
    final earlier = [
      for (final n in list)
        if (now.difference(n.createdAt) >= const Duration(hours: 24)) n,
    ];

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const BackOrHomeButton(),
          title: Text(strings.notificationsNotifications),
          actions: [
            IconButton(
              tooltip: strings.notificationsFriends,
              icon: const Icon(Icons.people_alt_rounded),
              onPressed: () => showFriendsPopup(context),
            ),
          ],
        ),
        body: AppBackground(
          child: SafeArea(
            child: notifications.isLoading && list.isEmpty
                ? const Center(child: UtopiaLoader(size: 64))
                : list.isEmpty
                ? const _Empty()
                : ListView(
                    padding: context.readablePadding(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.xl,
                    ),
                    children: [
                      if (today.isNotEmpty) ...[
                        _Heading(strings.notificationsToday),
                        for (final (i, n) in today.indexed)
                          _Row(
                            notification: n,
                            index: i,
                            open: _isOpen(n, pendingRequests, pendingInvites),
                            actor: actors?[n.actorId],
                          ),
                      ],
                      if (earlier.isNotEmpty) ...[
                        _Heading(strings.notificationsEarlier),
                        for (final (i, n) in earlier.indexed)
                          _Row(
                            notification: n,
                            index: today.length + i,
                            open: _isOpen(n, pendingRequests, pendingInvites),
                            actor: actors?[n.actorId],
                          ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Whether the request or challenge can still be answered.
  bool _isOpen(AppNotification n, Set<String> requests, Set<String> invites) =>
      switch (n.kind) {
        'friend_request' => requests.contains(n.refId),
        'game_invite' => invites.contains(n.refId),
        _ => false,
      };
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.sm),
      child: Text(
        text,
        style: AppTextStyles.display(
          fontSize: 16,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Row extends ConsumerStatefulWidget {
  const _Row({
    required this.notification,
    required this.index,
    required this.open,
    this.actor,
  });

  final AppNotification notification;
  final int index;
  final bool open;

  /// Who it's from, once everyone's been fetched.
  final Map<String, dynamic>? actor;

  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  bool _busy = false;
  String? _answered;

  Future<void> _answer(bool accept) async {
    final n = widget.notification;
    final id = n.refId;
    if (id == null) return;
    setState(() => _busy = true);
    final ok = n.kind == 'friend_request'
        ? await answerFriendRequest(
            ref,
            requestId: id,
            fromId: n.actorId,
            accept: accept,
          )
        : await answerGameInvite(
            ref,
            inviteId: id,
            stake: (n.data['stake'] as num?)?.toInt() ?? 0,
            accept: accept,
            game: n.data['game'] as String?,
          );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _answered = accept
            ? (n.kind == 'friend_request'
                  ? strings.notificationsFriends
                  : strings.notificationsAccepted)
            : strings.notificationsDeclined;
      }
    });
  }

  /// A birthday wish back to the friend whose birthday it is.
  Future<void> _wish() async {
    final friend = widget.notification.actorId;
    if (friend == null) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      await ref
          .read(supabaseClientProvider)
          .rpc('wish_happy_birthday', params: {'p_friend': friend});
      ok = true;
      ref.read(gameAudioProvider).play(Sfx.reaction);
    } catch (e) {
      if (mounted) {
        showUtopiaToast(
          context,
          e.toString().contains('not their birthday')
              ? strings.notificationsTheirBirthdayIsOverCatch
              : strings.notificationsCouldnTSendThatTry,
          kind: ToastKind.error,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _answered = strings.notificationsWished;
    });
  }

  /// A profile already loaded (a friend's, a computer player's), without
  /// asking the server for it: everyone's fetched together.
  Map<String, dynamic>? _known(String id) {
    final provider = profileByIdProvider(id);
    if (!isBotId(id) && !ref.exists(provider)) return null;
    return ref.watch(provider).valueOrNull;
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
        : widget.actor ?? _known(actor);
    final name = fromUtopia
        ? strings.notificationsUtopia
        : actor == null
        ? strings.notificationsSomeone
        : profileDisplayName(profile, actor);
    final look = NotificationLook.of(n, name);
    final open = widget.open && _answered == null;

    return Arrive(
      duration: Duration(milliseconds: 350 + widget.index.clamp(0, 8) * 70),
      fade: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: PopCard(
          borderRadius: 22,
          tint: n.unread ? look.color : null,
          glow: n.unread ? look.color : null,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
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
                          child: Icon(look.icon, size: 12, color: Colors.white),
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
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          look.subtitle,
                          style: AppTextStyles.body(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (look.quote != null) ...[
                          const SizedBox(height: 6),
                          GiftNote(look.quote!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _ago(n.createdAt),
                        style: AppTextStyles.body(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (n.unread) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: look.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (open &&
                  (n.kind == 'friend_request' || n.kind == 'game_invite'))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: AnswerButtons(
                    busy: _busy,
                    acceptLabel: n.kind == 'game_invite'
                        ? strings.notificationsPlay
                        : strings.notificationsAccept,
                    onDecline: () => _answer(false),
                    onAccept: () => _answer(true),
                  ),
                )
              else if (_answered != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _answered!,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.readable(AppColors.success),
                      ),
                    ),
                  ),
                )
              else if (n.kind == 'friend_birthday' &&
                  n.createdAt.isAfter(
                    DateTime.now().subtract(const Duration(days: 1)),
                  ))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: look.color,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _busy ? null : _wish,
                      icon: const Icon(Icons.cake_rounded, size: 18),
                      label: Text(strings.notificationsWishHappyBirthday),
                    ),
                  ),
                )
              else if (n.kind == 'friend_accepted')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.push('/chess'),
                      icon: const Icon(Icons.extension_rounded, size: 18),
                      label: Text(strings.notificationsPlayAGame),
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

String _ago(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${at.day}/${at.month}';
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinBuddy(mood: BuddyMood.idle, size: 96),
            const SizedBox(height: AppSpacing.md),
            Text(
              strings.notificationsAllQuiet,
              style: AppTextStyles.display(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              strings.notificationsFriendRequestsAndChallengesWill,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
