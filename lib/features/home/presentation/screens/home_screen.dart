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
import '../../../../core/widgets/doodle_ink.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/tilt_3d.dart';
import '../../../../core/widgets/primary_button.dart';
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
import '../../../chess/presentation/controllers/chess_match_controller.dart';
import '../../../friends/presentation/widgets/friend_icon_button.dart';
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
                    ? _MusicLine(key: const ValueKey('music'), music: music)
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
                                  style: AppTextStyles.display(fontSize: 20),
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
    barrierLabel: 'Close',
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
                          child: _BigBubble(
                            greeting: greeting,
                            shine: _shine,
                            burst: t,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Opacity(
                        opacity: (fade * 0.7).clamp(0.0, 1.0),
                        child: Text(
                          'Tap anywhere to close',
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
          child: RepaintBoundary(
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
                    'Save your account to keep your coins and worlds on any phone.',
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
                      'Pick a username so friends can find you.',
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

class _IncomingInvites extends ConsumerWidget {
  const _IncomingInvites({required this.myId});

  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites =
        ref.watch(incomingInvitesProvider(myId)).valueOrNull ?? const [];
    final pending = invites.where((i) => i['status'] == 'pending').toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pending.map((invite) => _InviteCard(invite: invite)).toList(),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite});

  final Map<String, dynamic> invite;

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
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
      if (matchId != null && context.mounted) {
        context.push(boardMatchRoute(invite['game'] as String?, matchId));
      }
    } catch (e) {
      if (context.mounted) {
        showUtopiaToast(
          context,
          friendlyError(e, fallback: 'That challenge is no longer open.'),
          kind: ToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromId = invite['from_user'] as String;
    final profile = ref.watch(profileByIdProvider(fromId)).valueOrNull;
    final name = profileDisplayName(profile, fromId);
    final stake = (invite['stake'] as num).toInt();
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
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        child: Row(
          children: [
            UserAvatar.fromProfile(profile, fallbackInitial: name, radius: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name wants a game',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        invite['game'] == 'checkers' ? 'Checkers' : 'Chess',
                        style: AppTextStyles.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        speedIcon(time.speed),
                        size: 15,
                        color: speedColor(time.speed),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        time.label,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (stake == 0) ...[
                        Icon(
                          Icons.favorite_rounded,
                          size: 14,
                          color: AppColors.coral,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Free',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ] else
                        CoinAmount(
                          stake,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Decline',
              icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
              onPressed: () => ref
                  .read(chessRepositoryProvider)
                  .respondMatchInvite(
                    inviteId: invite['id'] as String,
                    accept: false,
                  )
                  .catchError((_) => null),
            ),
            SizedBox(
              width: 92,
              child: PrimaryButton(
                label: 'Play',
                color: AppColors.success,
                onPressed: () => _accept(context, ref),
              ),
            ),
          ],
        ),
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
              Text('Games', style: AppTextStyles.display(fontSize: 20)),
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
              title: 'Chess',
              color: AppColors.accent,
              facts: const [
                (Icons.timer_rounded, '1 to 30 min'),
                (Icons.public_rounded, 'Online & friends'),
              ],
              onTap: () => context.push('/chess'),
            ),
            _GameTile(
              game: GameKind.ludo,
              title: 'Ludo',
              color: AppColors.mint,
              facts: const [
                (Icons.groups_rounded, '2 to 6 players'),
                (Icons.vpn_key_rounded, 'Room codes'),
              ],
              onTap: () => context.push('/ludo'),
            ),
            _GameTile(
              game: GameKind.checkers,
              title: 'Checkers',
              color: AppColors.coral,
              facts: const [
                (Icons.bolt_rounded, 'Multi-jumps'),
                (Icons.wifi_off_rounded, 'Play offline'),
              ],
              onTap: () => context.push('/checkers'),
            ),
            _GameTile(
              game: GameKind.doodle,
              title: 'Guess My Doodle',
              color: const Color(0xFFFF5C9C),
              facts: const [
                (Icons.brush_rounded, 'Draw & guess'),
                (Icons.groups_rounded, '2 to 8 players'),
              ],
              onTap: () => context.push('/guess-my-doodle'),
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
                                      'Your game is still on',
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
                                      'Rejoin',
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final v = Curves.easeInOut.transform(_c.value);
          return Transform.scale(
            scale: 1 + 0.06 * v,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [
                    Color.lerp(widget.color, Colors.white, 0.5)!,
                    widget.color,
                  ],
                ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.4 + 0.3 * v),
                    blurRadius: 12 + 10 * v,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: widget.size * 0.62,
        ),
      ),
    );
  }
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
    final name = id == null ? 'You' : profileDisplayName(profile, id);
    return Semantics(
      button: true,
      label: 'Open menu',
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
                          'Sketchbook',
                          style: AppTextStyles.display(fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Draw anything or color a picture, with real art tools.',
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
                        'Worlds & pieces',
                        style: AppTextStyles.display(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${UtopiaThemes.utopia.length} worlds and ${UtopiaThemes.colors.length} color themes, and pieces made of crystal, candy and starlight.',
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
    GameKind.chess => 'Chess',
    GameKind.checkers => 'Checkers',
    GameKind.ludo => 'Ludo',
    GameKind.doodle => 'Guess My Doodle',
  };
  final offline = game.offline;
  if (offline != null) {
    final against = offline.opponent;
    if (against == null || against == 'bots' || against == 'friends') {
      return '$name with ${against ?? 'bots'} · pick up where you left off';
    }
    return '$name vs $against · pick up where you left off';
  }
  return switch (game.kind) {
    GameKind.ludo => 'Ludo · the table is waiting',
    GameKind.doodle => '$name · the game goes on without you',
    _ => '$name · your clock may be running',
  };
}
