import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A random key for this install, kept on the device (in a browser, its
/// storage): the same for every account used here, so the guests made on
/// one device share one allowance for Chip. Empty until [load].
abstract final class DeviceKey {
  static const _key = 'device_key';
  static const _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  static String _value = '';

  static String get value => _value;

  /// Reads the key, or makes one on the first launch.
  static void load(SharedPreferences prefs) {
    var key = prefs.getString(_key);
    if (key == null || key.length < 16) {
      final random = Random.secure();
      key = List.generate(
        32,
        (_) => _chars[random.nextInt(_chars.length)],
      ).join();
      prefs.setString(_key, key);
    }
    _value = key;
  }
}
