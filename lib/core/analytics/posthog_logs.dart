import 'package:posthog_flutter/posthog_flutter.dart';

/// Purpose-written operational logs exported to PostHog.
///
/// This is intentionally separate from the app's existing loggers: only the
/// bounded, non-user-data lines below are sent to PostHog Logs.
abstract final class PostHogAppLogger {
  static void appReady() {
    Posthog().logger.info('utopia application initialized');
  }

  static void gameFinished() {
    Posthog().logger.info('utopia game completed');
  }

  static void storePurchaseCompleted() {
    Posthog().logger.info('utopia store purchase completed');
  }

  static void chipMessageSent() {
    Posthog().logger.info('utopia chip message submitted');
  }
}
