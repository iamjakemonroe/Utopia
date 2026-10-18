import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/birthday/domain/birthday.dart';

void main() {
  test('a birthday is its day, any year', () {
    const b = Birthday(10, 18);
    expect(b.isOn(DateTime(2026, 10, 18, 23, 59)), isTrue);
    expect(b.isOn(DateTime(2031, 10, 18)), isTrue);
    expect(b.isOn(DateTime(2026, 10, 19)), isFalse);
    expect(b.isOn(DateTime(2026, 11, 18)), isFalse);
    expect(b.label, '18 October');
  });

  test('29 February is celebrated on the 28th in other years', () {
    const leapling = Birthday(2, 29);
    expect(leapling.isOn(DateTime(2028, 2, 29)), isTrue);
    expect(leapling.isOn(DateTime(2028, 2, 28)), isFalse);
    expect(leapling.isOn(DateTime(2027, 2, 28)), isTrue);
    expect(leapling.isOn(DateTime(2100, 2, 28)), isTrue); // not a leap year
    expect(leapling.isOn(DateTime(2000, 2, 28)), isFalse); // a leap year
  });

  test('days in each month allow 29 February', () {
    expect(Birthday.daysIn(2), 29);
    expect([4, 6, 9, 11].map(Birthday.daysIn).toSet(), {30});
    expect([1, 3, 5, 7, 8, 10, 12].map(Birthday.daysIn).toSet(), {31});
  });

  test('it can be corrected for a day, then it is locked', () {
    const b = Birthday(1, 1);
    expect(SavedBirthday(b, DateTime.now()).canChange, isTrue);
    expect(
      SavedBirthday(
        b,
        DateTime.now().subtract(const Duration(hours: 25)),
      ).canChange,
      isFalse,
    );
  });
}
