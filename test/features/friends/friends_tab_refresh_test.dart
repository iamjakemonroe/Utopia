import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/friends/data/friend_repository.dart';
import 'package:utopia/features/friends/data/presence.dart';
import 'package:utopia/features/friends/presentation/providers/friends_providers.dart';
import 'package:utopia/features/friends/presentation/widgets/friends_popup.dart';
import 'package:utopia/features/friends/presentation/widgets/online_bubble.dart';

class _Friends implements FriendRepository {
  var asked = 0;

  @override
  Future<List<SocialProfile>> fetchFriends(String userId) async {
    asked++;
    return const [
      SocialProfile(
        id: 'f1',
        name: 'Kofi',
        username: 'kofi',
        avatarUrl: null,
        avatarKind: 'animal',
        avatarSeed: 7,
      ),
    ];
  }

  @override
  Future<List<SocialProfile>> fetchRecents(String userId) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchIncomingFriendRequests(
    String userId,
  ) async => const [];

  @override
  Future<Set<String>> fetchOutgoingRequestIds(String userId) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _bubble({required bool online}) =>
    find.byWidgetPredicate((w) => w is OnlineBubble && w.online == online);

void main() {
  testWidgets('pulling the Friends tab down asks who is around again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'sound.sfx': false});
    final prefs = await SharedPreferences.getInstance();
    final friends = _Friends();
    var looks = 0;
    late BuildContext host;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(
            const User(
              id: 'me',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-10-19T00:00:00Z',
            ),
          ),
          friendRepositoryProvider.overrideWithValue(friends),
          friendsOnlineProvider.overrideWith((ref) {
            looks++;
            return Stream.value(looks == 1 ? const <String>{} : const {'f1'});
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
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
    showFriendsPopup(host);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.textContaining('Friends ·'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_bubble(online: false), findsOneWidget);
    final before = (looks, friends.asked);

    await tester.fling(find.text('Kofi'), const Offset(0, 400), 1000);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(looks, greaterThan(before.$1));
    expect(friends.asked, greaterThan(before.$2));
    expect(_bubble(online: true), findsOneWidget);
  });
}
