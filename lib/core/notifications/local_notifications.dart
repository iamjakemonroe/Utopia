import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Notifications the phone shows itself: an alert when a friend request
/// or a challenge arrives while Utopia isn't on screen, and the occasional
/// "come play" reminder when the player has been away a while.
///
/// These are local: the app shows them while it's running (even in the
/// background). Alerts while the app is fully closed need push (APNs/FCM),
/// which is a separate setup.
class LocalNotifications {
  LocalNotifications._();

  static final instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// The route a tapped notification asked to open (consumed by the app).
  final ValueNotifier<String?> tapped = ValueNotifier(null);

  static const _social = AndroidNotificationDetails(
    'utopia_social',
    'Friends and challenges',
    channelDescription: 'Friend requests and game challenges.',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF7C4DFF),
  );

  static const _nudges = AndroidNotificationDetails(
    'utopia_reminders',
    'Reminders',
    channelDescription: 'Now and then, a nudge to come back and play.',
    importance: Importance.defaultImportance,
    color: Color(0xFFFFC94D),
  );

  /// Reminder notification ids (so they can be replaced together).
  static const _reminderIds = [9001, 9002, 9003];

  bool get _supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> init() async {
    if (_ready || !_supported) return;
    _ready = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_utopia'),
          // Permission is asked for later, at a moment that makes sense.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => tapped.value = r.payload,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        tapped.value = launch!.notificationResponse?.payload;
      }
    } catch (_) {
      // Notifications are a nicety; never let them stop the app.
    }
  }

  /// Asks to show notifications (iOS, Android 13+). Safe to call again:
  /// the system only asks once.
  Future<void> requestPermission() async {
    if (!_supported) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Shows an alert now. [route] opens when it's tapped.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? route,
  }) async {
    if (!_supported || !_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: route,
        notificationDetails: const NotificationDetails(
          android: _social,
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
      );
    } catch (_) {}
  }

  static const _reminders = [
    ('Chip misses you', 'One quick game? Your world is waiting.'),
    ('Game time?', 'A chess game takes five minutes. Go on.'),
    ('An empty seat', 'The Ludo table is waiting for someone to roll a six.'),
    ('Something new is glowing', 'Fresh auras are waiting in the store.'),
    ('Rematch?', 'Your friends are a tap away.'),
    ('Your clock is ready', 'Pick a time and find an opponent.'),
    ('Roll the dice', 'Fancy a round of Ludo with friends?'),
    ('Back to Utopia', 'Your coins are right where you left them.'),
  ];

  /// Clears any pending reminders and, if [enabled], sets up fresh ones
  /// for a day, three days and a week from now, each in the early evening.
  Future<void> scheduleReminders({required bool enabled}) async {
    if (!_supported || !_ready) return;
    try {
      for (final id in _reminderIds) {
        await _plugin.cancel(id: id);
      }
      if (!enabled) return;
      final rng = math.Random();
      final picks = [..._reminders]..shuffle(rng);
      final now = DateTime.now();
      for (final (i, days) in const [1, 3, 7].indexed) {
        final day = now.add(Duration(days: days));
        final at = DateTime(day.year, day.month, day.day, 18, rng.nextInt(50));
        final (title, body) = picks[i];
        await _plugin.zonedSchedule(
          id: _reminderIds[i],
          title: title,
          body: body,
          payload: '/home',
          scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: _nudges,
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    } catch (_) {}
  }
}
