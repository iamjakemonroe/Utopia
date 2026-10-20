import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/guess_doodle/presentation/widgets/doodle_chat.dart';

void main() {
  testWidgets('a tap anywhere on the guess pill brings the keyboard up', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox.expand(key: Key('drawing'))),
              SizedBox(
                width: 360,
                child: DoodleGuessField(
                  hint: 'Type your guess',
                  focusNode: focus,
                  onSend: (text) async {
                    sent.add(text);
                    return true;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final pill = tester.getRect(find.byType(DoodleGuessField));
    for (final (where, at) in [
      ('middle', pill.center),
      ('near its top', Offset(pill.center.dx, pill.top + 4)),
      ('near its bottom', Offset(pill.center.dx, pill.bottom - 4)),
      ('at its left edge', Offset(pill.left + 6, pill.center.dy)),
    ]) {
      focus.unfocus();
      await tester.pump();
      await tester.tapAt(at);
      await tester.pump();
      expect(focus.hasFocus, isTrue, reason: 'tapped $where');
    }

    // Focused, but the keyboard put away (Android's back key): a tap on
    // the pill's edge brings it back.
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tapAt(Offset(pill.left + 6, pill.center.dy));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue, reason: 'shown again');

    // Sending keeps it up for the next guess.
    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sent, ['cat']);
    expect(focus.hasFocus, isTrue, reason: 'still up after sending');

    // A tap on the drawing puts it away.
    await tester.tap(find.byKey(const Key('drawing')));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });
}
