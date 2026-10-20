import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/theme/theme_controller.dart'
    show sharedPreferencesProvider;
import 'package:utopia/features/coins/data/coin_gift_repository.dart';
import 'package:utopia/features/coins/presentation/gift_note.dart';
import 'package:utopia/features/coins/presentation/send_coins_sheet.dart';
import 'package:utopia/features/notifications/data/notification_repository.dart';
import 'package:utopia/features/notifications/presentation/notification_center.dart';

class _Repo extends CoinGiftRepository {
  _Repo()
    : super(
        SupabaseClient(
          'http://127.0.0.1:9',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final sent = <({int coins, String pin, String? note})>[];

  @override
  Future<GiftResult> send({
    required String to,
    required int coins,
    required String key,
    required String pin,
    String? note,
  }) async {
    sent.add((coins: coins, pin: pin, note: note));
    return const GiftResult(ok: true);
  }
}

const _allowance = GiftAllowance(
  ok: true,
  why: null,
  balance: 4820,
  giftable: 4820,
  held: 0,
  holdDays: 14,
  min: 1,
  pinSet: true,
);

/// Opens the sheet, writes [note] (if any), picks 500 and enters the PIN.
Future<_Repo> _send(WidgetTester tester, {String? note}) async {
  tester.view.physicalSize = const Size(430 * 3, 932 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
  });
  final prefs = await SharedPreferences.getInstance();
  final repo = _Repo();
  late BuildContext host;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        giftAllowanceProvider.overrideWith((ref) async => _allowance),
        coinGiftRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    ),
  );
  showSendCoinsSheet(host, (
    id: 'f2',
    name: 'Kofi',
    avatarUrl: null,
    avatarKind: 'animal',
    avatarSeed: 7,
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text('500'));
  await tester.pump();
  if (note != null) {
    await tester.enterText(find.byType(TextField).last, note);
    await tester.pump();
  }
  await tester.tap(find.textContaining('Send 500'));
  await tester.pump(const Duration(milliseconds: 500));
  // The note's shown with the PIN, as it'll go.
  expect(find.byType(GiftNote), note == null ? findsNothing : findsOneWidget);
  for (final d in ['2', '5', '8', '0']) {
    await tester.tap(find.text(d).last);
    await tester.pump(const Duration(milliseconds: 60));
  }
  // The "sent" toast, gone.
  await tester.pump(const Duration(seconds: 4));
  return repo;
}

AppNotification _gift(Map<String, dynamic> data) => AppNotification(
  id: 1,
  kind: 'coin_gift',
  actorId: 'a',
  refId: 'g',
  data: data,
  readAt: null,
  createdAt: DateTime.now(),
);

void main() {
  testWidgets('a note goes with the gift, tidied, and shows before the PIN', (
    tester,
  ) async {
    final repo = await _send(tester, note: '  Happy   birthday!  ');
    expect(repo.sent, hasLength(1));
    expect(repo.sent.single.coins, 500);
    expect(repo.sent.single.note, 'Happy birthday!');
  });

  testWidgets('no note: none is sent', (tester) async {
    final repo = await _send(tester);
    expect(repo.sent.single.note, isNull);
  });

  testWidgets('the note field takes no new lines and stops at 140', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430 * 3, 932 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'sound.sfx': false});
    final prefs = await SharedPreferences.getInstance();
    late BuildContext host;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          giftAllowanceProvider.overrideWith((ref) async => _allowance),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                host = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    showSendCoinsSheet(host, (
      id: 'f2',
      name: 'Kofi',
      avatarUrl: null,
      avatarKind: 'animal',
      avatarSeed: 7,
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final field = find.byType(TextField).last;
    await tester.enterText(field, 'line one\nline two');
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller!.text,
      'line oneline two',
    );
    await tester.enterText(field, 'x' * 200);
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller!.text.length,
      kGiftNoteLength,
    );
    expect(find.text('140/140'), findsOneWidget);
  });

  test('the friend sees the note: in the notification and on their phone', () {
    final withNote = NotificationLook.of(
      _gift({'coins': 500, 'note': 'Happy birthday!'}),
      'Ada',
    );
    expect(withNote.title, contains('500'));
    expect(withNote.quote, 'Happy birthday!');

    final without = NotificationLook.of(_gift({'coins': 500}), 'Ada');
    expect(without.quote, isNull);
    final blank = NotificationLook.of(
      _gift({'coins': 500, 'note': '   '}),
      'Ada',
    );
    expect(blank.quote, isNull);
  });
}
