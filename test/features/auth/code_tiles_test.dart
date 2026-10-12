import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/auth/presentation/widgets/auth_world.dart';

void main() {
  testWidgets('tapping the tiles brings back a keyboard that was put away', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CodeTilesInput(controller: controller, length: 8),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Focused straight away, keyboard up.
    expect(tester.testTextInput.isVisible, isTrue);

    // The keyboard is put away (back button, swipe) but focus stays.
    tester.testTextInput.hide();
    expect(tester.testTextInput.isVisible, isFalse);
    tester.testTextInput.log.clear();

    await tester.tap(find.byType(CodeTilesInput));
    await tester.pump();
    expect(
      tester.testTextInput.log.map((c) => c.method),
      contains('TextInput.show'),
    );

    // And typing still fills the tiles.
    tester.testTextInput.enterText('1234');
    await tester.pump();
    expect(controller.text, '1234');
    expect(SystemChannels.textInput, isNotNull);
  });
}
