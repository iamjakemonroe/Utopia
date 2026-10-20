import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chess/presentation/controllers/chess_match_controller.dart';
import '../../../chess/presentation/sent_challenges.dart';
import '../../../../core/widgets/bouncy_dialog.dart';
import '../../../notifications/presentation/answer_buttons.dart';
import '../../../notifications/presentation/notification_actions.dart';
import '../../data/friend_repository.dart';
import '../../data/presence.dart';
import 'online_bubble.dart';
import '../providers/friends_providers.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../coins/presentation/providers/coin_balance_provider.dart';
import '../../../coins/presentation/send_coins_sheet.dart';
import '../../../store/presentation/coin_shop.dart';
import 'invite_stake_sheet.dart';
import '../../../../l10n/strings.dart';

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
            friendlyError(e, fallback: strings.friendsCouldnTSendTheRequest),
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
                          strings.friendsFriends,
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
                      hintText: strings.friendsSearchByUsernameOrName,
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
                    Tab(text: strings.friendsAll),
                    Tab(text: strings.friendsFriends2(data.friends.length)),
                    Tab(text: strings.friendsRecents),
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
                              // Pulled down: who's around, asked now.
                              onRefresh: () async {
                                ref.invalidate(friendsOnlineProvider);
                                try {
                                  await Future.wait<void>([
                                    controller.refresh(),
                                    ref
                                        .read(friendsOnlineProvider.future)
                                        .then((_) {}),
                                  ]).timeout(const Duration(seconds: 8));
                                } catch (_) {
                                  // Offline: it stays as it was.
                                }
                              },
                              onGift: (f) => showSendCoinsSheet(context, (
                                id: f.id,
                                name: f.name,
                                avatarUrl: f.avatarUrl,
                                avatarKind: f.avatarKind,
                                avatarSeed: f.avatarSeed,
                              )),
                              emptyLabel: searching
                                  ? strings.friendsNoFriendsMatchThat
                                  : strings.friendsNoFriendsYetSearchFor,
                            ),
                            _PeopleList(
                              people: data.recents.where(matches).toList(),
                              statusOf: data.statusOf,
                              onAdd: add,
                              emptyLabel: strings.friendsPeopleYouVePlayedWho,
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
      return _Empty(strings.friendsPlayAMatchOrSearch);
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
                  strings.friendsOnUtopia,
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
            _Empty(strings.friendsNoOneByThatName)
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
                  strings.friendsWantsToBeFriends,
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
    this.onGift,
    this.onRefresh,
  });

  final List<SocialProfile> people;

  /// Pull down to refresh (the Friends tab: who's around now).
  final Future<void> Function()? onRefresh;

  /// Send a friend coins (the Friends tab).
  final ValueChanged<SocialProfile>? onGift;

  /// Friends who are around now: each row shows whether they are. Null
  /// shows nothing (only friends can see each other online).
  final Set<String>? online;
  final FriendshipStatus Function(String) statusOf;
  final ValueChanged<String> onAdd;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final refresh = onRefresh;
    if (refresh == null) return _list(context);
    return RefreshIndicator(
      onRefresh: refresh,
      color: AppColors.coinGoldBright,
      backgroundColor: AppColors.surface,
      child: _list(context),
    );
  }

  Widget _list(BuildContext context) {
    if (people.isEmpty) {
      if (onRefresh == null) return _Empty(emptyLabel);
      // Still pulls down when there's nobody yet.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: 240, child: _Empty(emptyLabel))],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: people.length,
      itemBuilder: (context, index) {
        final person = people[index];
        return _PersonRow(
          person: person,
          status: statusOf(person.id),
          onAdd: onAdd,
          online: online?.contains(person.id),
          onGift: onGift == null ? null : () => onGift!(person),
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
    this.onGift,
  });

  final SocialProfile person;
  final FriendshipStatus status;
  final ValueChanged<String> onAdd;

  /// Send them coins: shown in place of "Friends" (the Friends tab says
  /// that already).
  final VoidCallback? onGift;

  /// Whether they're around now, or null to not say.
  final bool? online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    final sent = me == null
        ? null
        : waitingChallenges(
            ref.watch(outgoingInvitesProvider(me)).valueOrNull ?? const [],
          ).where((i) => i['to_user'] == person.id).firstOrNull;
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
                // The bubble's box has room for its glow: it sits a
                // little past the picture's corner.
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: OnlineBubble(online: online!),
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
          if (onGift != null && status == FriendshipStatus.friends)
            _GiftButton(onTap: onGift!)
          else
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
          // A challenge already waiting for them: "Sent" (tap to take it
          // back) in place of Play.
          if (sent != null)
            FilledButton.tonalIcon(
              onPressed: () => _askCancel(context, ref, sent),
              icon: const Icon(Icons.hourglass_top_rounded, size: 18),
              label: Text(strings.friendsSent),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: AppColors.textSecondary.withValues(
                  alpha: 0.14,
                ),
                foregroundColor: AppColors.textSecondary,
              ),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () => _invite(context),
              icon: const Icon(Icons.sports_esports_outlined, size: 18),
              label: Text(strings.friendsPlay),
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

  Future<void> _askCancel(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> invite,
  ) async {
    final left = challengeMinutesLeft(invite);
    final sure = await confirmBouncy(
      context: context,
      title: strings.friendsChallengeSent,
      message: left == null
          ? strings.friendsWaitingForToAnswerTake(person.name)
          : strings.friendsHasMinLeftToAnswer(person.name, left),
      confirmLabel: strings.friendsCancelChallenge,
      cancelLabel: strings.friendsKeepIt,
      destructive: true,
    );
    if (sure && context.mounted) {
      await cancelChallenge(context, ref, invite, person.name);
    }
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
          strings.friendsChallengeSentToItLasts(person.name),
          kind: ToastKind.success,
          icon: Icons.send_rounded,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showUtopiaToast(
          context,
          friendlyError(e, fallback: strings.friendsCouldnTSendTheChallenge),
          kind: ToastKind.error,
        );
      }
    }
  }
}

/// Send a friend coins.
class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: strings.friendsSendCoins,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        icon: const CoinIcon(size: 18),
        label: Text(strings.friendsGift),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: AppColors.coinGold.withValues(alpha: 0.18),
          foregroundColor: AppColors.coinGoldBright,
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
        strings.friendsFriends,
        AppColors.success,
      ),
      FriendshipStatus.requested => pill(
        Icons.schedule_rounded,
        strings.friendsRequested,
        AppColors.textSecondary,
      ),
      FriendshipStatus.incoming => GestureDetector(
        onTap: onAccept,
        child: pill(
          Icons.person_add_alt_1_rounded,
          strings.friendsAccept,
          AppColors.sky,
        ),
      ),
      FriendshipStatus.self => const SizedBox.shrink(),
      FriendshipStatus.none => IconButton(
        icon: Icon(Icons.person_add_alt_1, color: AppColors.textSecondary),
        tooltip: strings.friendsAddFriend,
        onPressed: onAdd,
      ),
    };
  }
}
