import '../../../../core/widgets/leave_guard.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/audio/sound_controls.dart';
import '../../../../core/profiles/profile_freshness.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/settings/gameplay_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/bouncy_dialog.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/confetti_burst.dart';
import '../../../../core/widgets/countdown_border.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../../l10n/strings.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chat/domain/voice_note.dart';
import '../../../chat/presentation/chat_sticker.dart';
import '../../../chat/presentation/game_chat_sheet.dart';
import '../../../chat/presentation/voice_notes.dart';
import '../../../events/presentation/events_controller.dart';
import '../../../ludo/presentation/widgets/ludo_player_card.dart';
import '../../domain/eights_engine.dart';
import '../controllers/eights_match_controller.dart';
import '../widgets/card_art.dart';
import '../widgets/eights_rules_sheet.dart';
import '../widgets/eights_table_view.dart';

/// Each seat's color, for names in the chat and the frames round avatars.
const List<Color> kEightsSeatColors = [
  Color(0xFFFF5C6C),
  Color(0xFF2FD98E),
  Color(0xFFFFC93D),
  Color(0xFF4DA3FF),
  Color(0xFFFF8A3D),
  Color(0xFFB27BFF),
];

class EightsMatchScreen extends ConsumerStatefulWidget {
  const EightsMatchScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<EightsMatchScreen> createState() => _EightsMatchScreenState();
}

class _EightsMatchScreenState extends ConsumerState<EightsMatchScreen> {
  /// Players whose chat this device hides.
  final Set<String> _muted = {};

  /// Latest chat line per player, shown as a bubble for a moment.
  final Map<String, (String, DateTime, Duration)> _speech = {};

  /// Seats that just went down to one card: "Last card!" for a moment.
  final Map<int, DateTime> _lastCall = {};
  static const _lastCallFor = Duration(milliseconds: 2600);
  static const _speechFor = Duration(seconds: 4);

  Timer? _refresh;
  bool _playedResult = false;
  bool _leaving = false;
  late final AppLifecycleListener _life;

  EightsMatchController get _controller =>
      ref.read(eightsMatchControllerProvider(widget.matchId).notifier);

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

  void _onStateChange(EightsMatchState? prev, EightsMatchState next) {
    if (prev == null) return;
    final audio = ref.read(gameAudioProvider);
    final me = ref.read(currentUserProvider)?.id;
    final t = next.table;
    final before = prev.table;

    if (t != null && before != null && t.seq != before.seq) {
      if (next.isMyTurn && !prev.isMyTurn) audio.play(Sfx.yourTurn);
      for (var seat = 0; seat < t.seats; seat++) {
        if (t.counts[seat] == 1 &&
            before.counts[seat] == 2 &&
            t.last?.kind == EightsActionKind.play) {
          _lastCall[seat] = DateTime.now();
          audio.play(Sfx.lastCard);
          _refreshIn(_lastCallFor);
        }
      }
    }

    if (next.chat.length > prev.chat.length) {
      final seen = prev.chat.isEmpty ? next.chatBaseline : prev.chat.last.id;
      var longest = Duration.zero;
      for (final m in next.chat) {
        if (m.id <= seen || m.id <= next.chatBaseline) continue;
        if (_muted.contains(m.senderId)) continue;
        final voice = m.kind == 'voice' ? VoiceNote.parse(m.body) : null;
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

    final mine = next.mySeat;
    if (mine != null &&
        next.missedTurns(mine) > prev.missedTurns(mine) &&
        next.isActive) {
      showUtopiaToast(
        context,
        kEightsMaxMissed - next.missedTurns(mine) == 1
            ? strings.ludoMatchOutOfTimeMissOne
            : strings.eightsOutOfTimeDrew,
        kind: ToastKind.warning,
      );
    }

    if (next.error != null && next.error != prev.error) {
      showUtopiaToast(context, next.error!, kind: ToastKind.error);
    }

    if (!next.isActive && !_playedResult) {
      _playedResult = true;
      ref
          .read(eventsProvider.notifier)
          .gameFinished(
            'eights',
            matchId: next.isLocal ? null : widget.matchId,
          );
      audio.play(next.winnerId == me ? Sfx.win : Sfx.lose);
    }
  }

  /// An eight: pick the suit to follow, then it's played.
  Future<void> _play(PlayingCard card) async {
    if (!card.isEight) {
      _controller.play(card);
      return;
    }
    final hand = ref.read(eightsMatchControllerProvider(widget.matchId)).hand;
    final suit = await showModalBottomSheet<CardSuit>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _SuitPicker(suggested: favoriteSuit([...hand]..remove(card))),
    );
    if (suit != null && mounted) _controller.play(card, suit: suit);
  }

  Future<void> _confirmLeave(EightsMatchState state) async {
    if (!state.isActive || state.iLeft) {
      LeaveGuard.release();
      context.go(state.isLocal ? '/eights' : '/home');
      return;
    }
    final ok = await confirmBouncy(
      context: context,
      audio: ref.read(gameAudioProvider),
      title: strings.ludoMatchLeaveThisGame,
      message: state.isLocal
          ? strings.ludoMatchThisGameAgainstTheBots
          : state.stake > 0
          ? strings.eightsLeaveLoseEntry(state.stake)
          : strings.eightsLeaveLoseGame,
      confirmLabel: strings.ludoMatchLeaveGame,
      cancelLabel: strings.ludoMatchKeepPlaying,
      destructive: true,
      hero: const CoinBuddy(mood: BuddyMood.sad, size: 76),
    );
    if (!ok || !mounted) return;
    setState(() => _leaving = true);
    try {
      await _controller.leave();
    } catch (_) {
      // The game may have just ended; either way, go.
    }
    LeaveGuard.release();
    if (mounted) context.go(state.isLocal ? '/eights' : '/home');
  }

  void _openChat() => showGameChat(
    context: context,
    muted: _muted,
    config: GameChatConfig(
      messages: eightsMatchControllerProvider(
        widget.matchId,
      ).select((s) => s.chat),
      friends: ref
          .read(eightsMatchControllerProvider(widget.matchId))
          .isFriendsGame,
      send: (text, kind) => _controller.sendChat(text, kind: kind),
      sendVoice: _controller.sendVoice,
      setOpen: (open) {
        if (_controller.mounted) _controller.setChatOpen(open);
      },
      accentFor: (userId) {
        final seat = ref
            .read(eightsMatchControllerProvider(widget.matchId))
            .seatOf(userId);
        return seat == null ? null : kEightsSeatColors[seat];
      },
    ),
  );

  void _openMenu(EightsMatchState state) {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => SafeArea(
        top: false,
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
                  showEightsRules(context);
                },
              ),
              if (!state.isLocal)
                _MenuTile(
                  icon: Icons.chat_bubble_rounded,
                  label: strings.ludoMatchChat,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    _openChat();
                  },
                ),
              if (state.isActive && !state.iLeft)
                _MenuTile(
                  icon: Icons.logout_rounded,
                  label: strings.ludoMatchLeaveGame,
                  danger: true,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    _confirmLeave(state);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = eightsMatchControllerProvider(widget.matchId);
    ref.listen(provider, _onStateChange);
    ref.listen(voicePlaybackProvider, (_, _) {});
    final state = ref.watch(provider);
    final myId = ref.watch(currentUserProvider)?.id;
    final table = state.table;

    if (state.loading || table == null || state.mySeat == null) {
      return Scaffold(
        body: AppBackground(
          child: Center(
            child: state.error != null && state.matchRow == null
                ? Text(
                    state.error!,
                    style: AppTextStyles.body(color: AppColors.error),
                  )
                : UtopiaLoader(size: 88, label: strings.eightsShuffling),
          ),
        ),
      );
    }
    ref.watch(
      liveProfilesProvider(
        liveProfilesKey(state.isLocal ? const [] : state.playerIds),
      ),
    );
    final done = !state.isActive;
    final mySeat = state.mySeat!;

    Widget seat(int s) {
      final userId = state.userFor(s);
      final speech = userId == null ? null : _speech[userId];
      final fresh =
          speech != null && DateTime.now().difference(speech.$2) < speech.$3;
      final call = _lastCall[s];
      return _EightsSeat(
        userId: userId,
        color: kEightsSeatColors[s % kEightsSeatColors.length],
        count: table.counts[s],
        onTurn: table.turn == s && !done && !table.isOver,
        left: table.left.contains(s),
        winner: table.winner == s,
        lastCard:
            call != null && DateTime.now().difference(call) < _lastCallFor,
        speech: fresh ? speech.$1 : null,
        missed: state.missedTurns(s),
        msLeft: () => state.turnMsLeft,
        totalMs: state.turnTime.inMilliseconds,
        onTap: state.isLocal || userId == null
            ? null
            : () => showEightsPlayerCard(
                context: context,
                ref: ref,
                userId: userId,
                color: kEightsSeatColors[s % kEightsSeatColors.length],
                matchId: widget.matchId,
                muted: _muted.contains(userId),
                onToggleMute: () => setState(() {
                  if (!_muted.remove(userId)) _muted.add(userId);
                }),
              ),
      );
    }

    return LeaveGuard(
      canLeave: done || state.iLeft || _leaving,
      onAsk: () => _confirmLeave(state),
      child: MusicTrackScope(
        track: MusicTrack.game,
        child: Scaffold(
          body: AppBackground(
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    pot: state.pot,
                    friends: state.isFriendsGame,
                    offline: state.isLocal,
                    unread: state.unread,
                    onMenu: () => _openMenu(state),
                    onChat: _openChat,
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: EightsTableView(
                          table: table,
                          hand: state.hand,
                          mySeat: mySeat,
                          playable: state.playable,
                          myTurn: state.isMyTurn,
                          canDraw: state.canDraw,
                          canPass: state.canPass,
                          onPlay: _play,
                          onDraw: _controller.draw,
                          onPass: _controller.pass,
                          seatBuilder: seat,
                          // A game nobody has moved in yet: deal it out.
                          deal: table.seq == 0,
                        ),
                      ),
                    ),
                  ),
                  _MyBar(
                    state: state,
                    lastCard:
                        _lastCall[mySeat] != null &&
                        DateTime.now().difference(_lastCall[mySeat]!) <
                            _lastCallFor,
                    onWarnSecond: ref.read(gameplaySettingsProvider).timerTicks
                        ? (_) => ref
                              .read(gameAudioProvider)
                              .play(Sfx.tick, volume: 0.7)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          bottomSheet: done ? _GameOverPanel(state: state, myId: myId) : null,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pot,
    required this.friends,
    required this.offline,
    required this.unread,
    required this.onMenu,
    required this.onChat,
  });

  final int pot;
  final bool friends;
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
            Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: _RoundButton(
                icon: Icons.chat_bubble_rounded,
                label: strings.ludoMatchChat,
                onTap: onChat,
              ),
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
          ),
          child: Icon(icon, color: Colors.white, size: 22),
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
    return ListTile(
      leading: Icon(
        icon,
        color: danger ? AppColors.error : AppColors.accentSecondary,
      ),
      title: Text(
        label,
        style: AppTextStyles.body(
          fontWeight: FontWeight.w700,
          color: danger ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

/// Another player at the table: their avatar (the clock round it on their
/// turn), name, how many cards they hold, and their latest chat line.
class _EightsSeat extends ConsumerWidget {
  const _EightsSeat({
    required this.userId,
    required this.color,
    required this.count,
    required this.onTurn,
    required this.left,
    required this.winner,
    required this.lastCard,
    required this.speech,
    required this.missed,
    required this.msLeft,
    required this.totalMs,
    required this.onTap,
  });

  final String? userId;
  final Color color;
  final int count;
  final bool onTurn;
  final bool left;
  final bool winner;
  final bool lastCard;
  final String? speech;
  final int missed;
  final int? Function() msLeft;
  final int totalMs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    final profile = id == null
        ? null
        : ref.watch(profileByIdProvider(id)).valueOrNull;
    final name = id == null ? '' : profileDisplayName(profile, id);
    Widget avatar = Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: onTurn ? 0.35 : 0.85),
        boxShadow: onTurn
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)]
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: AppColors.surface,
        ),
        alignment: Alignment.center,
        child: UserAvatar.fromProfile(
          profile,
          fallbackInitial: name,
          radius: 19,
        ),
      ),
    );
    if (onTurn) {
      avatar = CountdownBorder(
        msLeft: msLeft,
        totalMs: totalMs,
        color: Color.lerp(color, Colors.white, 0.2)!,
        borderRadius: 16,
        child: avatar,
      );
    }
    return Opacity(
      opacity: left ? 0.45 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    avatar,
                    if (winner)
                      const Positioned(top: -18, child: CrownIcon(size: 22)),
                    // How many cards they hold.
                    if (!left)
                      Positioned(
                        right: -10,
                        bottom: -6,
                        child: _CountChip(count: count, color: color),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (left)
                  Text(
                    strings.ludoSeatPanelLeft,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.error,
                    ),
                  )
                else if (missed > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < kEightsMaxMissed; i++)
                        Icon(
                          Icons.hourglass_bottom_rounded,
                          size: 11,
                          color: i < missed
                              ? const Color(0xFFFF4D5E)
                              : AppColors.textSecondary.withValues(alpha: 0.35),
                        ),
                    ],
                  ),
              ],
            ),
            if (lastCard) const Positioned(top: -26, child: _LastCardTag()),
            if (speech != null)
              Positioned(bottom: 64, child: _Bubble(text: speech!)),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Container(
        key: ValueKey(count),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
          border: Border.all(color: color, width: 1.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_rounded, size: 11, color: AppColors.faceInk),
            const SizedBox(width: 2),
            Text(
              '$count',
              style: AppTextStyles.body(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.faceInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Last card!", popping up over a player down to one.
class _LastCardTag extends StatelessWidget {
  const _LastCardTag();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE066), Color(0xFFFF9F2E)],
          ),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6)],
        ),
        child: Text(
          strings.eightsLastCard,
          style: AppTextStyles.body(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppColors.faceInk,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final voice = VoiceNote.isVoice(text) ? VoiceNote.parse(text) : null;
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(
        scale: v,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: voice != null
          ? VoiceSpeechChip(note: voice)
          : isChatSticker(text)
          ? ChatSticker(id: text, size: 48)
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Color(0x55000000), blurRadius: 6),
                  ],
                ),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.faceInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Along the bottom: my clock, and what to do now.
class _MyBar extends ConsumerWidget {
  const _MyBar({
    required this.state,
    required this.lastCard,
    required this.onWarnSecond,
  });

  final EightsMatchState state;
  final bool lastCard;
  final ValueChanged<int>? onWarnSecond;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = state.table!;
    final me = state.mySeat!;
    final mine = state.isMyTurn;
    final turnName = () {
      final id = state.userFor(t.turn);
      if (id == null) return '';
      return profileDisplayName(
        ref.watch(profileByIdProvider(id)).valueOrNull,
        id,
      );
    }();
    final suitName = switch (t.suit) {
      CardSuit.spades => strings.eightsSpades,
      CardSuit.hearts => strings.eightsHearts,
      CardSuit.diamonds => strings.eightsDiamonds,
      CardSuit.clubs => strings.eightsClubs,
    };
    final String text;
    if (!state.isActive) {
      text = '';
    } else if (state.iLeft) {
      text = strings.ludoMatchYouLeftThisGame;
    } else if (lastCard) {
      text = strings.eightsYouHaveOneLeft;
    } else if (mine && state.canPass) {
      text = state.playable.isEmpty
          ? strings.eightsNothingGoesPassing
          : strings.eightsPlayOrPass;
    } else if (mine) {
      text = state.playable.isEmpty
          ? strings.eightsNothingGoesDraw
          : t.top.isEight
          ? strings.eightsPlayASuitOrEight(suitName)
          : strings.eightsMatchSuitOrRank(suitName, t.top.label);
    } else {
      text = strings.ludoMatchIsPlaying(turnName);
    }
    final color = kEightsSeatColors[me % kEightsSeatColors.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (mine)
            SizedBox(
              width: 34,
              height: 34,
              child: CountdownBorder(
                msLeft: () => state.turnMsLeft,
                totalMs: state.turnTime.inMilliseconds,
                color: color,
                circle: true,
                strokeWidth: 3,
                onWarnSecond: onWarnSecond,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.3),
                  ),
                  child: const Icon(
                    Icons.timer_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (mine) const SizedBox(width: 8),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: text.isEmpty
                  ? const SizedBox(height: 32)
                  : Container(
                      key: ValueKey(text),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.surface.withValues(alpha: 0.9),
                        border: Border.all(
                          color: mine
                              ? AppColors.goldBorder
                              : AppColors.glowRing.withValues(alpha: 0.5),
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: mine
                              ? AppColors.goldBorderBright
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which suit an eight asks for. The suit you hold most of is marked.
class _SuitPicker extends StatelessWidget {
  const _SuitPicker({required this.suggested});

  final CardSuit suggested;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: PopCard(
        borderRadius: 26,
        sheet: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.eightsPickASuit,
              style: AppTextStyles.display(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              strings.eightsPickASuitHint,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final suit in CardSuit.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _SuitButton(
                        suit: suit,
                        suggested: suit == suggested,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuitButton extends StatelessWidget {
  const _SuitButton({required this.suit, required this.suggested});

  final CardSuit suit;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final label = switch (suit) {
      CardSuit.spades => strings.eightsSpades,
      CardSuit.hearts => strings.eightsHearts,
      CardSuit.diamonds => strings.eightsDiamonds,
      CardSuit.clubs => strings.eightsClubs,
    };
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(suit),
        child: AspectRatio(
          aspectRatio: 0.8,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              border: Border.all(
                color: suggested ? AppColors.coinGoldBright : Colors.white,
                width: suggested ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: suggested
                      ? AppColors.coinGold.withValues(alpha: 0.5)
                      : const Color(0x44000000),
                  blurRadius: suggested ? 14 : 6,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(40),
                  painter: _SuitPainter(suit),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: suitColor(suit),
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

class _SuitPainter extends CustomPainter {
  _SuitPainter(this.suit);

  final CardSuit suit;

  @override
  void paint(Canvas canvas, Size size) =>
      drawSuit(canvas, suit, size.center(Offset.zero), size.width);

  @override
  bool shouldRepaint(covariant _SuitPainter old) => old.suit != suit;
}

/// Who won, everyone's place (fewest cards left first), the prize, and
/// where to next.
class _GameOverPanel extends ConsumerWidget {
  const _GameOverPanel({required this.state, required this.myId});

  final EightsMatchState state;
  final String? myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = state.table!;
    final iWon = state.winnerId != null && state.winnerId == myId;
    final order = [for (var s = 0; s < t.seats; s++) s]
      ..sort((a, b) {
        if (a == t.winner) return -1;
        if (b == t.winner) return 1;
        final aLeft = t.left.contains(a), bLeft = t.left.contains(b);
        if (aLeft != bLeft) return aLeft ? 1 : -1;
        return t.counts[a].compareTo(t.counts[b]);
      });
    final myPlace = order.indexOf(state.mySeat!) + 1;
    final commissionBps =
        (state.matchRow?['commission_bps'] as num?)?.toInt() ?? 0;
    final payout = (state.pot * (1 - commissionBps / 10000)).floor();
    final winnerId = state.winnerId;
    final winnerName = winnerId == null
        ? strings.ludoMatchSomeone
        : profileDisplayName(
            ref.watch(profileByIdProvider(winnerId)).valueOrNull,
            winnerId,
          );
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
                    mood: iWon ? BuddyMood.happy : BuddyMood.sad,
                    size: 64,
                  ),
                  Text(
                    iWon
                        ? strings.ludoMatchYouWon
                        : strings.ludoMatchYouCame(_place(myPlace)),
                    style: AppTextStyles.display(fontSize: 26),
                  ),
                  Text(
                    iWon
                        ? strings.eightsYouWentOut
                        : strings.eightsWentOut(winnerName),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final (i, seat) in order.indexed)
                    _StandingRow(
                      userId: state.userFor(seat),
                      color: kEightsSeatColors[seat % kEightsSeatColors.length],
                      place: i + 1,
                      cards: t.counts[seat],
                      left: t.left.contains(seat),
                      isMe: seat == state.mySeat,
                      prize: i == 0 && state.stake > 0 ? payout : null,
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
                            final setup = state.isLocal
                                ? localEightsSetup(
                                    state.matchRow?['id'] as String? ?? '',
                                  )
                                : null;
                            if (setup != null) {
                              context.pushReplacement(
                                '/eights/${startLocalEights(setup)}',
                              );
                            } else {
                              context.go('/eights');
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

String _place(int place) => switch (place) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${place}th',
};

class _StandingRow extends ConsumerWidget {
  const _StandingRow({
    required this.userId,
    required this.color,
    required this.place,
    required this.cards,
    required this.left,
    required this.isMe,
    required this.prize,
    required this.index,
  });

  final String? userId;
  final Color color;
  final int place;
  final int cards;
  final bool left;
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
        : (id == null ? '' : profileDisplayName(profile, id));
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
              ? color.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.22),
          border: Border.all(
            color: isMe
                ? color.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: place == 1
                  ? const CrownIcon(size: 20)
                  : Text(
                      '$place',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(fontSize: 16),
                    ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: UserAvatar.fromProfile(
                profile,
                fallbackInitial: name,
                radius: 15,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                left ? strings.eightsNameLeft(name) : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(fontWeight: FontWeight.w800),
              ),
            ),
            if (!left) ...[
              const Icon(Icons.style_rounded, size: 14),
              const SizedBox(width: 2),
              Text(
                '$cards',
                style: AppTextStyles.body(fontWeight: FontWeight.w800),
              ),
            ],
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
