import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads coin balances. This is READ-ONLY by design — there is no method
/// here to mutate a balance. All balance changes happen server-side (the
/// coin ledger, via RPCs), and other players' exact balances aren't
/// readable from the profiles table at all.
class CoinRepository {
  CoinRepository(this._client);

  final SupabaseClient _client;

  /// The caller's own balance, live: fetched at once, again the moment a
  /// new entry lands in their coin ledger (every change writes one), and
  /// every half minute in case the live connection dropped.
  Stream<int> watchBalance(String userId) {
    late final StreamController<int> out;
    RealtimeChannel? channel;
    Timer? poll;
    var fetching = false;
    var again = false;

    Future<void> refresh() async {
      if (fetching) {
        again = true;
        return;
      }
      fetching = true;
      try {
        final value = await _client.rpc('get_my_coins');
        if (!out.isClosed && value != null) out.add((value as num).toInt());
      } catch (_) {
        // Offline for a moment: the next change or poll tries again.
      } finally {
        fetching = false;
        if (again) {
          again = false;
          unawaited(refresh());
        }
      }
    }

    out = StreamController<int>(
      onListen: () {
        refresh();
        channel = _client
            .channel('my-coins-$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'ledger_entries',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (_) => refresh(),
            )
            .subscribe((status, _) {
              // (Re)connected: catch up on anything missed meanwhile.
              if (status == RealtimeSubscribeStatus.subscribed) refresh();
            });
        poll = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
      },
      onCancel: () {
        poll?.cancel();
        final c = channel;
        if (c != null) _client.removeChannel(c);
      },
    );
    return out.stream;
  }

  /// Other players' coins, for the ones who show them: id -> coins.
  Future<Map<String, int>> publicCoins(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client.rpc(
      'get_public_coins',
      params: {'p_ids': ids.take(100).toList()},
    );
    return {
      for (final r in (rows as List? ?? const []))
        (r as Map)['id'] as String: (r['coins'] as num).toInt(),
    };
  }

  /// "Hide my coins" (or show them again).
  Future<void> setShowCoins(bool show) =>
      _client.rpc('set_show_coins', params: {'p_show': show});

  /// Today's daily reward: whether it can be claimed, the streak it would
  /// make (or made) and what it's worth.
  Future<({bool claimable, int streak, int coins})> dailyRewardStatus() async {
    final r = (await _client.rpc('daily_reward_status') as Map)
        .cast<String, dynamic>();
    return (
      claimable: r['claimable'] == true,
      streak: (r['streak'] as num?)?.toInt() ?? 1,
      coins: (r['coins'] as num?)?.toInt() ?? 0,
    );
  }

  /// Claims today's reward; returns the coins added and the new streak.
  Future<({int coins, int streak})> claimDailyReward() async {
    final r = (await _client.rpc('claim_daily_reward') as Map)
        .cast<String, dynamic>();
    return (
      coins: (r['coins'] as num?)?.toInt() ?? 0,
      streak: (r['streak'] as num?)?.toInt() ?? 1,
    );
  }
}
