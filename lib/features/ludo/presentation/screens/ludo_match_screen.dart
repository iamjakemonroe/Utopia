import '../../../../core/widgets/leave_guard.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/audio/sound_controls.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_freshness.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/widgets/confetti_burst.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/bouncy_dialog.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/settings/gameplay_settings.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/ludo_engine.dart';
import '../../../chat/domain/voice_note.dart';
import '../controllers/ludo_match_controller.dart';
import '../widgets/ludo_board.dart';
import '../widgets/ludo_board_geometry.dart';
import '../widgets/ludo_capture_bubble.dart';
import '../widgets/ludo_chat_sheet.dart';
import '../widgets/ludo_dice.dart';
import '../widgets/ludo_pieces.dart';
import '../widgets/ludo_player_card.dart';
import '../widgets/ludo_rules_sheet.dart';
import '../widgets/ludo_seat_panel.dart';
import '../../../chat/presentation/voice_notes.dart';
import '../../../events/presentation/events_controller.dart';
import '../../../../core/layout/game_stage.dart';
import '../../../../l10n/strings.dart';

class LudoMatchScreen extends ConsumerStatefulWidget {
  const LudoMatchScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<LudoMatchScreen> createState() => _LudoMatchScreenState();
}

class _LudoMatchScreenState extends ConsumerState<LudoMatchScreen> {
  /// Players whose chat this device hides.
  final Set<String> _muted = {};

  /// Latest chat line per player, shown as a speech bubble for a moment.
  final Map<String, (String, DateTime, Duration)> _speech = {};

  /// Who rolled last and when, so the die lingers with them long enough
  /// for everyone to see what came up before it moves on.
  LudoColor? _lastRoller;
  DateTime _lastRollAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _refresh;
  bool _playedResult = false;
  bool _leaving = false;

  /// The reaction card that's open: the capture, and whose piece in it
  /// (the one that took it, or one sent home) its player tapped.
  (int, LudoColor)? _reactingTo;

  /// Finished while the others play on, and chose to stay and watch.
  bool _watching = false;

  /// Someone just finished while the game goes on: who, their place, and
  /// when (a banner over the board for a moment).
  (LudoColor, int, DateTime)? _finishBanner;
  static const _bannerFor = Duration(milliseconds: 3200);

  // The roller keeps the die until everyone has seen what they got.
  static const _diceHold = Duration(milliseconds: 1200);

  /// The one die, wherever it is: it keeps its state as it moves from seat
  /// to seat, so a roll that arrives as it moves still tumbles and lands
  /// (a new die there would just appear showing the number).
  final _diceKey = GlobalKey();
  static const _speechFor = Duration(seconds: 4);

  /// An offline game waits while the app is in the background.
  late final AppLifecycleListener _life;

  LudoMatchController get _controller =>
      ref.read(ludoMatchControllerProvider(widget.matchId).notifier);

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onHide: () => _controller.appHidden(),
      onShow: () => _controller.appShown(),
    );
  }

  @override
  void dispose() {
    _life.dispose();
    _refresh?.cancel();
    super.dispose();
  }

  void _refreshIn(Duration d) {
    _refresh?.cancel();
    _refresh = Timer(d, () {
      if (mounted) setState(() {});
    });
  }

  void _onStateChange(LudoMatchState? prev, LudoMatchState next) {
    if (prev == null || prev.loading) return;
    final audio = ref.read(gameAudioProvider);
    final me = ref.read(currentUserProvider)?.id;

    if (next.game.rollSeq != prev.game.rollSeq && next.game.lastRoll != null) {
      _lastRoller = next.game.lastRoll!.color;
      _lastRollAt = DateTime.now();
      _refreshIn(_diceHold);
    }
    if (next.isMyTurn &&
        !next.game.hasRolled &&
        !(prev.isMyTurn && !prev.game.hasRolled)) {
      audio.play(Sfx.yourTurn);
    }
    final rules = next.game.rules;
    int home(LudoState g) =>
        g.tokens.values.expand((t) => t).where(rules.isHome).length;
    if (home(next.game) > home(prev.game)) audio.play(Sfx.home);

    final reaction = next.reactions.lastOrNull;
    if (reaction != null && reaction != prev.reactions.lastOrNull) {
      audio.play(switch (reaction.kind) {
        TokenReaction.war => Sfx.captureWar,
        TokenReaction.peace => Sfx.capturePeace,
        TokenReaction.sad => Sfx.reactSad,
        TokenReaction.again => Sfx.reactAgain,
        TokenReaction.none => Sfx.reaction,
      });
    }

    // Someone got all four home while the others play on: a banner and a
    // fanfare (the game's end has its own).
    if (next.game.finished.length > prev.game.finished.length &&
        !next.game.isOver) {
      final who = next.game.finished.last;
      final place = next.game.finished.length;
      setState(() => _finishBanner = (who, place, DateTime.now()));
      _refreshIn(_bannerFor);
      audio.play(who == next.myColor && place == 1 ? Sfx.win : Sfx.finish);
    }

    // I've finished and the others play on: the game counts for me now
    // (once the move is in), whether I watch or go.
    if (next.iFinished && !next.busy && next.isActive && !_playedResult) {
      _playedResult = true;
      ref
          .read(eventsProvider.notifier)
          .gameFinished('ludo', matchId: next.isLocal ? null : widget.matchId);
    }

    if (next.chat.length > prev.chat.length) {
      final seen = prev.chat.isEmpty ? next.chatBaseline : prev.chat.last.id;
      var longest = Duration.zero;
      for (final m in next.chat) {
        if (m.id <= seen || m.id <= next.chatBaseline) continue;
        if (m.kind == 'reaction' || _muted.contains(m.senderId)) continue;
        final voice = m.kind == 'voice' ? VoiceNote.parse(m.body) : null;
        // A voice note's bubble stays up while it plays.
        final showFor = voice == null
            ? _speechFor
            : Duration(milliseconds: voice.ms + 1500);
        _speech[m.senderId] = (m.body, DateTime.now(), showFor);
        if (voice != null &&
            m.senderId != me &&
            ref.read(gameplaySettingsProvider).autoPlayVoice) {
          ref.read(voicePlaybackProvider.notifier).play(voice);
        } else if (m.senderId != me) {
          audio.play(Sfx.chat);
        }
        if (showFor > longest) longest = showFor;
      }
      if (longest > Duration.zero) _refreshIn(longest);
    }

    final mine = next.myColor;
    if (mine != null &&
        next.missedTurns(mine) > prev.missedTurns(mine) &&
        next.isActive) {
      final left = kMaxMissedTurns - next.missedTurns(mine);
      showUtopiaToast(
        context,
        left == 1
            ? strings.ludoMatchOutOfTimeMissOne
            : strings.ludoMatchOutOfTimeYourTurn,
        kind: ToastKind.warning,
      );
    }

    final done = !next.isActive && next.status != 'pending';
    if (done && !_playedResult) {
      _playedResult = true;
      ref
          .read(eventsProvider.notifier)
          .gameFinished('ludo', matchId: next.isLocal ? null : widget.matchId);
      audio.play(next.winnerId == me ? Sfx.win : Sfx.lose);
    }
  }

  Future<void> _confirmLeave(LudoMatchState state) async {
    if (!state.isActive || state.iLeft) {
      LeaveGuard.release();
      context.go('/home');
      return;
    }
    // Finished: going costs nothing, the place (and any prize) is kept.
    if (state.iFinished) {
      await _controller.leave();
      LeaveGuard.release();
      if (mounted) context.go(state.isLocal ? '/ludo' : '/home');
      return;
    }
    final others = state.game.activePlayers.length - 1;
    final ok = await confirmBouncy(
      context: context,
      audio: ref.read(gameAudioProvider),
      title: strings.ludoMatchLeaveThisGame,
      message: state.isLocal
          ? strings.ludoMatchThisGameAgainstTheBots
          : state.stake > 0
          ? strings.ludoMatchYouLlLoseYourCoin(
              state.stake,
              others > 1 ? strings.ludoMatchAndTheGameWillGo : '',
            )
          : strings.ludoMatchYouLlLoseThisGame(
              others > 1 ? strings.ludoMatchAndItWillGoOn : '',
            ),
      confirmLabel: strings.ludoMatchLeaveGame,
      cancelLabel: strings.ludoMatchKeepPlaying,
      destructive: true,
      hero: const CoinBuddy(mood: BuddyMood.sad, size: 76),
    );
    if (!ok || !mounted) return;
    setState(() => _leaving = true);
    try {
      await ref
          .read(ludoMatchControllerProvider(widget.matchId).notifier)
          .leave();
    } catch (_) {
      // The game may have just ended; either way, head home.
    }
    LeaveGuard.release();
    if (mounted) context.go(state.isLocal ? '/ludo' : '/home');
  }

  void _openMenu(LudoMatchState state) {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.zero,
          child: PopCard(
            borderRadius: 26,
            sheet: true,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuTile(
                  icon: Icons.music_note_rounded,
                  label: strings.ludoMatchSoundMusic,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    showSoundSettings(context);
                  },
                ),
                _MenuTile(
                  icon: Icons.menu_book_rounded,
                  label: strings.ludoMatchHowToPlay,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    showLudoRules(context);
                  },
                ),
                if (!state.isLocal)
                  _MenuTile(
                    icon: Icons.chat_bubble_rounded,
                    label: strings.ludoMatchChat,
                    onTap: () {
                      Navigator.of(sheet).pop();
                      showLudoChat(
                        context: context,
                        matchId: widget.matchId,
                        muted: _muted,
                      );
                    },
                  ),
                if (state.isActive && !state.iLeft)
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    label: state.iFinished
                        ? strings.ludoMatchLeaveFinished
                        : strings.ludoMatchLeaveGame,
                    danger: !state.iFinished,
                    onTap: () {
                      Navigator.of(sheet).pop();
                      _confirmLeave(state);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The thought bubble (or, once its player taps, the reaction card) over
  /// [color]'s piece in [pending]'s capture.
  LudoTokenAnchor _reactionAnchor(
    LudoMatchState state,
    PendingReaction pending,
    LudoColor color,
    String setId,
  ) {
    final mine = state.playsHere(color);
    final capturer = color == pending.capture.by;
    final key = (pending.capture.seq, color);
    final open = mine && _reactingTo == key;
    void toggle() => setState(() => _reactingTo = open ? null : key);
    final tag = '${pending.capture.seq}${color.name}';
    return LudoTokenAnchor(
      color: color,
      token: pending.tokenFor(color),
      width: open ? LudoReactionCard.size.width : LudoCaptureBadge.size.width,
      onTokenTap: mine ? toggle : null,
      child: !open
          ? LudoCaptureBadge(
              key: ValueKey('badge$tag'),
              deadline: pending.deadline,
              window: kReactionWindow,
              onTap: mine ? toggle : null,
            )
          : capturer
          ? LudoReactionCard.capture(
              key: ValueKey('card$tag'),
              deadline: pending.deadline,
              window: kReactionWindow,
              onWar: () => _controller.chooseReaction(TokenReaction.war),
              onPeace: () => _controller.chooseReaction(TokenReaction.peace),
            )
          : LudoReactionCard.sentHome(
              key: ValueKey('card$tag'),
              deadline: pending.deadline,
              window: kReactionWindow,
              color: color,
              setId: setId,
              onSad: () =>
                  _controller.chooseReaction(TokenReaction.sad, color: color),
              onAgain: () =>
                  _controller.chooseReaction(TokenReaction.again, color: color),
            ),
    );
  }

  /// A player's name for a banner: theirs, or their color offline.
  String _nameFor(LudoMatchState state, LudoColor color) {
    final id = state.userFor(color);
    if (state.isLocal || id == null) return ludoColorName(color);
    return profileDisplayName(
      ref.read(profileByIdProvider(id)).valueOrNull,
      id,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ludoMatchControllerProvider(widget.matchId), _onStateChange);
    // Keeps the voice-note player alive for the whole match (without
    // rebuilding the board every time playback moves).
    ref.listen(voicePlaybackProvider, (_, _) {});
    final state = ref.watch(ludoMatchControllerProvider(widget.matchId));
    final controller = ref.read(
      ludoMatchControllerProvider(widget.matchId).notifier,
    );
    final myId = ref.watch(currentUserProvider)?.id;

    if (state.loading) {
      return Scaffold(
        body: AppBackground(
          child: Center(
            child: UtopiaLoader(
              size: 88,
              label: strings.ludoMatchSettingUpTheBoard,
            ),
          ),
        ),
      );
    }
    if (state.error != null && state.matchRow == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.ludoMatchLudo)),
        body: AppBackground(
          child: Center(
            child: Text(
              state.error!,
              style: AppTextStyles.body(color: AppColors.error),
            ),
          ),
        ),
      );
    }

    final game = state.game;
    final done = !state.isActive;
    final canPop = done || state.iLeft || state.iFinished || _leaving;
    // Everyone's piece sets, names and auras stay current during the game.
    // (Offline games have only bots and you: nothing to watch.)
    ref.watch(
      liveProfilesProvider(
        liveProfilesKey(state.isLocal ? const [] : state.playerIds),
      ),
    );

    // Each player's piece set comes from their profile.
    final pieceSets = <LudoColor, String>{
      for (final color in game.players)
        color: pieceSetFor(
          state.userFor(color) == null
              ? null
              : ref
                    .watch(profileByIdProvider(state.userFor(color)!))
                    .valueOrNull,
        ),
    };

    // After a capture: a small badge on the piece that did it, and on each
    // piece sent home once it's back in its yard. Their players tap the
    // piece (or the badge) to react: war or peace for the one that took
    // it, sad or "again" for one sent home. The time runs either way, and
    // rolling on passes.
    final pending = state.pendingReaction;
    final anchors = <LudoTokenAnchor>[
      if (pending != null)
        for (final color in pending.reactors)
          if (pending.waitingOn(color))
            _reactionAnchor(state, pending, color, pieceSets[color]!),
    ];

    final holding = DateTime.now().difference(_lastRollAt) < _diceHold;
    final diceOwner = holding && _lastRoller != null ? _lastRoller! : game.turn;

    Widget panel(LudoColor color, {required bool mirrored}) {
      final userId = state.userFor(color);
      final speech = userId == null ? null : _speech[userId];
      final fresh =
          speech != null && DateTime.now().difference(speech.$2) < speech.$3;
      final isOwner = color == diceOwner && !done && !game.left.contains(color);
      return LudoSeatPanel(
        color: color,
        userId: userId,
        isMe: userId == myId,
        isTurn: color == game.turn && !done,
        left: game.left.contains(color),
        home: game.tokens[color]!.where(game.rules.isHome).length,
        winner: done && userId != null && userId == state.winnerId,
        place: game.placeOf(color),
        mirrored: mirrored,
        speech: fresh ? speech.$1 : null,
        msLeft: () => state.turnMsLeft,
        totalMs: state.turnTime.inMilliseconds,
        missedTurns: state.missedTurns(color),
        onWarnSecond:
            userId == myId && ref.read(gameplaySettingsProvider).timerTicks
            ? (_) => ref.read(gameAudioProvider).play(Sfx.tick, volume: 0.7)
            : null,
        dice: isOwner
            ? LudoDice(
                key: _diceKey,
                rollSeq: game.rollSeq,
                value: game.lastRoll?.value,
                enabled:
                    state.playsHere(color) &&
                    state.canRoll &&
                    color == game.turn,
                onRoll: controller.rollDice,
                active: color == game.turn || (holding && color == _lastRoller),
                size: state.playsHere(color) ? 44 : 36,
                glow: ludoColorPalette[color],
              )
            : null,
        // Offline there's no one to look up: bots have no stats.
        onAvatarTap: state.isLocal
            ? () {}
            : () => showLudoPlayerCard(
                context: context,
                ref: ref,
                userId: userId!,
                color: color,
                matchId: widget.matchId,
                muted: _muted.contains(userId),
                onToggleMute: () => setState(() {
                  if (!_muted.remove(userId)) _muted.add(userId);
                }),
              ),
      );
    }

    // Seat each player's panel in the corner their yard is drawn in.
    final g = LudoGeometry.of(game.board);
    final rotation = g.viewRotation(state.myColor);
    final top = <(double, LudoColor)>[];
    final bottom = <(double, LudoColor)>[];
    for (final color in game.players) {
      final a = g.yardAngle(g.rules.seatOf(color)) + rotation;
      (math.sin(a) < 0 ? top : bottom).add((math.cos(a), color));
    }

    Widget row(List<(double, LudoColor)> seats) {
      LudoColor? at(bool Function(double) where) =>
          seats.where((s) => where(s.$1)).map((s) => s.$2).firstOrNull;
      final left = at((x) => x < -0.3);
      final middle = at((x) => x >= -0.3 && x <= 0.3);
      final right = at((x) => x > 0.3);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            left == null
                ? const SizedBox(width: 110)
                : panel(left, mirrored: false),
            if (middle != null) panel(middle, mirrored: false),
            right == null
                ? const SizedBox(width: 110)
                : panel(right, mirrored: true),
          ],
        ),
      );
    }

    return LeaveGuard(
      canLeave: canPop,
      onAsk: () => _confirmLeave(state),
      child: MusicTrackScope(
        track: MusicTrack.game,
        child: Scaffold(
          body: AppBackground(
            child: SafeArea(
              child: GameStage(
                above: [
                  _TopBar(
                    pot: state.pot,
                    friends: state.isFriendsGame,
                    offline: state.isLocal,
                    unread: state.unread,
                    onMenu: () => _openMenu(state),
                    onChat: () => showLudoChat(
                      context: context,
                      matchId: widget.matchId,
                      muted: _muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  row(top),
                ],
                board: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 4,
                        ),
                        child: LudoBoardView(
                          game: game,
                          myColor: state.myColor,
                          movableTokens: state.movableTokens,
                          onTokenTap: controller.selectToken,
                          pieceSets: pieceSets,
                          reactions: state.reactions,
                          anchors: anchors,
                        ),
                      ),
                    ),
                    if (_finishBanner case (
                      final who,
                      final place,
                      final at,
                    ) when DateTime.now().difference(at) < _bannerFor)
                      Positioned(
                        top: 6,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _FinishBanner(
                            key: ValueKey('${who.name}$place'),
                            color: who,
                            place: place,
                            name: state.playsHere(who) && who == state.myColor
                                ? null
                                : _nameFor(state, who),
                          ),
                        ),
                      ),
                  ],
                ),
                below: [
                  row(bottom),
                  _StatusLine(
                    state: state,
                    onLeave: () => _confirmLeave(state),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ),
            ),
          ),
          bottomSheet: done
              ? _GameOverPanel(state: state, myId: myId)
              : state.iFinished && state.playingOn && !_watching
              ? _FinishedPanel(
                  state: state,
                  onWatch: () => setState(() => _watching = true),
                  onLeave: () => _confirmLeave(state),
                )
              : null,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pot,
    required this.friends,
    this.offline = false,
    required this.unread,
    required this.onMenu,
    required this.onChat,
  });

  final int pot;
  final bool friends;

  /// Against bots, on this phone: no chat.
  final bool offline;
  final int unread;
  final VoidCallback onMenu;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.menu_rounded,
            label: strings.ludoMatchGameMenu,
            onTap: onMenu,
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.surface.withValues(alpha: 0.9),
              border: Border.all(color: AppColors.goldBorder, width: 1.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pot > 0)
                  const CrownIcon(size: 18)
                else
                  Icon(
                    Icons.favorite_rounded,
                    color: AppColors.coral,
                    size: 16,
                  ),
                const SizedBox(width: 4),
                Text(
                  pot > 0 ? formatCoins(pot) : strings.ludoMatchFree,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (friends) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.people_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                ],
                if (offline) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.smart_toy_rounded, size: 16, color: AppColors.sky),
                ],
              ],
            ),
          ),
          const Spacer(),
          const SoundQuickToggle(),
          if (!offline) ...[
            const SizedBox(width: AppSpacing.sm),
            Stack(
              clipBehavior: Clip.none,
              children: [
                _RoundButton(
                  icon: Icons.chat_bubble_rounded,
                  label: strings.ludoMatchChat,
                  onTap: onChat,
                ),
                if (unread > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: AppTextStyles.body(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.4),
              colors: [
                Color.lerp(AppColors.accent, Colors.white, 0.3)!,
                AppColors.accent,
              ],
            ),
            border: Border.all(color: AppColors.goldBorder, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: AppColors.glowRing.withValues(alpha: 0.4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state, required this.onLeave});

  final LudoMatchState state;

  /// Leaving, for someone who's finished and is watching.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final game = state.game;
    final passing = state.friendColors.isNotEmpty;
    final sentHome = state.sentHomeChoosing;
    String text;
    if (!state.isActive) {
      text = '';
    } else if (state.iLeft) {
      text = strings.ludoMatchYouLeftThisGame;
    } else if (state.iFinished && !passing) {
      return _WatchingLine(
        text: strings.ludoMatchYouFinishedWatching(placeLabel(state.myPlace!)),
        onLeave: onLeave,
      );
    } else if (sentHome.isNotEmpty && !state.isMyTurn) {
      text = passing
          ? strings.ludoMatchSentHomeTapThePiece(ludoColorName(sentHome.first))
          : strings.ludoMatchSentHomeTapYourPiece;
    } else if (state.choosingReaction) {
      text = passing
          ? strings.ludoMatchCapturedTapThePieceTo(
              ludoColorName(state.pendingReaction!.capture.by),
            )
          : strings.ludoMatchCapturedTapYourPieceTo;
    } else if (state.isMyTurn && state.movableTokens.isNotEmpty) {
      text = passing
          ? strings.ludoMatchTapAGlowingPiece(ludoColorName(game.turn))
          : strings.ludoMatchTapAGlowingPieceTo;
    } else if (state.isMyTurn) {
      // Passing the phone round: say whose hands it should be in.
      text = passing
          ? strings.ludoMatchSTurnTapTheDie(ludoColorName(game.turn))
          : strings.ludoMatchYourTurnTapTheDie;
    } else {
      text = strings.ludoMatchIsPlaying(ludoColorName(game.turn));
    }
    if (text.isEmpty) return const SizedBox(height: 30);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.surface.withValues(alpha: 0.9),
          border: Border.all(
            color: state.isMyTurn
                ? AppColors.goldBorder
                : AppColors.glowRing.withValues(alpha: 0.5),
            width: 1.4,
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.body(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: state.isMyTurn
                ? AppColors.goldBorderBright
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      leading: Icon(
        icon,
        color: danger ? AppColors.error : AppColors.accentSecondary,
      ),
      title: Text(
        label,
        style: AppTextStyles.body(fontWeight: FontWeight.w700, color: color),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

/// For someone who's finished: where they came, and a way out.
class _WatchingLine extends StatelessWidget {
  const _WatchingLine({required this.text, required this.onLeave});

  final String text;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surface.withValues(alpha: 0.9),
        border: Border.all(color: AppColors.goldBorder, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.visibility_rounded,
            size: 16,
            color: AppColors.coinGold,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onLeave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.accent,
              ),
              child: Text(
                strings.ludoMatchLeave,
                style: AppTextStyles.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Red came 2nd!": a medal and a name dropping in over the board when
/// someone finishes while the others play on.
class _FinishBanner extends StatelessWidget {
  const _FinishBanner({
    super.key,
    required this.color,
    required this.place,
    required this.name,
  });

  final LudoColor color;
  final int place;

  /// Null when it's me.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final seat = ludoColorPalette[color]!;
    final medal = kPlaceMedals[place] ?? kPlaceMedals[3]!;
    final text = name == null
        ? (place == 1
              ? strings.ludoMatchYouWon
              : strings.ludoMatchYouCame(placeLabel(place)))
        : strings.ludoMatchFinished(name!, placeLabel(place));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, -30 * (1 - v)),
        child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: AppColors.surfaceElevated,
          border: Border.all(color: seat, width: 2),
          boxShadow: [
            BoxShadow(color: seat.withValues(alpha: 0.5), blurRadius: 16),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: medal,
                ),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: place == 1
                  ? const CrownIcon(size: 20)
                  : Text(
                      '$place',
                      style: AppTextStyles.display(
                        fontSize: 16,
                        color: AppColors.faceInk,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display(fontSize: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown to someone who's just got all four home while the others play
/// on: where they came, any prize, and the choice to watch or go.
class _FinishedPanel extends StatelessWidget {
  const _FinishedPanel({
    required this.state,
    required this.onWatch,
    required this.onLeave,
  });

  final LudoMatchState state;
  final VoidCallback onWatch;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final place = state.myPlace ?? 1;
    final first = place == 1;
    final commissionBps =
        (state.matchRow?['commission_bps'] as num?)?.toInt() ?? 0;
    final prize = first && state.stake > 0
        ? (state.pot * (1 - commissionBps / 10000)).floor()
        : null;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Stack(
        children: [
          PopCard(
            borderRadius: 28,
            tint: first ? AppColors.success : null,
            glow: first ? AppColors.success : AppColors.accent,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinBuddy(mood: BuddyMood.happy, size: 64),
                  Text(
                    first
                        ? strings.ludoMatchYouWon
                        : strings.ludoMatchYouCame(placeLabel(place)),
                    style: AppTextStyles.display(fontSize: 26),
                  ),
                  Text(
                    strings.ludoMatchOthersPlayOn(placeLabel(place + 1)),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  if (prize != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.ludoMatchYourPrize,
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CoinAmount(
                          prize,
                          prefix: '+',
                          size: 16,
                          color: AppColors.readable(AppColors.success),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: strings.ludoMatchWatch,
                          onPressed: onWatch,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          label: strings.ludoMatchLeave,
                          color: AppColors.success,
                          onPressed: onLeave,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (first) const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }
}

/// One player's place when the game ends.
class LudoStanding {
  const LudoStanding({
    required this.color,
    required this.place,
    required this.home,
    required this.progress,
    required this.left,
  });

  final LudoColor color;
  final int place;

  /// Pieces brought home (0-4).
  final int home;

  /// How far their pieces got overall, 0-1.
  final double progress;
  final bool left;
}

/// Final places: everyone who finished, in the order they did; then
/// everyone still racing by pieces home and then by how far their pieces
/// got; then players who left (the last to leave ranks highest among
/// them).
List<LudoStanding> ludoStandings(LudoState game) {
  final finish = game.rules.finish;
  int homeOf(LudoColor c) => game.tokens[c]!.where(game.rules.isHome).length;
  double progressOf(LudoColor c) =>
      game.tokens[c]!.fold<int>(0, (sum, p) => sum + (p < 0 ? 0 : p + 1)) /
      (4 * (finish + 1));

  final racing = [...game.racing]
    ..sort((a, b) {
      final byHome = homeOf(b).compareTo(homeOf(a));
      if (byHome != 0) return byHome;
      return progressOf(b).compareTo(progressOf(a));
    });
  final order = [
    ...game.finished,
    ...racing,
    for (final c in game.left.reversed)
      if (!game.finished.contains(c)) c,
  ];
  return [
    for (final (i, c) in order.indexed)
      LudoStanding(
        color: c,
        place: i + 1,
        home: homeOf(c),
        progress: progressOf(c),
        left: game.left.contains(c) && !game.finished.contains(c),
      ),
  ];
}

class _GameOverPanel extends ConsumerWidget {
  const _GameOverPanel({required this.state, required this.myId});

  final LudoMatchState state;
  final String? myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iWon = state.winnerId != null && state.winnerId == myId;
    final result = state.matchRow?['result'] as String?;
    final standings = ludoStandings(state.game);
    final myPlace = state.myColor == null
        ? null
        : standings.where((s) => s.color == state.myColor).firstOrNull?.place;
    final title = state.status == 'disputed'
        ? strings.ludoMatchResultUnderReview
        : iWon
        ? strings.ludoMatchYouWon
        : myPlace != null
        ? strings.ludoMatchYouCame(placeLabel(myPlace))
        : strings.ludoMatchGameOver;
    final winnerId = state.winnerId;
    final winnerName = winnerId == null
        ? strings.ludoMatchSomeone
        : profileDisplayName(
            ref.watch(profileByIdProvider(winnerId)).valueOrNull,
            winnerId,
          );
    final subtitle = switch (result) {
      'win' =>
        iWon
            ? strings.ludoMatchAllFourPiecesHome
            : strings.ludoMatchGotAllFourPiecesHome(winnerName),
      'resignation' =>
        iWon
            ? strings.ludoMatchEveryoneElseLeftTheWin
            : strings.ludoMatchYouLeftThisGame,
      'timeout' =>
        iWon
            ? strings.ludoMatchTheOthersRanOutOf
            : strings.ludoMatchYouRanOutOfTime,
      _ => '',
    };
    final commissionBps =
        (state.matchRow?['commission_bps'] as num?)?.toInt() ?? 0;
    final payout = (state.pot * (1 - commissionBps / 10000)).floor();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Stack(
        children: [
          PopCard(
            borderRadius: 28,
            tint: iWon ? AppColors.success : null,
            glow: iWon ? AppColors.success : AppColors.accent,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinBuddy(
                    mood: iWon
                        ? BuddyMood.happy
                        : (myPlace == 2 ? BuddyMood.idle : BuddyMood.sad),
                    size: 64,
                  ),
                  Text(title, style: AppTextStyles.display(fontSize: 26)),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  for (final (i, standing) in standings.indexed)
                    _StandingRow(
                      standing: standing,
                      userId: state.userFor(standing.color),
                      isMe: standing.color == state.myColor,
                      prize: standing.place == 1 && state.stake > 0
                          ? payout
                          : null,
                      index: i,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: strings.ludoMatchHome,
                          onPressed: () => context.go('/home'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          label: strings.ludoMatchPlayAgain,
                          color: AppColors.success,
                          onPressed: () {
                            // Against the bots: same table, a fresh game.
                            final setup = state.isLocal
                                ? localLudoSetup(
                                    state.matchRow?['id'] as String? ?? '',
                                  )
                                : null;
                            if (setup != null) {
                              context.pushReplacement(
                                '/ludo/${startLocalLudo(setup)}',
                              );
                            } else {
                              context.go('/ludo');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (iWon) const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }
}

/// A row of the final standings: medal, player, pieces home, and the prize
/// for the winner. Rows pop in one after another.
class _StandingRow extends ConsumerWidget {
  const _StandingRow({
    required this.standing,
    required this.userId,
    required this.isMe,
    required this.prize,
    required this.index,
  });

  final LudoStanding standing;
  final String? userId;
  final bool isMe;
  final int? prize;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    final profile = id == null
        ? null
        : ref.watch(profileByIdProvider(id)).valueOrNull;
    final name = isMe
        ? strings.ludoMatchYou
        : id == null
        ? ludoColorName(standing.color)
        : profileDisplayName(profile, id);
    final seat = ludoColorPalette[standing.color]!;
    final medal = kPlaceMedals[standing.place];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 160),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - v)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isMe
              ? seat.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.22),
          border: Border.all(
            color: isMe
                ? seat.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
            width: isMe ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: medal == null
                    ? null
                    : RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: medal,
                      ),
                color: medal == null
                    ? Colors.white.withValues(alpha: 0.1)
                    : null,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.4,
                ),
              ),
              child: standing.place == 1
                  ? const CrownIcon(size: 20)
                  : Text(
                      '${standing.place}',
                      style: AppTextStyles.display(
                        fontSize: 16,
                        color: medal == null
                            ? AppColors.textPrimary
                            : AppColors.faceInk,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: seat),
              child: UserAvatar.fromProfile(
                profile,
                fallbackInitial: name,
                radius: 15,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    standing.left
                        ? strings.ludoMatchLeftTheGame(
                            placeLabel(standing.place),
                          )
                        : placeLabel(standing.place),
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Pieces home, one dot per piece.
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Icon(
                  Icons.home_rounded,
                  size: 14,
                  color: i < standing.home
                      ? seat
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
            if (prize != null) ...[
              const SizedBox(width: 8),
              CoinAmount(
                prize!,
                prefix: '+',
                size: 13,
                color: AppColors.readable(AppColors.success),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
