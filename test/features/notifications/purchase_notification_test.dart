import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/supabase/supabase_providers.dart';
import 'package:utopia/core/theme/theme_controller.dart'
    show sharedPreferencesProvider;
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/notifications/data/notification_repository.dart';
import 'package:utopia/features/notifications/presentation/notification_center.dart';
import 'package:utopia/features/notifications/presentation/notifications_screen.dart';

AppNotification _bought(int id, Map<String, dynamic> data) => AppNotification(
  id: id,
  kind: 'purchase',
  actorId: null,
  refId: null,
  data: data,
  readAt: null,
  createdAt: DateTime.now().subtract(Duration(minutes: id)),
);

const _naira = {
  'app': 'utopia',
  'product_id': 'utopia.coins.starter',
  'title': '20,000 coins',
  'coins': 20000,
  'amount': 1000,
  'currency': 'NGN',
  'renewal': false,
  'ref': 'utopia-abc',
};

const _maestro = {
  'app': 'utopia',
  'product_id': 'utopia.maestro.monthly',
  'title': 'Chip Maestro',
  'amount': 6.49,
  'currency': 'GBP',
  'renewal': false,
  'period': 'monthly',
};

NotificationLook _look(Map<String, dynamic> data) =>
    NotificationLook.of(_bought(1, data), 'Utopia');

void main() {
  group('a purchase reads', () {
    test('coins, with what was paid', () {
      final look = _look(_naira);
      expect(look.title, 'You bought 20,000 coins · ₦1,000');
      expect(look.icon, Icons.monetization_on_rounded);
    });

    test('coins bought in another app name it', () {
      expect(
        _look({
          ..._naira,
          'app': 'chip',
          'coins': 55000,
          'amount': 3.99,
          'currency': 'GBP',
        }).title,
        'You bought 55,000 coins in Chip Rizz · £3.99',
      );
    });

    test('coins from the App Store, which keeps the price', () {
      expect(
        _look({
          'app': 'utopia',
          'product_id': 'utopia.coins.chest',
          'coins': 120000,
          'renewal': false,
          'platform': 'ios',
        }).title,
        'You bought 120,000 coins',
      );
    });

    test('Chip Maestro, on, at its price a month', () {
      final look = _look(_maestro);
      expect(look.title, 'Chip Maestro is on · £6.49 a month');
      expect(look.icon, Icons.auto_awesome_rounded);
    });

    test('Chip Maestro renewed', () {
      final look = _look({..._maestro, 'renewal': true});
      expect(look.title, 'Chip Maestro renewed · £6.49');
      expect(look.subtitle, 'Another month, paid. Thank you!');
      expect(
        _look({
          'app': 'utopia',
          'product_id': 'utopia.maestro.monthly',
          'renewal': true,
        }).title,
        'Chip Maestro renewed',
      );
    });

    test("another app's plan names the app", () {
      final look = _look({
        'app': 'study',
        'product_id': 'study.pro.student.monthly',
        'title': 'Chip Study Pro (student)',
        'amount': 5.49,
        'currency': 'EUR',
        'renewal': false,
        'period': 'monthly',
      });
      expect(look.title, 'Chip Study Pro is on · €5.49 a month');
      expect(look.subtitle, 'Ready in Chip Study.');
      expect(
        _look({
          'app': 'chip',
          'product_id': 'rizz.pro.weekly',
          'amount': 3.99,
          'currency': 'USD',
          'renewal': false,
          'period': 'weekly',
        }).title,
        r'Chip Rizz Pro is on · $3.99 a week',
      );
    });

    test('it comes from Utopia, not a player', () {
      expect(NotificationLook.fromUtopia(_bought(1, _naira)), isTrue);
    });
  });

  testWidgets('purchases in the notifications, with a way onward', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sound.sfx': false,
      'sound.music': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final client = SupabaseClient(
      'http://127.0.0.1:9',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          supabaseClientProvider.overrideWithValue(client),
          currentUserProvider.overrideWithValue(null),
          notificationsProvider.overrideWith(
            (ref) => Stream.value([
              _bought(1, _naira),
              _bought(2, _maestro),
              _bought(3, {
                'app': 'study',
                'product_id': 'study.pro.monthly',
                'renewal': false,
                'period': 'monthly',
              }),
            ]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/notifications',
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SizedBox()),
              GoRoute(
                path: '/notifications',
                builder: (_, _) => const NotificationsScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('You bought 20,000 coins · ₦1,000'), findsOneWidget);
    expect(find.text('Chip Maestro is on · £6.49 a month'), findsOneWidget);
    expect(find.text('Chip Study Pro is on'), findsOneWidget);
    expect(find.byIcon(Icons.monetization_on_rounded), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
    // Each goes somewhere: the coin shop, the plan, the app it's in.
    expect(find.text('Coin shop'), findsOneWidget);
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('Open Chip Study'), findsOneWidget);

    // Gone before it marks them read (that needs a signed-in player).
    await tester.pumpWidget(const SizedBox());
  });
}
