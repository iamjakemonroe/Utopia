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
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/confetti_burst.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../chess/presentation/widgets/board_match_parts.dart';
import '../../../chess/domain/time_control.dart';
import '../../../chess/presentation/widgets/bot_clock.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../home/data/offline_game.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/checkers_bot.dart';
import '../../domain/checkers_engine.dart';
import '../widgets/checkers_board.dart';
import '../widgets/checkers_disc.dart';

/// Checkers on this phone, no internet needed: against Chip or Robo (who
/// think off the main thread and react to the game), or two people taking
/// turns on one phone when [opponent] is null. Takebacks are allowed.
class CheckersBotScreen extends ConsumerStatefulWidget {
  const CheckersBotScreen({
    super.key,
    required this.opponent,
    required this.level,
    required this.mySide,
    this.clock,
    this.resume = false,
  });

  /// Null for two players on one phone.
  final BotPersona? opponent;
  final BotLevel level;
  final CheckersSide mySide;

  /// The clock (minutes each, plus seconds per move), or null for an
  /// untimed game.
  final TimeControl? clock;

  /// Pick up the game saved before the app closed.
  final bool resume;

  @override
  ConsumerState<CheckersBotScreen> createState() => _CheckersBotScreenState();
}

enum _Moment {
  start,
  botCapture,
  playerCapture,
  botDouble,
  playerDouble,
  botKing,
  playerKing,
  botWin,
  playerWin,
  draw,
}

class _CheckersBotScreenState extends ConsumerState<CheckersBotScreen> {
  static const _engine = CheckersEngine();
  final _rng = math.Random();

  final List<CheckersPosition> _history = [CheckersPosition.initial()];
  final List<CheckersMove> _moves = [];

  /// While looking back through the game: how many moves in the board
  /// shows. Null when following the game live.
  int? _reviewPly;
  int? _selected;
  CheckersMove? _fly;
  bool _thinking = false;
  bool _resigned = false;
  bool _showResult = false;
  int _gen = 0;

  late final BotClock<CheckersSide>? _clock = widget.clock == null
      ? null
      : BotClock(
          Duration(minutes: widget.clock!.minutes),
          CheckersSide.values,
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
      '/checkers/bot?opponent=${widget.opponent?.key ?? 'local'}'
      '&level=${widget.level.name}'
      '&color=${widget.mySide == CheckersSide.dark ? 'white' : 'black'}'
      '&clock=${widget.clock?.minutes ?? 0}&inc=${widget.clock?.increment ?? 0}';

  /// Whose time ran out, ending the game.
  CheckersSide? _flagged;

  String? _speech;
  int _speechId = 0;
  BuddyMood _mood = BuddyMood.happy;

  CheckersPosition get _pos => _history.last;
  bool get _reviewing => _reviewPly != null;
  int get _shownPly => _reviewPly ?? _moves.length;
  bool get _twoPlayer => widget.opponent == null;
  CheckersSide get _me => widget.mySide;
  CheckersSide get _bot => widget.mySide.opponent;
  bool get _isChip => widget.opponent?.key == kChessChip.key;
  bool get _botsTurn => !_twoPlayer && _pos.toMove == _bot;

  CheckersStatus get _status => _engine.status(_pos);
  bool get _over =>
      _resigned || _flagged != null || _status != CheckersStatus.ongoing;

  /// Null for a draw.
  CheckersSide? get _winner {
    if (_resigned) return _twoPlayer ? _pos.toMove.opponent : _bot;
    if (_flagged != null) return _flagged!.opponent;
    return switch (_status) {
      CheckersStatus.darkWins => CheckersSide.dark,
      CheckersStatus.lightWins => CheckersSide.light,
      _ => null,
    };
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
      if (_botsTurn) _botTurn();
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

  /// Saves the game so far; a game that's over, or not begun, is forgotten.
  void _save() {
    if (_over || _moves.isEmpty) {
      _store.clear(route: _route);
      return;
    }
    final clock = _clock;
    _store.save(
      OfflineGame(
        kind: GameKind.checkers,
        route: _route,
        opponent: widget.opponent?.name ?? 'a friend',
        data: {
          'moves': [for (final m in _moves) m.notation],
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
      final pos = _pos;
      final move = _engine
          .legalMoves(pos)
          .where((m) => m.notation == code)
          .firstOrNull;
      if (move == null) break;
      _history.add(pos.apply(move));
      _moves.add(move);
    }
    final clock = saved.data['clock'];
    if (_clock != null && clock is Map) {
      _clock.restore(
        {
          for (final c in CheckersSide.values)
            if (clock[c.name] is num) c: (clock[c.name] as num).toInt(),
        },
        CheckersSide.values
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
        _Moment.botCapture ||
        _Moment.botDouble ||
        _Moment.botKing ||
        _Moment.botWin => BuddyMood.excited,
        _Moment.playerCapture ||
        _Moment.playerDouble ||
        _Moment.playerKing ||
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
      "Let's play! Dark goes first.",
      "Ready? I've been practising my jumps!",
      'Good luck! Have fun!',
    ],
    _Moment.botCapture: ['Hop! Gotcha.', 'Mine now!', 'Yoink!'],
    _Moment.playerCapture: ['Hey! I needed that.', 'Oof, nice jump.', 'Nooo!'],
    _Moment.botDouble: ['Double jump!', 'Boing boing!', 'Two for one!'],
    _Moment.playerDouble: [
      'Two at once?!',
      'Whoa, a double!',
      "That's not fair... it is fair.",
    ],
    _Moment.botKing: ['Crown me!', "I'm a king now!", 'All hail me!'],
    _Moment.playerKing: [
      'Oh no, you got a king.',
      'Your Majesty...',
      'Kings go backwards too. Eek.',
    ],
    _Moment.botWin: ['I won! Good game!', 'No moves left for you! Rematch?'],
    _Moment.playerWin: ['You got me! Well played.', "I'm all out of moves!"],
    _Moment.draw: ['A draw! Nobody loses.', 'Even match!'],
  };

  static const _roboLines = {
    _Moment.start: ['BEEP. GAME START.', 'CHECKERS MODULE LOADED.'],
    _Moment.botCapture: ['TARGET ACQUIRED.', 'PIECE COLLECTED.'],
    _Moment.playerCapture: [
      'PIECE LOST. RECALCULATING.',
      'ERROR: PIECE MISSING.',
    ],
    _Moment.botDouble: ['CHAIN JUMP EXECUTED.', 'EFFICIENCY: 200 PERCENT.'],
    _Moment.playerDouble: ['MULTIPLE LOSSES DETECTED.', 'ALERT. ALERT.'],
    _Moment.botKing: ['UPGRADE COMPLETE: KING.', 'CROWN INSTALLED.'],
    _Moment.playerKing: ['WARNING: HUMAN KING.', 'THREAT LEVEL RAISED.'],
    _Moment.botWin: [
      'NO MOVES REMAIN. GG HUMAN.',
      'VICTORY PROTOCOL COMPLETE.',
    ],
    _Moment.playerWin: ['SYSTEM DEFEATED. WELL PLAYED.', 'REBOOTING PRIDE.'],
    _Moment.draw: ['DRAW. NO WINNER.', 'STALEMATE. COMPUTING... OK.'],
  };

  // ── playing ──────────────────────────────────────────────────────────────

  List<CheckersMove> get _legal => _engine.legalMoves(_pos);

  bool get _myTurn =>
      !_over && !_thinking && !_reviewing && (_twoPlayer || _pos.toMove == _me);

  void _onSquare(int square) {
    if (!_myTurn) return;
    final legal = _legal;
    final from = _selected;
    if (from != null) {
      final moves = [
        for (final m in legal)
          if (m.from == from && m.to == square) m,
      ]..sort((a, b) => b.captured.length.compareTo(a.captured.length));
      if (moves.isNotEmpty) {
        _play(moves.first);
        return;
      }
    }
    final movable = legal.any((m) => m.from == square);
    setState(() => _selected = movable && square != from ? square : null);
    if (_selected != null) HapticFeedback.selectionClick();
  }

  void _play(CheckersMove move) {
    final after = _pos.apply(move);
    setState(() {
      _history.add(after);
      _moves.add(move);
      _fly = move;
      _selected = null;
      // A new move brings the board back to the game.
      _reviewPly = null;
    });

    if (_over) {
      _clock?.stop();
      Future.delayed(checkersFlightTime(move), () {
        if (mounted) _finish();
      });
      return;
    }
    // The other side's time starts running.
    _clock?.start(_pos.toMove);
    _save();
    final byMe = !_twoPlayer && move.piece.side == _me;
    if (move.promotes) {
      _say(byMe ? _Moment.playerKing : _Moment.botKing);
    } else if (move.captured.length > 1) {
      _say(byMe ? _Moment.playerDouble : _Moment.botDouble);
    } else if (move.isCapture && _rng.nextBool()) {
      _say(byMe ? _Moment.playerCapture : _Moment.botCapture);
    }
    if (_botsTurn) _botTurn(after: checkersFlightTime(move));
  }

  Future<void> _botTurn({Duration after = Duration.zero}) async {
    final gen = ++_gen;
    setState(() {
      _thinking = true;
      if (_speech == null) _mood = BuddyMood.thinking;
    });
    final started = DateTime.now();
    final move = await findCheckersBotMove(_pos, widget.level);
    // Never answer before the player's move has landed.
    final wait =
        after +
        const Duration(milliseconds: 450) -
        DateTime.now().difference(started);
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
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showResult = true);
    });
  }

  /// Takes back the last move (and, against a bot, its reply).
  void _takeBack() {
    if (_moves.isEmpty || _over) return;
    _gen++;
    setState(() {
      _thinking = false;
      _selected = null;
      _reviewPly = null;
      if (_twoPlayer) {
        _moves.removeLast();
        _history.removeLast();
      } else {
        var removedMine = false;
        while (_moves.isNotEmpty) {
          final m = _moves.removeLast();
          _history.removeLast();
          if (m.piece.side == _me) removedMine = true;
          if (removedMine && _pos.toMove == _me) break;
        }
      }
      _fly = null;
    });
    if (_moves.isEmpty) {
      _clock?.stop();
    } else {
      _clock?.start(_pos.toMove);
    }
    _save();
    ref.read(gameAudioProvider).play(Sfx.chessMove, volume: 0.5);
    if (_botsTurn) _botTurn();
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
        ..add(CheckersPosition.initial());
      _moves.clear();
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
    if (_botsTurn) _botTurn();
  }

  // ── looking back ─────────────────────────────────────────────────────────

  void _stepBack() {
    final ply = _shownPly;
    if (ply <= 0) return;
    final m = _moves[ply - 1];
    HapticFeedback.selectionClick();
    setState(() {
      _reviewPly = ply - 1;
      // Back along the same path; jumped pieces are simply there again.
      _fly = CheckersMove(path: m.path.reversed.toList(), piece: m.piece);
      _selected = null;
    });
  }

  void _stepForward() {
    final ply = _shownPly;
    if (!_reviewing || ply >= _moves.length) return;
    HapticFeedback.selectionClick();
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

  String _sideName(CheckersSide side) =>
      side == CheckersSide.dark ? 'Dark' : 'Light';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    final mySet = profile?['equipped_chess_pieces'] as String? ?? 'classic';
    final botSet = widget.opponent?.chessPieces ?? mySet;
    final hints = ref.watch(gameplaySettingsProvider).moveHints;
    final audio = ref.read(gameAudioProvider);
    final legal = _legal;
    final mustCapture = legal.isNotEmpty && legal.first.isCapture;
    final targets = _selected == null || !(hints || mustCapture)
        ? const <CheckersMove>[]
        : [
            for (final m in legal)
              if (m.from == _selected) m,
          ];
    final winner = _winner;
    final iWon = _over && (_twoPlayer ? winner != null : winner == _me);
    final last = _shownPly == 0 ? null : _moves[_shownPly - 1];
    final levelName = switch (widget.level) {
      BotLevel.easy => 'Easy',
      BotLevel.normal => 'Normal',
      BotLevel.hard => 'Hard',
    };
    final toMove = _pos.toMove;

    final String status;
    if (_over) {
      status = winner == null
          ? 'Draw'
          : _flagged != null && _twoPlayer
          ? '${_sideName(_flagged!)} ran out of time'
          : _flagged == _me
          ? 'Out of time'
          : _twoPlayer
          ? '${_sideName(winner)} wins!'
          : winner == _me
          ? 'You won!'
          : '${widget.opponent!.name} won';
    } else if (_thinking) {
      status = '${widget.opponent!.name} is thinking...';
    } else if (_twoPlayer) {
      status = mustCapture
          ? '${_sideName(toMove)}: you must take a piece'
          : "${_sideName(toMove)}'s move";
    } else {
      status = mustCapture ? 'You must take a piece' : 'Your move';
    }

    final scaffold = Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          [
            _twoPlayer ? 'Checkers · one phone' : 'vs ${widget.opponent!.name}',
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
            onPressed: _over ? null : _resign,
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
            child: Column(
              children: [
                if (_twoPlayer)
                  _SideBar(
                    side: CheckersSide.light,
                    set: mySet,
                    active: !_over && toMove == CheckersSide.light,
                    taken: 12 - _pos.count(CheckersSide.dark),
                    flipped: true,
                    clock: _clock == null
                        ? null
                        : ClockPill(
                            msLeft: () => _clock.msLeft(CheckersSide.light),
                            running:
                                _clock.isRunning(CheckersSide.light) && !_over,
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
                Expanded(
                  child: Center(
                    child: PopCard(
                      borderRadius: 28,
                      glow: mustCapture && _myTurn
                          ? const Color(0xFFFF7A45)
                          : AppColors.accent,
                      padding: const EdgeInsets.all(10),
                      child: CheckersBoard(
                        position: _history[_shownPly],
                        lastMove: last,
                        fly: _fly,
                        selected: _selected,
                        targets: targets,
                        movable: _myTurn
                            ? {for (final m in legal) m.from}
                            : const {},
                        mustCapture: mustCapture,
                        bottom: _twoPlayer ? CheckersSide.dark : _me,
                        // Face to face: Light sits across the table.
                        turnedFor: _twoPlayer ? CheckersSide.light : null,
                        interactive: _myTurn,
                        onSquareTap: _onSquare,
                        darkSet: _twoPlayer || _me == CheckersSide.dark
                            ? mySet
                            : botSet,
                        lightSet: _twoPlayer || _me == CheckersSide.light
                            ? mySet
                            : botSet,
                        gameOver: _over && !_reviewing,
                        winner: winner,
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
                  labels: [for (final m in _moves) m.notation],
                  displayPly: _shownPly,
                  reviewing: _reviewing,
                  onBack: _stepBack,
                  onForward: _stepForward,
                  onJump: _jumpTo,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_twoPlayer)
                  _SideBar(
                    side: CheckersSide.dark,
                    set: mySet,
                    active: !_over && toMove == CheckersSide.dark,
                    taken: 12 - _pos.count(CheckersSide.light),
                    status: status,
                    clock: _clock == null
                        ? null
                        : ClockPill(
                            msLeft: () => _clock.msLeft(CheckersSide.dark),
                            running:
                                _clock.isRunning(CheckersSide.dark) && !_over,
                          ),
                    onResult: _over && !_showResult
                        ? () => setState(() => _showResult = true)
                        : null,
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
                          status,
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w800,
                            color: mustCapture && _myTurn
                                ? const Color(0xFFFF7A45)
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, _) => _gen++,
      child: MusicTrackScope(
        track: MusicTrack.game,
        child: Stack(
          children: [
            scaffold,
            if (_showResult)
              Positioned.fill(
                child: _Result(
                  persona: widget.opponent,
                  title: _over && winner == null
                      ? "It's a draw"
                      : _flagged != null && _twoPlayer
                      ? '${_sideName(_flagged!)} ran out of time'
                      : _flagged == _me
                      ? 'Out of time'
                      : _flagged != null
                      ? '${widget.opponent!.name} ran out of time'
                      : _twoPlayer
                      ? '${_sideName(winner!)} wins!'
                      : iWon
                      ? 'You won!'
                      : _resigned
                      ? 'You resigned'
                      : '${widget.opponent!.name} won',
                  won: iWon,
                  draw: winner == null,
                  onAgain: _newGame,
                  onReview: () => setState(() => _showResult = false),
                  onDone: () => Navigator.of(context).maybePop(),
                ),
              ),
            if (_showResult && iWon)
              const Positioned.fill(
                child: IgnorePointer(child: ConfettiBurst(pieces: 90)),
              ),
          ],
        ),
      ),
    );
  }
}

/// One side's strip in a game on one phone. The top one is turned around
/// so the player across the table can read it.
class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.side,
    required this.set,
    required this.active,
    required this.taken,
    this.flipped = false,
    this.status,
    this.onResult,
    this.clock,
  });

  final CheckersSide side;
  final String set;
  final bool active;
  final int taken;
  final bool flipped;
  final String? status;
  final VoidCallback? onResult;
  final Widget? clock;

  @override
  Widget build(BuildContext context) {
    final name = side == CheckersSide.dark ? 'Dark' : 'Light';
    final bar = PopCard(
      borderRadius: 20,
      tint: active ? AppColors.accentSecondary : null,
      glow: active ? AppColors.accentSecondary : null,
      borderWidth: active ? 1.8 : 1.2,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 30,
            child: CustomPaint(
              painter: _DiscIcon(set: set, side: side),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status != null && active ? status! : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontWeight: FontWeight.w800),
            ),
          ),
          if (taken > 0)
            Text(
              'Took $taken',
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          if (onResult != null)
            TextButton(onPressed: onResult, child: const Text('Result')),
          if (clock != null) ...[const SizedBox(width: 8), clock!],
        ],
      ),
    );
    return flipped ? RotatedBox(quarterTurns: 2, child: bar) : bar;
  }
}

class _DiscIcon extends CustomPainter {
  _DiscIcon({required this.set, required this.side});

  final String set;
  final CheckersSide side;

  @override
  void paint(Canvas canvas, Size size) {
    paintCheckersDisc(
      canvas,
      size.center(Offset.zero).translate(0, -2),
      size.width * 0.4,
      finish: checkersFinish(set, side),
      character: checkersCharacter(set),
    );
  }

  @override
  bool shouldRepaint(covariant _DiscIcon old) =>
      old.set != set || old.side != side;
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

class _Result extends StatelessWidget {
  const _Result({
    required this.persona,
    required this.title,
    required this.won,
    required this.draw,
    required this.onAgain,
    required this.onReview,
    required this.onDone,
  });

  final BotPersona? persona;
  final String title;
  final bool won;
  final bool draw;
  final VoidCallback onAgain;
  final VoidCallback onReview;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = persona;
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
                  Text(title, style: AppTextStyles.display(fontSize: 28)),
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
