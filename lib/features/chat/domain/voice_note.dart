import 'dart:math' as math;

/// A voice note in game chat. Sent as a chat message whose body is
/// `voice:{storage path}|{length in ms}|{waveform}`, the waveform being one
/// digit (0-9) per bar.
class VoiceNote {
  const VoiceNote({required this.path, required this.ms, required this.wave});

  /// Path in the `voice-notes` bucket: `{match id}/{note id}.m4a`.
  final String path;
  final int ms;
  final List<int> wave;

  static const maxLength = Duration(seconds: 30);
  static const minLength = Duration(milliseconds: 700);
  static const bars = 28;

  static bool isVoice(String body) => body.startsWith('voice:');

  static VoiceNote? parse(String body) {
    if (!isVoice(body)) return null;
    final parts = body.substring(6).split('|');
    if (parts.length != 3) return null;
    final ms = int.tryParse(parts[1]);
    if (ms == null) return null;
    return VoiceNote(
      path: parts[0],
      ms: ms,
      wave: [for (final c in parts[2].split('')) int.tryParse(c) ?? 0],
    );
  }

  String encode() => 'voice:$path|$ms|${wave.join()}';

  /// A new storage path for a note in [matchId].
  static String newPath(String matchId) => '$matchId/${_uuid()}.m4a';

  /// Squeezes live loudness samples (dBFS) into [bars] digits.
  static List<int> waveFrom(List<double> dbfs) {
    if (dbfs.isEmpty) return List.filled(bars, 1);
    return [
      for (var i = 0; i < bars; i++)
        () {
          final from = (i * dbfs.length / bars).floor();
          final to = math.max(from + 1, ((i + 1) * dbfs.length / bars).floor());
          final slice = dbfs.sublist(from, math.min(to, dbfs.length));
          final loudest = slice.reduce(math.max);
          return (((loudest + 50) / 50).clamp(0.0, 1.0) * 9).round();
        }(),
    ];
  }

  static String _uuid() {
    final r = math.Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int from, int to) => [
      for (final x in b.sublist(from, to)) x.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}

/// 3200 -> "0:03".
String formatVoiceLength(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
