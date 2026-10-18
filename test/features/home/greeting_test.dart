import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/home/domain/greeting.dart';

void main() {
  group('greetingName', () {
    test('Chip uses the nickname when there is one', () {
      expect(
        greetingName({'display_name': 'mira k', 'username': 'mira_k64'}),
        'Mira K',
      );
    });

    test('falls back to the username, with a capital', () {
      expect(
        greetingName({'display_name': '', 'username': 'maya42'}),
        'Maya42',
      );
      expect(greetingName({'username': 'jake'}), 'Jake');
    });

    test('keeps the rest of the name as typed', () {
      expect(greetingName({'display_name': 'deMarco'}), 'DeMarco');
    });

    test('no name at all', () {
      expect(greetingName(null), isNull);
      expect(greetingName({'display_name': '  ', 'username': null}), isNull);
    });
  });

  test('the greeting puts a capital on the name', () {
    for (var seed = 0; seed < 20; seed++) {
      final g = pickGreeting(
        DateTime(2026, 10, 2, 10),
        'jake',
        math.Random(seed),
      );
      expect(g.title, isNot(contains('jake')));
    }
  });

  test('on their birthday, Chip only talks about that, all day', () {
    for (final hour in [3, 8, 14, 19, 23]) {
      for (var seed = 0; seed < 20; seed++) {
        final g = pickGreeting(
          DateTime(2026, 10, 18, hour),
          'ada',
          math.Random(seed),
          true,
        );
        expect(g.icon.codePoint, Icons.cake_rounded.codePoint);
        expect(
          g.title,
          anyOf(contains('birthday'), contains('your day'), contains('Party')),
        );
        expect(g.title, contains('Ada'));
      }
    }
    final noName = pickGreeting(DateTime(2026, 10, 18, 9), null, null, true);
    expect(noName.title, isNot(contains('{name}')));
    expect(noName.title, isNot(contains(', !')));
  });
}
