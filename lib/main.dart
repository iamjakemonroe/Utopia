import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _addFontLicenses();

  final configError = Env.configError;
  if (configError != null) {
    runApp(_ConfigErrorApp(message: configError));
    return;
  }

  // Restores any persisted session (including anonymous ones) before the
  // first frame, so the splash screen knows where to send the user. The
  // splash logo decodes and saved settings (theme, sound) load in
  // parallel so they're ready for that first frame.
  final prefs = SharedPreferences.getInstance();
  await Future.wait([
    Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    ),
    _decodeSplashLogo(),
    prefs,
  ]);

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(await prefs)],
      child: const UtopiaApp(),
    ),
  );
}

/// The bundled fonts (assets/google_fonts) are under the SIL Open Font
/// License, which travels with them.
void _addFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Inter', 'Inter-OFL.txt'),
      ('Space Grotesk', 'SpaceGrotesk-OFL.txt'),
    ]) {
      final text = await rootBundle.loadString('assets/google_fonts/$file');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}

/// Loads the splash logo into the image cache. Never fails startup: if
/// decoding errors, the splash just loads it normally instead.
Future<void> _decodeSplashLogo() {
  final done = Completer<void>();
  final stream = const AssetImage(
    kSplashLogoAsset,
  ).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  void finish() {
    stream.removeListener(listener);
    if (!done.isCompleted) done.complete();
  }

  listener = ImageStreamListener(
    (_, _) => finish(),
    onError: (_, _) => finish(),
  );
  stream.addListener(listener);
  return done.future;
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: SelectableText(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
