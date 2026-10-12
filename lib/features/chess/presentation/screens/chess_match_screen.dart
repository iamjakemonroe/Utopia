import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../coins/presentation/player_coins.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/audio/sound_controls.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_freshness.dart';
import '../../../../core/settings/gameplay_settings.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/bouncy_dialog.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/confetti_burst.dart';
import '../../../../core/widgets/countdown_border.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../chat/domain/voice_note.dart';
import '../../../chat/presentation/game_chat_controller.dart';
import '../../../chat/presentation/game_chat_sheet.dart';
import '../../../chat/presentation/voice_notes.dart';
import '../../../ludo/presentation/widgets/ludo_player_card.dart';
import '../../domain/chess_engine.dart';
import '../../domain/chess_position.dart';
import '../../domain/chess_types.dart';
import '../controllers/chess_match_controller.dart';
import '../widgets/animated_chess_board.dart';
import '../widgets/board_match_parts.dart';
import '../widgets/chess_piece_art.dart';
import '../widgets/chess_piece_styles.dart';
import '../widgets/promotion_sheet.dart';
import '../widgets/time_control_style.dart';

const _whiteInk = Color(0xFFF4EEDC);
const _blackInk = Color(0xFFB79BFF);

class ChessMatchScreen extends ConsumerStatefulWidget {
  const ChessMatchScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<ChessMatchScreen> createState() => _ChessMatchScreenState();
}

class _ChessMatchScreenState extends ConsumerState<ChessMatchScreen> {
  bool _promotionSheetOpen = false;
  bool _playedResult = false;

  /// The result card is up. It opens by itself when the game ends; "Review
  /// the game" tucks it away and the bar under the board brings it back.
  bool _showResult = false;
  bool _resultShownOnce = false;

  /// Players whose chat this device hides.
  final Set<String> _muted = {};

  /// The latest chat line per player, shown in their bar for a moment.
  final Map<String, (String, String, DateTime, Duration)> _speech = {};
  Timer? _speechTimer;

  static const _speechFor = Duration(seconds: 4);

  (ChatGame, String) get _chatKey => (ChatGame.chess, widget.matchId);

  @override
  void dispose() {
    _speechTimer?.cancel();
    super.dispose();
  }

  void _onChange(ChessMatchState? prev, ChessMatchState next) {
    final audio = ref.read(gameAudioProvider);
    if (prev != null && !prev.loading && next.lastSan != prev.lastSan) {
      final san = next.lastSan ?? '';
      audio.play(
        san.contains('+') || san.contains('#')
            ? Sfx.chessCheck
            : san.contains('x')
            ? Sfx.chessCapture
            : Sfx.chessMove,
      );
    }
    if (next.isOver && !_resultShownOnce) {
      _resultShownOnce = true;
      // A beat to watch the final move land before the card comes up.
      final fresh = prev != null && !prev.loading;
      Future.delayed(Duration(milliseconds: fresh ? 900 : 200), () {
        if (mounted) setState(() => _showResult = true);
      });
      if (fresh && !_playedResult) {
        _playedResult = true;
        final me = ref.read(currentUserProvider)?.id;
        final winner = next.outcome?.winnerId;
        if (winner != null) audio.play(winner == me ? Sfx.win : Sfx.lose);
      }
    }
  }

  void _onChat(GameChatState? prev, GameChatState next) {
    if (prev == null || next.messages.length <= prev.messages.length) return;
    final me = ref.read(currentUserProvider)?.id;
    final seen = prev.messages.isEmpty ? next.baseline : prev.messages.last.id;
    var longest = Duration.zero;
    for (final m in next.messages) {
      if (m.id <= seen || m.id <= next.baseline) continue;
      if (_muted.contains(m.senderId)) continue;
      final voice = m.kind == 'voice' ? VoiceNote.parse(m.body) : null;
      final showFor = voice == null
          ? _speechFor
          : Duration(milliseconds: voice.ms + 1500);
      _speech[m.senderId] = (m.kind, m.body, DateTime.now(), showFor);
      if (m.senderId != me) {
        if (voice != null && ref.read(gameplaySettingsProvider).autoPlayVoice) {
          ref.read(voicePlaybackProvider.notifier).play(voice);
        } else {
          ref.read(gameAudioProvider).play(Sfx.chat);
        }
      }
      if (showFor > longest) longest = showFor;
    }
    if (longest > Duration.zero) {
      setState(() {});
      _speechTimer?.cancel();
      _speechTimer = Timer(longest, () {
        if (mounted) setState(() {});
      });
    }
  }

  (String, String)? _speechOf(String? userId) {
    final s = userId == null ? null : _speech[userId];
    if (s == null || DateTime.now().difference(s.$3) >= s.$4) return null;
    return (s.$1, s.$2);
  }

  void _openChat(String? whiteId) {
    final chat = gameChatProvider(_chatKey);
    final controller = ref.read(chat.notifier);
    showGameChat(
      context: context,
      muted: _muted,
      config: GameChatConfig(
        messages: chat.select((s) => s.messages),
        friends: ref.read(chat).friends,
        send: (text, kind) => controller.send(text, kind: kind),
        sendVoice: controller.sendVoice,
        setOpen: (open) {
          if (controller.mounted) controller.setOpen(open);
        },
        accentFor: (id) => id == whiteId ? _whiteInk : _blackInk,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = chessMatchControllerProvider(widget.matchId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final myId = ref.watch(currentUserProvider)?.id;
    final play = ref.watch(gameplaySettingsProvider);
    final hints = play.moveHints;
    final chat = ref.watch(gameChatProvider(_chatKey));

    ref.listen(provider, (previous, next) async {
      _onChange(previous, next);
      if (next.pendingPromotion != null && !_promotionSheetOpen) {
        _promotionSheetOpen = true;
        final choice = await showPromotionSheet(
          context,
          next.pendingPromotion!.piece.color,
          pieceSet: _setOf(myId),
        );
        _promotionSheetOpen = false;
        if (!context.mounted) return;
        if (choice != null) {
          controller.choosePromotion(choice);
        } else {
          controller.cancelPromotion();
        }
      }
    });
    ref.listen(gameChatProvider(_chatKey), _onChat);
    // Keeps the voice-note player alive for the whole game.
    ref.listen(voicePlaybackProvider, (_, _) {});

    if (state.loading) {
      return const Scaffold(
        body: AppBackground(
          child: Center(
            child: UtopiaLoader(size: 88, label: 'Setting up the board'),
          ),
        ),
      );
    }
    if (state.matchRow == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinBuddy(mood: BuddyMood.sad, size: 80),
                const SizedBox(height: AppSpacing.md),
                Text(
                  "We couldn't find this game.",
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final row = state.matchRow!;
    final whiteId = row['player_white'] as String?;
    final blackId = row['player_black'] as String?;
    // Both players' sets, names and auras stay current during the game.
    ref.watch(liveProfilesProvider(liveProfilesKey([whiteId, blackId])));
    final opponentId = whiteId == myId ? blackId : whiteId;
    final myColor = state.myColor ?? PieceColor.white;
    final over = state.isOver;
    // Still playing: leaving resigns. A game that's over on the board isn't
    // resigned, even before the server confirms it.
    final playing = state.isActive && !over;
    final shownMove = state.displayLastMove;
    final trail =
        shownMove != null &&
        (state.reviewing || shownMove.piece.color != myColor);

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: playing ? 'Leave game' : 'Close',
          onPressed: () => _confirmLeave(context, controller, playing),
        ),
        title: _TimeControlTitle(state: state),
        actions: [
          MatchChatButton(unread: chat.unread, onTap: () => _openChat(whiteId)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: SoundQuickToggle(),
          ),
          if (playing)
            IconButton(
              icon: const Icon(Icons.flag_rounded),
              tooltip: 'Resign',
              onPressed: () => _confirmLeave(context, controller, playing),
            ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                _PlayerBar(
                  userId: opponentId,
                  color: myColor.opponent,
                  state: state,
                  capturedSet: _setOf(myId),
                  speech: _speechOf(opponentId),
                  onAvatarTap: opponentId == null
                      ? null
                      : () => showChessPlayerCard(
                          context: context,
                          ref: ref,
                          userId: opponentId,
                          white: myColor.opponent == PieceColor.white,
                          matchId: widget.matchId,
                          muted: _muted.contains(opponentId),
                          onToggleMute: () => setState(() {
                            if (!_muted.remove(opponentId)) {
                              _muted.add(opponentId);
                            }
                          }),
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatusLine(state: state, onLive: controller.goLive),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Center(
                    child: PopCard(
                      borderRadius: 28,
                      blur: 10,
                      glow: state.reviewing
                          ? AppColors.sky
                          : state.gameStatus == GameStatus.check && playing
                          ? AppColors.error
                          : AppColors.accent,
                      padding: const EdgeInsets.all(10),
                      child: AnimatedChessBoard(
                        position: state.displayPosition,
                        lastMove: shownMove,
                        fly: state.fly,
                        trail: trail,
                        legalDestinations:
                            state.selectedSquare == null || !hints
                            ? const []
                            : state.legalDestinations,
                        selectedSquare: state.selectedSquare,
                        myColor: state.myColor,
                        interactive:
                            state.isMyTurn && !state.reviewing && playing,
                        onSquareTap: controller.selectSquare,
                        whiteSet: _setOf(whiteId) ?? 'classic',
                        blackSet: _setOf(blackId) ?? 'classic',
                        // Looking back shows the game as it was then.
                        gameOver: over && !state.reviewing,
                        winner: state.outcome?.winnerId == null
                            ? null
                            : state.outcome!.winnerId == whiteId
                            ? PieceColor.white
                            : PieceColor.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MoveStrip(
                  labels: [for (final m in state.history) m.san],
                  displayPly: state.displayPly,
                  reviewing: state.reviewing,
                  onBack: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(gameAudioProvider)
                        .play(Sfx.chessMove, volume: 0.5);
                    controller.stepBack();
                  },
                  onForward: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(gameAudioProvider)
                        .play(Sfx.chessMove, volume: 0.5);
                    controller.stepForward();
                  },
                  onJump: controller.jumpTo,
                ),
                const SizedBox(height: AppSpacing.sm),
                _PlayerBar(
                  userId: myId,
                  color: myColor,
                  state: state,
                  isMe: true,
                  capturedSet: _setOf(opponentId),
                  speech: _speechOf(myId),
                  onWarnSecond: play.timerTicks
                      ? (_) => ref
                            .read(gameAudioProvider)
                            .play(Sfx.tick, volume: 0.7)
                      : null,
                ),
                if (over && !_showResult) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AfterGameBar(
                    playAgainRoute: '/chess',
                    won:
                        state.outcome?.winnerId != null &&
                        state.outcome?.winnerId == myId,
                    onResult: () => setState(() => _showResult = true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final iWon =
        over &&
        state.outcome?.winnerId != null &&
        state.outcome?.winnerId == myId;

    return PopScope(
      canPop: !playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context, controller, playing);
      },
      child: MusicTrackScope(
        track: MusicTrack.game,
        child: Stack(
          children: [
            scaffold,
            if (over && _showResult)
              Positioned.fill(
                child: MatchResultCard(
                  result: state.outcome?.result,
                  winnerId: state.outcome?.winnerId,
                  settled: state.outcome?.settled ?? true,
                  disputed: state.status == 'disputed',
                  stake: state.stake,
                  myId: myId,
                  opponentId: opponentId,
                  playAgainRoute: '/chess',
                  describe: (result, won) => switch (result) {
                    'checkmate' =>
                      won ? 'Checkmate. Beautifully played.' : 'Checkmated.',
                    'stalemate' => 'Stalemate: no legal moves left.',
                    _ => null,
                  },
                  onReview: () => setState(() => _showResult = false),
                ),
              ),
            if (iWon && _showResult)
              const Positioned.fill(
                child: IgnorePointer(child: ConfettiBurst(pieces: 90)),
              ),
          ],
        ),
      ),
    );
  }

  String? _setOf(String? userId) => userId == null
      ? null
      : ref
                .watch(profileByIdProvider(userId))
                .valueOrNull?['equipped_chess_pieces']
            as String?;

  Future<void> _confirmLeave(
    BuildContext context,
    ChessMatchController controller,
    bool playing,
  ) async {
    if (!playing) {
      context.go('/home');
      return;
    }
    final stake = ref.read(chessMatchControllerProvider(widget.matchId)).stake;
    final ok = await confirmBouncy(
      context: context,
      audio: ref.read(gameAudioProvider),
      title: 'Resign this game?',
      message: stake > 0
          ? 'Your opponent wins the game and the prize.'
          : 'Your opponent wins the game.',
      confirmLabel: 'Resign',
      cancelLabel: 'Keep playing',
      destructive: true,
      hero: const CoinBuddy(mood: BuddyMood.sad, size: 76),
    );
    if (!ok || !context.mounted) return;
    try {
      await controller.resign();
    } catch (_) {
      // Already over; head home either way.
    }
    if (context.mounted) context.go('/home');
  }
}

class _TimeControlTitle extends StatelessWidget {
  const _TimeControlTitle({required this.state});

  final ChessMatchState state;

  @override
  Widget build(BuildContext context) {
    final tc = state.timeControl;
    final color = speedColor(tc.speed);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(speedIcon(tc.speed), color: color, size: 20),
        const SizedBox(width: 6),
        Text(
          state.timed ? tc.label : 'Chess',
          style: AppTextStyles.display(fontSize: 18),
        ),
        if (state.stake > 0) ...[
          const SizedBox(width: 10),
          CoinAmount(state.stake, size: 13, color: AppColors.textSecondary),
        ],
      ],
    );
  }
}

/// One player: avatar (ringed by their clock while it runs), name, the
/// pieces they've taken (or what they just said in chat), and their clock.
class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({
    required this.userId,
    required this.color,
    required this.state,
    required this.capturedSet,
    this.isMe = false,
    this.speech,
    this.onWarnSecond,
    this.onAvatarTap,
  });

  final String? userId;
  final PieceColor color;
  final VoidCallback? onAvatarTap;
  final ChessMatchState state;
  final String? capturedSet;
  final bool isMe;

  /// A fresh chat line: (kind, body).
  final (String, String)? speech;
  final ValueChanged<int>? onWarnSecond;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = userId == null
        ? null
        : ref.watch(profileByIdProvider(userId!)).valueOrNull;
    final name = isMe
        ? 'You'
        : userId == null
        ? 'Opponent'
        : profileDisplayName(profile, userId!);
    final live = state.isActive && !state.isOver;
    final running =
        live && state.timed && state.plyCount >= 2 && state.onClock == color;
    final toMove = live && state.position.sideToMove == color;
    final total = (state.matchRow?['clock_initial_ms'] as num?)?.toInt() ?? 1;
    final ink = color == PieceColor.white ? _whiteInk : const Color(0xFF2A2050);

    final avatar = SizedBox.square(
      dimension: 50,
      child: CountdownBorder(
        circle: true,
        strokeWidth: 3.5,
        totalMs: total,
        warnMs: 10000,
        color: AppColors.accentSecondary,
        msLeft: () => running ? state.msLeft(color) : null,
        onWarnSecond: onWarnSecond,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: UserAvatar.fromProfile(
            profile,
            fallbackInitial: name,
            radius: 21,
          ),
        ),
      ),
    );

    return PopCard(
      borderRadius: 22,
      blur: 10,
      tint: toMove ? AppColors.accentSecondary : null,
      glow: toMove ? AppColors.accentSecondary : null,
      borderWidth: toMove ? 1.8 : 1.2,
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      child: Row(
        children: [
          GestureDetector(onTap: onAvatarTap, child: avatar),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                PlayerCoins(userId: userId),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: a,
                    alignment: Alignment.centerLeft,
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: speech != null
                      ? SpeechPill(
                          key: ValueKey(speech),
                          kind: speech!.$1,
                          body: speech!.$2,
                        )
                      : _Captured(
                          key: const ValueKey('captured'),
                          position: state.position,
                          by: color,
                          pieceSet: capturedSet,
                        ),
                ),
              ],
            ),
          ),
          if (state.timed)
            ClockPill(msLeft: () => state.msLeft(color) ?? 0, running: running),
        ],
      ),
    );
  }
}

/// The pieces [by] has taken from the other side, smallest first, plus a
/// "+3" when they're ahead on material.
class _Captured extends StatelessWidget {
  const _Captured({
    super.key,
    required this.position,
    required this.by,
    required this.pieceSet,
  });

  final ChessPosition position;
  final PieceColor by;
  final String? pieceSet;

  static const _start = {
    PieceType.pawn: 8,
    PieceType.knight: 2,
    PieceType.bishop: 2,
    PieceType.rook: 2,
    PieceType.queen: 1,
  };
  static const _value = {
    PieceType.pawn: 1,
    PieceType.knight: 3,
    PieceType.bishop: 3,
    PieceType.rook: 5,
    PieceType.queen: 9,
  };

  Map<PieceType, int> _onBoard(PieceColor color) {
    final counts = <PieceType, int>{};
    for (final rank in position.board) {
      for (final p in rank) {
        if (p != null && p.color == color) {
          counts[p.type] = (counts[p.type] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  int _material(Map<PieceType, int> counts) =>
      counts.entries.fold(0, (sum, e) => sum + (_value[e.key] ?? 0) * e.value);

  @override
  Widget build(BuildContext context) {
    final theirs = _onBoard(by.opponent);
    final mine = _onBoard(by);
    final taken = <PieceType>[
      for (final entry in _start.entries)
        for (var i = 0; i < entry.value - (theirs[entry.key] ?? 0); i++)
          entry.key,
    ];
    final lead = _material(mine) - _material(theirs);
    if (taken.isEmpty && lead <= 0) return const SizedBox(height: 18);

    final finish = ChessPieceStyle.byId(pieceSet).of(by.opponent);
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          Flexible(
            child: ClipRect(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, type) in taken.indexed)
                    Align(
                      widthFactor: i == taken.length - 1 ? 1 : 0.62,
                      child: ChessPieceArt(
                        type: type,
                        finish: finish,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (lead > 0) ...[
            const SizedBox(width: 4),
            Text(
              '+$lead',
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatefulWidget {
  const _StatusLine({required this.state, required this.onLive});

  final ChessMatchState state;
  final VoidCallback onLive;

  @override
  State<_StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<_StatusLine>
    with SingleTickerProviderStateMixin {
  // Ticks only to count down the first-move window.
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Started here: a lazy field would only be created (and started)
    // on first use, which for a ticker is never.
    _ticker = createTicker((_) {
      if (widget.state.firstMoveMsLeft != null) {
        setState(() {});
      } else {
        // The countdown is over: nothing left to animate.
        _ticker.stop();
      }
    });
    if (widget.state.firstMoveMsLeft != null) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant _StatusLine old) {
    super.didUpdateWidget(old);
    if (widget.state.firstMoveMsLeft != null && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    if (state.reviewing) {
      return SizedBox(
        height: 30,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 18, color: AppColors.sky),
            const SizedBox(width: 6),
            Text(
              state.displayPly == 0
                  ? 'Starting position'
                  : 'Move ${state.displayPly} of ${state.history.length}',
              style: AppTextStyles.body(
                color: AppColors.sky,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (state.isActive && !state.isOver) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: widget.onLive,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.error,
                  ),
                  child: Text(
                    'Back to live',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
    if (!state.isActive || state.isOver) return const SizedBox(height: 30);

    final check = state.gameStatus == GameStatus.check;
    final firstMove = state.firstMoveMsLeft;
    final lastWasTheirs =
        state.lastMove != null && state.lastMove!.piece.color != state.myColor;
    final (IconData icon, String text, Color color) = check
        ? (
            Icons.warning_amber_rounded,
            state.isMyTurn ? "You're in check" : 'Check!',
            AppColors.error,
          )
        : state.isMyTurn
        ? (
            Icons.touch_app_rounded,
            firstMove != null
                ? 'Your move · ${(firstMove / 1000).ceil()}s to start'
                : lastWasTheirs && state.lastSan != null
                ? 'Your move · they played ${state.lastSan}'
                : 'Your move',
            AppColors.accentSecondary,
          )
        : (
            Icons.hourglass_top_rounded,
            firstMove != null
                ? 'Waiting for the first move · ${(firstMove / 1000).ceil()}s'
                : 'Their move',
            AppColors.textSecondary,
          );

    return SizedBox(
      height: 30,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey(text.split('·').first + (lastWasTheirs ? 'm' : '')),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surface.withValues(alpha: 0.85),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
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
