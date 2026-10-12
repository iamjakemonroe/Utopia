// The Zombie Bite on a photo (gold border) and on a generated avatar, to
// check the bite takes the picture and its border with it.
// Renders test/tool/goldens/zombie_bite.png.
// Run: flutter test --run-skipped --update-goldens test/tool/zombie_bite_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/auras/presentation/aura_frame.dart';
import 'package:utopia/core/widgets/user_avatar.dart';

void main() {
  testWidgets('zombie bite', (tester) async {
    tester.view.physicalSize = const Size(1000, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const ValueKey('sheet'),
          child: Container(
            color: const Color(0xFF1E1638),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // A photo: what UserAvatar draws, a gold border round it.
                AuraFrame(
                  aura: 'zombie',
                  radius: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6FA8DC),
                      border: Border.all(
                        color: const Color(0xFFFFC94D),
                        width: 4,
                      ),
                    ),
                  ),
                ),
                const UserAvatar(
                  avatarUrl: null,
                  fallbackInitial: 'J',
                  avatarKind: 'animal',
                  avatarSeed: 7,
                  radius: 150,
                  aura: 'zombie',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/zombie_bite.png'),
    );
  });
}
