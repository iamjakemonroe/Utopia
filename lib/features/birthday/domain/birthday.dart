/// A player's birthday: the day and month only. The year is never asked
/// for, so no one's age is ever kept.
class Birthday {
  const Birthday(this.month, this.day);

  /// 1 to 12.
  final int month;

  /// 1 to [daysIn] the month.
  final int day;

  static const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// The most days [month] ever has (29 for February).
  static int daysIn(int month) => switch (month) {
    2 => 29,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };

  static bool _leap(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  /// Whether [date] (the player's own day) is their birthday. 29 February
  /// is celebrated on the 28th in other years.
  bool isOn(DateTime date) {
    if (date.month == month && date.day == day) return true;
    return month == 2 &&
        day == 29 &&
        date.month == 2 &&
        date.day == 28 &&
        !_leap(date.year);
  }

  /// "18 October".
  String get label => '$day ${monthNames[month - 1]}';

  @override
  bool operator ==(Object other) =>
      other is Birthday && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(month, day);
}

/// The birthday a player has saved, and whether it can still be corrected
/// (for a day after it was first set; then it's locked).
class SavedBirthday {
  const SavedBirthday(this.birthday, this.setAt, {this.tellFriends = true});

  final Birthday birthday;
  final DateTime setAt;

  /// Whether their friends hear about it on the day.
  final bool tellFriends;

  bool get canChange =>
      DateTime.now().difference(setAt) < const Duration(days: 1);
}
