import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_controller.dart';

@immutable
class GameplaySettings {
  const GameplaySettings({
    this.haptics = true,
    this.moveHints = true,
    this.timerTicks = true,
    this.autoPlayVoice = true,
    this.reminders = true,
    this.showNowPlaying = true,
    this.floatingChip = true,
  });

  /// Little buzzes on dice, captures, your turn and wins.
  final bool haptics;

  /// Dots on the squares a chess piece can move to.
  final bool moveHints;

  /// A soft tick in the last seconds of your turn.
  final bool timerTicks;

  /// Play other players' voice notes as they arrive.
  final bool autoPlayVoice;

  /// Now-and-then nudges to come back and play, when away a while.
  final bool reminders;

  /// Chip notices the music playing on the phone and vibes along.
  final bool showNowPlaying;

  /// Chip floats over the app's screens, ready to chat when tapped.
  final bool floatingChip;

  GameplaySettings copyWith({
    bool? haptics,
    bool? moveHints,
    bool? timerTicks,
    bool? autoPlayVoice,
    bool? reminders,
    bool? showNowPlaying,
    bool? floatingChip,
  }) {
    return GameplaySettings(
      haptics: haptics ?? this.haptics,
      moveHints: moveHints ?? this.moveHints,
      timerTicks: timerTicks ?? this.timerTicks,
      autoPlayVoice: autoPlayVoice ?? this.autoPlayVoice,
      reminders: reminders ?? this.reminders,
      showNowPlaying: showNowPlaying ?? this.showNowPlaying,
      floatingChip: floatingChip ?? this.floatingChip,
    );
  }
}

class GameplaySettingsController extends StateNotifier<GameplaySettings> {
  GameplaySettingsController(this._prefs)
    : super(
        GameplaySettings(
          haptics: _prefs.getBool('play.haptics') ?? true,
          moveHints: _prefs.getBool('play.moveHints') ?? true,
          timerTicks: _prefs.getBool('play.timerTicks') ?? true,
          autoPlayVoice: _prefs.getBool('play.autoPlayVoice') ?? true,
          reminders: _prefs.getBool('play.reminders') ?? true,
          showNowPlaying: _prefs.getBool('play.nowPlaying') ?? true,
          floatingChip: _prefs.getBool('play.floatingChip') ?? true,
        ),
      );

  final SharedPreferences _prefs;

  void setHaptics(bool on) {
    state = state.copyWith(haptics: on);
    _prefs.setBool('play.haptics', on);
  }

  void setMoveHints(bool on) {
    state = state.copyWith(moveHints: on);
    _prefs.setBool('play.moveHints', on);
  }

  void setAutoPlayVoice(bool on) {
    state = state.copyWith(autoPlayVoice: on);
    _prefs.setBool('play.autoPlayVoice', on);
  }

  void setReminders(bool on) {
    state = state.copyWith(reminders: on);
    _prefs.setBool('play.reminders', on);
  }

  void setShowNowPlaying(bool on) {
    state = state.copyWith(showNowPlaying: on);
    _prefs.setBool('play.nowPlaying', on);
  }

  void setFloatingChip(bool on) {
    state = state.copyWith(floatingChip: on);
    _prefs.setBool('play.floatingChip', on);
  }

  void setTimerTicks(bool on) {
    state = state.copyWith(timerTicks: on);
    _prefs.setBool('play.timerTicks', on);
  }
}

final gameplaySettingsProvider =
    StateNotifierProvider<GameplaySettingsController, GameplaySettings>(
      (ref) => GameplaySettingsController(ref.watch(sharedPreferencesProvider)),
    );
