import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/env.dart';

/// Configures the PostHog SDK once before the app is built.
///
/// Flutter Web is initialized by the snippet in web/index.html because Dart
/// setup is a no-op in web builds.
Future<void> setupPostHog() async {
  if (kIsWeb) return;

  if (Env.posthogProjectToken.isEmpty) {
    if (kDebugMode) {
      throw StateError(
        'POSTHOG_PROJECT_TOKEN variable required by PostHog is missing or '
        'un-configured, this causes events to be silently missed. This error '
        'stops appearing once POSTHOG_PROJECT_TOKEN is configured',
      );
    }
    return;
  }
  if (Env.posthogHost.isEmpty) {
    if (kDebugMode) {
      throw StateError(
        'POSTHOG_HOST variable required by PostHog is missing or '
        'un-configured, this causes events to be silently missed. This error '
        'stops appearing once POSTHOG_HOST is configured',
      );
    }
    return;
  }

  final config = PostHogConfig(Env.posthogProjectToken);
  config.host = Env.posthogHost;
  config.debug = kDebugMode;

  // The SDK natively encodes and batches the dedicated application logs.
  // Existing print/debugPrint and application loggers remain local.
  config.logsConfig.serviceName = 'utopia';

  // Capture unhandled errors globally through the SDK's framework, runtime,
  // isolate, and native error hooks. Handled errors stay under the app's
  // existing error-reporting flow.
  config.errorTrackingConfig.captureFlutterErrors = true;
  config.errorTrackingConfig.capturePlatformDispatcherErrors = true;
  config.errorTrackingConfig.captureIsolateErrors = true;
  config.errorTrackingConfig.captureNativeExceptions = true;

  await Posthog().setup(config);
}
