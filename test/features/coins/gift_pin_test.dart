import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/theme/theme_controller.dart'
    show sharedPreferencesProvider;
import 'package:utopia/features/coins/data/coin_gift_repository.dart';
import 'package:utopia/features/coins/presentation/gift_pin.dart';

class _Repo extends CoinGiftRepository {
  _Repo()
    : super(
        SupabaseClient(
          'http://127.0.0.1:9',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final saved = <(String, String?)>[];
  GiftResult answer = const GiftResult(ok: true);

  @override
  Future<GiftResult> setPin(String pin, {String? current}) async {
    saved.add((pin, current));
    return answer;
  }
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  test('obvious PINs are turned away, others do', () {
    for (final pin in ['0000', '9999', '1234', '6789', '9876', '3210']) {
      expect(giftPinProblem(pin), isNotNull, reason: pin);
    }
    for (final pin in ['123', '12a4', '']) {
      expect(giftPinProblem(pin), 'Four digits, please.', reason: pin);
    }
    for (final pin in ['2580', '1590', '7391', '1122']) {
      expect(giftPinProblem(pin), isNull, reason: pin);
    }
    expect(maskEmail('jake@gmail.com'), 'j•••@gmail.com');
  });

  testWidgets('the keypad: digits, deleting, and done at four', (tester) async {
    final done = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GiftPinPad(title: 'Enter your gift PIN', onDone: done.add),
        ),
      ),
    );
    await _type(tester, '25');
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pump();
    await _type(tester, '581');
    expect(done, ['2581']);
  });

  testWidgets('choosing a PIN: an obvious one, a slip, then saved', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'sound.sfx': false});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repo();
    final done = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          coinGiftRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GiftPinFlow(goal: GiftPinGoal.set, onDone: done.add),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Choose a gift PIN'), findsOneWidget);

    await _type(tester, '1234');
    expect(find.textContaining('too easy'), findsOneWidget);

    await _type(tester, '2580');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Enter it again'), findsOneWidget);
    await _type(tester, '2581');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining("didn't match"), findsOneWidget);
    expect(find.text('Choose a gift PIN'), findsOneWidget);
    expect(repo.saved, isEmpty);

    await _type(tester, '2580');
    await tester.pump(const Duration(milliseconds: 300));
    await _type(tester, '2580');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.saved, [('2580', null)]);
    expect(done, ['2580']);
  });

  testWidgets('what the server says is shown', (tester) async {
    SharedPreferences.setMockInitialValues({'sound.sfx': false});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repo()..answer = const GiftResult(ok: false, why: 'weak');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          coinGiftRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GiftPinFlow(goal: GiftPinGoal.set, onDone: (_) {}),
            ),
          ),
        ),
      ),
    );
    await _type(tester, '7391');
    await tester.pump(const Duration(milliseconds: 300));
    await _type(tester, '7391');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('too easy'), findsOneWidget);
    expect(
      giftPinWhy(const GiftResult(ok: false, why: 'wrong_pin', triesLeft: 3)),
      'Wrong PIN. 3 tries left.',
    );
  });
}
