import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chess/data/chess_repository.dart';
import '../../../chess/domain/time_control.dart';
import '../../../chess/presentation/controllers/chess_match_controller.dart'
    show chessRepositoryProvider, kFirstMoveWindow;
import '../../domain/checkers_engine.dart';
import '../../../house/presentation/house_waker.dart';
import '../../../../l10n/strings.dart';

const checkersEngine = CheckersEngine();

/// The squares a move visits, from its notation ("11x18x25").
List<int> checkersPathOf(String notation) => [
  for (final s in notation.split(RegExp('[-x]'))) int.parse(s) - 1,
];

/// The full move (piece, jumped pieces, crowning) that follows [path] from
/// [before]: the legal move with that path, or one rebuilt from the path if
/// the log and the board ever disagree.
CheckersMove checkersMoveFrom(CheckersPosition before, List<int> path) {
  for (final m in checkersEngine.legalMoves(before)) {
    if (listEquals(m.path, path)) return m;
  }
  final piece = before.at(path.first) ?? CheckersPiece(before.toMove);
  return CheckersMove(
    path: path,
    piece: piece,
    captured: [
      for (var i = 1; i < path.length; i++)
        if ((rowOf(path[i]) - rowOf(path[i - 1])).abs() == 2)
          squareAt(
            (rowOf(path[i]) + rowOf(path[i - 1])) ~/ 2,
            (colOf(path[i]) + colOf(path[i - 1])) ~/ 2,
          )!,
    ],
  );
}

/// One move of the game as the server logged it.
class CheckersMoveRecord {
  CheckersMoveRecord({
    required this.ply,
    required this.notation,
    required this.codeAfter,
  });

  final int ply;
  final String notation;
  final String codeAfter;

  factory CheckersMoveRecord.fromRow(Map<String, dynamic> row) =>
      CheckersMoveRecord(
        ply: (row['ply'] as num).toInt(),
        notation: row['san'] as String,
        codeAfter: row['fen_after'] as String,
      );

  late final CheckersPosition positionAfter = CheckersPosition.decode(
    codeAfter,
  );
  late final List<int> path = checkersPathOf(notation);
}

/// How a game ended, as far as this device can tell.
class CheckersOutcome {
  const CheckersOutcome({
    required this.result,
    required this.winnerId,
    required this.settled,
  });

  /// 'win', 'draw', 'resignation', 'timeout', 'aborted'.
  final String? result;
  final String? winnerId;
  final bool settled;
}

class CheckersMatchState {
  CheckersMatchState({
    required this.position,
    this.matchRow,
    this.mySide,
    this.selected,
    this.targets = const [],
    this.lastMove,
    this.fly,
    this.loading = true,
    this.error,
    this.history = const [],
    this.reviewPly,
  });

  final CheckersPosition position;
  final Map<String, dynamic>? matchRow;

  /// Dark is player_white (it moves first).
  final CheckersSide? mySide;
  final int? selected;
  final List<CheckersMove> targets;
  final CheckersMove? lastMove;

  /// The move the board should animate (a new object each time).
  final CheckersMove? fly;
  final bool loading;
  final String? error;
  final List<CheckersMoveRecord> history;
  final int? reviewPly;

  String get status => matchRow?['status'] as String? ?? 'pending';
  int get stake => (matchRow?['stake'] as num?)?.toInt() ?? 0;
  bool get isActive => status == 'active';
  bool get reviewing => reviewPly != null;
  bool get isMyTurn =>
      mySide != null &&
      mySide == position.toMove &&
      isActive &&
      localOutcome == null;

  late final CheckersStatus gameStatus = checkersEngine.status(position);
  late final List<CheckersMove> legalMoves = checkersEngine.legalMoves(
    position,
  );
  bool get mustCapture => legalMoves.isNotEmpty && legalMoves.first.isCapture;

  String? playerOf(CheckersSide side) =>
      matchRow?[side == CheckersSide.dark ? 'player_white' : 'player_black']
          as String?;

  int get displayPly => reviewPly ?? history.length;

  CheckersPosition get displayPosition {
    final ply = reviewPly;
    if (ply == null) return position;
    return _positionAt(ply);
  }

  CheckersPosition _positionAt(int ply) =>
      ply == 0 ? CheckersPosition.initial() : history[ply - 1].positionAfter;

  CheckersMove? get displayLastMove {
    final ply = reviewPly;
    if (ply == null) return lastMove;
    if (ply == 0) return null;
    return checkersMoveFrom(_positionAt(ply - 1), history[ply - 1].path);
  }

  late final CheckersOutcome? localOutcome = _computeLocalOutcome();

  CheckersOutcome? _computeLocalOutcome() {
    if (!isActive || matchRow == null) return null;
    return switch (gameStatus) {
      CheckersStatus.darkWins => CheckersOutcome(
        result: 'win',
        winnerId: playerOf(CheckersSide.dark),
        settled: false,
      ),
      CheckersStatus.lightWins => CheckersOutcome(
        result: 'win',
        winnerId: playerOf(CheckersSide.light),
        settled: false,
      ),
      CheckersStatus.draw => const CheckersOutcome(
        result: 'draw',
        winnerId: null,
        settled: false,
      ),
      CheckersStatus.ongoing => null,
    };
  }

  CheckersOutcome? get outcome {
    if (matchRow == null || status == 'pending') return null;
    if (!isActive) {
      return CheckersOutcome(
        result: matchRow!['result'] as String?,
        winnerId: matchRow!['winner_id'] as String?,
        settled: true,
      );
    }
    return localOutcome;
  }

  bool get isOver => outcome != null;

  // ── clocks (the same columns as chess: white is dark) ────────────────────

  TimeControl get timeControl => TimeControl.fromRow(matchRow);
  bool get timed => matchRow?['white_ms'] != null;
  int get plyCount => (matchRow?['ply_count'] as num?)?.toInt() ?? 0;
  CheckersSide get onClock =>
      plyCount.isEven ? CheckersSide.dark : CheckersSide.light;

  DateTime get turnStartedAt {
    final now = DateTime.now();
    final raw = matchRow?['turn_started_at'] as String?;
    final at = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (at == null || at.isAfter(now)) return now;
    return at;
  }

  int? msLeft(CheckersSide side) {
    final row = matchRow;
    if (row == null || !timed) return null;
    if (row['result'] == 'timeout' && onClock == side) return 0;
    var ms = (row[side == CheckersSide.dark ? 'white_ms' : 'black_ms'] as num)
        .toInt();
    if (isActive && localOutcome == null && plyCount >= 2 && onClock == side) {
      ms -= DateTime.now().difference(turnStartedAt).inMilliseconds;
    }
    return ms < 0 ? 0 : ms;
  }

  int? get firstMoveMsLeft {
    if (!timed || !isActive || plyCount >= 2) return null;
    final left =
        kFirstMoveWindow.inMilliseconds -
        DateTime.now().difference(turnStartedAt).inMilliseconds;
    return left < 0 ? 0 : left;
  }

  CheckersMatchState copyWith({
    CheckersPosition? position,
    Map<String, dynamic>? matchRow,
    CheckersSide? mySide,
    int? selected,
    bool clearSelected = false,
    List<CheckersMove>? targets,
    CheckersMove? lastMove,
    CheckersMove? fly,
    bool clearFly = false,
    bool? loading,
    String? error,
    List<CheckersMoveRecord>? history,
    int? reviewPly,
    bool clearReview = false,
  }) {
    return CheckersMatchState(
      position: position ?? this.position,
      matchRow: matchRow ?? this.matchRow,
      mySide: mySide ?? this.mySide,
      selected: clearSelected ? null : (selected ?? this.selected),
      targets: targets ?? this.targets,
      lastMove: lastMove ?? this.lastMove,
      fly: clearFly ? null : (fly ?? this.fly),
      loading: loading ?? this.loading,
      error: error,
      history: history ?? this.history,
      reviewPly: clearReview ? null : (reviewPly ?? this.reviewPly),
    );
  }
}

/// Drives one live checkers match, the same way chess's controller does:
/// the `matches` row (status, clocks, players) and the `match_moves` log
/// feed it, the board follows whichever is further along, and our own
/// moves show at once and roll back if the server refuses them.
class CheckersMatchController extends StateNotifier<CheckersMatchState> {
  CheckersMatchController(this._repository, this._matchId, this._myUserId)
    : super(CheckersMatchState(position: CheckersPosition.initial())) {
    _matchSub = _repository.watchMatch(_matchId).listen(_onMatchRow);
    _movesSub = _repository.watchMoves(_matchId).listen(_onMoves);
    _clock = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => _checkFlag(),
    );
    // A house player's turn: woken now and then, in case one stalled.
    _presence = Timer.periodic(const Duration(seconds: 8), (_) {
      _touch();
      unawaited(_house.maybeWake(_row, again: true));
    });
  }

  final ChessRepository _repository;
  final String _matchId;
  final String _myUserId;

  StreamSubscription<Map<String, dynamic>?>? _matchSub;
  StreamSubscription<List<Map<String, dynamic>>>? _movesSub;
  bool _hasReportedTermination = false;
  bool _movesPrimed = false;
  int _lastSeenPly = 0;
  Timer? _clock;
  Timer? _presence;
  late final _house = HouseWaker(_repository, _matchId);
  DateTime _lastClaim = DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, dynamic>? _row;
  List<CheckersMoveRecord> _serverMoves = const [];
  CheckersMoveRecord? _pending;
  String? _positionCode;

  void _touch() {
    if (!mounted || state.matchRow == null || !state.isActive) return;
    _repository.touchMatch(_matchId).catchError((_) {});
  }

  void _checkFlag() {
    if (!mounted || !state.isActive) return;
    final now = DateTime.now();
    if (state.localOutcome != null) {
      if (!_hasReportedTermination ||
          now.difference(_lastClaim) < const Duration(seconds: 4)) {
        return;
      }
      _lastClaim = now;
      _repository.claimTimeout(_matchId).catchError((_) => null);
      return;
    }
    if (!state.timed) return;
    final flagged =
        state.firstMoveMsLeft == 0 || state.msLeft(state.onClock) == 0;
    if (!flagged) return;
    if (now.difference(_lastClaim) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastClaim = now;
    _repository.claimTimeout(_matchId).catchError((_) => null);
  }

  void _onMatchRow(Map<String, dynamic>? row) {
    if (row == null) {
      state = state.copyWith(
        loading: false,
        error: strings.checkersMatchMatchNotFound,
      );
      return;
    }
    final firstRow = _row == null;
    _row = row;
    _sync();
    unawaited(_house.maybeWake(row));
    if (firstRow) _touch();
  }

  void _onMoves(List<Map<String, dynamic>> rows) {
    _serverMoves = rows.map(CheckersMoveRecord.fromRow).toList()
      ..sort((a, b) => a.ply.compareTo(b.ply));
    if (_pending != null && _serverMoves.length >= _pending!.ply) {
      _pending = null;
    }
    _sync();
  }

  void _sync() {
    final row = _row;
    if (row == null) return;

    final history = [
      ..._serverMoves,
      if (_pending != null && _pending!.ply > _serverMoves.length) _pending!,
    ];

    final rowPly = (row['ply_count'] as num?)?.toInt() ?? 0;
    final code = history.length > rowPly && history.isNotEmpty
        ? history.last.codeAfter
        : row['board_fen'] as String;
    final moved = code != _positionCode;
    final position = moved ? CheckersPosition.decode(code) : state.position;
    _positionCode = code;

    final mySide = row['player_white'] == _myUserId
        ? CheckersSide.dark
        : (row['player_black'] == _myUserId ? CheckersSide.light : null);

    CheckersMove? lastMove = state.lastMove;
    CheckersMove? fly;
    var leaveReview = false;
    if (history.isNotEmpty) {
      final newest = history.last;
      final before = history.length >= 2
          ? history[history.length - 2].positionAfter
          : CheckersPosition.initial();
      if (!_movesPrimed) {
        _movesPrimed = true;
        _lastSeenPly = newest.ply;
        lastMove = checkersMoveFrom(before, newest.path);
      } else if (newest.ply > _lastSeenPly) {
        _lastSeenPly = newest.ply;
        lastMove = checkersMoveFrom(before, newest.path);
        fly = lastMove;
        leaveReview = state.reviewing;
      }
    } else if (!_movesPrimed && _serverMoves.isEmpty) {
      _movesPrimed = rowPly == 0;
    }

    final statusChanged = row['status'] != state.matchRow?['status'];
    state = state.copyWith(
      position: position,
      matchRow: row,
      mySide: mySide,
      loading: false,
      history: history,
      lastMove: lastMove,
      fly: fly,
      clearReview: leaveReview,
      clearSelected: moved || statusChanged,
      targets: moved || statusChanged ? const [] : state.targets,
    );

    if (row['status'] == 'active') _maybeReportTermination(position, row);
  }

  void _maybeReportTermination(
    CheckersPosition position,
    Map<String, dynamic> row,
  ) {
    final status = checkersEngine.status(position);
    if (status == CheckersStatus.ongoing) {
      _hasReportedTermination = false;
      return;
    }
    if (_hasReportedTermination) return;
    _hasReportedTermination = true;

    final winnerId = switch (status) {
      CheckersStatus.darkWins => row['player_white'] as String?,
      CheckersStatus.lightWins => row['player_black'] as String?,
      _ => null,
    };
    _repository
        .reportMatchResult(
          matchId: _matchId,
          winnerId: winnerId,
          result: winnerId == null ? 'draw' : 'win',
        )
        .catchError((Object _) {
          _hasReportedTermination = false;
        });
  }

  // ── looking back ─────────────────────────────────────────────────────────

  void stepBack() {
    final ply = state.displayPly;
    if (ply <= 0) return;
    final undo = state.history[ply - 1];
    final before = ply == 1
        ? CheckersPosition.initial()
        : state.history[ply - 2].positionAfter;
    final move = checkersMoveFrom(before, undo.path);
    state = state.copyWith(
      reviewPly: ply - 1,
      // Back along the same path; the jumped pieces are simply there again.
      fly: CheckersMove(path: move.path.reversed.toList(), piece: move.piece),
      clearSelected: true,
      targets: const [],
    );
  }

  void stepForward() {
    final ply = state.displayPly;
    if (!state.reviewing || ply >= state.history.length) return;
    final before = ply == 0
        ? CheckersPosition.initial()
        : state.history[ply - 1].positionAfter;
    final next = state.history[ply];
    state = state.copyWith(
      reviewPly: ply + 1 == state.history.length ? null : ply + 1,
      clearReview: ply + 1 == state.history.length,
      fly: checkersMoveFrom(before, next.path),
    );
  }

  void jumpTo(int ply) {
    if (ply < 0 || ply > state.history.length || ply == state.displayPly) {
      return;
    }
    state = state.copyWith(
      reviewPly: ply == state.history.length ? null : ply,
      clearReview: ply == state.history.length,
      clearFly: true,
      clearSelected: true,
      targets: const [],
    );
  }

  void goLive() => jumpTo(state.history.length);

  // ── playing ──────────────────────────────────────────────────────────────

  void selectSquare(int square) {
    if (!state.isMyTurn || state.reviewing) return;
    final legal = state.legalMoves;

    final chosen = [
      for (final m in state.targets)
        if (m.to == square) m,
    ];
    if (chosen.isNotEmpty) {
      // Two jump routes can end on the same square: take the bigger one.
      chosen.sort((a, b) => b.captured.length.compareTo(a.captured.length));
      _commitMove(chosen.first);
      return;
    }

    final mine = [
      for (final m in legal)
        if (m.from == square) m,
    ];
    if (mine.isEmpty || square == state.selected) {
      state = state.copyWith(clearSelected: true, targets: const []);
      return;
    }
    state = state.copyWith(selected: square, targets: mine);
  }

  void _commitMove(CheckersMove move) {
    final after = state.position.apply(move);
    final code = after.encode();
    final ply = state.history.length + 1;

    final row = state.matchRow;
    Map<String, dynamic>? optimisticRow;
    if (row != null && state.timed) {
      final mover = state.onClock;
      final key = mover == CheckersSide.dark ? 'white_ms' : 'black_ms';
      var left = state.msLeft(mover) ?? 0;
      if (state.plyCount >= 2) {
        left += ((row['clock_increment_ms'] as num?)?.toInt() ?? 0);
      }
      optimisticRow = {
        ...row,
        key: left,
        'ply_count': state.plyCount + 1,
        'turn_started_at': DateTime.now().toUtc().toIso8601String(),
      };
      _row = optimisticRow;
    }

    _pending = CheckersMoveRecord(
      ply: ply,
      notation: move.notation,
      codeAfter: code,
    );
    _lastSeenPly = ply;
    _positionCode = code;

    state = state.copyWith(
      position: after,
      matchRow: optimisticRow,
      clearSelected: true,
      targets: const [],
      lastMove: move,
      fly: move,
      history: [...state.history, _pending!],
    );

    _repository
        .recordMove(
          matchId: _matchId,
          from: '${move.from + 1}',
          to: '${move.to + 1}',
          promotion: move.promotes ? 'k' : null,
          san: move.notation,
          fenAfter: code,
        )
        .catchError((Object _) {
          if (!mounted) return;
          _pending = null;
          _lastSeenPly = _serverMoves.isEmpty ? 0 : _serverMoves.last.ply;
          _repository.watchMatch(_matchId).first.then((fresh) {
            if (fresh != null) _row = fresh;
            if (mounted) _sync();
          });
          state = state.copyWith(error: strings.checkersMatchThatMoveDidnTGo);
        });
  }

  Future<void> resign() => _repository.resignMatch(_matchId);

  @override
  void dispose() {
    _clock?.cancel();
    _presence?.cancel();
    _matchSub?.cancel();
    _movesSub?.cancel();
    super.dispose();
  }
}

final checkersMatchControllerProvider = StateNotifierProvider.autoDispose
    .family<CheckersMatchController, CheckersMatchState, String>((
      ref,
      matchId,
    ) {
      final repository = ref.watch(chessRepositoryProvider);
      final userId = ref.watch(currentUserProvider)?.id ?? '';
      return CheckersMatchController(repository, matchId, userId);
    });
