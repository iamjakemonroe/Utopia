// A phone screenshot of the friends popup's Friends tab, with who's
// online, into test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/friends_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/friends/data/friend_repository.dart';
import 'package:utopia/features/friends/data/presence.dart';
import 'package:utopia/features/friends/presentation/providers/friends_providers.dart';
import 'package:utopia/features/friends/presentation/widgets/friends_popup.dart';

const _friends = [
  ('f1', 'Amara', 'amara_o', 'human', 3),
  ('f2', 'Kofi', 'kofi.b', 'animal', 7),
  ('f3', 'Lena', 'lena', 'plant', 2),
  ('f4', 'Tunde', 'tunde_plays', 'human', 5),
];

class _FakeFriends implements FriendRepository {
  @override
  Future<List<SocialProfile>> fetchFriends(String userId) async => [
    for (final (id, name, username, kind, seed) in _friends)
      SocialProfile(
        id: id,
        name: name,
        username: username,
        avatarUrl: null,
        avatarKind: kind,
        avatarSeed: seed,
      ),
  ];

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

void main() {
  testWidgets('friends tab, who is online', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'sound.sfx': false,
      'sound.music': false,
    });
    final prefs = await SharedPreferences.getInstance();
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
          friendRepositoryProvider.overrideWithValue(_FakeFriends()),
          // Kofi and Tunde are around.
          friendsOnlineProvider.overrideWith(
            (ref) => Stream.value(const {'f2', 'f4'}),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Scaffold(
            body: AppBackground(
              child: Builder(
                builder: (context) {
                  host = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
      final icons = File(
        '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytesSync();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
      await GoogleFonts.pendingFonts();
    });
    showFriendsPopup(host);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.textContaining('Friends ·'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Fonts the popup asked for once it was up.
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/friends_online.png'),
    );
  });
}
