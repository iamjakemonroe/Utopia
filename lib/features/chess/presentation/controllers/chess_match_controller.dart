import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/chess_repository.dart';
import '../../domain/chess_engine.dart';
import '../../domain/chess_move.dart';
import '../../domain/chess_position.dart';
import '../../domain/chess_types.dart';
import '../../domain/time_control.dart';
import '../../../house/presentation/house_waker.dart';
import '../../../../l10n/strings.dart';

final chessRepositoryProvider = Provider<ChessRepository>((ref) {
  return ChessRepository(ref.watch(supabaseClientProvider));
});

/// Invites addressed to the current user, for the home-screen "you've been
/// challenged" banner.
final incomingInvitesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
      return ref.watch(chessRepositoryProvider).watchIncomingInvites(userId);
    });

/// Invites the current user sent, watched so the sender's client can jump
/// straight into the match the moment the other side accepts.
final outgoingInvitesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
      return ref.watch(chessRepositoryProvider).watchOutgoingInvites(userId);
    });

const chessEngine = ChessEngine();

/// How long each side has for its first move before the game is called off
/// (matches _chess_check_clock on the server).
const kFirstMoveWindow = Duration(seconds: 30);

/// One move of the game as the server logged it.
class ChessMoveRecord {
  ChessMoveRecord({
    required this.ply,
    required this.from,
    required this.to,
    required this.san,
    required this.fenAfter,
  });

  final int ply;
  final Square from;
  final Square to;
  final String san;
  final String fenAfter;

  factory ChessMoveRecord.fromRow(Map<String, dynamic> row) => ChessMoveRecord(
    ply: (row['ply'] as num).toInt(),
    from: Square.fromAlgebraic(row['from_square'] as String),
    to: Square.fromAlgebraic(row['to_square'] as String),
    san: row['san'] as String,
    fenAfter: row['fen_after'] as String,
  );

  /// Parsed once, so stepping through the game doesn't re-read it.
  late final ChessPosition positionAfter = ChessPosition.fromFen(fenAfter);

  /// Enough of the move to highlight and animate it: the piece now on
  /// [to] is the one that moved there (promotions included).
  ChessMove toMove([ChessPosition? after]) {
    final position = after ?? positionAfter;
    final piece =
        position.at(to) ?? const ChessPiece(PieceType.pawn, PieceColor.white);
    return ChessMove(from: from, to: to, piece: piece);
  }
}

/// How a game ended, as far as this device can tell.
class ChessOutcome {
  const ChessOutcome({
    required this.result,
    required this.winnerId,
    required this.settled,
  });

  /// 'checkmate', 'stalemate', 'draw', 'resignation', 'timeout', 'aborted'.
  final String? result;
  final String? winnerId;

  /// False while the board shows the game is over but the server hasn't
  /// confirmed it yet (prizes are paid on confirmation).
  final bool settled;
}

class ChessMatchState {
  ChessMatchState({
    required this.position,
    this.matchRow,
    this.myColor,
    this.selectedSquare,
    this.legalDestinations = const [],
    this.lastMove,
    this.fly,
    this.pendingPromotion,
    this.loading = true,
    this.error,
    this.lastSan,
    this.history = const [],
    this.reviewPly,
  });

  /// The live position.
  final ChessPosition position;
  final Map<String, dynamic>? matchRow;
  final PieceColor? myColor;
  final Square? selectedSquare;
  final List<ChessMove> legalDestinations;

  /// The latest move, highlighted on the live board.
  final ChessMove? lastMove;

  /// The move the board should animate. A new object means "animate this";
  /// stepping back through the history sends the move in reverse.
  final ChessMove? fly;
  final ChessMove? pendingPromotion;
  final bool loading;
  final String? error;

  /// The latest move in algebraic notation, for its sound ("x" capture,
  /// "+" check).
  final String? lastSan;

  /// Every move so far, oldest first.
  final List<ChessMoveRecord> history;

  /// While looking back through the game: how many moves in the board
  /// shows (0 is the starting position). Null when following live.
  final int? reviewPly;

  String get status => matchRow?['status'] as String? ?? 'pending';
  int get stake => (matchRow?['stake'] as num?)?.toInt() ?? 0;
  String? get winnerId => matchRow?['winner_id'] as String?;
  String? get result => matchRow?['result'] as String?;
  bool get isActive => status == 'active';
  bool get reviewing => reviewPly != null;
  bool get isMyTurn =>
      myColor != null &&
      myColor == position.sideToMove &&
      isActive &&
      localOutcome == null;

  /// Worked out once per state: the clocks ask on every frame, and it means
  /// generating every legal move.
  late final GameStatus gameStatus = chessEngine.status(position);

  /// Moves shown on the board right now.
  int get displayPly => reviewPly ?? history.length;

  ChessPosition get displayPosition {
    final ply = reviewPly;
    if (ply == null) return position;
    if (ply == 0) return _start;
    return history[ply - 1].positionAfter;
  }

  static final _start = ChessPosition.initial();

  ChessMove? get displayLastMove {
    final ply = reviewPly;
    if (ply == null) return lastMove;
    if (ply == 0) return null;
    return history[ply - 1].toMove(displayPosition);
  }

  /// The game is over on the board (mate, stalemate, a dead draw) but the
  /// server hasn't settled it yet.
  ChessOutcome? get localOutcome => _localOutcome;

  late final ChessOutcome? _localOutcome = _computeLocalOutcome();

  ChessOutcome? _computeLocalOutcome() {
    if (!isActive || matchRow == null) return null;
    return switch (gameStatus) {
      GameStatus.checkmate => ChessOutcome(
        result: 'checkmate',
        // The side to move is the side that's mated.
        winnerId: position.sideToMove == PieceColor.white
            ? matchRow!['player_black'] as String?
            : matchRow!['player_white'] as String?,
        settled: false,
      ),
      GameStatus.stalemate => const ChessOutcome(
        result: 'stalemate',
        winnerId: null,
        settled: false,
      ),
      GameStatus.draw => const ChessOutcome(
        result: 'draw',
        winnerId: null,
        settled: false,
      ),
      _ => null,
    };
  }

  /// How the game ended, settled or not; null while it's still on.
  ChessOutcome? get outcome {
    if (matchRow == null || status == 'pending') return null;
    if (!isActive) {
      return ChessOutcome(result: result, winnerId: winnerId, settled: true);
    }
    return localOutcome;
  }

  bool get isOver => outcome != null;

  // ── clocks ───────────────────────────────────────────────────────────────

  TimeControl get timeControl => TimeControl.fromRow(matchRow);

  /// Games from before clocks existed have none.
  bool get timed => matchRow?['white_ms'] != null;

  int get plyCount => (matchRow?['ply_count'] as num?)?.toInt() ?? 0;

  /// Whose clock is running, going by the server's move count.
  PieceColor get onClock =>
      plyCount.isEven ? PieceColor.white : PieceColor.black;

  /// When the side on the clock started thinking. Never in the future, in
  /// case this device's clock runs a little behind the server's.
  DateTime get turnStartedAt {
    final now = DateTime.now();
    final raw = matchRow?['turn_started_at'] as String?;
    final at = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (at == null || at.isAfter(now)) return now;
    return at;
  }

  /// Time left for [color] right now, or null for an untimed game.
  int? msLeft(PieceColor color) {
    final row = matchRow;
    if (row == null || !timed) return null;
    // The flag fell: the server ends the game without touching the clock.
    if (result == 'timeout' && onClock == color) return 0;
    var ms = (row[color == PieceColor.white ? 'white_ms' : 'black_ms'] as num)
        .toInt();
    if (isActive && localOutcome == null && plyCount >= 2 && onClock == color) {
      ms -= DateTime.now().difference(turnStartedAt).inMilliseconds;
    }
    return ms < 0 ? 0 : ms;
  }

  /// While a side still owes its first move: the time left to make it.
  int? get firstMoveMsLeft {
    if (!timed || !isActive || plyCount >= 2) return null;
    final left =
        kFirstMoveWindow.inMilliseconds -
        DateTime.now().difference(turnStartedAt).inMilliseconds;
    return left < 0 ? 0 : left;
  }

  ChessMatchState copyWith({
    ChessPosition? position,
    Map<String, dynamic>? matchRow,
    PieceColor? myColor,
    Square? selectedSquare,
    bool clearSelectedSquare = false,
    List<ChessMove>? legalDestinations,
    ChessMove? lastMove,
    ChessMove? fly,
    bool clearFly = false,
    ChessMove? pendingPromotion,
    bool clearPendingPromotion = false,
    bool? loading,
    String? error,
    String? lastSan,
    List<ChessMoveRecord>? history,
    int? reviewPly,
    bool clearReview = false,
  }) {
    return ChessMatchState(
      position: position ?? this.position,
      matchRow: matchRow ?? this.matchRow,
      myColor: myColor ?? this.myColor,
      selectedSquare: clearSelectedSquare
          ? null
          : (selectedSquare ?? this.selectedSquare),
      legalDestinations: legalDestinations ?? this.legalDestinations,
      lastMove: lastMove ?? this.lastMove,
      fly: clearFly ? null : (fly ?? this.fly),
      pendingPromotion: clearPendingPromotion
          ? null
          : (pendingPromotion ?? this.pendingPromotion),
      loading: loading ?? this.loading,
      error: error,
      lastSan: lastSan ?? this.lastSan,
      history: history ?? this.history,
      reviewPly: clearReview ? null : (reviewPly ?? this.reviewPly),
    );
  }
}

/// Drives a single live chess match. Two realtime streams feed it: the
/// `matches` row (status, clocks, players) and the `match_moves` log (the
/// moves themselves, each with the position after it). The board follows
/// whichever of the two is further along, so the opponent's move shows the
/// moment its log entry lands. Local moves are applied optimistically and
/// rolled back if the server refuses them.
class ChessMatchController extends StateNotifier<ChessMatchState> {
  ChessMatchController(this._repository, this._matchId, this._myUserId)
    : super(ChessMatchState(position: ChessPosition.initial())) {
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
  List<ChessMoveRecord> _serverMoves = const [];

  /// A move of ours the server hasn't logged yet.
  ChessMoveRecord? _pending;
  String? _positionFen;

  void _touch() {
    if (!mounted || state.matchRow == null || !state.isActive) return;
    _repository.touchMatch(_matchId).catchError((_) {});
  }

  /// When a clock hits zero, ask the server to end the game. Either player
  /// can; the server checks the time itself. Once the board shows the game
  /// is over, keep asking every few seconds: if the other player has gone,
  /// the server settles it on our report alone.
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
        error: strings.chessMatchMatchNotFound,
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
    _serverMoves = rows.map(ChessMoveRecord.fromRow).toList()
      ..sort((a, b) => a.ply.compareTo(b.ply));
    if (_pending != null && _serverMoves.length >= _pending!.ply) {
      _pending = null;
    }
    _sync();
  }

  /// Rebuilds the state from the latest row and move log.
  void _sync() {
    final row = _row;
    if (row == null) return;

    final history = [
      ..._serverMoves,
      if (_pending != null && _pending!.ply > _serverMoves.length) _pending!,
    ];

    // The board follows whichever source is further along.
    final rowPly = (row['ply_count'] as num?)?.toInt() ?? 0;
    final fen = history.length > rowPly && history.isNotEmpty
        ? history.last.fenAfter
        : row['board_fen'] as String;
    final moved = fen != _positionFen;
    final position = moved ? ChessPosition.fromFen(fen) : state.position;
    _positionFen = fen;

    final myColor = row['player_white'] == _myUserId
        ? PieceColor.white
        : (row['player_black'] == _myUserId ? PieceColor.black : null);

    // A move we haven't shown yet: highlight it, animate it, and (unless
    // we're looking back through the game) jump to it.
    ChessMove? lastMove = state.lastMove;
    ChessMove? fly;
    String? san;
    var leaveReview = false;
    if (history.isNotEmpty) {
      final newest = history.last;
      if (!_movesPrimed) {
        _movesPrimed = true;
        _lastSeenPly = newest.ply;
        lastMove = newest.toMove(position);
        san = newest.san;
      } else if (newest.ply > _lastSeenPly) {
        _lastSeenPly = newest.ply;
        lastMove = newest.toMove(position);
        fly = lastMove;
        san = newest.san;
        // The opponent moved: come back to the live board to answer it.
        leaveReview = state.reviewing;
      }
    } else if (!_movesPrimed && _serverMoves.isEmpty) {
      _movesPrimed = rowPly == 0;
    }

    final statusChanged = row['status'] != state.matchRow?['status'];
    state = state.copyWith(
      position: position,
      matchRow: row,
      myColor: myColor,
      loading: false,
      history: history,
      lastMove: lastMove,
      fly: fly,
      lastSan: san,
      clearReview: leaveReview,
      clearSelectedSquare: moved || statusChanged,
      legalDestinations: moved || statusChanged
          ? const []
          : state.legalDestinations,
    );

    if (row['status'] == 'active') _maybeReportTermination(position, row);
  }

  void _maybeReportTermination(
    ChessPosition position,
    Map<String, dynamic> row,
  ) {
    final gameStatus = chessEngine.status(position);
    if (gameStatus != GameStatus.checkmate &&
        gameStatus != GameStatus.stalemate &&
        gameStatus != GameStatus.draw) {
      _hasReportedTermination = false;
      return;
    }
    if (_hasReportedTermination) return;
    _hasReportedTermination = true;

    String? winnerId;
    String result;
    if (gameStatus == GameStatus.checkmate) {
      // The side to move is the side in checkmate, i.e. the loser.
      final winnerColor = position.sideToMove.opponent;
      winnerId = winnerColor == PieceColor.white
          ? row['player_white'] as String?
          : row['player_black'] as String?;
      result = 'checkmate';
    } else {
      result = gameStatus == GameStatus.stalemate ? 'stalemate' : 'draw';
    }

    _repository
        .reportMatchResult(
          matchId: _matchId,
          winnerId: winnerId,
          result: result,
        )
        .catchError((Object _) {
          // Try again on the next update.
          _hasReportedTermination = false;
        });
  }

  // ── looking back ─────────────────────────────────────────────────────────

  void stepBack() {
    final ply = state.displayPly;
    if (ply <= 0) return;
    final undo = state.history[ply - 1];
    final before = ply == 1
        ? ChessPosition.initial()
        : state.history[ply - 2].positionAfter;
    final piece = before.at(undo.from) ?? undo.toMove().piece;
    state = state.copyWith(
      reviewPly: ply - 1,
      fly: ChessMove(from: undo.to, to: undo.from, piece: piece),
      clearSelectedSquare: true,
      legalDestinations: const [],
    );
  }

  void stepForward() {
    final ply = state.displayPly;
    if (!state.reviewing || ply >= state.history.length) return;
    final next = state.history[ply];
    state = state.copyWith(
      reviewPly: ply + 1 == state.history.length ? null : ply + 1,
      clearReview: ply + 1 == state.history.length,
      fly: next.toMove(),
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
      clearSelectedSquare: true,
      legalDestinations: const [],
    );
  }

  void goLive() => jumpTo(state.history.length);

  // ── playing ──────────────────────────────────────────────────────────────

  void selectSquare(Square square) {
    if (!state.isMyTurn || state.reviewing || state.pendingPromotion != null) {
      return;
    }

    final piece = state.position.at(square);

    if (state.selectedSquare == null) {
      if (piece == null || piece.color != state.myColor) return;
      final legal = chessEngine
          .legalMoves(state.position)
          .where((m) => m.from == square)
          .toList();
      state = state.copyWith(selectedSquare: square, legalDestinations: legal);
      return;
    }

    if (square == state.selectedSquare) {
      state = state.copyWith(
        clearSelectedSquare: true,
        legalDestinations: const [],
      );
      return;
    }

    final candidate = state.legalDestinations
        .where((m) => m.to == square)
        .toList();
    if (candidate.isEmpty) {
      // Tapped a different square of our own — reselect instead of no-op.
      if (piece != null && piece.color == state.myColor) {
        final legal = chessEngine
            .legalMoves(state.position)
            .where((m) => m.from == square)
            .toList();
        state = state.copyWith(
          selectedSquare: square,
          legalDestinations: legal,
        );
      } else {
        state = state.copyWith(
          clearSelectedSquare: true,
          legalDestinations: const [],
        );
      }
      return;
    }

    if (candidate.length > 1) {
      // All candidates share from/to and differ only by promotion choice.
      state = state.copyWith(
        pendingPromotion: candidate.first,
        clearSelectedSquare: true,
        legalDestinations: const [],
      );
      return;
    }

    _commitMove(candidate.first);
  }

  void choosePromotion(PieceType type) {
    final pending = state.pendingPromotion;
    if (pending == null) return;
    _commitMove(
      ChessMove(
        from: pending.from,
        to: pending.to,
        piece: pending.piece,
        captured: pending.captured,
        promotion: type,
        flag: MoveFlag.promotion,
      ),
    );
  }

  void _commitMove(ChessMove move) {
    final beforePosition = state.position;
    final san = chessEngine.toSan(beforePosition, move);
    final afterPosition = beforePosition.applyMove(move);
    final fenAfter = afterPosition.toFen();
    final ply = state.history.length + 1;

    // Optimistic: the move shows at once and the clocks switch over the
    // way the server will. The next row and log entry confirm it.
    final row = state.matchRow;
    Map<String, dynamic>? optimisticRow;
    if (row != null && state.timed) {
      final mover = state.onClock;
      final key = mover == PieceColor.white ? 'white_ms' : 'black_ms';
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

    _pending = ChessMoveRecord(
      ply: ply,
      from: move.from,
      to: move.to,
      san: san,
      fenAfter: fenAfter,
    );
    _lastSeenPly = ply;
    _positionFen = fenAfter;

    state = state.copyWith(
      position: afterPosition,
      matchRow: optimisticRow,
      clearSelectedSquare: true,
      legalDestinations: const [],
      clearPendingPromotion: true,
      lastMove: move,
      fly: move,
      lastSan: san,
      history: [...state.history, _pending!],
    );

    _repository
        .recordMove(
          matchId: _matchId,
          from: move.from.algebraic,
          to: move.to.algebraic,
          promotion: move.promotion?.letter.toLowerCase(),
          san: san,
          fenAfter: fenAfter,
        )
        .catchError((Object _) {
          if (!mounted) return;
          // Refused (time ran out, or we were out of sync): back to the
          // server's board.
          _pending = null;
          _lastSeenPly = _serverMoves.isEmpty ? 0 : _serverMoves.last.ply;
          _repository.watchMatch(_matchId).first.then((fresh) {
            if (fresh != null) _row = fresh;
            if (mounted) _sync();
          });
          state = state.copyWith(error: strings.chessMatchThatMoveDidnTGo);
        });
  }

  void cancelPromotion() {
    state = state.copyWith(clearPendingPromotion: true);
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

final chessMatchControllerProvider = StateNotifierProvider.autoDispose
    .family<ChessMatchController, ChessMatchState, String>((ref, matchId) {
      final repository = ref.watch(chessRepositoryProvider);
      final userId = ref.watch(currentUserProvider)?.id ?? '';
      return ChessMatchController(repository, matchId, userId);
    });
