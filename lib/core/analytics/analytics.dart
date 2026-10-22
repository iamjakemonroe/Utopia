import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';
import 'posthog_logs.dart';

/// Our own analytics: a few moments that say whether Utopia works (the
/// app opening, screens, games finished, purchases, rewards, chats with
/// Chip, invites), kept in our database (app_events, see the
/// analytics_daily and analytics_retention views) and mirrored to PostHog.
///
/// Database events wait in a queue and go up together, every 20 seconds or when
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
    _capturePostHog(name, {
      for (final entry in props.entries)
        if (entry.value != null) entry.key: entry.value!,
    });
    if (_queue.length >= 50) {
      flush();
    } else {
      _timer ??= Timer(const Duration(seconds: 20), flush);
    }
  }

  /// Mirrors the bounded product-event contract to PostHog. AuthRepository
  /// identifies the current Supabase user centrally, so these plain captures
  /// inherit that stable identity without placing person data on events.
  void _capturePostHog(String name, Map<String, Object> props) {
    switch (name) {
      case 'account_saved':
        unawaited(
          Posthog().capture(eventName: 'account_saved', properties: props),
        );
      case 'signed_in':
        unawaited(
          Posthog().capture(eventName: 'signed_in', properties: props),
        );
      case 'names_saved':
        unawaited(
          Posthog().capture(eventName: 'names_saved', properties: props),
        );
      case 'birthday_saved':
        unawaited(
          Posthog().capture(eventName: 'birthday_saved', properties: props),
        );
      case 'game_finished':
        unawaited(
          Posthog().capture(eventName: 'game_finished', properties: props),
        );
        PostHogAppLogger.gameFinished();
      case 'reward_earned':
        unawaited(
          Posthog().capture(eventName: 'reward_earned', properties: props),
        );
      case 'invite_shared':
        unawaited(
          Posthog().capture(eventName: 'invite_shared', properties: props),
        );
      case 'web_checkout':
        unawaited(
          Posthog().capture(eventName: 'web_checkout', properties: props),
        );
      case 'coin_purchase':
        unawaited(
          Posthog().capture(eventName: 'coin_purchase', properties: props),
        );
      case 'store_purchase':
        unawaited(
          Posthog().capture(eventName: 'store_purchase', properties: props),
        );
        PostHogAppLogger.storePurchaseCompleted();
      case 'world_rented':
        unawaited(
          Posthog().capture(eventName: 'world_rented', properties: props),
        );
      case 'maestro_joined':
        unawaited(
          Posthog().capture(eventName: 'maestro_joined', properties: props),
        );
      case 'frame_bought':
        unawaited(
          Posthog().capture(eventName: 'frame_bought', properties: props),
        );
      case 'chip_message':
        unawaited(
          Posthog().capture(eventName: 'chip_message', properties: props),
        );
        PostHogAppLogger.chipMessageSent();
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
