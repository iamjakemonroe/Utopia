// Every screen in the Doodle world (the one light world: ink on paper),
// looking for text that can't be read: drawn in a color too close to
// what's behind it (white on the paper, usually). Run:
// flutter test --run-skipped test/tool/doodle_contrast_audit_test.dart
@Tags(['sheet'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/audio/sound_controls.dart';
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/features/chip/presentation/chip_chat_sheet.dart';
import 'package:utopia/features/friends/presentation/widgets/friends_popup.dart';
import 'package:utopia/features/help/presentation/help_sheet.dart';
import 'package:utopia/features/home/presentation/widgets/side_menu.dart';
import 'package:utopia/features/maestro/presentation/maestro_sheet.dart';
import 'package:utopia/features/rankings/presentation/rankings_widgets.dart';
import 'package:utopia/features/store/presentation/coin_shop.dart';
import 'package:utopia/core/supabase/supabase_providers.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/auth/presentation/screens/auth_choice_screen.dart';
import 'package:utopia/features/birthday/presentation/birthday_screen.dart';
import 'package:utopia/features/chess/presentation/screens/chess_lobby_screen.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/collection/presentation/collection_screen.dart';
import 'package:utopia/features/doodle_studio/presentation/sketchbook_screen.dart';
import 'package:utopia/features/guess_doodle/presentation/chip_doodle_screen.dart';
import 'package:utopia/features/guess_doodle/presentation/guess_doodle_lobby_screen.dart';
import 'package:utopia/features/help/presentation/how_to_play_screen.dart';
import 'package:utopia/features/home/presentation/screens/home_screen.dart';
import 'package:utopia/features/ludo/presentation/screens/ludo_lobby_screen.dart';
import 'package:utopia/features/notifications/presentation/notifications_screen.dart';
import 'package:utopia/features/profile/presentation/screens/profile_screen.dart';
import 'package:utopia/features/rankings/data/rankings_repository.dart';
import 'package:utopia/features/rankings/domain/ranking.dart';
import 'package:utopia/features/rankings/presentation/rankings_screen.dart';
import 'package:utopia/features/settings/presentation/settings_screen.dart';
import 'package:utopia/features/store/data/store_repository.dart';
import 'package:utopia/features/store/presentation/store_controller.dart';
import 'package:utopia/features/store/presentation/store_screen.dart';
import 'package:utopia/features/support/presentation/privacy_screen.dart';
import 'package:utopia/features/support/presentation/report_bug_screen.dart';
import 'package:utopia/core/widgets/game_card_art.dart';

final _found = <String>[];

final _board = Leaderboard(
  top: [
    for (final (i, (name, rating)) in [
      ('Ada', 1820),
      ('Kofi', 1655),
      ('Lena', 1590),
      ('Ravi', 1430),
      ('Mia', 1290),
      ('Tunde', 1150),
      ('Sam', 1040),
    ].indexed)
      BoardEntry(
        place: i + 1,
        userId: 'u$i',
        profile: {'display_name': name, 'avatar_seed': i * 7 + 3},
        rating: rating,
        games: 20 + i,
        house: i == 1,
      ),
  ],
  myPlace: 3,
  myRating: 1588,
  myGames: 40,
);

/// Owns the Doodle world (signed out, nothing's owned, and the store would
/// move them out of it).
class _OwnsDoodle extends StoreRepository {
  _OwnsDoodle(super.client);

  @override
  Future<Set<String>> fetchOwned() async => {UtopiaThemes.utopiaDoodle.id};
}

final _shotKey = GlobalKey();

double _lum(int r, int g, int b) {
  double c(int v) {
    final s = v / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b);
}

/// The text on screen too faint against what's behind it.
Future<void> _audit(WidgetTester tester, String screen) async {
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final w = image.width;
  final h = image.height;
  final seen = <String>{};
  void walk(RenderObject r) {
    if (r is RenderParagraph && r.attached && r.hasSize) {
      final text = r.text.toPlainText().trim();
      final rect = MatrixUtils.transformRect(
        r.getTransformTo(boundary),
        Offset.zero & r.size,
      ).intersect(Offset.zero & Size(w.toDouble(), h.toDouble()));
      if (text.isNotEmpty && rect.width >= 4 && rect.height >= 6) {
        final lums = <double>[];
        for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
          for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
            final i = (y * w + x) * 4;
            lums.add(
              _lum(
                bytes.getUint8(i),
                bytes.getUint8(i + 1),
                bytes.getUint8(i + 2),
              ),
            );
          }
        }
        if (lums.length > 20) {
          final sorted = [...lums]..sort();
          final bg = sorted[sorted.length ~/ 2];
          // The ink: the pixels furthest from the background.
          final far = [...lums]
            ..sort((a, b) => (b - bg).abs().compareTo((a - bg).abs()));
          final ink = far[(far.length * 0.03).floor()];
          final ratio = (math.max(bg, ink) + 0.05) / (math.min(bg, ink) + 0.05);
          if (ratio < 1.8) {
            final chain = r.debugCreator
                .toString()
                .split('\n')
                .first
                .split(' ← ')
                .skip(1)
                .take(7)
                .join(' ← ');
            final key = '$screen|$text|$chain';
            if (seen.add(key)) {
              _found.add(
                '[$screen] "${text.length > 40 ? text.substring(0, 40) : text}" '
                'contrast ${ratio.toStringAsFixed(2)} (bg ${bg.toStringAsFixed(2)}) <- $chain',
              );
            }
          }
        }
      }
    }
    r.visitChildren(walk);
  }

  walk(boundary);
  final png = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  ))!;
  File('build/doodle/${screen.replaceAll(' ', '_')}.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png.buffer.asUint8List());
  image.dispose();
}

Future<void> _show(
  WidgetTester tester,
  String name,
  Widget screen, {
  Future<void> Function(WidgetTester tester)? then,
}) async {
  UtopiaThemes.active = UtopiaThemes.utopiaDoodle;
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
    'utopia.theme': UtopiaThemes.utopiaDoodle.id,
  });
  final prefs = await SharedPreferences.getInstance();
  final client = SupabaseClient(
    'http://127.0.0.1:9',
    'test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          supabaseClientProvider.overrideWithValue(client),
          storeRepositoryProvider.overrideWithValue(_OwnsDoodle(client)),
          currentUserProvider.overrideWithValue(null),
          isAnonymousProvider.overrideWithValue(false),
          coinBalanceProvider.overrideWith((ref) => Stream.value(1250)),
          leaderboardProvider.overrideWith((ref, key) async => _board),
          myRecordProvider.overrideWith(
            (ref, game) async => const PlayerRecord(
              rating: 1588,
              best: 1610,
              games: 40,
              wins: 26,
              losses: 12,
              draws: 2,
            ),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: GoRouter(
            initialLocation: '/screen',
            routes: [
              GoRoute(path: '/screen', builder: (_, _) => screen),
              GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
            ],
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
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  await then?.call(tester);
  // Whatever went wrong without a server (no data) isn't what's checked.
  while (tester.takeException() != null) {}
  await _audit(tester, name);
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  while (tester.takeException() != null) {}
  tester.view.reset();
}

/// A screen that opens a sheet or menu over itself once it's up.
class _Opens extends ConsumerStatefulWidget {
  const _Opens(this.open);

  final void Function(BuildContext context, WidgetRef ref) open;

  @override
  ConsumerState<_Opens> createState() => _OpensState();
}

class _OpensState extends ConsumerState<_Opens> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.open(context, ref),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: AppBackground(child: SizedBox.expand()));
}

void main() {
  tearDownAll(() {
    final out = File('build/doodle_contrast.txt')..createSync(recursive: true);
    out.writeAsStringSync(_found.join('\n'));
    // ignore: avoid_print
    print('${_found.length} faint texts; see build/doodle_contrast.txt');
  });

  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'profile': const ProfileScreen(),
    'store': const StoreScreen(),
    'store worlds': const StoreScreen(initialTab: 1),
    'collection': const CollectionScreen(),
    'rankings': const RankingsScreen(),
    'how to play': const HowToPlayScreen(),
    'notifications': const NotificationsScreen(),
    'settings': const SettingsScreen(),
    'sketchbook': const SketchbookScreen(),
    'privacy': const PrivacyScreen(),
    'report bug': const ReportBugScreen(),
    'chess lobby': const ChessLobbyScreen(),
    'checkers lobby': const ChessLobbyScreen(game: GameKind.checkers),
    'ludo lobby': const LudoLobbyScreen(),
    'doodle lobby': const GuessDoodleLobbyScreen(),
    'chip doodle': const ChipDoodleScreen(),
    'auth': const AuthChoiceScreen(),
    'birthday': const BirthdayScreen(onboarding: true),
    'side menu': _Opens((c, r) => showSideMenu(c, r)),
    'friends': _Opens((c, r) => showFriendsPopup(c)),
    'coin shop': _Opens((c, r) => showCoinShop(c)),
    'chip chat': _Opens((c, r) => showChipChat(c)),
    'help': _Opens((c, r) => showHelpSheet(c, from: 'home')),
    'tier guide': _Opens((c, r) => showTierGuide(c)),
    'sound': _Opens((c, r) => showSoundSettings(c)),
    'maestro': _Opens((c, r) => showMaestroSheet(c)),
  };
  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets(name, (tester) => _show(tester, name, screen));
  }
}
