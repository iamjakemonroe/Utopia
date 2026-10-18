// Phone screenshots of Chip drawing real portraits, for showing the idea
// before the image model is switched on. The pictures are stand-ins made
// on this computer; pass their folder and the app's fonts:
// flutter test --run-skipped --update-goldens \
//   --dart-define=DEMO=<folder with einstein_art.png, parrot_art.png,
//   parrot_photo.jpg> --dart-define=FONTS=<folder with Inter_400.ttf ...
//   SpaceGrotesk_700.ttf> test/tool/chip_portrait_demo_test.dart
// Renders test/tool/goldens/demo_1_ask.png to demo_4_photo.png.
@Tags(['sheet'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/chip/chip_brain.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/chip/presentation/chip_chat_controller.dart';
import 'package:utopia/features/chip/presentation/chip_chat_sheet.dart';
import 'package:utopia/features/doodle_studio/data/picture_library.dart';
import 'package:utopia/features/doodle_studio/domain/coloring_pages.dart';
import 'package:utopia/features/doodle_studio/domain/line_art.dart';

const _demo = String.fromEnvironment('DEMO');
const _fonts = String.fromEnvironment('FONTS');

Future<void> _loadFonts() async {
  Future<void> add(String family, String file) async {
    final bytes = File(file).readAsBytesSync();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }

  // google_fonts names each weight '<Family>_<weight>' ('regular' for
  // 400); registering those names here means it never has to fetch them.
  for (final w in const [400, 500, 600, 700, 800, 900]) {
    final variant = w == 400 ? 'regular' : '$w';
    await add('Inter_$variant', '$_fonts/Inter_$w.ttf');
    await add(
      'SpaceGrotesk_$variant',
      '$_fonts/SpaceGrotesk_${w > 700 ? 700 : w}.ttf',
    );
  }
  // The test runner lives in the SDK's cache/artifacts/engine/<platform>.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  await add(
    'MaterialIcons',
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  );
}

/// google_fonts would fetch the fonts (and fail in a test); with requests
/// that never answer it just waits, and the fonts loaded here are used.
class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Silent();
}

class _Silent implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required List<ChipLine> lines,
  UtopiaTheme world = UtopiaThemes.utopiaTwilight,
}) async {
  UtopiaThemes.active = world;
  addTearDown(() => UtopiaThemes.active = UtopiaThemes.utopiaTwilight);
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'chip_chat_me': jsonEncode([for (final l in lines) l.toStore()]),
    // No sound plugin in tests.
    'sound.sfx': false,
    'sound.music': false,
    // The world the theme controller starts in.
    'utopia.theme': world.id,
  });
  final prefs = await SharedPreferences.getInstance();
  HttpOverrides.global = _NoNetwork();
  LineArt.source = (path) async => File('$_demo/$path').readAsBytesSync();
  await tester.runAsync(() async {
    await _loadFonts();
    for (final id in const ['einstein', 'parrot']) {
      await LineArt.load(
        ColoringPage.fromArt(id: 'p:$id', name: id, artPath: '${id}_art.png'),
      );
    }
    // Into the image cache, so the sent photo shows on the first frame.
    final done = Completer<void>();
    FileImage(File('$_demo/parrot_photo.jpg'))
        .resolve(ImageConfiguration.empty)
        .addListener(ImageStreamListener((_, _) => done.complete()));
    await done.future;
  });
  late BuildContext host;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isAnonymousProvider.overrideWithValue(false),
        chipChatProvider.overrideWith(
          (ref) => ChipChatController(ref, prefs, 'me'),
        ),
        pictureWatchProvider.overrideWith(
          (ref, id) => Stream.value(
            LibraryPicture(
              id: id,
              status: 'ready',
              title: id == 'einstein' ? 'Albert Einstein' : 'My parrot',
              art: '${id}_art.png',
            ),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            host = context;
            return Stack(
              children: [
                Positioned.fill(
                  child: UtopiaWorld(style: UtopiaThemes.active.world),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  showChipChat(host);
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/demo_$name.png'),
  );
}

const _askEinstein = ChipLine(
  fromChip: false,
  text: 'Can you draw Albert Einstein?',
);
const _offerEinstein = ChipLine(
  fromChip: true,
  text:
      'The genius with the wild hair! I can have him drawn for real, so he '
      'looks just like himself.',
  mood: 'excited',
  portrait: ChipPortraitOffer(subject: 'Albert Einstein', state: 'free'),
);
const _sendParrot = ChipLine(
  fromChip: false,
  text: 'Turn my parrot into a coloring page',
  photo: '$_demo/parrot_photo.jpg',
);
const _offerParrot = ChipLine(
  fromChip: true,
  text:
      'What a beauty! I can have your parrot drawn for real, just from your '
      'photo.',
  mood: 'excited',
  portrait: ChipPortraitOffer(
    subject: 'your parrot',
    fromPhoto: true,
    state: 'maestro',
    left: 30,
  ),
);

void main() {
  testWidgets('1 ask for anyone', (tester) async {
    await _shoot(
      tester,
      name: '1_ask',
      lines: const [
        ChipLine(fromChip: false, text: 'Draw me a dragon'),
        ChipLine(
          fromChip: true,
          text: 'On it! One fierce dragon coming up.',
          mood: 'excited',
        ),
        _askEinstein,
        _offerEinstein,
      ],
    );
  });

  testWidgets('2 the real portrait', (tester) async {
    await _shoot(
      tester,
      name: '2_famous',
      world: UtopiaThemes.utopiaDoodle,
      lines: const [
        _askEinstein,
        _offerEinstein,
        ChipLine(
          fromChip: true,
          text: 'Here he is, drawn for real. Want to color him in?',
          mood: 'excited',
          picture: ChipPicture(
            status: 'ready',
            subject: 'Albert Einstein',
            id: 'einstein',
          ),
        ),
      ],
    );
  });

  testWidgets('3 send a photo', (tester) async {
    await _shoot(
      tester,
      name: '3_photo_ask',
      lines: const [_sendParrot, _offerParrot],
    );
  });

  testWidgets('4 drawn from the photo', (tester) async {
    await _shoot(
      tester,
      name: '4_photo',
      world: UtopiaThemes.utopiaDoodle,
      lines: const [
        _sendParrot,
        _offerParrot,
        ChipLine(
          fromChip: true,
          text: "Here's your parrot. Only you can see this one.",
          mood: 'excited',
          picture: ChipPicture(
            status: 'ready',
            subject: 'your parrot',
            id: 'parrot',
            fromPhoto: true,
          ),
        ),
      ],
    );
  });
}
