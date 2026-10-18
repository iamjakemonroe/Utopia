import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/audio/sound_controls.dart';
import '../../../../core/bots/bots.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/settings/gameplay_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/bouncy_dialog.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/confetti_burst.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/chess_bot.dart';
import '../../domain/chess_engine.dart';
import '../../domain/chess_move.dart';
import '../../domain/chess_position.dart';
import '../../domain/chess_types.dart';
import '../../domain/time_control.dart';
import '../widgets/animated_chess_board.dart';
import '../widgets/chess_piece_styles.dart';
import '../widgets/chess_piece_art.dart';
import '../widgets/board_match_parts.dart';
import '../widgets/bot_clock.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../home/data/offline_game.dart';
import '../widgets/promotion_sheet.dart';
import '../../../events/presentation/events_controller.dart';
import '../../../../core/layout/game_stage.dart';

/// Chess against the computer, all on this phone: no internet needed.
/// Chip (or Robo) thinks off the main thread, reacts to the game with a
/// face and a line, and takebacks are allowed.
class ChessBotScreen extends ConsumerStatefulWidget {
  const ChessBotScreen({
    super.key,
    required this.opponent,
    required this.level,
    required this.myColor,
    this.clock,
    this.resume = false,
  });

  /// Chip or Robo; null for two people taking turns on one phone.
  final BotPersona? opponent;
  final BotLevel level;
  final PieceColor myColor;

  /// The clock (minutes each, plus seconds per move), or null for an
  /// untimed game.
  final TimeControl? clock;

  /// Pick up the game saved before the app closed.
  final bool resume;

  @override
  ConsumerState<ChessBotScreen> createState() => _ChessBotScreenState();
}

enum _Moment {
  start,
  botCapture,
  playerCapture,
  botCheck,
  playerCheck,
  botWin,
  playerWin,
  draw,
}

class _ChessBotScreenState extends ConsumerState<ChessBotScreen> {
  static const _engine = ChessEngine();
  final _rng = math.Random();

  final List<ChessPosition> _history = [ChessPosition.initial()];
  final List<ChessMove> _moves = [];

  /// Each move's notation, for the strip of moves.
  final List<String> _sans = [];

  /// While looking back through the game: how many moves in the board
  /// shows. Null when following the game live.
  int? _reviewPly;
  Square? _selected;
  ChessMove? _fly;
  bool _thinking = false;
  bool _resigned = false;
  bool _showResult = false;

  /// Bumped to drop a move the bot is still thinking about (takeback, new
  /// game, leaving).
  int _gen = 0;

  late final BotClock<PieceColor>? _clock = widget.clock == null
      ? null
      : BotClock(
          Duration(minutes: widget.clock!.minutes),
          PieceColor.values,
          increment: Duration(seconds: widget.clock!.increment),
        );
  Timer? _flagCheck;

  /// Leaving for another app pauses the clocks and saves the game, in case
  /// the phone closes the app while it's away.
  late final AppLifecycleListener _life;

  /// Saves the game after every move, so it comes back if the app closes.
  late final OfflineGameStore _store;

  /// This game's setup, as a route: how it opens again.
  late final String _route =
      '/chess/bot?opponent=${widget.opponent?.key ?? 'local'}'
      '&level=${widget.level.name}'
      '&color=${widget.myColor.name}&clock=${widget.clock?.minutes ?? 0}'
      '&inc=${widget.clock?.increment ?? 0}';

  /// Whose time ran out, ending the game.
  PieceColor? _flagged;

  String? _speech;
  int _speechId = 0;
  BuddyMood _mood = BuddyMood.happy;

  ChessPosition get _pos => _history.last;
  bool get _reviewing => _reviewPly != null;
  int get _shownPly => _reviewPly ?? _moves.length;

  /// Two people on one phone, no bot.
  bool get _twoPlayer => widget.opponent == null;

  /// Whoever plays this move: the player, or on one phone, the side to
  /// move.
  PieceColor get _me => _twoPlayer ? _pos.sideToMove : widget.myColor;
  PieceColor get _bot => _me.opponent;
  bool get _isChip => widget.opponent?.key == kChessChip.key;

  static String _sideName(PieceColor c) =>
      c == PieceColor.white ? 'White' : 'Black';

  GameStatus get _status => _engine.status(_pos);

  bool get _over =>
      _resigned ||
      _flagged != null ||
      _status == GameStatus.checkmate ||
      _status == GameStatus.stalemate ||
      _status == GameStatus.draw;

  /// Moves on the board and no result yet: leaving would throw it away.
  bool get _inProgress => !_over && _moves.isNotEmpty;

  /// Null for a draw.
  PieceColor? get _winner {
    if (_resigned) return _bot;
    if (_flagged != null) return _flagged!.opponent;
    if (_status == GameStatus.checkmate) return _pos.sideToMove.opponent;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _store = ref.read(offlineGameStoreProvider);
    if (widget.resume) _restore();
    _life = AppLifecycleListener(
      onHide: () {
        final ticking = _clock?.running != null;
        _clock?.pause();
        // Moves are saved as they're made; this keeps the clock times. A
        // stopped clock (a question on screen) has nothing new to save.
        if (ticking) _save();
      },
      onShow: () => _clock?.resume(),
    );
    if (_clock != null) {
      _flagCheck = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _checkFlag(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _say(_Moment.start);
      if (_pos.sideToMove == _bot) _botTurn();
    });
  }

  @override
  void dispose() {
    _gen++;
    _flagCheck?.cancel();
    _life.dispose();
    // Leaving on purpose ends the game (a closed app never gets here, so
    // that game comes back).
    _store.clear(route: _route);
    super.dispose();
  }

  // ── saving ───────────────────────────────────────────────────────────────

  static String _code(ChessMove m) =>
      '${m.from.algebraic}${m.to.algebraic}'
      '${m.promotion?.letter.toLowerCase() ?? ''}';

  /// Saves the game so far; a game that's over, or not begun, is forgotten.
  void _save() {
    if (_over || _moves.isEmpty) {
      _store.clear(route: _route);
      return;
    }
    final clock = _clock;
    _store.save(
      OfflineGame(
        kind: GameKind.chess,
        route: _route,
        opponent: widget.opponent?.name ?? 'a friend',
        data: {
          'moves': [for (final m in _moves) _code(m)],
          if (clock != null) ...{
            'clock': {
              for (final e in clock.snapshot.entries) e.key.name: e.value,
            },
            'running': clock.running?.name,
          },
        },
      ),
    );
  }

  /// Replays the saved moves and sets the clocks back to where they were.
  void _restore() {
    final saved = _store.load();
    if (saved == null || saved.route != _route) return;
    for (final code
        in (saved.data['moves'] as List? ?? const []).cast<String>()) {
      if (code.length < 4) break;
      final pos = _pos;
      final from = Square.fromAlgebraic(code.substring(0, 2));
      final to = Square.fromAlgebraic(code.substring(2, 4));
      final promo = code.length > 4 ? code[4] : null;
      final move = _engine
          .legalMoves(pos)
          .where(
            (m) =>
                m.from == from &&
                m.to == to &&
                (promo == null || m.promotion?.letter.toLowerCase() == promo),
          )
          .firstOrNull;
      if (move == null) break;
      _sans.add(_engine.toSan(pos, move));
      _history.add(pos.applyMove(move));
      _moves.add(move);
    }
    final clock = saved.data['clock'];
    if (_clock != null && clock is Map) {
      _clock.restore(
        {
          for (final c in PieceColor.values)
            if (clock[c.name] is num) c: (clock[c.name] as num).toInt(),
        },
        PieceColor.values
            .where((c) => c.name == saved.data['running'])
            .firstOrNull,
      );
    }
  }

  /// Out of time: the game's over, and the other side wins.
  void _checkFlag() {
    final side = _clock?.flagged;
    if (side == null || _over || !mounted) return;
    _gen++;
    _clock!.stop();
    setState(() {
      _thinking = false;
      _flagged = side;
    });
    _finish();
  }

  // ── talking ──────────────────────────────────────────────────────────────

  void _say(_Moment moment) {
    if (_twoPlayer) return;
    final lines = _isChip ? _chipLines[moment]! : _roboLines[moment]!;
    final id = ++_speechId;
    setState(() {
      _speech = lines[_rng.nextInt(lines.length)];
      _mood = switch (moment) {
        _Moment.start => BuddyMood.happy,
        _Moment.botCapture || _Moment.botCheck => BuddyMood.excited,
        _Moment.playerCapture || _Moment.playerCheck => BuddyMood.sad,
        _Moment.botWin => BuddyMood.excited,
        _Moment.playerWin => BuddyMood.sad,
        _Moment.draw => BuddyMood.peaceful,
      };
    });
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && id == _speechId && !_over) {
        setState(() {
          _speech = null;
          _mood = BuddyMood.idle;
        });
      }
    });
  }

  static const _chipLines = {
    _Moment.start: [
      "Let's play! Go easy on me.",
      "Ready? I've been practising!",
      'Good luck! Have fun!',
    ],
    _Moment.botCapture: ['Gotcha!', 'Mine now!', 'Yoink!'],
    _Moment.playerCapture: [
      'Hey! I needed that.',
      'Oof, nice one.',
      'Nooo, my piece!',
    ],
    _Moment.botCheck: ['Check!', 'Watch your king!', 'Check! Your move.'],
    _Moment.playerCheck: ['Eek! My king!', 'Whoa, check?', 'Okay, I see it.'],
    _Moment.botWin: ['Checkmate! Good game!', 'I won! Rematch?'],
    _Moment.playerWin: [
      'You got me! Well played.',
      "Checkmate... you're good!",
    ],
    _Moment.draw: ['A draw! Nobody loses.', 'Even match!'],
  };

  static const _roboLines = {
    _Moment.start: ['BEEP. GAME START.', 'CHESS MODULE LOADED.'],
    _Moment.botCapture: ['TARGET ACQUIRED.', 'PIECE COLLECTED.'],
    _Moment.playerCapture: [
      'PIECE LOST. RECALCULATING.',
      'ERROR: PIECE MISSING.',
    ],
    _Moment.botCheck: ['CHECK. BEEP BOOP.', 'KING IN RANGE.'],
    _Moment.playerCheck: ['WARNING: KING UNDER ATTACK.', 'ALERT. ALERT.'],
    _Moment.botWin: ['CHECKMATE. GG HUMAN.', 'VICTORY PROTOCOL COMPLETE.'],
    _Moment.playerWin: ['SYSTEM DEFEATED. WELL PLAYED.', 'REBOOTING PRIDE.'],
    _Moment.draw: ['STALEMATE. NO WINNER.', 'DRAW. COMPUTING... OK.'],
  };

  // ── playing ──────────────────────────────────────────────────────────────

  Future<void> _onSquare(Square square) async {
    if (_over || _thinking || _reviewing || _pos.sideToMove != _me) return;
    final piece = _pos.board[square.rank][square.file];
    final from = _selected;
    if (from != null) {
      final moves = [
        for (final m in _engine.legalMoves(_pos))
          if (m.from == from && m.to == square) m,
      ];
      if (moves.isNotEmpty) {
        var move = moves.first;
        if (moves.length > 1) {
          // A pawn reaching the end: choose what it becomes.
          final type = await showPromotionSheet(context, _me, pieceSet: _mySet);
          if (type == null || !mounted) return;
          move = moves.firstWhere(
            (m) => m.promotion == type,
            orElse: () => moves.first,
          );
        }
        _play(move);
        return;
      }
    }
    setState(() {
      _selected = piece != null && piece.color == _me && square != from
          ? square
          : null;
    });
    if (_selected != null) HapticFeedback.selectionClick();
  }

  void _play(ChessMove move) {
    final before = _pos;
    final after = before.applyMove(move);
    final san = _engine.toSan(before, move);
    final audio = ref.read(gameAudioProvider);
    setState(() {
      _history.add(after);
      _moves.add(move);
      _sans.add(san);
      // A new move brings the board back to the game.
      _reviewPly = null;
      _fly = move;
      _selected = null;
    });
    final byMe = move.piece.color == _me;
    final status = _engine.status(after);
    if (status == GameStatus.check) {
      audio.play(Sfx.chessCheck);
    } else {
      audio.play(move.isCapture ? Sfx.chessCapture : Sfx.chessMove);
    }

    if (_over) {
      _clock?.stop();
      _finish();
      return;
    }
    // The other side's time starts running.
    _clock?.start(after.sideToMove);
    _save();
    if (status == GameStatus.check) {
      _say(byMe ? _Moment.playerCheck : _Moment.botCheck);
    } else if (move.isCapture &&
        (move.captured?.type != PieceType.pawn || _rng.nextBool())) {
      _say(byMe ? _Moment.playerCapture : _Moment.botCapture);
    }
    if (after.sideToMove == _bot) _botTurn();
  }

  Future<void> _botTurn() async {
    final gen = ++_gen;
    setState(() {
      _thinking = true;
      if (_speech == null) _mood = BuddyMood.thinking;
    });
    final started = DateTime.now();
    final move = await findBotMove(_pos, widget.level);
    // A beat, so the reply never lands before the player's move does.
    final wait =
        const Duration(milliseconds: 650) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted || gen != _gen) return;
    setState(() {
      _thinking = false;
      if (_speech == null) _mood = BuddyMood.idle;
    });
    if (move != null) _play(move);
  }

  void _finish() {
    _save();
    ref.read(eventsProvider.notifier).gameFinished('chess');
    final audio = ref.read(gameAudioProvider);
    final winner = _winner;
    if (winner == null) {
      _say(_Moment.draw);
      audio.play(Sfx.lose);
    } else if (_twoPlayer || winner == _me) {
      _say(_Moment.playerWin);
      audio.play(Sfx.win);
    } else {
      _say(_Moment.botWin);
      audio.play(Sfx.lose);
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showResult = true);
    });
  }

  /// Takes back the player's last move (and the reply to it).
  void _takeBack() {
    if (_moves.isEmpty || _over) return;
    _gen++;
    var removedMine = false;
    setState(() {
      _thinking = false;
      _selected = null;
      _reviewPly = null;
      if (_twoPlayer) {
        _moves.removeLast();
        _history.removeLast();
        _sans.removeLast();
      } else {
        while (_moves.isNotEmpty) {
          final m = _moves.removeLast();
          _history.removeLast();
          _sans.removeLast();
          if (m.piece.color == widget.myColor) removedMine = true;
          if (removedMine && _pos.sideToMove == widget.myColor) break;
        }
      }
      _fly = null;
    });
    if (_moves.isEmpty) {
      _clock?.stop();
    } else {
      _clock?.start(_pos.sideToMove);
    }
    _save();
    ref.read(gameAudioProvider).play(Sfx.chessMove, volume: 0.5);
    if (_pos.sideToMove == _bot) _botTurn();
  }

  /// Asks [question] with the game held still: the clock stops and a reply
  /// the bot is working on is set aside. Kept playing, the clock picks up
  /// where it was and the bot thinks its reply again.
  Future<bool> _askPaused(Future<bool> Function() question) async {
    final running = _clock?.running;
    _gen++;
    _clock?.stop();
    final ok = await question();
    if (!ok && mounted && !_over) {
      if (running != null) _clock?.start(running);
      if (_pos.sideToMove == _bot) _botTurn();
    }
    return ok;
  }

  Future<void> _confirmLeave() async {
    final leave = await _askPaused(
      () => confirmBouncy(
        context: context,
        audio: ref.read(gameAudioProvider),
        title: 'Leave this game?',
        message: _twoPlayer
            ? "This game ends here and won't be saved."
            : 'Your game against ${widget.opponent!.name} ends here and '
                  "won't be saved.",
        confirmLabel: 'Leave',
        cancelLabel: 'Keep playing',
        destructive: true,
        hero: const CoinBuddy(mood: BuddyMood.sad, size: 76),
      ),
    );
    // Navigator.pop, not maybePop: the PopScope would only ask again.
    if (leave && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmResign() async {
    final resign = await _askPaused(
      () => confirmBouncy(
        context: context,
        audio: ref.read(gameAudioProvider),
        title: 'Resign this game?',
        message: _twoPlayer
            ? '${_sideName(_bot)} wins this one.'
            : '${widget.opponent!.name} wins this one.',
        confirmLabel: 'Resign',
        cancelLabel: 'Keep playing',
        destructive: true,
        hero: const CoinBuddy(mood: BuddyMood.sad, size: 76),
      ),
    );
    if (resign && mounted) _resign();
  }

  void _resign() {
    if (_over) return;
    _gen++;
    _clock?.stop();
    setState(() {
      _thinking = false;
      _resigned = true;
    });
    _finish();
  }

  void _newGame() {
    _gen++;
    setState(() {
      _history
        ..clear()
        ..add(ChessPosition.initial());
      _moves.clear();
      _sans.clear();
      _reviewPly = null;
      _selected = null;
      _fly = null;
      _thinking = false;
      _resigned = false;
      _flagged = null;
      _showResult = false;
    });
    _clock?.reset();
    _save();
    _say(_Moment.start);
    if (_pos.sideToMove == _bot) _botTurn();
  }

  // ── looking back ─────────────────────────────────────────────────────────

  void _stepBack() {
    final ply = _shownPly;
    if (ply <= 0) return;
    final m = _moves[ply - 1];
    HapticFeedback.selectionClick();
    ref.read(gameAudioProvider).play(Sfx.chessMove, volume: 0.5);
    setState(() {
      _reviewPly = ply - 1;
      // The move plays backwards.
      _fly = ChessMove(from: m.to, to: m.from, piece: m.piece);
      _selected = null;
    });
  }

  void _stepForward() {
    final ply = _shownPly;
    if (!_reviewing || ply >= _moves.length) return;
    HapticFeedback.selectionClick();
    ref.read(gameAudioProvider).play(Sfx.chessMove, volume: 0.5);
    setState(() {
      _reviewPly = ply + 1 == _moves.length ? null : ply + 1;
      _fly = _moves[ply];
    });
  }

  void _jumpTo(int ply) {
    if (ply < 0 || ply > _moves.length || ply == _shownPly) return;
    setState(() {
      _reviewPly = ply == _moves.length ? null : ply;
      _fly = null;
      _selected = null;
    });
  }

  String? get _mySet {
    final me = ref.read(currentUserProvider)?.id;
    if (me == null) return null;
    return ref
            .read(profileByIdProvider(me))
            .valueOrNull?['equipped_chess_pieces']
        as String?;
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    final mySet = profile?['equipped_chess_pieces'] as String? ?? 'classic';
    final botSet = widget.opponent?.chessPieces ?? mySet;
    final hints = ref.watch(gameplaySettingsProvider).moveHints;
    final status = _status;
    final legal = _selected == null || !hints
        ? const <ChessMove>[]
        : [
            for (final m in _engine.legalMoves(_pos))
              if (m.from == _selected) m,
          ];
    final last = _shownPly == 0 ? null : _moves[_shownPly - 1];
    final winner = _winner;
    final iWon = _over && winner == _me;
    final levelName = switch (widget.level) {
      BotLevel.easy => 'Easy',
      BotLevel.normal => 'Normal',
      BotLevel.hard => 'Hard',
    };

    final scaffold = Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: _inProgress ? 'Leave game' : 'Close',
          // maybePop goes through the PopScope below, which asks first.
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          [
            _twoPlayer ? 'Chess · one phone' : 'vs ${widget.opponent!.name}',
            ?widget.clock?.label,
          ].join(' · '),
        ),
        actions: [
          const SoundQuickToggle(),
          IconButton(
            tooltip: 'Take back',
            icon: const Icon(Icons.undo_rounded),
            onPressed: _moves.isEmpty || _over ? null : _takeBack,
          ),
          IconButton(
            tooltip: 'Resign',
            icon: const Icon(Icons.flag_rounded),
            onPressed: _over ? null : _confirmResign,
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
              AppSpacing.md,
            ),
            child: GameStage(
              above: [
                if (_twoPlayer)
                  _SideStrip(
                    color: PieceColor.black,
                    pieceSet: mySet,
                    active: !_over && _pos.sideToMove == PieceColor.black,
                    flipped: true,
                    clock: _clock == null
                        ? null
                        : ClockPill(
                            msLeft: () => _clock.msLeft(PieceColor.black),
                            running:
                                _clock.isRunning(PieceColor.black) && !_over,
                          ),
                  )
                else
                  _BotBar(
                    persona: widget.opponent!,
                    level: levelName,
                    mood: _thinking && _speech == null
                        ? BuddyMood.thinking
                        : _mood,
                    speech: _speech,
                    thinking: _thinking,
                    clock: _clock == null
                        ? null
                        : ClockPill(
                            msLeft: () => _clock.msLeft(_bot),
                            running: _clock.isRunning(_bot) && !_over,
                          ),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
              board: Center(
                child: PopCard(
                  borderRadius: 28,
                  glow: status == GameStatus.check && !_over
                      ? AppColors.error
                      : AppColors.accent,
                  padding: const EdgeInsets.all(10),
                  child: AnimatedChessBoard(
                    position: _history[_shownPly],
                    lastMove: last,
                    fly: _fly,
                    trail:
                        last != null &&
                        (_twoPlayer || last.piece.color == _bot),
                    legalDestinations: legal,
                    selectedSquare: _selected,
                    myColor: _twoPlayer ? PieceColor.white : _me,
                    interactive:
                        !_over &&
                        !_thinking &&
                        !_reviewing &&
                        _pos.sideToMove == _me,
                    onSquareTap: _onSquare,
                    whiteSet: _twoPlayer || _me == PieceColor.white
                        ? mySet
                        : botSet,
                    blackSet: _twoPlayer || _me == PieceColor.black
                        ? mySet
                        : botSet,
                    gameOver: _over && !_reviewing,
                    winner: winner,
                    // Face to face: Black sits across the table.
                    turnedFor: _twoPlayer ? PieceColor.black : null,
                  ),
                ),
              ),
              below: [
                const SizedBox(height: AppSpacing.sm),
                MoveStrip(
                  labels: _sans,
                  displayPly: _shownPly,
                  reviewing: _reviewing,
                  onBack: _stepBack,
                  onForward: _stepForward,
                  onJump: _jumpTo,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_twoPlayer)
                  _SideStrip(
                    color: PieceColor.white,
                    pieceSet: mySet,
                    active: !_over && _pos.sideToMove == PieceColor.white,
                    status: _over
                        ? (winner == null
                              ? 'Draw'
                              : _flagged != null
                              ? '${_sideName(_flagged!)} ran out of time'
                              : '${_sideName(winner)} wins!')
                        : status == GameStatus.check
                        ? '${_sideName(_pos.sideToMove)}: check!'
                        : "${_sideName(_pos.sideToMove)}'s move",
                    onResult: _over && !_showResult
                        ? () => setState(() => _showResult = true)
                        : null,
                    clock: _clock == null
                        ? null
                        : ClockPill(
                            msLeft: () => _clock.msLeft(PieceColor.white),
                            running:
                                _clock.isRunning(PieceColor.white) && !_over,
                          ),
                  )
                else
                  Row(
                    children: [
                      UserAvatar.fromProfile(
                        profile,
                        fallbackInitial: 'You',
                        radius: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _over
                              ? (iWon
                                    ? 'You won!'
                                    : winner == null
                                    ? 'Draw'
                                    : _flagged == _me
                                    ? 'Out of time'
                                    : '${widget.opponent!.name} won')
                              : _thinking
                              ? '${widget.opponent!.name} is thinking...'
                              : status == GameStatus.check
                              ? 'Check! Protect your king'
                              : 'Your move',
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w800,
                            color: status == GameStatus.check && !_over
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_over && !_showResult)
                        TextButton(
                          onPressed: () => setState(() => _showResult = true),
                          child: const Text('Result'),
                        ),
                      if (_clock != null)
                        ClockPill(
                          msLeft: () => _clock.msLeft(_me),
                          running: _clock.isRunning(_me) && !_over,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // A game in progress asks before going (close button and back gesture
    // alike); a finished or unstarted one just goes.
    return PopScope(
      canPop: !_inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _gen++;
        } else {
          _confirmLeave();
        }
      },
      child: MusicTrackScope(
        track: MusicTrack.game,
        child: Stack(
          children: [
            scaffold,
            if (_showResult)
              Positioned.fill(
                child: _BotResult(
                  persona: widget.opponent,
                  title: _twoPlayer
                      ? (winner == null
                            ? "It's a draw"
                            : _flagged != null
                            ? '${_sideName(_flagged!)} ran out of time'
                            : '${_sideName(winner)} wins!')
                      : null,
                  won: iWon,
                  draw: winner == null,
                  resigned: _resigned,
                  timedOut: _flagged != null,
                  onAgain: _newGame,
                  onReview: () => setState(() => _showResult = false),
                  onDone: () => Navigator.of(context).maybePop(),
                ),
              ),
            if (_showResult && (iWon || (_twoPlayer && winner != null)))
              const Positioned.fill(
                child: IgnorePointer(child: ConfettiBurst(pieces: 90)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The opponent: Chip's face (or Robo), the level, and what they're saying.
class _BotBar extends StatelessWidget {
  const _BotBar({
    required this.persona,
    required this.level,
    required this.mood,
    required this.speech,
    required this.thinking,
    this.clock,
  });

  final BotPersona persona;
  final String level;
  final BuddyMood mood;
  final String? speech;
  final bool thinking;

  /// The bot's clock, in a timed game.
  final Widget? clock;

  @override
  Widget build(BuildContext context) {
    final chip = persona.key == kChessChip.key;
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          chip
              ? CoinBuddy(mood: mood, size: 66)
              : UserAvatar.fromProfile(
                  botProfile(persona.id),
                  fallbackInitial: persona.name,
                  radius: 26,
                ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: a,
                alignment: Alignment.centerLeft,
                child: FadeTransition(opacity: a, child: child),
              ),
              child: speech != null
                  ? Container(
                      key: ValueKey(speech),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border.all(
                          color: AppColors.glowRing.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        speech!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Column(
                      key: const ValueKey('name'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          persona.name,
                          style: AppTextStyles.display(fontSize: 20),
                        ),
                        Text(
                          thinking ? 'Thinking...' : '$level · offline',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (clock != null) ...[const SizedBox(width: 8), clock!],
        ],
      ),
    );
  }
}

class _BotResult extends StatelessWidget {
  const _BotResult({
    required this.persona,
    this.title,
    required this.won,
    required this.draw,
    required this.resigned,
    this.timedOut = false,
    required this.onAgain,
    required this.onReview,
    required this.onDone,
  });

  /// Null on one phone.
  final BotPersona? persona;

  /// Overrides the usual "You won!" lines (on one phone).
  final String? title;
  final bool won;
  final bool draw;
  final bool resigned;

  /// Someone's time ran out.
  final bool timedOut;
  final VoidCallback onAgain;
  final VoidCallback onReview;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = persona;
    final heading =
        title ??
        (won && timedOut
            ? 'Their time ran out!'
            : timedOut && !draw
            ? 'Out of time'
            : won
            ? 'You won!'
            : draw
            ? "It's a draw"
            : resigned
            ? 'You resigned'
            : '${p?.name} won');
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.elasticOut,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: PopCard(
              borderRadius: 28,
              tint: won ? AppColors.success : null,
              glow: won ? AppColors.success : AppColors.accent,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p == null)
                    const CoinBuddy(mood: BuddyMood.excited, size: 90)
                  else if (p.key == kChessChip.key)
                    CoinBuddy(
                      mood: won
                          ? BuddyMood.sad
                          : draw
                          ? BuddyMood.peaceful
                          : BuddyMood.excited,
                      size: 90,
                    )
                  else
                    UserAvatar.fromProfile(
                      botProfile(p.id),
                      fallbackInitial: p.name,
                      radius: 40,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(fontSize: 28),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Play again',
                    color: AppColors.success,
                    onPressed: onAgain,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: onReview,
                          child: const Text('See the board'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: onDone,
                          child: const Text('Done'),
                        ),
                      ),
                    ],
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

/// One side's strip in a game on one phone: its king, its name (or what's
/// happening, on the side to move), and its clock. The top one is turned
/// round so the player across the table can read it.
class _SideStrip extends StatelessWidget {
  const _SideStrip({
    required this.color,
    required this.pieceSet,
    required this.active,
    this.flipped = false,
    this.status,
    this.onResult,
    this.clock,
  });

  final PieceColor color;
  final String pieceSet;
  final bool active;
  final bool flipped;
  final String? status;
  final VoidCallback? onResult;
  final Widget? clock;

  @override
  Widget build(BuildContext context) {
    final name = color == PieceColor.white ? 'White' : 'Black';
    final strip = PopCard(
      borderRadius: 20,
      tint: active ? AppColors.accentSecondary : null,
      glow: active ? AppColors.accentSecondary : null,
      borderWidth: active ? 1.8 : 1.2,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          ChessPieceArt(
            type: PieceType.king,
            finish: ChessPieceStyle.byId(pieceSet).of(color),
            size: 34,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status != null && (active || onResult != null) ? status! : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontWeight: FontWeight.w800),
            ),
          ),
          if (onResult != null)
            TextButton(onPressed: onResult, child: const Text('Result')),
          if (clock != null) ...[const SizedBox(width: 8), clock!],
        ],
      ),
    );
    return flipped ? RotatedBox(quarterTurns: 2, child: strip) : strip;
  }
}
