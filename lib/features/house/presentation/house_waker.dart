import '../../chess/data/chess_repository.dart';

/// Wakes a game's house player on their turn (the house-move function
/// plays it after a person's thinking time). Called on every update of the
/// match and every few seconds: once a turn, unless the server didn't have
/// it as theirs yet (a move of ours still on its way), and again in case
/// something stalled.
class HouseWaker {
  HouseWaker(this._repository, this._matchId);

  final ChessRepository _repository;
  final String _matchId;
  int? _woken;

  Future<void> maybeWake(
    Map<String, dynamic>? row, {
    bool again = false,
  }) async {
    if (row == null || row['status'] != 'active') return;
    final house = row['house_player'] as String?;
    if (house == null) return;
    final ply = (row['ply_count'] as num?)?.toInt() ?? 0;
    final houseIsWhite = row['player_white'] == house;
    if (ply.isEven != houseIsWhite) return;
    if (!again && _woken == ply) return;
    _woken = ply;
    final thinking = await _repository.wakeHouse(_matchId);
    if (!thinking && _woken == ply) _woken = null;
  }
}
