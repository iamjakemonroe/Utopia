import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_seat_panel.dart';

const _die = Key('die');

Future<void> _pumpPanel(
  WidgetTester tester, {
  required bool mirrored,
  String? speech,
  VoidCallback? onRoll,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: mirrored ? Alignment.topRight : Alignment.topLeft,
            child: LudoSeatPanel(
              color: LudoColor.red,
              userId: null,
              isMe: true,
              isTurn: true,
              left: false,
              home: 0,
              mirrored: mirrored,
              speech: speech,
              onAvatarTap: () {},
              dice: onRoll == null
                  ? null
                  : GestureDetector(
                      key: _die,
                      behavior: HitTestBehavior.opaque,
                      onTap: onRoll,
                      child: const SizedBox.square(dimension: 44),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final mirrored in [false, true]) {
    testWidgets(
      'a chat line pops up over the die${mirrored ? ' (right-hand seat)' : ''}',
      (tester) async {
        var rolls = 0;
        await _pumpPanel(
          tester,
          mirrored: mirrored,
          speech: 'Watch this six!',
          onRoll: () => rolls++,
        );
        final bubble = tester.getRect(find.text('Watch this six!'));
        final die = tester.getRect(find.byKey(_die));
        expect(
          bubble.overlaps(die),
          isTrue,
          reason: 'over the die: $bubble / $die',
        );
        // Level with it, not above the panel.
        expect((bubble.center.dy - die.center.dy).abs(), lessThan(12));
        // Taps go through to the die.
        await tester.tapAt(die.center);
        expect(rolls, 1);
      },
    );
  }

  testWidgets('no chat line, no bubble', (tester) async {
    await _pumpPanel(tester, mirrored: false);
    expect(find.byType(Text), findsWidgets);
    expect(find.text('Watch this six!'), findsNothing);
  });
}
