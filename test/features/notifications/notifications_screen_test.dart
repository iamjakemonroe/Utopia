import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/profiles/profile_providers.dart';
import 'package:utopia/core/profiles/profile_repository.dart';
import 'package:utopia/core/supabase/supabase_providers.dart';
import 'package:utopia/core/theme/theme_controller.dart'
    show sharedPreferencesProvider;
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/notifications/data/notification_repository.dart';
import 'package:utopia/features/notifications/presentation/notifications_screen.dart';

const _ada = '00000000-0000-4000-8000-00000000000a';
const _bo = '00000000-0000-4000-8000-00000000000b';

class _Profiles extends ProfileRepository {
  _Profiles(super.client);

  final batches = <List<String>>[];
  var singles = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchByIds(List<String> ids) async {
    batches.add(ids);
    return [
      {'id': _ada, 'display_name': 'Ada', 'username': 'ada'},
      {'id': _bo, 'display_name': 'Bo', 'username': 'bo'},
    ].where((p) => ids.contains(p['id'])).toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchById(String id) async {
    singles++;
    return null;
  }
}

AppNotification _n(
  int id,
  String kind,
  String? actor, {
  Map<String, dynamic> data = const {
    'status': 'fixed',
    'note': 'Fixed, thanks!',
  },
}) => AppNotification(
  id: id,
  kind: kind,
  actorId: actor,
  refId: 'ref-$id',
  data: data,
  readAt: null,
  createdAt: DateTime.now().subtract(Duration(minutes: id)),
);

void main() {
  testWidgets('everyone in the notifications is fetched at once', (
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
    final profiles = _Profiles(client);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          supabaseClientProvider.overrideWithValue(client),
          profileRepositoryProvider.overrideWithValue(profiles),
          currentUserProvider.overrideWithValue(null),
          notificationsProvider.overrideWith(
            (ref) => Stream.value([
              _n(1, 'friend_request', _ada),
              _n(2, 'friend_accepted', _bo),
              _n(3, 'game_invite', _ada),
              _n(4, 'report_update', null),
              _n(
                5,
                'coin_gift',
                _bo,
                data: const {'coins': 500, 'note': 'Happy birthday, Ada!'},
              ),
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

    expect(find.textContaining('Ada'), findsWidgets);
    expect(find.textContaining('Bo '), findsWidgets);
    // A gift's note, in their own words.
    expect(find.text('Happy birthday, Ada!'), findsOneWidget);
    expect(profiles.batches, [
      [_ada, _bo],
    ]);
    expect(profiles.singles, 0);

    // Gone before it marks them read (that needs a signed-in player).
    await tester.pumpWidget(const SizedBox());
  });
}
