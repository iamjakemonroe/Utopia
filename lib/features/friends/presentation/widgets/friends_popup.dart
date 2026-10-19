import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chess/presentation/controllers/chess_match_controller.dart';
import '../../../notifications/presentation/answer_buttons.dart';
import '../../../notifications/presentation/notification_actions.dart';
import '../../data/friend_repository.dart';
import '../../data/presence.dart';
import '../providers/friends_providers.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../coins/presentation/providers/coin_balance_provider.dart';
import '../../../store/presentation/coin_shop.dart';
import 'invite_stake_sheet.dart';

/// Opens the friends popup: All / Friends / Recents, with a search that
/// finds anyone on Utopia by username or nickname, and a "Play" challenge
/// on every row. Triggered from the person icon in the home app bar.
void showFriendsPopup(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _FriendsPopup(),
  );
}

class _FriendsPopup extends ConsumerStatefulWidget {
  const _FriendsPopup();

  @override
  ConsumerState<_FriendsPopup> createState() => _FriendsPopupState();
}

class _FriendsPopupState extends ConsumerState<_FriendsPopup> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final me = ref.read(currentUserProvider)?.id;
    if (me != null) {
      // Fresh each time it opens: requests may have been answered elsewhere.
      Future.microtask(
        () => ref.read(friendsPopupControllerProvider(me).notifier).refresh(),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(currentUserProvider)?.id;
    if (myId == null) return const SizedBox.shrink();

    final data = ref.watch(friendsPopupControllerProvider(myId));
    final controller = ref.read(friendsPopupControllerProvider(myId).notifier);
    // Friends who are around now (looked up again every 30 seconds).
    final online = ref.watch(friendsOnlineProvider).valueOrNull ?? const {};
    final query = _searchController.text.trim().toLowerCase().replaceFirst(
      RegExp(r'^@'),
      '',
    );
    final searching = query.isNotEmpty;

    bool matches(SocialProfile p) =>
        !searching ||
        p.name.toLowerCase().contains(query) ||
        (p.username?.toLowerCase().contains(query) ?? false);

    final all = data.all.where(matches).toList();
    final shown = {for (final p in all) p.id};
    final others = [
      for (final row in data.searchResults)
        if (!shown.contains(row['id'])) SocialProfile.fromProfileRow(row),
    ];

    Future<void> add(String id) async {
      try {
        await controller.sendFriendRequest(id);
      } catch (e) {
        if (context.mounted) {
          showUtopiaToast(
            context,
            friendlyError(e, fallback: "Couldn't send the request. Try again."),
            kind: ToastKind.error,
          );
        }
      }
    }

    return DefaultTabController(
      length: 3,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: PopCard(
          borderRadius: 28,
          sheet: true,
          blur: 20,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Friends',
                          style: AppTextStyles.display(fontSize: 24),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      setState(() {});
                      controller.search(v);
                    },
                    style: AppTextStyles.body(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search by username or name',
                      hintStyle: AppTextStyles.body(
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: searching
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                controller.search('');
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (data.incomingRequests.isNotEmpty && !searching) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _IncomingRequests(requests: data.incomingRequests),
                ],
                const SizedBox(height: AppSpacing.xs),
                TabBar(
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.accent,
                  tabs: [
                    Tab(text: 'All'),
                    Tab(text: 'Friends · ${data.friends.length}'),
                    const Tab(text: 'Recents'),
                  ],
                ),
                Expanded(
                  child: data.loading
                      ? const Center(child: UtopiaLoader(size: 40))
                      : TabBarView(
                          children: [
                            _AllTab(
                              people: all,
                              others: others,
                              searching: searching,
                              loadingOthers: data.searching,
                              statusOf: data.statusOf,
                              onAdd: add,
                            ),
                            _PeopleList(
                              // Who's around first.
                              people: [
                                ...data.friends.where(
                                  (f) => matches(f) && online.contains(f.id),
                                ),
                                ...data.friends.where(
                                  (f) => matches(f) && !online.contains(f.id),
                                ),
                              ],
                              online: online,
                              statusOf: data.statusOf,
                              onAdd: add,
                              emptyLabel: searching
                                  ? 'No friends match that.'
                                  : 'No friends yet. Search for someone above.',
                            ),
                            _PeopleList(
                              people: data.recents.where(matches).toList(),
                              statusOf: data.statusOf,
                              onAdd: add,
                              emptyLabel:
                                  "People you've played who aren't friends yet will show up here.",
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Everyone you know, and while searching, everyone else on Utopia who
/// matches.
class _AllTab extends StatelessWidget {
  const _AllTab({
    required this.people,
    required this.others,
    required this.searching,
    required this.loadingOthers,
    required this.statusOf,
    required this.onAdd,
  });

  final List<SocialProfile> people;
  final List<SocialProfile> others;
  final bool searching;
  final bool loadingOthers;
  final FriendshipStatus Function(String) statusOf;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    if (!searching && people.isEmpty) {
      return const _Empty(
        'Play a match or search for a username to add your first friend.',
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        for (final p in people)
          _PersonRow(person: p, status: statusOf(p.id), onAdd: onAdd),
        if (searching) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(Icons.public_rounded, size: 16, color: AppColors.sky),
                const SizedBox(width: 6),
                Text(
                  'On Utopia',
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (loadingOthers)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: UtopiaLoader(size: 36)),
            )
          else if (others.isEmpty && people.isEmpty)
            const _Empty('No one by that name yet.')
          else
            for (final p in others)
              _PersonRow(person: p, status: statusOf(p.id), onAdd: onAdd),
        ],
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Requests waiting on this player: one full-width card each, with Decline
/// and Accept at the end. A long list scrolls inside a few cards' height.
class _IncomingRequests extends StatelessWidget {
  const _IncomingRequests({required this.requests});

  final List<Map<String, dynamic>> requests;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 3 * 66.0),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) => _RequestCard(
          key: ValueKey(requests[index]['id']),
          request: requests[index],
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _answer(bool accept) async {
    setState(() => _busy = true);
    await answerFriendRequest(
      ref,
      requestId: widget.request['id'] as String,
      fromId: widget.request['from_user'] as String,
      accept: accept,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final fromId = widget.request['from_user'] as String;
    final profile = ref.watch(profileByIdProvider(fromId)).valueOrNull;
    final name = profileDisplayName(profile, fromId);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sky.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          UserAvatar.fromProfile(profile, fallbackInitial: name, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(fontWeight: FontWeight.w900),
                ),
                Text(
                  'wants to be friends',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnswerButtons(
            compact: true,
            busy: _busy,
            onDecline: () => _answer(false),
            onAccept: () => _answer(true),
          ),
        ],
      ),
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({
    required this.people,
    required this.statusOf,
    required this.onAdd,
    required this.emptyLabel,
    this.online,
  });

  final List<SocialProfile> people;

  /// Friends who are around now: each row shows whether they are. Null
  /// shows nothing (only friends can see each other online).
  final Set<String>? online;
  final FriendshipStatus Function(String) statusOf;
  final ValueChanged<String> onAdd;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return _Empty(emptyLabel);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: people.length,
      itemBuilder: (context, index) {
        final person = people[index];
        return _PersonRow(
          person: person,
          status: statusOf(person.id),
          onAdd: onAdd,
          online: online?.contains(person.id),
        );
      },
    );
  }
}

class _PersonRow extends ConsumerWidget {
  const _PersonRow({
    required this.person,
    required this.status,
    required this.onAdd,
    this.online,
  });

  final SocialProfile person;
  final FriendshipStatus status;
  final ValueChanged<String> onAdd;

  /// Whether they're around now, or null to not say.
  final bool? online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = UserAvatar(
      avatarUrl: person.avatarUrl,
      avatarKind: person.avatarKind,
      avatarSeed: person.avatarSeed,
      fallbackInitial: person.name,
    );
    return ListTile(
      leading: online == null
          ? avatar
          : Stack(
              clipBehavior: Clip.none,
              children: [
                avatar,
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: OnlineDot(online: online!),
                ),
              ],
            ),
      title: Text(
        person.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body(fontWeight: FontWeight.w700),
      ),
      subtitle: person.username != null
          ? Text(
              '@${person.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: _FriendState(
              key: ValueKey(status),
              status: status,
              onAdd: () => onAdd(person.id),
              onAccept: () {
                final me = ref.read(currentUserProvider)?.id;
                final requestId = me == null
                    ? null
                    : ref
                          .read(friendsPopupControllerProvider(me))
                          .incomingRequestFrom(person.id);
                if (requestId == null) return;
                answerFriendRequest(
                  ref,
                  requestId: requestId,
                  fromId: person.id,
                  accept: true,
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          FilledButton.tonalIcon(
            onPressed: () => _invite(context),
            icon: const Icon(Icons.sports_esports_outlined, size: 18),
            label: const Text('Play'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              foregroundColor: AppColors.accentSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _invite(BuildContext context) async {
    final challenge = await showInviteStakeSheet(
      context,
      opponentName: person.name,
    );
    if (challenge == null || !context.mounted) return;

    final container = ProviderScope.containerOf(context);
    final balance = container.read(coinBalanceProvider).valueOrNull ?? 0;
    if (challenge.entry > balance) {
      showCoinShop(context, needed: challenge.entry);
      return;
    }
    final repository = container.read(chessRepositoryProvider);
    try {
      await repository.sendMatchInvite(
        toUserId: person.id,
        stake: challenge.entry,
        minutes: challenge.time.minutes,
        increment: challenge.time.increment,
        game: challenge.game,
      );
      if (context.mounted) {
        showUtopiaToast(
          context,
          'Challenge sent to ${person.name}',
          kind: ToastKind.success,
          icon: Icons.send_rounded,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showUtopiaToast(
          context,
          friendlyError(e, fallback: "Couldn't send the challenge. Try again."),
          kind: ToastKind.error,
        );
      }
    }
  }
}

/// On a friend's picture: green while they're around, an empty ring
/// when they're not.
class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: online ? 'Online' : 'Offline',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: online ? AppColors.success : Colors.transparent,
          border: Border.all(
            color: online
                ? AppColors.surface
                : Colors.white.withValues(alpha: 0.55),
            width: online ? 2.5 : 1.8,
          ),
          boxShadow: online
              ? [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// Where you stand with someone: add them, a request on its way, theirs to
/// accept, or already friends.
class _FriendState extends StatelessWidget {
  const _FriendState({
    super.key,
    required this.status,
    required this.onAdd,
    required this.onAccept,
  });

  final FriendshipStatus status;
  final VoidCallback onAdd;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    Widget pill(IconData icon, String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );

    return switch (status) {
      FriendshipStatus.friends => pill(
        Icons.check_circle_rounded,
        'Friends',
        AppColors.success,
      ),
      FriendshipStatus.requested => pill(
        Icons.schedule_rounded,
        'Requested',
        AppColors.textSecondary,
      ),
      FriendshipStatus.incoming => GestureDetector(
        onTap: onAccept,
        child: pill(Icons.person_add_alt_1_rounded, 'Accept', AppColors.sky),
      ),
      FriendshipStatus.self => const SizedBox.shrink(),
      FriendshipStatus.none => IconButton(
        icon: Icon(Icons.person_add_alt_1, color: AppColors.textSecondary),
        tooltip: 'Add friend',
        onPressed: onAdd,
      ),
    };
  }
}
