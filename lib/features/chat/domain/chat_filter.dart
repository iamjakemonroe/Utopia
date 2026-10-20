import '../../../l10n/strings.dart';

/// Keeps public-game chat friendly. Runs in the app before a message is
/// sent (the server masks again as a backstop no client can skip, see
/// mask_offensive in the Ludo v2 migration).
///
/// It catches the usual dodges: c4ps and l33t letters, stretched letters
/// ("fuuuck"), and words spelled out with spaces or dots ("f u c k").
class ChatFilter {
  ChatFilter._();

  static const mask = '★★★';

  /// Word stems that are masked along with any ending ("fucking").
  static const _stems = [
    'fuck',
    'motherf',
    'shit',
    'bitch',
    'cunt',
    'nigg',
    'fagg',
    'retard',
    'whore',
    'slut',
    'bastard',
    'asshole',
    'dickhead',
    'cocksuck',
    'wank',
    'twat',
    'rapist',
    'dumbass',
    'jackass',
    'kike',
    'chink',
    'tranny',
    'trannies',
  ];

  /// Words masked only as a whole word (as stems they'd hit innocent words
  /// like "cocktail", "grapes" or "scrape").
  static const _words = {
    'fag',
    'fags',
    'cock',
    'cocks',
    'pussy',
    'pussies',
    'dick',
    'dicks',
    'rape',
    'raped',
    'kys',
    'stfu',
    'wtf',
    'idiot',
    'moron',
    'loser',
    'stupid',
    'spic',
    'spics',
  };

  static const _leet = {
    '0': 'o',
    '1': 'i',
    '!': 'i',
    '3': 'e',
    '4': 'a',
    '@': 'a',
    '5': 's',
    r'$': 's',
    '7': 't',
    '8': 'b',
    '9': 'g',
    '+': 't',
  };

  static String _normalize(String word) {
    final buffer = StringBuffer();
    for (final ch in word.toLowerCase().split('')) {
      final mapped = _leet[ch] ?? ch;
      if (RegExp('[a-z]').hasMatch(mapped)) buffer.write(mapped);
    }
    // Squash stretched letters: "fuuuuck" -> "fuck".
    return buffer.toString().replaceAllMapped(
      RegExp(r'([a-z])\1+'),
      (m) => m[1]!,
    );
  }

  static bool _bad(String normalized) {
    if (normalized.isEmpty) return false;
    if (_words.contains(normalized)) return true;
    return _stems.any(normalized.startsWith);
  }

  static bool isClean(String text) => filter(text) == text;

  /// [text] with every offensive word replaced by [mask].
  static String filter(String text) {
    final parts = text.split(RegExp(r'(\s+)'));
    final spaces = RegExp(r'\s+').allMatches(text).map((m) => m[0]!).toList();
    final masked = List<String>.from(parts);

    for (var i = 0; i < parts.length; i++) {
      if (_bad(_normalize(parts[i]))) masked[i] = mask;
    }

    // Letters spelled out one at a time: "f u c k" or "f.u.c.k".
    var run = <int>[];
    void flush() {
      if (run.length >= 3) {
        final joined = _normalize(run.map((i) => parts[i]).join());
        if (_bad(joined)) {
          masked[run.first] = mask;
          for (final i in run.skip(1)) {
            masked[i] = '';
          }
        }
      }
      run = [];
    }

    for (var i = 0; i < parts.length; i++) {
      if (_normalize(parts[i]).length == 1) {
        run.add(i);
      } else {
        flush();
      }
    }
    flush();

    final out = StringBuffer();
    for (var i = 0; i < masked.length; i++) {
      out.write(masked[i]);
      if (i < spaces.length && masked[i].isNotEmpty) out.write(spaces[i]);
    }
    return out.toString().trim();
  }

  /// One-tap phrases for chat.
  static final quickPhrases = [
    'Good luck!',
    strings.chatFilterNiceMove,
    strings.chatFilterWellPlayed,
    strings.chatFilterSoClose,
    strings.chatFilterLetSGo,
    strings.chatFilterYourTurn,
    strings.chatFilterOops,
    strings.chatFilterGoodGame,
  ];
}
