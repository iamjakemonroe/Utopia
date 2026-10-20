import '../../../l10n/strings.dart';

/// How fast a time control plays, by estimated game length (minutes × 60 +
/// 40 × increment), using the usual online-chess thresholds.
enum ChessSpeed { bullet, blitz, rapid, classical }

/// A chess time control: each player's starting minutes plus the seconds
/// added after every move. Only the controls the server accepts are listed
/// in [all] (see _chess_time_control_ok).
class TimeControl {
  const TimeControl(this.minutes, this.increment);

  final int minutes;
  final int increment;

  static const all = [
    TimeControl(1, 0),
    TimeControl(2, 1),
    TimeControl(3, 0),
    TimeControl(3, 2),
    TimeControl(5, 0),
    TimeControl(10, 0),
    TimeControl(15, 10),
    TimeControl(30, 0),
  ];

  static const standard = TimeControl(10, 0);

  ChessSpeed get speed {
    final seconds = minutes * 60 + 40 * increment;
    if (seconds < 180) return ChessSpeed.bullet;
    if (seconds < 480) return ChessSpeed.blitz;
    if (seconds < 1500) return ChessSpeed.rapid;
    return ChessSpeed.classical;
  }

  /// "10 min", or "3 | 2" when there's an increment.
  String get label => increment == 0 ? '$minutes min' : '$minutes | $increment';

  static TimeControl fromRow(Map<String, dynamic>? row) {
    final ms = (row?['clock_initial_ms'] as num?)?.toInt();
    if (ms == null) return standard;
    final inc = ((row?['clock_increment_ms'] as num?)?.toInt() ?? 0) ~/ 1000;
    return TimeControl(ms ~/ 60000, inc);
  }

  @override
  bool operator ==(Object other) =>
      other is TimeControl &&
      other.minutes == minutes &&
      other.increment == increment;

  @override
  int get hashCode => Object.hash(minutes, increment);
}

extension ChessSpeedName on ChessSpeed {
  String get title => switch (this) {
    ChessSpeed.bullet => strings.timeControlBullet,
    ChessSpeed.blitz => strings.timeControlBlitz,
    ChessSpeed.rapid => strings.timeControlRapid,
    ChessSpeed.classical => strings.timeControlClassical,
  };
}

/// 65_000 -> "1:05", 9_400 -> "0:09.4" (tenths under ten seconds).
String formatClock(int ms) {
  if (ms <= 0) return '0:00';
  if (ms < 10000) {
    final tenths = ms ~/ 100;
    return '0:0${tenths ~/ 10}.${tenths % 10}';
  }
  final total = (ms / 1000).ceil();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
