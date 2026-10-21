import 'package:supabase_flutter/supabase_flutter.dart';

/// All chess and checkers data access (the two share the matches, moves,
/// queue and invite tables; checkers rows say game = 'checkers'): realtime streams for a live match, and the RPC
/// calls that mutate matchmaking/invites/moves/settlement server-side (see
/// `supabase/migrations/20260922120000_chess_social_schema.sql`). Like
/// [CoinRepository], there is no client-side balance math here — every coin
/// movement happens inside a SECURITY DEFINER function.
class ChessRepository {
  ChessRepository(this._client);

  final SupabaseClient _client;

  /// Live-updating row for [matchId] — board FEN, status, players, result.
  Stream<Map<String, dynamic>?> watchMatch(String matchId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// Live-updating move log for [matchId], oldest first.
  Stream<List<Map<String, dynamic>>> watchMoves(String matchId) {
    return _client
        .from('match_moves')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('ply');
  }

  /// Pending invites addressed to the current user (surfaced in the
  /// friends popup and as a home-screen banner).
  Stream<List<Map<String, dynamic>>> watchIncomingInvites(String userId) {
    return _client
        .from('match_invites')
        .stream(primaryKey: ['id'])
        .eq('to_user', userId)
        .order('created_at');
  }

  /// Invites the current user sent — watched so the sender's client can
  /// notice the moment the other person accepts (match_id gets set) and
  /// jump straight into the match without any polling on their end.
  Stream<List<Map<String, dynamic>>> watchOutgoingInvites(String userId) {
    return _client
        .from('match_invites')
        .stream(primaryKey: ['id'])
        .eq('from_user', userId)
        .order('created_at');
  }

  /// Joins the random-opponent queue at [stake]. Returns the new match id
  /// immediately if this call paired with someone already waiting;
  /// otherwise null, and the caller should watch [watchQueueMatch] for a
  /// pairing that happens later from the other side.
  Future<String?> joinMatchmakingQueue(
    int stake, {
    int minutes = 10,
    int increment = 0,
    String game = 'chess',
  }) async {
    final result = await _client.rpc(
      'join_board_queue',
      params: {
        'p_game': game,
        'p_stake': stake,
        'p_minutes': minutes,
        'p_increment': increment,
      },
    );
    return result as String?;
  }

  /// Waited long enough for a free game: a real player who's just come
  /// along, or one of Utopia's house players (null: keep waiting).
  Future<String?> startHouseMatch({
    required String game,
    required int minutes,
    required int increment,
  }) async {
    final id = await _client.rpc(
      'house_match_start',
      params: {'p_game': game, 'p_minutes': minutes, 'p_increment': increment},
    );
    return id as String?;
  }

  /// The house player's turn in [matchId]: wakes them (house-move). Whether
  /// they're thinking about it.
  Future<bool> wakeHouse(String matchId) async {
    try {
      final res = await _client.functions.invoke(
        'house-move',
        body: {'match_id': matchId},
      );
      final data = res.data;
      return data is Map && data['thinking'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> leaveMatchmakingQueue() {
    return _client.rpc('leave_matchmaking_queue');
  }

  /// While queued, a match can be created by the *other* player's call to
  /// [joinMatchmakingQueue]. This watches for that: any active match where
  /// we're a player and it didn't exist a moment ago is picked up by the
  /// caller polling/subscribing to this alongside the queue row.
  Stream<List<Map<String, dynamic>>> watchQueueRow(String userId) {
    return _client
        .from('matchmaking_queue')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId);
  }

  /// Matches where the user is a player, newest first — used to detect a
  /// queue pairing landing (status flips to active) and to build the
  /// "recents" opponent list for the friends popup.
  Stream<List<Map<String, dynamic>>> watchMyMatches(String userId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .order('created_at');
    // Filtering to player_white == userId OR player_black == userId isn't
    // expressible in a single postgrest .eq() stream filter; RLS already
    // restricts rows to matches the user is in, so no extra filter is
    // needed for correctness — this just returns "my matches" by construction.
  }

  Future<String?> sendMatchInvite({
    required String toUserId,
    required int stake,
    int minutes = 10,
    int increment = 0,
    String game = 'chess',
  }) async {
    final result = await _client.rpc(
      'send_board_invite',
      params: {
        'p_to_user': toUserId,
        'p_game': game,
        'p_stake': stake,
        'p_minutes': minutes,
        'p_increment': increment,
      },
    );
    return result as String?;
  }

  Future<String?> respondMatchInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final result = await _client.rpc(
      'respond_match_invite',
      params: {'p_invite_id': inviteId, 'p_accept': accept},
    );
    return result as String?;
  }

  /// Takes back a challenge the player sent, while it's still waiting.
  Future<void> cancelMatchInvite(String inviteId) =>
      _client.rpc('cancel_match_invite', params: {'p_invite_id': inviteId});

  /// Plays a move. The server checks it with the games' own rules on the
  /// board it holds (the board-move function) and settles the game if it
  /// ended it; [san] tells two checkers jumps between the same squares
  /// apart. Throws if the move isn't allowed, it isn't this player's turn,
  /// or their clock ran out.
  ///
  /// Until the server checks moves (its function or migration not there
  /// yet), the move and the board after it ([fenAfter]) are saved as they
  /// were before.
  Future<void> recordMove({
    required String matchId,
    required String from,
    required String to,
    String? promotion,
    required String san,
    required String fenAfter,
  }) async {
    try {
      await _client.functions.invoke(
        'board-move',
        body: {
          'match_id': matchId,
          'from': from,
          'to': to,
          'promotion': promotion,
          'notation': san,
        },
      );
      return;
    } on FunctionException catch (e) {
      // The referee said no: not a move to save some other way.
      if (e.status == 409 || e.status == 422 || e.status == 403) rethrow;
    }
    await _client.rpc(
      'record_move',
      params: {
        'p_match_id': matchId,
        'p_from': from,
        'p_to': to,
        'p_promotion': promotion,
        'p_san': san,
        'p_fen_after': fenAfter,
      },
    );
  }

  Future<void> reportMatchResult({
    required String matchId,
    String? winnerId,
    required String result,
  }) {
    return _client.rpc(
      'report_match_result',
      params: {
        'p_match_id': matchId,
        'p_winner_id': winnerId,
        'p_result': result,
      },
    );
  }

  /// Ends the game if the player on turn has run out of time (or never
  /// made a first move). Returns the result it ended with, or null if
  /// there's still time on the clock.
  Future<String?> claimTimeout(String matchId) async {
    final result = await _client.rpc(
      'claim_chess_timeout',
      params: {'p_match_id': matchId},
    );
    return result as String?;
  }

  Future<void> resignMatch(String matchId) {
    return _client.rpc('resign_match', params: {'p_match_id': matchId});
  }

  /// Tells the server this player is still at the board. A finished game
  /// whose result only one side reported settles once the other side has
  /// stopped checking in (see the chess_unanswered_results migration).
  Future<void> touchMatch(String matchId) {
    return _client.rpc('touch_chess_match', params: {'p_match_id': matchId});
  }

  /// The board game the user is in the middle of, if any (newest first):
  /// its id and which game it is ('chess' or 'checkers').
  Future<(String, String)?> activeMatch(String userId) async {
    final row = await _client
        .from('matches')
        .select('id, game')
        .eq('status', 'active')
        .or('player_white.eq.$userId,player_black.eq.$userId')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return (row['id'] as String, row['game'] as String? ?? 'chess');
  }
}

/// Where a board game's match lives in the app.
String boardMatchRoute(String? game, String matchId) =>
    game == 'checkers' ? '/checkers/$matchId' : '/chess/$matchId';
