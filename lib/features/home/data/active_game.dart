import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/game_card_art.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../chess/data/chess_repository.dart';
import '../../chess/presentation/controllers/chess_match_controller.dart';
import '../../ludo/data/ludo_repository.dart';
import 'offline_game.dart';
import '../../ludo/presentation/controllers/ludo_match_controller.dart';

/// A game the player is still in.
class ActiveGame {
  const ActiveGame({required this.kind, required this.matchId, this.offline});

  final GameKind kind;
  final String matchId;

  /// A game on this phone (against bots), rather than online.
  final OfflineGame? offline;

  String get route =>
      offline?.resumeRoute ??
      switch (kind) {
        GameKind.chess => '/chess/$matchId',
        GameKind.checkers => '/checkers/$matchId',
        GameKind.ludo => '/ludo/$matchId',
        GameKind.doodle => '/doodle-game/$matchId',
      };
}

/// The game the player left without finishing (the app closed, or they
/// backed out), so they can be brought straight back to it. Chess and
/// checkers first: their clocks keep running.
final activeGameProvider = FutureProvider.autoDispose<ActiveGame?>((ref) {
  final me = ref.watch(currentUserProvider)?.id;
  if (me == null) return null;
  return findActiveGame(
    ref.read(chessRepositoryProvider),
    ref.read(ludoRepositoryProvider),
    me,
    offline: ref.read(offlineGameStoreProvider),
  );
});

Future<ActiveGame?> findActiveGame(
  ChessRepository chess,
  LudoRepository ludo,
  String userId, {
  OfflineGameStore? offline,
}) async {
  final board = await chess.activeMatch(userId).catchError((Object _) => null);
  if (board != null) {
    final (id, game) = board;
    return ActiveGame(
      kind: game == 'checkers' ? GameKind.checkers : GameKind.chess,
      matchId: id,
    );
  }
  final ludoId = await ludo
      .activeMatchId(userId)
      .catchError((Object _) => null);
  if (ludoId != null) return ActiveGame(kind: GameKind.ludo, matchId: ludoId);
  // Then a game against bots on this phone, if the app closed mid-game.
  final saved = offline?.load();
  if (saved == null) return null;
  if (saved.kind == GameKind.ludo) restoreLocalLudo(saved.route, saved.data);
  return ActiveGame(kind: saved.kind, matchId: '', offline: saved);
}
