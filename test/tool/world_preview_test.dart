// Renders a world into test/tool/goldens/world_<id>.png for a look without
// a device. Run: flutter test --update-goldens test/tool/world_preview_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/utopia_world.dart';

void main() {
  for (final theme in [UtopiaThemes.utopiaDojo]) {
    testWidgets('world ${theme.id}', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('world'),
            // Laid out at phone size, painted at 3x for a close look.
            child: FittedBox(
              child: SizedBox(
                width: 430,
                height: 932,
                child: UtopiaWorld(style: theme.world),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await expectLater(
        find.byKey(const ValueKey('world')),
        matchesGoldenFile('goldens/world_${theme.id}.png'),
      );
    });
  }
}
