import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/profile/domain/nickname_rules.dart';

void main() {
  test('nicknames can be written any way a player likes', () {
    for (final name in [
      '\u{1D4D9}\u{1D4EA}\u{1D4F4}\u{1D4EE}', // script letters
      '\u1D0A\u1D00\u1D0B\u1D07', // small capitals
      '\uFF2A\uFF41\uFF4B\uFF45', // full width
      '\uA9C1\u0F3A Jake \u0F3B\uA9C2', // decorations
      'J\u0337a\u0337k\u0337e\u0337', // a mark on each letter
      'J\u00F3se \u00D1\u00FA\u00F1ez',
      '\u674E\u5C0F\u9F8D',
      'Jake \u{1F451}\u{1F525}',
      '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466} fam',
      '\u{1F1F3}\u{1F1EC} Naija',
      'x_X',
    ]) {
      expect(NicknameRules.problem(name), isNull, reason: name);
    }
  });

  test('what hides, flips, vanishes or spills is turned away', () {
    expect(NicknameRules.problem('Ja\u200Bke'), contains('Hidden'));
    expect(NicknameRules.problem('\u202EkaJ'), contains('Hidden'));
    expect(NicknameRules.problem('\u3164\u3164\u3164'), contains('see'));
    expect(NicknameRules.problem('J'), contains('see'));
    expect(NicknameRules.problem('Ja\u0301\u0302\u0303\u0304ke'), contains('marks'));
    expect(NicknameRules.problem('a' * 25), contains('24'));
  });

  test('characters are counted as a person counts them', () {
    // Emoji families: one character each, though each is built of seven.
    final family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}';
    expect(NicknameRules.problem(family * 12), isNull);
    expect(NicknameRules.problem('${family * 2} and family'), isNull);
    expect(NicknameRules.tidy('  Jake\u3000\u00A0\n Monroe '), 'Jake Monroe');
  });
}
