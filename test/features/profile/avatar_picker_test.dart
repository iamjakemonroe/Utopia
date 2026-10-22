import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/generated_avatar.dart';
import 'package:utopia/features/profile/presentation/widgets/avatar_picker.dart';

void main() {
  /// Opens the picker as a new player's first step; returns what it gave
  /// back once [act] has run, or null.
  Future<(AvatarChoice?, bool)> pick(
    WidgetTester tester,
    Future<void> Function() act,
  ) async {
    AvatarChoice? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<AvatarChoice>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const AvatarPickerSheet(
                    currentKind: 'animal',
                    currentSeed: 3,
                    title: 'Choose your picture',
                    body: 'It is what friends see.',
                    skipLabel: 'Skip for now',
                  ),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your picture'), findsOneWidget);
    expect(find.text('It is what friends see.'), findsOneWidget);
    await act();
    await tester.pumpAndSettle();
    return (result, closed);
  }

  testWidgets('skipping keeps the avatar they were given', (tester) async {
    final (choice, closed) = await pick(
      tester,
      () => tester.tap(find.text('Skip for now')),
    );
    expect(closed, isTrue);
    expect(choice, isNull);
  });

  testWidgets('picking a drawn avatar gives it back', (tester) async {
    final (choice, _) = await pick(
      tester,
      () => tester.tap(find.byType(GeneratedAvatar).at(5)),
    );
    expect(choice?.kind, 'animal');
    expect(choice?.seed, 5);
  });

  testWidgets('the photo tab asks for a photo', (tester) async {
    final (choice, closed) = await pick(
      tester,
      () => tester.tap(find.byIcon(Icons.add_a_photo_rounded)),
    );
    expect(closed, isTrue);
    expect(choice, isNotNull);
    expect(choice!.kind, isNull);
  });
}
