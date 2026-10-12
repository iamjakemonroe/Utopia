import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/theme_controller.dart'
    show sharedPreferencesProvider;
import '../../../core/widgets/game_card_art.dart';

/// A game being played on this phone (against Chip, Robo or Ludo bots, or
/// checkers between two people on one phone), saved after every move so it
/// picks up where it left off if the app closes, the way online games do.
/// Leaving the game on purpose ends it and forgets it.
class OfflineGame {
  const OfflineGame({
    required this.kind,
    required this.route,
    required this.data,
    this.opponent,
  });

  final GameKind kind;

  /// Where the game opens (its setup is in the route).
  final String route;

  /// The game so far: moves, clocks, the board.
  final Map<String, dynamic> data;

  /// Who it's against, for the "your game is still on" card.
  final String? opponent;

  /// Opens it again from the saved moves.
  String get resumeRoute => kind == GameKind.ludo
      ? route
      : '$route${route.contains('?') ? '&' : '?'}resume=1';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'route': route,
    'data': data,
    'opponent': ?opponent,
  };

  static OfflineGame? fromJson(Map<String, dynamic> json) {
    final kind = GameKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final route = json['route'] as String?;
    final data = json['data'];
    if (kind == null || route == null || data is! Map) return null;
    return OfflineGame(
      kind: kind,
      route: route,
      data: data.cast<String, dynamic>(),
      opponent: json['opponent'] as String?,
    );
  }
}

/// The one game on this phone that's in progress, if any.
class OfflineGameStore {
  OfflineGameStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'offline_game';

  OfflineGame? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return OfflineGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void save(OfflineGame game) {
    _prefs.setString(_key, jsonEncode(game.toJson()));
  }

  /// Forgets the saved game: only if it's the one at [route], when given,
  /// so ending one game never wipes a different one.
  void clear({String? route}) {
    if (route != null && load()?.route != route) return;
    _prefs.remove(_key);
  }
}

final offlineGameStoreProvider = Provider<OfflineGameStore>(
  (ref) => OfflineGameStore(ref.watch(sharedPreferencesProvider)),
);
