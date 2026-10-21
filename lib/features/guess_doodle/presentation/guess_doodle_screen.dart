import '../../../core/widgets/leave_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/share_invite.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/doodle_game.dart';
import 'doodle_game_controller.dart';
import 'widgets/doodle_canvas_view.dart';
import 'widgets/doodle_chat.dart';
import 'widgets/doodle_header.dart';
import 'widgets/doodle_overlays.dart';
import 'widgets/doodle_tools.dart';
import '../../invites/domain/game_invite.dart';
import '../../events/presentation/events_controller.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/layout/game_stage.dart';
import '../../../l10n/strings.dart';

/// Name colors, given out in drawing order.
const _nameColors = [
  Color(0xFFFF8FB8),
  Color(0xFF6BF0B0),
  Color(0xFF8FD8FF),
  Color(0xFFFFC94D),
  Color(0xFFB79BFF),
  Color(0xFFFF9F5A),
  Color(0xFF5AE0E0),
  Color(0xFFFF6B6B),
  Color(0xFFC6F06B),
  Color(0xFFFFB3E6),
];

/// A game of Guess My Doodle: the word (or its blanks) and the clock up
/// top, everyone playing, the paper, the chat floating under it, and the
/// guess box, or for the drawer, the pens.
class GuessDoodleScreen extends ConsumerStatefulWidget {
  const GuessDoodleScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<GuessDoodleScreen> createState() => _GuessDoodleScreenState();
}

class _GuessDoodleScreenState extends ConsumerState<GuessDoodleScreen> {
  DoodlePen _pen = const DoodlePen();
  final _focus = FocusNode();
  DateTime? _lastChatSound;

  DoodleGameController get _ctrl =>
      ref.read(doodleGameControllerProvider(widget.gameId).notifier);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _play(Sfx sfx) => ref.read(gameAudioProvider).play(sfx);

  /// Sounds and buzzes for what just happened.
  void _react(DoodleGameState? prev, DoodleGameState next, String? me) {
    final was = prev?.game;
    final game = next.game;
    if (game == null) return;
    if (was?.phase != game.phase || was?.turn != game.turn) {
      switch (game.phase) {
        case DoodlePhase.choosing when game.drawerId == me:
          _play(Sfx.yourTurn);
          HapticFeedback.mediumImpact();
        case DoodlePhase.drawing:
          if (game.drawerId == me) _focus.unfocus();
        case DoodlePhase.reveal:
          _play(Sfx.drop);
        case DoodlePhase.over:
          _play(game.winnerIds.contains(me) ? Sfx.win : Sfx.reaction);
          if (was != null) {
            ref
                .read(eventsProvider.notifier)
                .gameFinished('doodle', matchId: widget.gameId);
          }
        default:
      }
    }
    if (next.lastCorrect != null &&
        prev?.lastCorrect?.at != next.lastCorrect!.at) {
      _play(Sfx.win);
      HapticFeedback.heavyImpact();
    }
    final before = prev?.messages.lastOrNull?.id ?? 0;
    if (prev == null || prev.messages.isEmpty) return;
    for (final m in next.messages) {
      if (m.id <= before) continue;
      if (m.kind == DoodleMessageKind.guessed && m.senderId != me) {
        _play(Sfx.reaction);
      } else if (m.kind == DoodleMessageKind.chat && m.senderId != me) {
        final now = DateTime.now();
        if (_lastChatSound == null ||
            now.difference(_lastChatSound!) > const Duration(seconds: 2)) {
          _lastChatSound = now;
          _play(Sfx.chat);
        }
      } else if (m.kind == DoodleMessageKind.close && m.senderId == me) {
        HapticFeedback.lightImpact();
      }
    }
  }

  Future<bool> _send(String text) async {
    try {
      await _ctrl.send(text);
      return true;
    } catch (e) {
      if (!mounted) return false;
      final s = e.toString();
      showUtopiaToast(
        context,
        s.contains('slow down')
            ? strings.guessDoodleSlowDownALittle
            : s.contains('not in this game')
            ? strings.guessDoodleYouReNotInThis
            : friendlyError(e),
        kind: ToastKind.warning,
      );
      return false;
    }
  }

  Future<void> _startGame() async {
    try {
      await _ctrl.startGame();
    } catch (e) {
      if (mounted) {
        showUtopiaToast(context, friendlyError(e), kind: ToastKind.error);
      }
    }
  }

  Future<void> _leave() async {
    _focus.unfocus();
    try {
      await _ctrl.leave();
    } catch (_) {}
    if (!mounted) return;
    LeaveGuard.release();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.maybeOf(context)?.go('/home');
    }
  }

  Future<void> _askToLeave() async {
    final state = ref.read(doodleGameControllerProvider(widget.gameId));
    final game = state.game;
    if (game == null || !game.playing || state.left) {
      await _leave();
      return;
    }
    _play(Sfx.drawer);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          strings.guessDoodleLeaveTheGame,
          style: AppTextStyles.display(fontSize: 22),
        ),
        content: Text(
          strings.guessDoodleTheOthersWillCarryOn,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.guessDoodleStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              strings.guessDoodleLeave,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (leave == true) await _leave();
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _play(Sfx.tap);
    showUtopiaToast(
      context,
      strings.guessDoodleCodeCopied,
      icon: Icons.content_copy_rounded,
      kind: ToastKind.success,
    );
  }

  Future<void> _share(String code) async {
    ref.read(analyticsProvider).log('invite_shared', {'game': 'doodle'});
    _play(Sfx.tap);
    final box = context.findRenderObject() as RenderBox?;
    await shareInvite(
      context,
      text: strings.guessDoodleComePlayGuessMyDoodle(
        code,
        GameInvite(InviteGame.doodle, code).link,
      ),
      subject: strings.guessDoodleGuessMyDoodleInUtopia,
      origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _confirmClear() async {
    _play(Sfx.drawer);
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          strings.guessDoodleClearTheDrawing,
          style: AppTextStyles.display(fontSize: 22),
        ),
        content: Text(
          strings.guessDoodleYouCanTUndoThis,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.guessDoodleKeepIt),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              strings.guessDoodleClear,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (clear == true) _ctrl.clearCanvas();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.id;
    final provider = doodleGameControllerProvider(widget.gameId);
    final state = ref.watch(provider);
    ref.listen(provider, (prev, next) => _react(prev, next, me));
    final ctrl = ref.read(provider.notifier);
    final game = state.game;
    final active = state.active;
    final order = [for (final p in state.players) p.userId];
    Color colorOf(String? id) {
      final i = id == null ? -1 : order.indexOf(id);
      return i < 0
          ? AppColors.textSecondary
          : _nameColors[i % _nameColors.length];
    }

    final drawer = game != null && game.drawerId == me && game.playing;
    final drawing = drawer && game.phase == DoodlePhase.drawing;
    final guessed = ctrl.guessedThisTurn && game?.phase == DoodlePhase.drawing;
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    final hint = switch (game?.phase) {
      DoodlePhase.drawing when guessed =>
        strings.guessDoodleChatWithPlayersWhoGot,
      DoodlePhase.drawing => strings.guessDoodleTypeYourGuess,
      DoodlePhase.choosing when drawer =>
        strings.guessDoodleOnlyPlayersWhoGuessWill,
      _ => strings.guessDoodleSaySomething,
    };

    final totalFor = switch (game?.phase) {
      DoodlePhase.choosing => 15,
      DoodlePhase.drawing => game?.drawSeconds ?? 80,
      DoodlePhase.reveal => 6,
      DoodlePhase.over => 25,
      DoodlePhase.lobby => 10,
      _ => 0,
    };
    final showTimer =
        game != null &&
        game.phaseEndsAt != null &&
        !(game.phase == DoodlePhase.over && !game.isPublic);

    Widget? overlay;
    if (state.left || game?.phase == DoodlePhase.closed) {
      overlay = DoodleEnded(onBack: _leave);
    } else if (game == null) {
      overlay = const Center(child: CircularProgressIndicator());
    } else {
      overlay = switch (game.phase) {
        DoodlePhase.lobby => DoodleWaitingRoom(
          game: game,
          players: active,
          me: me,
          offset: state.clockOffset,
          onCopy: () => _copy(game.code),
          onShare: () => _share(game.code),
          onStart: _startGame,
        ),
        DoodlePhase.choosing => DoodleChoosing(
          key: ValueKey('choose${game.turn}'),
          drawerId: game.drawerId,
          me: me,
          choices: state.secretTurn == game.turn ? state.choices : const [],
          onChoose: ctrl.choose,
        ),
        DoodlePhase.reveal => DoodleReveal(
          key: ValueKey('reveal${game.turn}'),
          word: game.revealedWord,
          players: active,
          drawerId: game.drawerId,
          me: me,
        ),
        DoodlePhase.over => DoodleScores(
          game: game,
          players: active,
          me: me,
          offset: state.clockOffset,
          onAgain: _startGame,
          onLeave: _leave,
        ),
        _ => null,
      };
    }

    final correct = state.lastCorrect;
    final freshCorrect =
        correct != null &&
        DateTime.now().difference(correct.at) < const Duration(seconds: 3);

    return LeaveGuard(
      canLeave: false,
      onAsk: _askToLeave,
      child: Scaffold(
        body: AppBackground(
          child: Stack(
            children: [
              SafeArea(
                child: GameStage(
                  above: [
                    _TopBar(
                      round: game?.round ?? 0,
                      rounds: game?.rounds ?? 0,
                      playing: game?.playing ?? false,
                      onBack: _askToLeave,
                      timer: showTimer
                          ? DoodleTimer(
                              endsAt: game.phaseEndsAt,
                              total: totalFor,
                              offset: state.clockOffset,
                              onSecond: (s) {
                                if (game.phase == DoodlePhase.drawing &&
                                    s <= 5) {
                                  _play(Sfx.tick);
                                }
                              },
                            )
                          : null,
                    ),
                    SizedBox(
                      height: 40,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: game == null
                              ? const SizedBox.shrink()
                              : DoodleWordBar(
                                  mask: game.phase == DoodlePhase.drawing
                                      ? game.wordMask
                                      : null,
                                  word:
                                      game.phase == DoodlePhase.drawing &&
                                          state.secretTurn == game.turn
                                      ? state.word
                                      : null,
                                  revealed: game.phase == DoodlePhase.reveal
                                      ? game.revealedWord
                                      : null,
                                  guessed: guessed,
                                  drawing: drawer,
                                ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: typing || game == null || active.isEmpty
                          ? const SizedBox(width: double.infinity)
                          : DoodlePlayersStrip(
                              players: active,
                              game: game,
                              me: me,
                              colorOf: colorOf,
                            ),
                    ),
                  ],
                  board: LayoutBuilder(
                    builder: (context, c) {
                      // While typing, the drawing gives up room so the
                      // chat still shows a few lines.
                      final room = c.maxHeight - (typing ? 116 : 70);
                      final side = (c.maxWidth - 24)
                          .clamp(0.0, room < 0 ? 0.0 : room)
                          .toDouble();
                      return Column(
                        children: [
                          const SizedBox(height: 4),
                          SizedBox.square(
                            dimension: side,
                            child: DoodleCanvasView(
                              ink: ctrl.ink,
                              canDraw: drawing,
                              onStart: (p) => ctrl.strokeStart(
                                p,
                                _pen.tool,
                                _pen.color,
                                _pen.size,
                              ),
                              onMove: ctrl.strokeMove,
                              onEnd: ctrl.strokeEnd,
                              overlay: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                child:
                                    overlay ??
                                    const SizedBox.shrink(
                                      key: ValueKey('none'),
                                    ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: DoodleChatFeed(
                                messages: state.messages,
                                me: me,
                                colorOf: colorOf,
                                filter: game?.isPublic ?? true,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  below: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: drawing
                            ? ListenableBuilder(
                                key: const ValueKey('tools'),
                                listenable: ctrl.ink,
                                builder: (context, _) => DoodleTools(
                                  pen: _pen,
                                  onPen: (p) => setState(() => _pen = p),
                                  canUndo: ctrl.ink.canUndo,
                                  onUndo: ctrl.undo,
                                  onClear: _confirmClear,
                                ),
                              )
                            : DoodleGuessField(
                                key: const ValueKey('guess'),
                                hint: hint,
                                focusNode: _focus,
                                glow: guessed ? const Color(0xFF2FD98E) : null,
                                onSend: _send,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (freshCorrect)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ConfettiBurst(
                            key: ValueKey(correct.at),
                            pieces: 50,
                          ),
                        ),
                        _CorrectBurst(
                          key: ValueKey(correct.at),
                          points: correct.points,
                        ),
                      ],
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.round,
    required this.rounds,
    required this.playing,
    required this.onBack,
    required this.timer,
  });

  final int round;
  final int rounds;
  final bool playing;
  final VoidCallback onBack;
  final Widget? timer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          IconButton(
            tooltip: strings.guessDoodleLeave,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.guessDoodleGuessMyDoodle,
                  style: AppTextStyles.display(fontSize: 18),
                ),
                if (playing && rounds > 0)
                  Text(
                    strings.guessDoodleRoundOf(round, rounds),
                    style: AppTextStyles.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: timer ?? const SizedBox(width: 46),
          ),
        ],
      ),
    );
  }
}

/// "+340" rising from the middle when you guess it.
class _CorrectBurst extends StatelessWidget {
  const _CorrectBurst({super.key, required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1800),
        builder: (context, v, child) {
          final pop = Curves.elasticOut.transform((v / 0.4).clamp(0.0, 1.0));
          final fade = v < 0.7 ? 1.0 : 1 - (v - 0.7) / 0.3;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -60 * v),
              child: Transform.scale(scale: 0.5 + 0.5 * pop, child: child),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.guessDoodleYouGotIt,
              style:
                  AppTextStyles.display(
                    fontSize: 30,
                    color: AppColors.onWorld,
                  ).copyWith(
                    shadows: const [
                      Shadow(blurRadius: 12, color: Colors.black54),
                    ],
                  ),
            ),
            Text(
              '+$points',
              style:
                  AppTextStyles.display(
                    fontSize: 44,
                    color: const Color(0xFF6BF0B0),
                  ).copyWith(
                    shadows: const [
                      Shadow(blurRadius: 14, color: Colors.black54),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
