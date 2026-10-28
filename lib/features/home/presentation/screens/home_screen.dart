import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/session_memory.dart';
import '../../../../core/router/popup_tracker.dart';
import '../../../auth/presentation/guest_transfer.dart';
import '../../../install/presentation/install_sheet.dart';
import '../../../coins/presentation/daily_reward_sheet.dart';
import '../../../birthday/presentation/birthday_party.dart';
import '../../../birthday/presentation/birthday_providers.dart';
import '../../../welcome/presentation/welcome_week.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/now_playing/now_playing.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/settings/gameplay_settings.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/coin_balance_pill.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/drawn_ahead.dart';
import '../../../../core/widgets/doodle_ink.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/tilt_3d.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/utopia_themes.dart';
import '../../../chess/data/chess_repository.dart';
import '../../../chess/domain/time_control.dart';
import '../../../chess/presentation/widgets/time_control_style.dart';
import '../../../chip/presentation/chip_chat_sheet.dart';
import '../../../coins/presentation/providers/coin_balance_provider.dart';
import '../../../store/presentation/coin_shop.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../../store/presentation/store_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../friends/data/presence.dart';
import '../../../friends/presentation/providers/friends_providers.dart';
import '../../../chess/presentation/controllers/chess_match_controller.dart';
import '../../../chess/presentation/sent_challenges.dart';
import '../../../friends/presentation/widgets/friend_icon_button.dart';
import '../../../notifications/presentation/answer_buttons.dart';
import '../../../notifications/presentation/notification_bell.dart';
import '../../../profile/presentation/username_dialog.dart';
import '../../data/active_game.dart';
import '../../domain/greeting.dart';
import '../widgets/now_playing_widgets.dart';
import '../widgets/side_menu.dart';
import '../../../events/presentation/event_widgets.dart';
import '../../../events/presentation/events_controller.dart';
import '../../../../core/analytics/analytics.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/layout/tile_grid.dart';
import '../../../../core/widgets/frosted.dart';
import '../../../../core/widgets/frame_island.dart';
import '../../../../core/widgets/live_transform.dart';
import '../../../../l10n/strings.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// The player this run of the app has already looked for a game to go
  /// back to. Only the first look after opening the app (or after signing
  /// in as someone else) jumps straight in; after that the "Rejoin" card is
  /// there instead.
  static String? _resumeCheckedFor;

  /// The player today's welcome and reward have been offered to this
  /// session (per player, so switching accounts offers them again). In a
  /// browser a refresh is the same session, not a new visit.
  static String? _offeredTo;
  static String? get _rewardOfferedTo =>
      _offeredTo ??= SessionMemory.read('home_offered_to');
  static set _rewardOfferedTo(String? me) {
    _offeredTo = me;
    SessionMemory.write('home_offered_to', me);
  }

  /// The player whose visit the events have counted this session.
  static String? _eventsVisitedBy;
  Timer? _rewardTimer;

  final Set<String> _navigatedInviteIds = {};
  bool _invitesPrimed = false;

  /// Challenges we sent that were waiting the last time we looked: one
  /// that's been declined or has run out since gets a word.
  final Set<String> _waitingInviteIds = {};
  bool _adoptedWorld = false;
  GoRouter? _router;
  late final NowPlayingController _music;

  @override
  void initState() {
    super.initState();
    // Chip listens along only while home is on screen.
    _music = ref.read(nowPlayingProvider.notifier)..setWatching(true);
    // Events count the day (and hand back this season's earned items).
    final me = ref.read(currentUserProvider)?.id;
    if (me != null && _eventsVisitedBy != me) {
      _eventsVisitedBy = me;
      ref.read(eventsProvider.notifier).visit();
      ref.read(analyticsProvider).log('app_open', {
        'guest': ref.read(isAnonymousProvider),
      });
      // A guest's things that couldn't come over at sign-in (offline) come
      // now.
      unawaited(finishGuestTransfer(ref));
    }
    _offerRewardSoon();
  }

  /// Once a session, a moment after landing on home (and only on home,
  /// with nothing else popped up), offers today's daily reward. If the
  /// server can't be asked yet, or something else is on screen, it tries
  /// again a little later; leaving home waits until coming back.
  void _offerRewardSoon([Duration delay = const Duration(milliseconds: 1600)]) {
    final me = ref.read(currentUserProvider)?.id;
    if (me == null || _rewardOfferedTo == me) return;
    _rewardTimer?.cancel();
    _rewardTimer = Timer(delay, () async {
      if (!mounted || _rewardOfferedTo == me) return;
      final router = _router;
      if (router == null || currentPath(router) != '/home') return;
      if (PopupTracker.instance.open.value > 0) {
        _offerRewardSoon(const Duration(seconds: 4));
        return;
      }
      _rewardOfferedTo = me;
      // Their birthday party comes first (on the day), then a new player's
      // welcome week (or its last-day reminder, or its goodbye), then
      // today's reward.
      await celebrateBirthdayIfToday(context, ref);
      if (!mounted) return;
      await showWelcomeIfDue(context, ref);
      if (!mounted) return;
      final asked = await showDailyRewardIfReady(context, ref);
      if (!asked && mounted) {
        _rewardOfferedTo = null;
        _offerRewardSoon(const Duration(seconds: 15));
        return;
      }
      // In a browser, then: installing Utopia (or its store app, once out).
      if (mounted && kIsWeb) await offerWebAppIfDue(context, ref);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onRoute);
      _router = router?..routerDelegate.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    _rewardTimer?.cancel();
    _music.setWatching(false);
    super.dispose();
  }

  /// Back on home (from a game, say): check again for an unfinished game.
  void _onRoute() {
    final router = _router;
    final path = router == null ? null : currentPath(router);
    if (!mounted) return;
    _music.setWatching(path == '/home');
    if (path == '/home') {
      ref.invalidate(activeGameProvider);
      _offerRewardSoon();
    }
  }

  /// Pulled down: everything on home asked for again (coins, profile and
  /// frame, events, challenges, notifications, what they own, and any game
  /// still on). It all updates by itself too; this is for when they want
  /// it now.
  Future<void> _refresh() async {
    ref.read(gameAudioProvider).play(Sfx.tap);
    final me = ref.read(currentUserProvider)?.id;
    ref.invalidate(activeGameProvider);
    ref.invalidate(coinBalanceProvider);
    ref.invalidate(notificationsProvider);
    if (me != null) {
      ref.invalidate(profileByIdProvider(me));
      ref.invalidate(incomingInvitesProvider(me));
    }
    try {
      await Future.wait<void>([
        ref.read(eventsProvider.notifier).visit(),
        ref.read(storeControllerProvider.notifier).refresh(),
        ref.read(activeGameProvider.future).then((_) {}),
        if (me != null) ref.read(profileByIdProvider(me).future).then((_) {}),
      ]).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Offline, or slow: what could be fetched is in.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnonymous = ref.watch(isAnonymousProvider);
    final myId = ref.watch(currentUserProvider)?.id;

    // Opening the app mid-game (it closed, or they backed out) goes
    // straight back to that game, with home underneath.
    if (myId != null && _resumeCheckedFor != myId) {
      ref.listen(activeGameProvider, (_, next) {
        if (_resumeCheckedFor == myId || !next.hasValue) return;
        _resumeCheckedFor = myId;
        final game = next.value;
        if (game != null && mounted) context.push(game.route);
      });
    }

    // Loads what the player owns and rents (which also moves them out of a
    // rented world whose time ran out), and says so here.
    ref.listen(storeControllerProvider.select((s) => s.message), (_, message) {
      if (message != null &&
          (message.contains('ran out') || message.contains('is over'))) {
        showUtopiaToast(context, message, icon: Icons.timer_off_rounded);
        ref.read(storeControllerProvider.notifier).clearMessage();
      }
    });

    // A fresh install lands in the world saved on the account.
    if (myId != null && !_adoptedWorld) {
      final saved = ref.watch(
        profileByIdProvider(
          myId,
        ).select((p) => p.valueOrNull?['equipped_theme'] as String?),
      );
      if (saved != null) {
        _adoptedWorld = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(themeControllerProvider.notifier).adoptFromAccount(saved);
          }
        });
      }
    }

    // The moment an invite we *sent* gets accepted, jump straight into the
    // match — the person who accepted already gets the match id back
    // directly from respond_match_invite, this is the other half for us.
    if (myId != null) {
      ref.listen(outgoingInvitesProvider(myId), (previous, next) {
        next.whenData((invites) {
          final accepted = [
            for (final invite in invites)
              if (invite['status'] == 'accepted' && invite['match_id'] != null)
                invite,
          ];
          // A friend said no, or it ran out: say so (once, and only for
          // ones seen waiting, never old history).
          for (final invite in invites) {
            final id = invite['id'] as String;
            final status = invite['status'];
            if (status == 'pending') {
              _waitingInviteIds.add(id);
              continue;
            }
            if (!_waitingInviteIds.remove(id)) continue;
            if (status != 'declined' && status != 'expired') continue;
            // Not over a game, or anything else on top of home.
            if (ModalRoute.of(context)?.isCurrent == false) continue;
            final toId = invite['to_user'] as String;
            final name = profileDisplayName(
              ref.read(profileByIdProvider(toId)).valueOrNull,
              toId,
            );
            showUtopiaToast(
              context,
              status == 'declined'
                  ? strings.homeSaidNotNow(name)
                  : strings.homeYourChallengeToRanOut(name),
              icon: status == 'declined'
                  ? Icons.do_not_disturb_on_outlined
                  : Icons.hourglass_disabled_rounded,
            );
          }
          // The first batch is history: invites accepted before we were
          // watching (earlier games) must not reopen those games.
          if (!_invitesPrimed) {
            _invitesPrimed = true;
            _navigatedInviteIds.addAll(accepted.map((i) => i['id'] as String));
            return;
          }
          for (final invite in accepted) {
            if (_navigatedInviteIds.add(invite['id'] as String)) {
              context.push(
                boardMatchRoute(
                  invite['game'] as String?,
                  invite['match_id'] as String,
                ),
              );
            }
          }
        });
      });
    }

    // On a tablet the cards under the greeting sit side by side, a few to
    // a row (like the games), instead of each stretching across.
    final wide = context.screenSize.width >= 760;
    final about = [
      _HomeGreeting(myId: myId),
      const SizedBox(height: AppSpacing.lg),
      if (wide)
        TileGrid(
          columns: context.screenSize.width >= 1200 ? 3 : 2,
          spacing: AppSpacing.md,
          children: [
            if (isAnonymous)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _SaveAccountBanner(
                  onTap: () => context.push('/auth/link'),
                ),
              ),
            if (myId != null) ...[
              const _RejoinCard(),
              for (final event in ref.watch(eventsProvider).onHome)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: EventTile(event: event),
                ),
              _UsernameBanner(myId: myId),
              _IncomingInvites(myId: myId),
              _SentChallenges(myId: myId),
            ],
          ],
        )
      else ...[
        if (isAnonymous) ...[
          _SaveAccountBanner(onTap: () => context.push('/auth/link')),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (myId != null) const _RejoinCard(),
        if (myId != null) const EventCard(),
        if (myId != null) _UsernameBanner(myId: myId),
        if (myId != null) _IncomingInvites(myId: myId),
        if (myId != null) _SentChallenges(myId: myId),
      ],
    ];
    const extras = [_SketchbookCard(), _StoreCard()];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Your picture's aura spills past the bar (a dragon's wings, flames);
        // don't cut it off.
        clipBehavior: Clip.none,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Center(child: _MenuAvatar(userId: myId)),
        ),
        actions: [
          const NotificationBellButton(),
          // Friends need a real account to find and add you by; guests are
          // pointed at "save your account" instead (banner below).
          if (!isAnonymous) const FriendIconButton(),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md, left: AppSpacing.xs),
            child: CoinBalancePill(),
          ),
        ],
      ),
      body: DoodleInk(
        child: AppBackground(
          under: const DrawnAhead(ahead: SideMenuAhead()),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.coinGoldBright,
              backgroundColor: AppColors.surface,
              child: ListView(
                // Pulls down even when it all fits.
                physics: const AlwaysScrollableScrollPhysics(),
                // On a tablet: centered, wide enough for all the games in a
                // row.
                padding: context.readablePadding(
                  maxWidth: 1040,
                  min: AppSpacing.lg,
                  top: MediaQuery.of(context).padding.top > 0
                      ? AppSpacing.md
                      : AppSpacing.lg,
                  bottom: AppSpacing.lg,
                ),
                children: [
                  // On a tablet: two columns, you on the left (Chip, your
                  // cards, the sketchbook and store) and the games on the
                  // right. On a phone, one after the other.
                  ...about,
                  _GamesGrid(columns: context.screenSize.width >= 760 ? 4 : 2),
                  const SizedBox(height: AppSpacing.md),
                  ...extras,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeGreeting extends ConsumerStatefulWidget {
  const _HomeGreeting({required this.myId});

  final String? myId;

  @override
  ConsumerState<_HomeGreeting> createState() => _HomeGreetingState();
}

class _HomeGreetingState extends ConsumerState<_HomeGreeting> {
  // One pick per visit to home, so it changes but doesn't flicker.
  final _seed = math.Random().nextInt(1 << 20);

  @override
  Widget build(BuildContext context) {
    final id = widget.myId;
    final profile = id == null
        ? null
        : ref.watch(profileByIdProvider(id)).valueOrNull;
    // On their birthday, Chip only talks about that (not even the music).
    final birthday = ref.watch(birthdayTodayProvider);
    final greeting = pickGreeting(
      DateTime.now(),
      greetingName(profile),
      math.Random(_seed),
      birthday,
    );
    final music = ref.watch(nowPlayingProvider);
    final vibing =
        !birthday &&
        music.listening &&
        ref.watch(gameplaySettingsProvider).showNowPlaying;

    return Row(
      children: [
        // Tap Chip to chat with him.
        GestureDetector(
          onTap: () => showChipChat(context),
          child: AmbientTilt3D(
            child: CoinBuddy(
              mood: vibing ? music.chipLine.mood : greeting.mood,
              flavor: vibing ? music.chipLine.flavor : ChipFlavor.none,
              size: 72,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          // As wide as there's room for, up to a phone's worth: on a tablet
          // or a computer it ran the whole width of the screen.
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _bubbleMaxWidth),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => vibing
                      ? showNowPlaying(context, ref)
                      : _showGreeting(context, ref, greeting),
                  child: _GreetingBubble(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.9, end: 1.0).animate(animation),
                          alignment: Alignment.centerLeft,
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous, ?current],
                      ),
                      child: vibing
                          ? _MusicLine(
                              key: const ValueKey('music'),
                              music: music,
                            )
                          : Column(
                              key: const ValueKey('greeting'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      greeting.icon,
                                      size: 16,
                                      color: AppColors.coinGold,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        greeting.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.display(
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  greeting.line,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.88,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// What Chip says while the player has music on: the song and its cover,
/// with little bars bouncing along.
class _MusicLine extends StatelessWidget {
  const _MusicLine({super.key, required this.music});

  final NowPlayingState music;

  @override
  Widget build(BuildContext context) {
    final track = music.track;
    final line = music.chipLine;
    final by = track == null
        ? null
        : track.artist.isNotEmpty
        ? track.artist
        : (track.show ?? track.source);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MediaKindBadge(
                    kind: track?.kind ?? MediaKind.unknown,
                    playing: music.listening,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      line.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // What's on is the star of the bubble.
              Text(
                track?.title ?? line.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display(fontSize: 19),
              ),
              if (by != null && by.isNotEmpty)
                Text(
                  by,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ),
        if (track != null) ...[
          const SizedBox(width: AppSpacing.sm),
          TrackArt(track: track, size: 46),
        ],
      ],
    );
  }
}

/// Chip says the whole thing: the world blurs away, Chip hops in and a big
/// bubble pops out with the full greeting, sparkles bursting round it and a
/// shine sweeping across. Tap anywhere to let it go.
void _showGreeting(BuildContext context, WidgetRef ref, Greeting greeting) {
  HapticFeedback.lightImpact();
  ref.read(gameAudioProvider).play(Sfx.reaction);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.homeClose,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 650),
    pageBuilder: (context, animation, _) =>
        _GreetingPopup(greeting: greeting, animation: animation),
  );
}

class _GreetingPopup extends StatefulWidget {
  const _GreetingPopup({required this.greeting, required this.animation});

  final Greeting greeting;
  final Animation<double> animation;

  @override
  State<_GreetingPopup> createState() => _GreetingPopupState();
}

class _GreetingPopupState extends State<_GreetingPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = widget.greeting;
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final t = widget.animation.value;
        final closing = widget.animation.status == AnimationStatus.reverse;
        final fade = Curves.easeOut.transform(t);
        final pop = closing
            ? Curves.easeIn.transform(t)
            : Curves.elasticOut.transform(((t - 0.12) / 0.88).clamp(0, 1));
        final hop = closing ? t : Curves.elasticOut.transform(t);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Frosted(
                sigma: 14 * fade,
                child: ColoredBox(
                  color: AppColors.background.withValues(alpha: 0.45 * fade),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      Transform.translate(
                        offset: Offset(0, -30 * (1 - hop)),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * hop,
                          child: CoinBuddy(mood: greeting.mood, size: 104),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: pop.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.4 + 0.6 * pop,
                          alignment: Alignment.topCenter,
                          // A tablet's or a computer's width would stretch
                          // what Chip says across the whole screen.
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _bubbleMaxWidth,
                            ),
                            child: _BigBubble(
                              greeting: greeting,
                              shine: _shine,
                              burst: t,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Opacity(
                        opacity: (fade * 0.7).clamp(0.0, 1.0),
                        child: Text(
                          strings.homeTapAnywhereToClose,
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: AppColors.textPrimary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BigBubble extends StatelessWidget {
  const _BigBubble({
    required this.greeting,
    required this.shine,
    required this.burst,
  });

  final Greeting greeting;
  final Animation<double> shine;

  /// 0-1, how far the opening sparkle burst has flown.
  final double burst;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _SparkBurstPainter(progress: burst),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The tail, pointing up at Chip.
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(
              child: CustomPaint(
                size: const Size(28, 14),
                painter: _TailPainter(
                  color: Color.lerp(
                    AppColors.surfaceElevated,
                    AppColors.glowRing,
                    0.18,
                  )!,
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      AppColors.surfaceElevated,
                      AppColors.glowRing,
                      0.18,
                    )!,
                    AppColors.surface,
                  ],
                ),
                border: Border.all(
                  color: AppColors.goldBorder.withValues(alpha: 0.85),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  // A shine sweeping across now and then.
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: shine,
                        builder: (context, _) {
                          final v = (shine.value / 0.4).clamp(0.0, 1.0);
                          if (v <= 0 || v >= 1) return const SizedBox.shrink();
                          return FractionalTranslation(
                            translation: Offset(-1.2 + 2.4 * v, 0),
                            child: Transform.rotate(
                              angle: 0.4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.16),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                    stops: const [0.35, 0.5, 0.65],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Icon(
                              greeting.icon,
                              size: 22,
                              color: AppColors.coinGold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              greeting.title,
                              style: AppTextStyles.display(fontSize: 24),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        greeting.line,
                        style: AppTextStyles.body(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width / 2,
        -size.height * 0.4,
        size.width,
        size.height,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color;
}

/// Gold sparkles bursting out from the bubble as it pops.
class _SparkBurstPainter extends CustomPainter {
  _SparkBurstPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05 || progress >= 1) return;
    final c = size.center(Offset.zero);
    final p = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (var i = 0; i < 14; i++) {
      final a = i * 2 * math.pi / 14 + (i.isEven ? 0.2 : -0.1);
      final reach = Offset(
        math.cos(a) * size.width * (0.45 + 0.25 * p),
        math.sin(a) * size.height * (0.55 + 0.6 * p),
      );
      final pos = c + reach;
      final s = (i.isEven ? 7.0 : 4.5) * (1 - p * 0.4);
      final star = Path()
        ..moveTo(pos.dx, pos.dy - s)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx + s, pos.dy)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + s)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx - s, pos.dy)
        ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - s);
      canvas.drawPath(
        star,
        Paint()
          ..color = (i % 3 == 0 ? Colors.white : AppColors.coinGoldBright)
              .withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBurstPainter old) =>
      old.progress != progress;
}

/// Chip's speech bubble: frosted glass with a little tail pointing at Chip,
/// so the greeting reads clearly over any world, with a sparkle drifting
/// around its corner.
/// How wide Chip's speech bubbles on home grow: a phone's width.
const _bubbleMaxWidth = 460.0;

class _GreetingBubble extends StatefulWidget {
  const _GreetingBubble({required this.child});

  final Widget child;

  @override
  State<_GreetingBubble> createState() => _GreetingBubbleState();
}

class _GreetingBubbleState extends State<_GreetingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipPath(
          clipper: const _BubbleClipper(),
          child: Frosted(
            sigma: 14,
            child: CustomPaint(
              painter: _BubblePainter(
                fill: AppColors.surface,
                glow: AppColors.glowRing,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _BubbleClipper.tail + 12,
                  10,
                  14,
                  11,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
        Positioned(
          right: 6,
          top: -6,
          child: FrameIsland(
            size: const Size.square(18),
            child: AnimatedBuilder(
              animation: _twinkle,
              builder: (context, _) {
                final t = _twinkle.value;
                final s = math.sin(t * math.pi);
                // Its biggest size always, grown and shrunk as it's drawn
                // (from its corner, as before): a size that changed every
                // frame laid the whole screen out again every frame.
                return SizedBox.square(
                  dimension: 18,
                  child: Transform.scale(
                    scale: (12 + 6 * s) / 18,
                    alignment: Alignment.topRight,
                    child: Transform.rotate(
                      angle: t * math.pi,
                      child: Opacity(
                        opacity: 0.35 + 0.65 * s,
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: AppColors.coinGoldBright,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleClipper extends CustomClipper<Path> {
  const _BubbleClipper();

  static const tail = 9.0;

  static Path shape(Size size) {
    final body = Path()
      ..addRRect(
        RRect.fromLTRBR(
          tail,
          0,
          size.width,
          size.height,
          const Radius.circular(20),
        ),
      );
    final mid = size.height / 2;
    final point = Path()
      ..moveTo(tail + 2, mid - 9)
      ..quadraticBezierTo(tail - 2, mid - 1, 0, mid + 4)
      ..quadraticBezierTo(tail + 1, mid + 5, tail + 2, mid + 9)
      ..close();
    return Path.combine(PathOperation.union, body, point);
  }

  @override
  Path getClip(Size size) => shape(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.fill, required this.glow});

  final Color fill;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _BubbleClipper.shape(size);
    final rect = Offset.zero & size;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fill.withValues(alpha: 0.72),
            Color.lerp(fill, glow, 0.25)!.withValues(alpha: 0.58),
          ],
        ).createShader(rect),
    );
    // A soft sheen along the top edge, like light on glass.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = glow.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.fill != fill || old.glow != glow;
}

class _SaveAccountBanner extends StatelessWidget {
  const _SaveAccountBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 22,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                GlossyBadge(
                  icon: Icons.shield_rounded,
                  color: AppColors.success,
                  size: 38,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    strings.homeSaveYourAccountToKeep,
                    style: AppTextStyles.body(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UsernameBanner extends ConsumerWidget {
  const _UsernameBanner({required this.myId});

  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(myId)).valueOrNull;
    if (profile == null || profile['username'] != null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: PopCard(
        borderRadius: 22,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => editProfileNames(context, ref),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  GlossyBadge(
                    icon: Icons.alternate_email_rounded,
                    color: AppColors.sky,
                    size: 38,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      strings.homePickAUsernameSoFriends,
                      style: AppTextStyles.body(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// When a challenge runs out (they last 10 minutes); null for an old one.
DateTime? _expiresAt(Map<String, dynamic> invite) =>
    DateTime.tryParse(invite['expires_at'] as String? ?? '')?.toLocal();

class _IncomingInvites extends ConsumerStatefulWidget {
  const _IncomingInvites({required this.myId});

  final String myId;

  @override
  ConsumerState<_IncomingInvites> createState() => _IncomingInvitesState();
}

class _IncomingInvitesState extends ConsumerState<_IncomingInvites> {
  /// Looks again now and then: each challenge's time left, and one that's
  /// run out goes (before the server's sweep says so).
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 20),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _tick;
    final invites =
        ref.watch(incomingInvitesProvider(widget.myId)).valueOrNull ?? const [];
    final now = DateTime.now();
    final pending = invites
        .where(
          (i) =>
              i['status'] == 'pending' && (_expiresAt(i)?.isAfter(now) ?? true),
        )
        .toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pending
            .map((invite) => ChallengeCard(invite: invite))
            .toList(),
      ),
    );
  }
}

/// A challenge a friend sent: who, the game, its clock and entry on
/// tags that wrap (on one line they squeezed together on small phones),
/// and the answer as two full-width buttons underneath.
class ChallengeCard extends ConsumerStatefulWidget {
  const ChallengeCard({super.key, required this.invite});

  final Map<String, dynamic> invite;

  @override
  ConsumerState<ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends ConsumerState<ChallengeCard> {
  bool _declining = false;

  Map<String, dynamic> get invite => widget.invite;

  Future<void> _accept() async {
    final stake = (invite['stake'] as num).toInt();
    final balance = ref.read(coinBalanceProvider).valueOrNull ?? 0;
    if (stake > balance) {
      showCoinShop(context, needed: stake);
      return;
    }
    final repository = ref.read(chessRepositoryProvider);
    try {
      final matchId = await runWithUtopiaLoader(
        context,
        () => repository.respondMatchInvite(
          inviteId: invite['id'] as String,
          accept: true,
        ),
      );
      if (matchId != null && mounted) {
        context.push(boardMatchRoute(invite['game'] as String?, matchId));
      }
    } catch (e) {
      if (mounted) {
        showUtopiaToast(
          context,
          friendlyError(e, fallback: strings.homeThatChallengeIsNoLonger),
          kind: ToastKind.error,
        );
      }
    }
  }

  /// The card goes once the invite's answered (it's watched).
  Future<void> _decline() async {
    setState(() => _declining = true);
    try {
      await ref
          .read(chessRepositoryProvider)
          .respondMatchInvite(inviteId: invite['id'] as String, accept: false);
    } catch (_) {
      if (mounted) setState(() => _declining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromId = invite['from_user'] as String;
    final profile = ref.watch(profileByIdProvider(fromId)).valueOrNull;
    final name = profileDisplayName(profile, fromId);
    final stake = (invite['stake'] as num).toInt();
    final checkers = invite['game'] == 'checkers';
    // A friend who sent it and has since stepped away (their presence is
    // live): the game would start without them, so Play waits for them.
    final me = ref.watch(currentUserProvider)?.id;
    final friend =
        me != null &&
        ref
            .watch(friendsPopupControllerProvider(me))
            .friends
            .any((f) => f.id == fromId);
    final away =
        friend &&
        ref.watch(friendsOnlineProvider).valueOrNull?.contains(fromId) == false;
    final expires = _expiresAt(invite);
    final minutesLeft = expires == null
        ? null
        : math.max(
            1,
            (expires.difference(DateTime.now()).inSeconds / 60).ceil(),
          );
    final time = TimeControl(
      (invite['minutes'] as num?)?.toInt() ?? 10,
      (invite['increment'] as num?)?.toInt() ?? 0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PopCard(
        borderRadius: 22,
        tint: AppColors.accentSecondary,
        glow: AppColors.accentSecondary,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar.fromProfile(
                      profile,
                      fallbackInitial: name,
                      radius: 24,
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentSecondary,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          checkers
                              ? Icons.blur_circular_rounded
                              : Icons.extension_rounded,
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
                        strings.homeChallengedYou(name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _InviteTag(
                            icon: checkers
                                ? Icons.blur_circular_rounded
                                : Icons.extension_rounded,
                            label: checkers
                                ? strings.homeCheckers
                                : strings.homeChess,
                          ),
                          _InviteTag(
                            icon: speedIcon(time.speed),
                            iconColor: speedColor(time.speed),
                            label: time.label,
                          ),
                          if (stake == 0)
                            _InviteTag(
                              icon: Icons.favorite_rounded,
                              iconColor: AppColors.coral,
                              label: strings.homeFree,
                            )
                          else
                            _InviteTag(
                              child: CoinAmount(
                                stake,
                                size: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (minutesLeft != null)
                            _InviteTag(
                              icon: Icons.hourglass_bottom_rounded,
                              label: strings.homeMinLeft(minutesLeft),
                            ),
                        ],
                      ),
                      if (away) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                strings.homeSteppedAwayPlayWaitsFor(name),
                                style: AppTextStyles.body(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnswerButtons(
              acceptLabel: strings.homePlay,
              busy: _declining,
              onDecline: _decline,
              onAccept: away ? null : _accept,
            ),
          ],
        ),
      ),
    );
  }
}

/// The challenges the player sent that are still waiting, each with how
/// long it has left and a way to take it back.
class _SentChallenges extends ConsumerStatefulWidget {
  const _SentChallenges({required this.myId});

  final String myId;

  @override
  ConsumerState<_SentChallenges> createState() => _SentChallengesState();
}

class _SentChallengesState extends ConsumerState<_SentChallenges> {
  /// Looks again now and then, like [_IncomingInvites]: the time left, and
  /// one that's run out goes.
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 20),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _tick;
    final waiting = waitingChallenges(
      ref.watch(outgoingInvitesProvider(widget.myId)).valueOrNull ?? const [],
    );
    if (waiting.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final invite in waiting)
            SentChallengeCard(key: ValueKey(invite['id']), invite: invite),
        ],
      ),
    );
  }
}

/// A challenge the player sent, waiting for their friend: who, the game,
/// its clock and entry, the time it has left, and Cancel.
class SentChallengeCard extends ConsumerStatefulWidget {
  const SentChallengeCard({super.key, required this.invite});

  final Map<String, dynamic> invite;

  @override
  ConsumerState<SentChallengeCard> createState() => _SentChallengeCardState();
}

class _SentChallengeCardState extends ConsumerState<SentChallengeCard> {
  bool _cancelling = false;

  Map<String, dynamic> get invite => widget.invite;

  Future<void> _cancel(String name) async {
    setState(() => _cancelling = true);
    final done = await cancelChallenge(context, ref, invite, name);
    // Gone once cancelled (the invites are watched); back if it wasn't.
    if (!done && mounted) setState(() => _cancelling = false);
  }

  @override
  Widget build(BuildContext context) {
    final toId = invite['to_user'] as String;
    final profile = ref.watch(profileByIdProvider(toId)).valueOrNull;
    final name = profileDisplayName(profile, toId);
    final stake = (invite['stake'] as num).toInt();
    final checkers = invite['game'] == 'checkers';
    final minutesLeft = challengeMinutesLeft(invite);
    final time = TimeControl(
      (invite['minutes'] as num?)?.toInt() ?? 10,
      (invite['increment'] as num?)?.toInt() ?? 0,
    );
    final ink = AppColors.light ? Colors.black : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PopCard(
        borderRadius: 22,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Who, and Cancel beside them; the facts get the card's whole
            // width underneath (beside the button they squeezed into a
            // column on a small phone).
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
                          color: AppColors.accent,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.homeWaitingFor(name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: _cancelling ? null : () => _cancel(name),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: ink.withValues(alpha: 0.25)),
                      shape: const StadiumBorder(),
                      textStyle: AppTextStyles.body(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: _cancelling
                        ? SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : Text(strings.homeCancel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _InviteTag(
                    icon: checkers
                        ? Icons.blur_circular_rounded
                        : Icons.extension_rounded,
                    label: checkers ? strings.homeCheckers : strings.homeChess,
                  ),
                  _InviteTag(
                    icon: speedIcon(time.speed),
                    iconColor: speedColor(time.speed),
                    label: time.label,
                  ),
                  if (stake == 0)
                    _InviteTag(
                      icon: Icons.favorite_rounded,
                      iconColor: AppColors.coral,
                      label: strings.homeFree,
                    )
                  else
                    _InviteTag(
                      child: CoinAmount(
                        stake,
                        size: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (minutesLeft != null)
                    _InviteTag(
                      icon: Icons.hourglass_bottom_rounded,
                      label: strings.homeMinLeft(minutesLeft),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One fact about a challenge, on a soft pill.
class _InviteTag extends StatelessWidget {
  const _InviteTag({this.icon, this.iconColor, this.label, this.child})
    : assert(child != null || label != null);

  final IconData? icon;
  final Color? iconColor;
  final String? label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.light ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: AppColors.light ? 0.05 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withValues(alpha: 0.1)),
      ),
      child:
          child ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: AppColors.readable(
                    iconColor ?? AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label!,
                style: AppTextStyles.body(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
    );
  }
}

/// The games, two to a row (more slot in as they arrive).
class _GamesGrid extends StatelessWidget {
  const _GamesGrid({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                Icons.sports_esports_rounded,
                size: 20,
                color: AppColors.coinGold,
              ),
              const SizedBox(width: 8),
              Text(
                strings.homeGames,
                style: AppTextStyles.display(fontSize: 20),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.7,
          children: [
            _GameTile(
              game: GameKind.chess,
              title: strings.homeChess,
              color: AppColors.accent,
              facts: [
                (Icons.timer_rounded, strings.home1To30Min),
                (Icons.public_rounded, strings.homeOnlineFriends),
              ],
              onTap: () => context.push('/chess'),
            ),
            _GameTile(
              game: GameKind.ludo,
              title: strings.homeLudo,
              color: AppColors.mint,
              facts: [
                (Icons.groups_rounded, strings.home2To6Players),
                (Icons.vpn_key_rounded, strings.homeRoomCodes),
              ],
              onTap: () => context.push('/ludo'),
            ),
            _GameTile(
              game: GameKind.checkers,
              title: strings.homeCheckers,
              color: AppColors.coral,
              facts: [
                (Icons.bolt_rounded, strings.homeMultiJumps),
                (Icons.wifi_off_rounded, strings.homePlayOffline),
              ],
              onTap: () => context.push('/checkers'),
            ),
            _GameTile(
              game: GameKind.doodle,
              title: strings.homeGuessMyDoodle,
              color: const Color(0xFFFF5C9C),
              facts: [
                (Icons.brush_rounded, strings.homeDrawGuess),
                (Icons.groups_rounded, strings.home2To20Players),
              ],
              onTap: () => context.push('/guess-my-doodle'),
            ),
            _GameTile(
              game: GameKind.eights,
              title: strings.homeCrazyEights,
              color: AppColors.sky,
              facts: [
                (Icons.style_rounded, strings.homeEightsAreWild),
                (Icons.groups_rounded, strings.home2To6Players),
              ],
              onTap: () => context.push('/eights'),
            ),
            _GameTile(
              game: GameKind.pool,
              title: strings.poolEightBall,
              color: const Color(0xFF2FD98E),
              facts: [
                (Icons.sports_baseball_rounded, strings.poolTileCues),
                (Icons.monetization_on_rounded, strings.poolTileCoins),
              ],
              onTap: () => context.push('/pool'),
            ),
          ],
        ),
      ],
    );
  }
}

/// One game: its living diorama, a breathing play button, its name and a
/// couple of facts.
class _GameTile extends StatefulWidget {
  const _GameTile({
    required this.game,
    required this.title,
    required this.color,
    required this.facts,
    required this.onTap,
  });

  final GameKind game;
  final String title;
  final Color color;
  final List<(IconData, String)> facts;
  final VoidCallback onTap;

  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        child: PopCard(
          borderRadius: 26,
          tint: widget.color,
          glow: widget.color,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(23),
                        ),
                        child: LayoutBuilder(
                          builder: (context, c) => GameSceneArt(
                            game: widget.game,
                            height: c.maxHeight,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _PlayBubble(color: widget.color, size: 42),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        style: AppTextStyles.display(fontSize: 21),
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final (icon, label) in widget.facts)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(icon, size: 13, color: widget.color),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your game is still on": shown while the player has an unfinished game,
/// glowing gently until they jump back in.
class _RejoinCard extends ConsumerStatefulWidget {
  const _RejoinCard();

  @override
  ConsumerState<_RejoinCard> createState() => _RejoinCardState();
}

class _RejoinCardState extends ConsumerState<_RejoinCard>
    with SingleTickerProviderStateMixin {
  // Made in initState: made lazily, a card never shown would first make it
  // in dispose, when its ticker can't look up the tree any more.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(activeGameProvider).valueOrNull;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: game == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final v = Curves.easeInOut.transform(_pulse.value);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.coral.withValues(
                              alpha: 0.25 + 0.3 * v,
                            ),
                            blurRadius: 10 + 12 * v,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: PopCard(
                    borderRadius: 24,
                    tint: AppColors.coral,
                    glow: AppColors.coral,
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => context.push(game.route),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Row(
                            children: [
                              GlossyBadge(
                                icon: switch (game.kind) {
                                  GameKind.chess => Icons.extension_rounded,
                                  GameKind.checkers =>
                                    Icons.blur_circular_rounded,
                                  GameKind.ludo => Icons.casino_rounded,
                                  GameKind.doodle => Icons.brush_rounded,
                                  GameKind.eights => Icons.style_rounded,
                                  GameKind.pool =>
                                    Icons.sports_baseball_rounded,
                                },
                                color: AppColors.coral,
                                size: 44,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      strings.homeYourGameIsStillOn,
                                      style: AppTextStyles.display(
                                        fontSize: 17,
                                      ),
                                    ),
                                    Text(
                                      _resumeLine(game),
                                      style: AppTextStyles.body(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: AppColors.coral,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      strings.homeRejoin,
                                      style: AppTextStyles.body(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// A round play button that breathes gently.
class _PlayBubble extends StatefulWidget {
  const _PlayBubble({required this.color, this.size = 58});

  final Color color;
  final double size;

  @override
  State<_PlayBubble> createState() => _PlayBubbleState();
}

class _PlayBubbleState extends State<_PlayBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // It pulses forever: by itself, or home is laid out each frame. And
    // only drawn again as it does (grown, its glow brighter), not built.
    return FrameIsland(
      size: Size.square(widget.size),
      child: LiveTransform(
        listenable: _c,
        transform: () {
          final scale = 1 + 0.06 * Curves.easeInOut.transform(_c.value);
          return Matrix4.diagonal3Values(scale, scale, 1);
        },
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _PlayBubblePainter(_c, widget.color),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: widget.size * 0.62,
            ),
          ),
        ),
      ),
    );
  }
}

/// The play button's ball: [color]'s, glowing brighter as [pulse] rises.
class _PlayBubblePainter extends CustomPainter {
  _PlayBubblePainter(this.pulse, this.color) : super(repaint: pulse);

  final Animation<double> pulse;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeInOut.transform(pulse.value);
    BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [Color.lerp(color, Colors.white, 0.5)!, color],
      ),
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.4 + 0.3 * v),
          blurRadius: 12 + 10 * v,
        ),
      ],
    ).createBoxPainter().paint(
      canvas,
      Offset.zero,
      ImageConfiguration(size: size),
    );
  }

  @override
  bool shouldRepaint(_PlayBubblePainter old) =>
      old.pulse != pulse || old.color != color;
}

/// Your avatar in the corner of home; tapping it opens the side menu.
class _MenuAvatar extends ConsumerWidget {
  const _MenuAvatar({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    final profile = id == null
        ? null
        : ref.watch(profileByIdProvider(id)).valueOrNull;
    final name = id == null ? strings.homeYou : profileDisplayName(profile, id);
    return Semantics(
      button: true,
      label: strings.homeOpenMenu,
      child: GestureDetector(
        onTap: () => showSideMenu(context, ref),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                AppColors.goldBorder,
                AppColors.goldBorderBright,
                AppColors.goldBorder,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.glowRing.withValues(alpha: 0.5),
                blurRadius: 10,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar.fromProfile(
                profile,
                fallbackInitial: name,
                radius: 19,
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    size: 10,
                    color: Colors.white,
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

/// A doorway to the store: new worlds and piece sets.
/// In the Doodle world only: the sketchbook, to draw and color.
class _SketchbookCard extends ConsumerWidget {
  const _SketchbookCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeControllerProvider);
    if (UtopiaThemes.active.world.biome != WorldBiome.doodle) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: PopCard(
        borderRadius: 26,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: () => context.push('/sketchbook'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
                    child: Icon(
                      Icons.draw_rounded,
                      color: AppColors.onAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.homeSketchbook,
                          style: AppTextStyles.display(fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.homeDrawAnythingOrColorA,
                          style: AppTextStyles.body(
                            fontSize: 13,
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

class _StoreCard extends StatelessWidget {
  const _StoreCard();

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 26,
      tint: AppColors.accentSecondary,
      glow: AppColors.goldBorderBright,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => context.push('/store'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const CoinBuddy(mood: BuddyMood.excited, size: 64),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.homeWorldsPieces,
                        style: AppTextStyles.display(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.homeWorldsAndColorThemesAnd(
                          UtopiaThemes.utopia.length,
                          UtopiaThemes.colors.length,
                        ),
                        style: AppTextStyles.body(
                          fontSize: 13,
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
    );
  }
}

/// What the "your game is still on" card says about the game.
String _resumeLine(ActiveGame game) {
  final name = switch (game.kind) {
    GameKind.chess => strings.homeChess,
    GameKind.checkers => strings.homeCheckers,
    GameKind.ludo => strings.homeLudo,
    GameKind.doodle => strings.homeGuessMyDoodle,
    GameKind.eights => strings.homeCrazyEights,
    GameKind.pool => strings.poolEightBall,
  };
  final offline = game.offline;
  if (offline != null) {
    final against = offline.opponent;
    if (against == null || against == 'bots' || against == 'friends') {
      return strings.homeWithPickUpWhereYou(name, against ?? 'bots');
    }
    return strings.homeVsPickUpWhereYou(name, against);
  }
  return switch (game.kind) {
    GameKind.ludo => strings.homeLudoTheTableIsWaiting,
    GameKind.eights => strings.homeEightsTheTableIsWaiting,
    GameKind.pool => strings.poolTheTableIsWaiting,
    GameKind.doodle => strings.homeTheGameGoesOnWithout(name),
    _ => strings.homeYourClockMayBeRunning(name),
  };
}
