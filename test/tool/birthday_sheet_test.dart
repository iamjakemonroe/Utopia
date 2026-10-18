// Renders the Birthday world plain and with the party at its peak (the
// Birthday frame worn there), into test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/birthday_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/world_sets.dart';

void main() {
  for (final (name, party, wait) in [
    ('plain', false, 3010),
    ('party', true, 5420),
  ]) {
    testWidgets('birthday $name', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      WorldSets.birthday.on.value = party;
      WorldSets.birthday.settle();
      addTearDown(() {
        WorldSets.birthday.on.value = false;
        WorldSets.birthday.settle();
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('world'),
            child: FittedBox(
              child: SizedBox(
                width: 430,
                height: 932,
                child: UtopiaWorld(style: UtopiaThemes.utopiaBirthday.world),
              ),
            ),
          ),
        ),
      );
      await tester.pump(Duration(milliseconds: wait));
      await expectLater(
        find.byKey(const ValueKey('world')),
        matchesGoldenFile('goldens/birthday_$name.png'),
      );
    });
  }
}
