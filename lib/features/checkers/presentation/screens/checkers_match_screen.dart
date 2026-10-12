import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../coins/presentation/player_coins.dart';
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
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chat/data/chat_repository.dart';
import '../../../chat/domain/voice_note.dart';
import '../../../chat/presentation/game_chat_controller.dart';
import '../../../chat/presentation/game_chat_sheet.dart';
import '../../../chat/presentation/voice_notes.dart';
import '../../../chess/presentation/widgets/board_match_parts.dart';
import '../../../chess/presentation/widgets/time_control_style.dart';
import '../../../ludo/presentation/widgets/ludo_player_card.dart';
import '../../domain/checkers_engine.dart';
import '../controllers/checkers_match_controller.dart';
import '../widgets/checkers_board.dart';
import '../widgets/checkers_disc.dart';

const _darkInk = Color(0xFFB79BFF);
const _lightInk = Color(0xFFF4EEDC);

/// A live checkers game against another player: their bar on top, the
/// board, the moves, and yours underneath, with clocks, chat and a result
/// card at the end. The same shape as a chess game.
class CheckersMatchScreen extends ConsumerStatefulWidget {
  const CheckersMatchScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<CheckersMatchScreen> createState() =>
      _CheckersMatchScreenState();
}

class _CheckersMatchScreenState extends ConsumerState<CheckersMatchScreen> {
  bool _playedResult = false;
  bool _showResult = false;
  bool _resultShownOnce = false;
  final Set<String> _muted = {};
  final Map<String, (String, String, DateTime, Duration)> _speech = {};
  Timer? _speechTimer;

  static const _speechFor = Duration(seconds: 4);

  (ChatGame, String) get _chatKey => (ChatGame.chess, widget.matchId);

  @override
  void dispose() {
    _speechTimer?.cancel();
    super.dispose();
  }

  void _onChange(CheckersMatchState? prev, CheckersMatchState next) {
    if (next.isOver && !_resultShownOnce) {
      _resultShownOnce = true;
      final fresh = prev != null && !prev.loading;
      final wait = fresh && next.lastMove != null
          ? checkersFlightTime(next.lastMove!) +
                const Duration(milliseconds: 600)
          : const Duration(milliseconds: 200);
      Future.delayed(wait, () {
        if (mounted) setState(() => _showResult = true);
      });
      if (fresh && !_playedResult) {
        _playedResult = true;
        final me = ref.read(currentUserProvider)?.id;
        final winner = next.outcome?.winnerId;
        if (winner != null) {
          ref.read(gameAudioProvider).play(winner == me ? Sfx.win : Sfx.lose);
        }
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

  void _openChat(String? darkId) {
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
        accentFor: (id) => id == darkId ? _darkInk : _lightInk,
      ),
    );
  }

  String? _setOf(String? userId) => userId == null
      ? null
      : ref
                .watch(profileByIdProvider(userId))
                .valueOrNull?['equipped_chess_pieces']
            as String?;

  @override
  Widget build(BuildContext context) {
    final provider = checkersMatchControllerProvider(widget.matchId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final myId = ref.watch(currentUserProvider)?.id;
    final play = ref.watch(gameplaySettingsProvider);
    final chat = ref.watch(gameChatProvider(_chatKey));
    final audio = ref.read(gameAudioProvider);

    ref.listen(provider, _onChange);
    ref.listen(gameChatProvider(_chatKey), _onChat);
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

    final darkId = state.playerOf(CheckersSide.dark);
    final lightId = state.playerOf(CheckersSide.light);
    ref.watch(liveProfilesProvider(liveProfilesKey([darkId, lightId])));
    final mySide = state.mySide ?? CheckersSide.dark;
    final opponentId = mySide == CheckersSide.dark ? lightId : darkId;
    final over = state.isOver;
    final playing = state.isActive && !over;
    final interactive = state.isMyTurn && !state.reviewing && playing;
    final winnerId = state.outcome?.winnerId;
    final iWon = over && winnerId != null && winnerId == myId;

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: playing ? 'Leave game' : 'Close',
          onPressed: () => _confirmLeave(context, controller, playing),
        ),
        title: _Title(state: state),
        actions: [
          MatchChatButton(unread: chat.unread, onTap: () => _openChat(darkId)),
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
                  side: mySide.opponent,
                  state: state,
                  pieceSet: _setOf(opponentId),
                  speech: _speechOf(opponentId),
                  onAvatarTap: opponentId == null
                      ? null
                      : () => showChessPlayerCard(
                          context: context,
                          ref: ref,
                          userId: opponentId,
                          white: mySide.opponent == CheckersSide.dark,
                          checkers: true,
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
                          : interactive && state.mustCapture
                          ? const Color(0xFFFF7A45)
                          : AppColors.accent,
                      padding: const EdgeInsets.all(10),
                      child: CheckersBoard(
                        position: state.displayPosition,
                        lastMove: state.displayLastMove,
                        fly: state.fly,
                        selected: state.selected,
                        targets: play.moveHints || state.mustCapture
                            ? state.targets
                            : const [],
                        movable: interactive
                            ? checkersEngine.movablePieces(state.position)
                            : const {},
                        mustCapture: state.mustCapture,
                        bottom: mySide,
                        interactive: interactive,
                        onSquareTap: (s) {
                          HapticFeedback.selectionClick();
                          controller.selectSquare(s);
                        },
                        darkSet: _setOf(darkId),
                        lightSet: _setOf(lightId),
                        gameOver: over && !state.reviewing,
                        winner: winnerId == null
                            ? null
                            : winnerId == darkId
                            ? CheckersSide.dark
                            : CheckersSide.light,
                        onHop: (_, capture) => audio.play(
                          capture ? Sfx.chessCapture : Sfx.chessMove,
                        ),
                        onCrown: () => audio.play(Sfx.home),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MoveStrip(
                  labels: [for (final m in state.history) m.notation],
                  displayPly: state.displayPly,
                  reviewing: state.reviewing,
                  onBack: () {
                    HapticFeedback.selectionClick();
                    controller.stepBack();
                  },
                  onForward: () {
                    HapticFeedback.selectionClick();
                    controller.stepForward();
                  },
                  onJump: controller.jumpTo,
                ),
                const SizedBox(height: AppSpacing.sm),
                _PlayerBar(
                  userId: myId,
                  side: mySide,
                  state: state,
                  isMe: true,
                  pieceSet: _setOf(myId),
                  speech: _speechOf(myId),
                  onWarnSecond: play.timerTicks
                      ? (_) => audio.play(Sfx.tick, volume: 0.7)
                      : null,
                ),
                if (over && !_showResult) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AfterGameBar(
                    won: iWon,
                    playAgainRoute: '/checkers',
                    onResult: () => setState(() => _showResult = true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

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
                  winnerId: winnerId,
                  settled: state.outcome?.settled ?? true,
                  disputed: state.status == 'disputed',
                  stake: state.stake,
                  myId: myId,
                  opponentId: opponentId,
                  playAgainRoute: '/checkers',
                  describe: (result, won) => switch (result) {
                    'win' =>
                      won
                          ? 'No moves left for them. Well played.'
                          : 'You ran out of moves.',
                    'draw' => 'Forty moves each with no progress.',
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

  Future<void> _confirmLeave(
    BuildContext context,
    CheckersMatchController controller,
    bool playing,
  ) async {
    if (!playing) {
      context.go('/home');
      return;
    }
    final stake = ref
        .read(checkersMatchControllerProvider(widget.matchId))
        .stake;
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

class _Title extends StatelessWidget {
  const _Title({required this.state});

  final CheckersMatchState state;

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
          state.timed ? tc.label : 'Checkers',
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

/// One player: avatar ringed by their clock, name, how many pieces they've
/// taken (or what they just said), and their clock.
class _PlayerBar extends ConsumerWidget {
  const _PlayerBar({
    required this.userId,
    required this.side,
    required this.state,
    required this.pieceSet,
    this.isMe = false,
    this.speech,
    this.onWarnSecond,
    this.onAvatarTap,
  });

  final String? userId;
  final CheckersSide side;
  final CheckersMatchState state;
  final String? pieceSet;
  final bool isMe;
  final (String, String)? speech;
  final ValueChanged<int>? onWarnSecond;
  final VoidCallback? onAvatarTap;

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
        live && state.timed && state.plyCount >= 2 && state.onClock == side;
    final toMove = live && state.position.toMove == side;
    final total = (state.matchRow?['clock_initial_ms'] as num?)?.toInt() ?? 1;

    return PopCard(
      borderRadius: 22,
      blur: 10,
      tint: toMove ? AppColors.accentSecondary : null,
      glow: toMove ? AppColors.accentSecondary : null,
      borderWidth: toMove ? 1.8 : 1.2,
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: SizedBox.square(
              dimension: 50,
              child: CountdownBorder(
                circle: true,
                strokeWidth: 3.5,
                totalMs: total,
                warnMs: 10000,
                color: AppColors.accentSecondary,
                msLeft: () => running ? state.msLeft(side) : null,
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
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox.square(
                      dimension: 16,
                      child: CustomPaint(
                        painter: _DiscIcon(set: pieceSet, side: side),
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
                      : _Taken(
                          key: const ValueKey('taken'),
                          count: 12 - state.position.count(side.opponent),
                          kings: state.position.count(side, kings: true),
                        ),
                ),
              ],
            ),
          ),
          if (state.timed)
            ClockPill(msLeft: () => state.msLeft(side) ?? 0, running: running),
        ],
      ),
    );
  }
}

class _DiscIcon extends CustomPainter {
  _DiscIcon({required this.set, required this.side});

  final String? set;
  final CheckersSide side;

  @override
  void paint(Canvas canvas, Size size) {
    paintCheckersDisc(
      canvas,
      size.center(Offset.zero).translate(0, -1),
      size.width * 0.42,
      finish: checkersFinish(set, side),
    );
  }

  @override
  bool shouldRepaint(covariant _DiscIcon old) =>
      old.set != set || old.side != side;
}

class _Taken extends StatelessWidget {
  const _Taken({super.key, required this.count, required this.kings});

  final int count;
  final int kings;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.body(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: AppColors.textSecondary,
    );
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          if (count > 0) Text('Took $count', style: style),
          if (count > 0 && kings > 0) Text('  ·  ', style: style),
          if (kings > 0) ...[
            const CrownIcon(size: 14),
            const SizedBox(width: 3),
            Text(kings == 1 ? '1 king' : '$kings kings', style: style),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatefulWidget {
  const _StatusLine({required this.state, required this.onLive});

  final CheckersMatchState state;
  final VoidCallback onLive;

  @override
  State<_StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<_StatusLine>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (widget.state.firstMoveMsLeft != null) {
        setState(() {});
      } else {
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

    final firstMove = state.firstMoveMsLeft;
    final capture = state.isMyTurn && state.mustCapture;
    final (IconData icon, String text, Color color) = capture
        ? (Icons.bolt_rounded, 'You must take a piece', const Color(0xFFFF7A45))
        : state.isMyTurn
        ? (
            Icons.touch_app_rounded,
            firstMove != null
                ? 'Your move · ${(firstMove / 1000).ceil()}s to start'
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
            key: ValueKey(text.split('·').first),
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
