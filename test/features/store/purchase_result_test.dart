import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/audio/game_audio.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/widgets/confetti_burst.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/store/data/store_repository.dart';
import 'package:utopia/features/store/presentation/purchase_result.dart';
import 'package:utopia/features/store/presentation/web_payment_return.dart';

/// Hears what the modal plays.
class _Ears extends GameAudio {
  _Ears() : super(const SoundSettings(musicOn: false, sfxOn: false));

  final heard = <Sfx>[];

  @override
  void play(Sfx sfx, {double volume = 1}) => heard.add(sfx);
}

class _Card {
  _Card(this.result, this.ears);

  final ValueNotifier<PurchaseResult> result;
  final _Ears ears;
  var closed = 0;
  var triedAgain = 0;
}

Future<_Card> _show(
  WidgetTester tester,
  PurchaseResult start, {
  bool still = false,
  int? balance = 40000,
}) async {
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
  });
  final prefs = await SharedPreferences.getInstance();
  final card = _Card(ValueNotifier(start), _Ears());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gameAudioProvider.overrideWithValue(card.ears),
        coinBalanceProvider.overrideWith(
          (ref) =>
              balance == null ? const Stream.empty() : Stream.value(balance),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: Scaffold(
            body: Center(
              child: PurchaseResultView(
                result: card.result,
                onClose: () => card.closed++,
                onTryAgain: () => card.triedAgain++,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return card;
}

/// Past the count-up and the confetti.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('paid for coins: what landed, what was paid, the new balance', (
    tester,
  ) async {
    final card = await _show(
      tester,
      const PurchaseResult(
        stage: PurchaseStage.paid,
        coins: 20000,
        paid: '₦1,000',
        balance: 40000,
      ),
    );
    expect(find.text('Payment received!'), findsOneWidget);
    expect(find.text('+20,000'), findsOneWidget);
    expect(find.text('You paid ₦1,000'), findsOneWidget);
    expect(find.text('New balance'), findsOneWidget);
    expect(find.text('40,000'), findsOneWidget);
    expect(card.ears.heard, [Sfx.purchase]);
    await tester.tap(find.text('Lovely!'));
    expect(card.closed, 1);
  });

  testWidgets('the live balance shows when it has caught up', (tester) async {
    await _show(
      tester,
      const PurchaseResult(
        stage: PurchaseStage.paid,
        coins: 20000,
        balance: 30000,
      ),
      balance: 45000,
    );
    expect(find.text('45,000'), findsOneWidget);
  });

  testWidgets('paid with reduced motion: no confetti, the coins at once', (
    tester,
  ) async {
    await _show(
      tester,
      const PurchaseResult(stage: PurchaseStage.paid, coins: 55000),
      still: true,
    );
    expect(find.byType(ConfettiBurst), findsNothing);
    expect(find.text('+55,000'), findsOneWidget);
  });

  testWidgets('paid with motion: a celebration', (tester) async {
    await _show(
      tester,
      const PurchaseResult(stage: PurchaseStage.paid, coins: 55000),
    );
    expect(find.byType(ConfettiBurst), findsOneWidget);
  });

  testWidgets('Chip Maestro: a welcome, and the price a month', (tester) async {
    final card = await _show(
      tester,
      const PurchaseResult(
        stage: PurchaseStage.paid,
        plan: true,
        paid: '£6.49',
      ),
    );
    expect(find.text('Welcome to Chip Maestro!'), findsOneWidget);
    expect(find.text('£6.49 a month, until you cancel'), findsOneWidget);
    await tester.tap(find.text("Let's create"));
    expect(card.closed, 1);
  });

  testWidgets('confirming, then paid the moment it is', (tester) async {
    final card = await _show(
      tester,
      const PurchaseResult(stage: PurchaseStage.confirming, coins: 20000),
    );
    expect(find.text('Confirming your payment…'), findsOneWidget);
    expect(card.ears.heard, isEmpty);
    card.result.value = card.result.value.copyWith(
      stage: PurchaseStage.paid,
      paid: '£1.00',
    );
    await _settle(tester);
    expect(find.text('Confirming your payment…'), findsNothing);
    expect(find.text('+20,000'), findsOneWidget);
    expect(find.text('You paid £1.00'), findsOneWidget);
    expect(card.ears.heard, [Sfx.purchase]);
  });

  testWidgets('still confirming after the wait: a notification will come', (
    tester,
  ) async {
    await _show(
      tester,
      const PurchaseResult(stage: PurchaseStage.waiting, coins: 20000),
    );
    expect(
      find.text(
        "We'll add your coins as soon as Flutterwave confirms. "
        "You'll get a notification.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed or cancelled: nothing charged, try again or close', (
    tester,
  ) async {
    final card = await _show(
      tester,
      const PurchaseResult(stage: PurchaseStage.failed, coins: 20000),
    );
    expect(find.text("The payment didn't go through"), findsOneWidget);
    expect(find.text('Nothing was charged.'), findsOneWidget);
    expect(card.ears.heard, [Sfx.toggleOff]);
    await tester.tap(find.text('Try again'));
    expect(card.triedAgain, 1);
    await tester.tap(find.text('Close'));
    expect(card.closed, 1);
  });

  testWidgets("couldn't confirm: honest, and where it will show", (
    tester,
  ) async {
    await _show(
      tester,
      const PurchaseResult(stage: PurchaseStage.unconfirmed, coins: 20000),
    );
    expect(find.textContaining("couldn't confirm"), findsWidgets);
    expect(find.textContaining('in your notifications'), findsOneWidget);
  });

  testWidgets('a store purchase still going through says so', (tester) async {
    await _show(
      tester,
      const PurchaseResult(
        stage: PurchaseStage.waiting,
        via: PurchaseVia.store,
        plan: true,
      ),
    );
    expect(find.textContaining('Chip Maestro starts as soon'), findsOneWidget);
  });

  group('settling a web payment', () {
    PurchaseResult start() =>
        const PurchaseResult(stage: PurchaseStage.confirming, coins: 20000);

    testWidgets('asks every few seconds until it is paid', (tester) async {
      final answers = [
        const WebConfirmation(status: 'pending'),
        const WebConfirmation(status: 'error'),
        const WebConfirmation(
          status: 'paid',
          coins: 20000,
          balance: 41000,
          amount: 1000,
          currency: 'NGN',
        ),
      ];
      var asked = 0;
      final settler = WebPaymentSettler(
        start: start(),
        confirm: () async => answers[asked++],
      );
      settler.start();
      await tester.pump();
      expect(settler.result.value.stage, PurchaseStage.confirming);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      expect(asked, 3);
      final r = settler.result.value;
      expect(r.stage, PurchaseStage.paid);
      expect(r.paid, '₦1,000');
      expect(r.balance, 41000);
      await tester.pump(const Duration(seconds: 10));
      expect(asked, 3);
      settler.dispose();
    });

    testWidgets('after two minutes, stops and says it will come', (
      tester,
    ) async {
      var asked = 0;
      final settler = WebPaymentSettler(
        start: start(),
        confirm: () async {
          asked++;
          return const WebConfirmation(status: 'pending');
        },
      );
      settler.start();
      await tester.pump(const Duration(seconds: 119));
      expect(settler.result.value.stage, PurchaseStage.confirming);
      await tester.pump(const Duration(seconds: 1));
      expect(settler.result.value.stage, PurchaseStage.waiting);
      final before = asked;
      await tester.pump(const Duration(seconds: 20));
      expect(asked, before);
      settler.dispose();
    });

    testWidgets('the coins in the live balance are as good as paid', (
      tester,
    ) async {
      final settler = WebPaymentSettler(
        start: start(),
        confirm: () async => const WebConfirmation(status: 'pending'),
      );
      settler.start();
      settler.balanceNow(5000);
      settler.balanceNow(5100);
      expect(settler.result.value.stage, PurchaseStage.confirming);
      settler.balanceNow(25000);
      expect(settler.result.value.stage, PurchaseStage.paid);
      expect(settler.result.value.balance, 25000);
      settler.dispose();
    });

    testWidgets('failed, unknown and another account settle at once', (
      tester,
    ) async {
      Future<PurchaseResult> after(String status) async {
        final settler = WebPaymentSettler(
          start: start(),
          confirm: () async => WebConfirmation(status: status),
        );
        settler.start();
        await tester.pump();
        settler.dispose();
        return settler.result.value;
      }

      expect((await after('failed')).stage, PurchaseStage.failed);
      expect((await after('cancelled')).stage, PurchaseStage.failed);
      expect((await after('unknown')).stage, PurchaseStage.unconfirmed);
      final other = await after('other');
      expect(other.stage, PurchaseStage.unconfirmed);
      expect(other.otherAccount, isTrue);
    });

    testWidgets('a cancelled checkout fails without asking', (tester) async {
      final settler = WebPaymentSettler(start: start(), confirm: null)..fail();
      expect(settler.result.value.stage, PurchaseStage.failed);
      expect(settler.result.value.coins, 20000);
      settler.dispose();
    });
  });

  test('a checkout is remembered for its own return only', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    rememberWebCheckout(prefs, ref: 'utopia-abc', coins: 20000, price: '£1.00');
    await Future<void>.delayed(Duration.zero);
    expect(recallWebCheckout(prefs, 'utopia-abc'), (
      coins: 20000,
      price: '£1.00',
    ));
    expect(recallWebCheckout(prefs, 'utopia-other'), isNull);
    forgetWebCheckout(prefs);
    await Future<void>.delayed(Duration.zero);
    expect(recallWebCheckout(prefs, 'utopia-abc'), isNull);
  });
}
