import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utopia_themes.dart';

/// Loaded once in main() before the first frame and injected with an
/// override, so anything can read saved settings synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Overridden in main()'),
);

/// The active app theme, remembered on this device. Ownership is checked
/// by the store before [apply] is called; this only switches looks.
class ThemeController extends StateNotifier<UtopiaTheme> {
  ThemeController(this._prefs)
    : super(UtopiaThemes.byId(_prefs.getString(_key))) {
    UtopiaThemes.active = state;
  }

  static const _key = 'utopia.theme';

  final SharedPreferences _prefs;

  /// On a fresh install (no world picked on this device yet), takes the
  /// world saved on the player's account, so they land where they left.
  void adoptFromAccount(String? themeId) {
    if (themeId == null || _prefs.containsKey(_key)) return;
    final theme = UtopiaThemes.all.where((t) => t.id == themeId).firstOrNull;
    if (theme == null) return;
    if (theme.id == state.id) {
      _prefs.setString(_key, theme.id);
      return;
    }
    apply(theme);
  }

  void apply(UtopiaTheme theme) {
    if (theme.id == state.id) return;
    UtopiaThemes.active = theme;
    _prefs.setString(_key, theme.id);
    state = theme;
    _rebuildEverything();
  }

  /// Widgets read theme colors through AppColors' getters rather than an
  /// InheritedWidget, so nothing below would know the theme changed. This
  /// marks every element dirty so the whole tree rebuilds with the new
  /// colors in one frame (the theme teleport covers that frame).
  static void _rebuildEverything() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, UtopiaTheme>(
      (ref) => ThemeController(ref.watch(sharedPreferencesProvider)),
    );
