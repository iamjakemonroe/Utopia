import 'package:flutter/widgets.dart' show StringCharacters;
import '../../../l10n/strings.dart';

/// What a nickname may be: anything a player likes to write (fancy
/// letters, symbols, any script, emoji), 2 to 24 characters as a person
/// counts them, but nothing that hides or flips text, at least 2 you can
/// see, and no glitch text. The server (set_nickname) checks the same.
abstract final class NicknameRules {
  static const max = 24;

  /// Characters that hide or flip text: zero-width spaces, direction
  /// overrides, soft hyphens, controls.
  static final _hidden = RegExp(
    r'[\u0001-\u001F\u007F-\u009F\u00AD\u200B\u200E\u200F\u202A-\u202E'
    r'\u2060-\u2064\u2066-\u2069\uFEFF\uFFF9-\uFFFB]',
  );

  /// Marks that sit on a letter (accents, strike-throughs).
  static const _marks =
      r'\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F';

  static final _stacked = RegExp('[$_marks]{4,}');

  /// What doesn't show on its own: spaces, marks, joiners and blank
  /// fillers.
  static final _unseen = RegExp(
    r'[\s\u200C\u200D\uFE00-\uFE0F' +
        _marks +
        r'\u115F\u1160\u180E\u2800\u3164\uFFA0\u{E0000}-\u{E007F}]',
    unicode: true,
  );

  static final _spaces = RegExp(
    r'[\s\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+',
  );

  /// [name] as it's saved: any run of spaces or line breaks as one space.
  static String tidy(String name) => name.replaceAll(_spaces, ' ').trim();

  /// Why [name] can't be a nickname, in a few words; null if it can (an
  /// empty one clears it).
  static String? problem(String name) {
    final n = tidy(name);
    if (n.isEmpty) return null;
    if (_hidden.hasMatch(n)) {
      return strings.nicknameRulesHiddenOrTextFlippingCharacters;
    }
    if (_stacked.hasMatch(n)) return strings.nicknameRulesAtMost3MarksOn;
    final seen = n.replaceAll(_unseen, '');
    if (seen.characters.length < 2) {
      return strings.nicknameRulesUseAtLeast2Characters;
    }
    // (And, as the server counts: what each is built of.)
    if (n.characters.length > max ||
        seen.runes.length > 64 ||
        n.runes.length > 128) {
      return strings.nicknameRulesUpToCharacters(max);
    }
    return null;
  }
}
