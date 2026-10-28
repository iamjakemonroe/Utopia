import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../chess/domain/chess_bot.dart' show BotLevel;
import '../domain/pool_bot.dart';
import '../domain/pool_physics.dart';
import '../domain/pool_rules.dart';

/// A coin table: what it costs to sit down, the pot the winner takes, and
/// Chip's level there (the server's pool_tables).
class PoolTableInfo {
  const PoolTableInfo({
    required this.id,
    required this.entry,
    required this.prize,
    required this.bot,
  });

  factory PoolTableInfo.fromRow(Map<String, dynamic> row) => PoolTableInfo(
    id: row['id'] as String,
    entry: (row['entry'] as num).toInt(),
    prize: (row['prize'] as num).toInt(),
    bot: BotLevel.values.byName(row['bot'] as String),
  );

  final String id;
  final int entry, prize;
  final BotLevel bot;
}

/// The tables as they were set when this was written, shown until the
/// server's own arrive.
const kPoolTables = [
  PoolTableInfo(id: 'lagoon', entry: 200, prize: 380, bot: BotLevel.easy),
  PoolTableInfo(id: 'dunes', entry: 1000, prize: 1900, bot: BotLevel.normal),
  PoolTableInfo(id: 'neon', entry: 5000, prize: 9500, bot: BotLevel.hard),
  PoolTableInfo(id: 'summit', entry: 25000, prize: 47500, bot: BotLevel.hard),
];

/// A game against Chip at a coin table, as the server holds it.
class PoolTableGame {
  const PoolTableGame({
    required this.id,
    required this.tableId,
    required this.entry,
    required this.prize,
    required this.bot,
    required this.botCue,
    required this.botCueLevel,
    required this.cueId,
    required this.cueLevel,
    required this.state,
    required this.shots,
    required this.status,
    this.result,
  });

  factory PoolTableGame.fromRow(Map<String, dynamic> row) => PoolTableGame(
    id: row['id'] as String,
    tableId: row['table_id'] as String,
    entry: (row['entry'] as num).toInt(),
    prize: (row['prize'] as num).toInt(),
    bot: BotLevel.values.byName(row['bot'] as String),
    botCue: row['bot_cue'] as String,
    botCueLevel: (row['bot_cue_level'] as num).toInt(),
    cueId: row['cue_id'] as String,
    cueLevel: (row['cue_level'] as num).toInt(),
    state: PoolGame.fromJson((row['state'] as Map).cast<String, Object?>()),
    shots: (row['shots'] as num).toInt(),
    status: row['status'] as String,
    result: row['result'] as String?,
  );

  final String id, tableId;
  final int entry, prize;
  final BotLevel bot;
  final String botCue;
  final int botCueLevel;
  final String cueId;
  final int cueLevel;
  final PoolGame state;
  final int shots;

  /// 'active', 'won' or 'lost'.
  final String status;
  final String? result;
}

/// What the server made of a shot: the table after it, how many shots
/// the game's had, whether it's over and the pot paid ([prize] when the
/// player won), and for Chip's turn the shot it played.
class PoolRuling {
  const PoolRuling({
    required this.state,
    required this.shots,
    required this.status,
    required this.prize,
    this.move,
  });

  factory PoolRuling.fromJson(Map<String, dynamic> json) {
    final move = json['move'] as Map?;
    final place = move?['place'] as Map?;
    return PoolRuling(
      state: PoolGame.fromJson((json['state'] as Map).cast<String, Object?>()),
      shots: (json['shots'] as num).toInt(),
      status: json['status'] as String,
      prize: (json['prize'] as num? ?? 0).toInt(),
      move: move == null
          ? null
          : PoolBotMove(
              shot: PoolShot.fromJson(
                (move['shot'] as Map).cast<String, Object?>(),
              ),
              cueX: (place?['x'] as num?)?.toDouble(),
              cueY: (place?['y'] as num?)?.toDouble(),
              called: (move['called'] as num?)?.toInt(),
            ),
    );
  }

  final PoolGame state;
  final int shots;
  final String status;
  final int prize;
  final PoolBotMove? move;
}

/// Why the server turned a shot or a game down: [conflict] when the table
/// moved on (another device, a stale screen) and the game should be
/// fetched again.
class PoolRefused implements Exception {
  const PoolRefused(this.message, {this.conflict = false});

  final String message;
  final bool conflict;

  @override
  String toString() => message;
}

/// The pool coin tables and cues, on the server: the tables, the
/// player's cue levels and game in play from the database; starting a
/// game, shots and Chip's turns through the pool-table function, which
/// referees them; resigning and upgrading through the database's own
/// functions.
class PoolRepository {
  PoolRepository(this._client);

  final SupabaseClient _client;

  Future<List<PoolTableInfo>> tables() async {
    final rows = await _client.from('pool_tables').select().order('sort');
    return [for (final row in rows) PoolTableInfo.fromRow(row)];
  }

  /// The levels the player has taken their cues to (a cue with no entry is
  /// at level 1).
  Future<Map<String, int>> cueLevels() async {
    final rows = await _client.from('user_pool_cues').select('cue_id, level');
    return {
      for (final row in rows)
        row['cue_id'] as String: (row['level'] as num).toInt(),
    };
  }

  /// The player's game in play, if they have one.
  Future<PoolTableGame?> activeGame() async {
    final row = await _client
        .from('pool_games')
        .select()
        .eq('status', 'active')
        .maybeSingle();
    return row == null ? null : PoolTableGame.fromRow(row);
  }

  Future<PoolTableGame> game(String id) async {
    final row = await _client.from('pool_games').select().eq('id', id).single();
    return PoolTableGame.fromRow(row);
  }

  /// Sits down at [table]: its entry paid (a game left unfinished is lost).
  Future<PoolTableGame> start(String table) async {
    final data = await _invoke({'action': 'start', 'table': table});
    return PoolTableGame.fromRow((data['game'] as Map).cast<String, dynamic>());
  }

  /// The player's [shot] on game [gameId], [shots] the shots they've seen;
  /// [place] where they put the cue ball (in hand), [called] the pocket
  /// called on the 8.
  Future<PoolRuling> shoot({
    required String gameId,
    required int shots,
    required PoolShot shot,
    (double, double)? place,
    int? called,
  }) async {
    final data = await _invoke({
      'action': 'shot',
      'game': gameId,
      'shots': shots,
      'shot': shot.toJson(),
      'place': place == null ? null : {'x': place.$1, 'y': place.$2},
      'called': called,
    });
    return PoolRuling.fromJson(data);
  }

  /// Chip's turn on game [gameId].
  Future<PoolRuling> chip({required String gameId, required int shots}) async {
    final data = await _invoke({
      'action': 'chip',
      'game': gameId,
      'shots': shots,
    });
    return PoolRuling.fromJson(data);
  }

  Future<void> resign(String gameId) =>
      _client.rpc('pool_resign', params: {'p_game': gameId});

  /// Takes [cueId] up a level; returns its new level.
  Future<int> upgradeCue(String cueId) async {
    final level = await _client.rpc(
      'upgrade_pool_cue',
      params: {'p_cue_id': cueId},
    );
    return (level as num).toInt();
  }

  Future<Map<String, dynamic>> _invoke(Map<String, Object?> body) async {
    try {
      final res = await _client.functions.invoke('pool-table', body: body);
      return (res.data as Map).cast<String, dynamic>();
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? '${details['error'] ?? ''}' : '$details';
      throw PoolRefused(
        message,
        conflict: e.status == 409 && message != 'insufficient balance',
      );
    }
  }
}

final poolRepositoryProvider = Provider<PoolRepository>(
  (ref) => PoolRepository(ref.watch(supabaseClientProvider)),
);

/// The coin tables (the built-in ones until the server's arrive).
final poolTablesProvider = FutureProvider<List<PoolTableInfo>>((ref) async {
  try {
    final tables = await ref.watch(poolRepositoryProvider).tables();
    return tables.isEmpty ? kPoolTables : tables;
  } catch (_) {
    return kPoolTables;
  }
});

/// The signed-in player's cue levels.
final poolCueLevelsProvider = FutureProvider<Map<String, int>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const {};
  return ref.watch(poolRepositoryProvider).cueLevels();
});

/// The signed-in player's game in play at a coin table, if any.
final activePoolGameProvider = FutureProvider.autoDispose<PoolTableGame?>((
  ref,
) async {
  if (ref.watch(currentUserProvider) == null) return null;
  return ref.watch(poolRepositoryProvider).activeGame();
});
