import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bots/bots.dart';
import '../../core/router/app_router.dart';
import '../auth/presentation/providers/auth_providers.dart';
import '../chip/presentation/chip_chat_sheet.dart';
import '../help/presentation/help_sheet.dart';
import '../ludo/presentation/controllers/ludo_match_controller.dart';
import '../ludo/presentation/widgets/ludo_setup_widgets.dart';
import '../store/presentation/coin_shop.dart';

/// A tour of every screen, for checking layouts (say on an iPad
/// simulator, taking screenshots as it goes). Only in debug builds run
/// with --dart-define=SCREEN_TOUR=true: signs in as a guest if need be,
/// then opens each screen in turn, in portrait and then landscape,
/// printing "TOUR orientation name" once each has settled.
const kScreenTour = bool.fromEnvironment('SCREEN_TOUR');

/// Just these stops (comma-separated names), when given.
const _only = String.fromEnvironment('TOUR_ONLY');

/// Around the whole app in tour builds, to photograph it.
final screenTourShots = GlobalKey(debugLabel: 'screen tour');

/// The size the app lays itself out at during the tour (scaled to fit the
/// real screen): null for the real screen's.
final screenTourCanvas = ValueNotifier<Size?>(null);

/// Starts the tour (watched at the app's root, in tour builds only).
final screenTourProvider = Provider<void>((ref) {
  if (!kDebugMode || !kScreenTour) return;
  Future<void>.delayed(const Duration(seconds: 8), () => _tour(ref));
});

typedef _Stop = (String name, Future<void> Function(BuildContext) open);

Future<void> _tour(Ref ref) async {
  final router = ref.read(goRouterProvider);
  Future<void> settle([int seconds = 3]) =>
      Future<void>.delayed(Duration(seconds: seconds));

  // Photos go in the app's documents, under tour/ (on the simulator:
  // xcrun simctl get_app_container <device> <bundle id> data).
  final dir = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/tour',
  )..createSync(recursive: true);

  Future<void> shot(String orientation, String name) async {
    final boundary =
        screenTourShots.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png != null) {
        File(
          '${dir.path}/${orientation}_$name.png',
        ).writeAsBytesSync(png.buffer.asUint8List());
      }
    }
    debugPrint('TOUR $orientation $name');
  }

  BuildContext? context() => router.routerDelegate.navigatorKey.currentContext;

  void closeSheets() {
    final ctx = context();
    if (ctx == null) return;
    Navigator.of(ctx, rootNavigator: true).popUntil((r) => r is! PopupRoute);
  }

  // Signed out: the start screen first, then in as a guest.
  if (ref.read(authRepositoryProvider).currentSession == null) {
    await shot('ipad', 'auth');
    await ref.read(authRepositoryProvider).signInAnonymously();
    await settle(4);
  }
  final me = ref.read(currentUserProvider)?.id ?? 'me';

  String ludoGame() =>
      '/ludo/${startLocalLudo(LocalLudoSetup(playerIds: [me, for (final b in kLudoBots.take(3)) b.id], colors: ludoSeatColors(4), humanId: me))}';

  final stops = <_Stop>[
    for (final (name, route) in [
      ('home', '/home'),
      ('profile', '/profile'),
      ('store', '/store'),
      ('store_auras', '/store?tab=auras'),
      ('collection', '/collection'),
      ('rankings', '/rankings'),
      ('how_to_play', '/how-to-play'),
      ('notifications', '/notifications'),
      ('settings', '/settings'),
      ('sketchbook', '/sketchbook'),
      ('studio', '/sketchbook/new'),
      ('privacy', '/privacy'),
      ('report_bug', '/report-bug'),
      ('chess_lobby', '/chess'),
      ('chess_bot', '/chess/bot?opponent=chip&level=normal&color=white'),
      ('checkers_lobby', '/checkers'),
      ('checkers_bot', '/checkers/bot?opponent=chip&color=white'),
      ('ludo_lobby', '/ludo'),
      ('doodle_lobby', '/guess-my-doodle'),
      ('doodle_chip', '/guess-my-doodle/chip'),
      ('birthday', '/birthday'),
      ('email', '/auth/link'),
    ])
      (name, (_) async => router.go(route)),
    ('ludo_game', (_) async => router.go(ludoGame())),
    (
      'chip_chat',
      (ctx) async {
        router.go('/home');
        await settle(2);
        final c = context();
        if (c != null && c.mounted) unawaited(showChipChat(c));
      },
    ),
    (
      'coin_shop',
      (ctx) async {
        final c = context();
        if (c != null && c.mounted) unawaited(showCoinShop(c));
      },
    ),
    (
      'help',
      (ctx) async {
        final c = context();
        if (c != null && c.mounted) {
          unawaited(showHelpSheet(c, from: '/home'));
        }
      },
    ),
  ];

  // An iPad upright and on its side, and a phone (to check nothing
  // changed there).
  for (final (orientation, canvas) in [
    ('ipad', const Size(1024, 1366)),
    ('ipad_landscape', const Size(1366, 1024)),
    ('phone', const Size(390, 844)),
  ]) {
    screenTourCanvas.value = canvas;
    await settle(2);
    for (final (name, open) in stops) {
      if (_only.isNotEmpty && !_only.split(',').contains(name)) continue;
      closeSheets();
      final ctx = context();
      if (ctx == null || !ctx.mounted) continue;
      try {
        await open(ctx);
      } catch (e) {
        debugPrint('TOUR-FAILED $name $e');
        continue;
      }
      await settle(3);
      await shot(orientation, name);
    }
    closeSheets();
  }
  screenTourCanvas.value = null;
  router.go('/home');
  debugPrint('TOUR done');
}
