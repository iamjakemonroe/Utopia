import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';

/// Our own analytics: a few moments that say whether Utopia works (the
/// app opening, screens, games finished, purchases, rewards, chats with
/// Chip, invites), kept in our database (app_events, see the
/// analytics_daily and analytics_retention views). Nothing goes to anyone
/// else.
///
/// Events wait in a queue and go up together, every 20 seconds or when
/// the app goes into the background. Failing to send drops them quietly:
/// analytics never get in a player's way.
class Analytics {
  Analytics(this._client) {
    _lifecycle = AppLifecycleListener(onHide: flush, onDetach: flush);
  }

  /// Null where there's no backend (tests): then nothing is logged.
  final SupabaseClient? _client;
  late final AppLifecycleListener _lifecycle;
  final _queue = <Map<String, Object?>>[];
  Timer? _timer;

  /// [name]: lowercase words joined by underscores ("game_finished").
  void log(String name, [Map<String, Object?> props = const {}]) {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return;
    _queue.add({
      'name': name,
      'props': props,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    if (_queue.length >= 50) {
      flush();
    } else {
      _timer ??= Timer(const Duration(seconds: 20), flush);
    }
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_queue.isEmpty) return;
    final batch = List.of(_queue);
    _queue.clear();
    try {
      await _client?.rpc('log_events', params: {'p_events': batch});
    } catch (_) {
      // Offline or signed out: these are dropped.
    }
  }

  void dispose() {
    _lifecycle.dispose();
    flush();
  }
}

final analyticsProvider = Provider<Analytics>((ref) {
  SupabaseClient? client;
  try {
    client = ref.watch(supabaseClientProvider);
  } catch (_) {
    // No backend here (tests): analytics stay quiet.
  }
  final analytics = Analytics(client);
  ref.onDispose(analytics.dispose);
  return analytics;
});

/// A screen's path without its ids ("/ludo/:id"), so screens group
/// together.
String screenName(String path) => path
    .replaceAll(
      RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'),
      ':id',
    )
    .replaceAll(RegExp(r'/local-[^/]+'), '/:id');
