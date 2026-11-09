import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/store/data/store_repository.dart';

void main() {
  test('prices read the way people write them', () {
    expect(formatMoney(7500, 'NGN'), '₦7,500');
    expect(formatMoney(150000, 'NGN'), '₦150,000');
    expect(formatMoney(1000, 'NGN'), '₦1,000');
    expect(formatMoney(4.99, 'USD'), r'$4.99');
    expect(formatMoney(99.99, 'USD'), r'$99.99');
    expect(formatMoney(1500, 'XOF'), 'XOF 1,500');
  });

  test('pounds, euros and dollars keep their pennies', () {
    expect(formatMoney(3.99, 'GBP'), '£3.99');
    expect(formatMoney(1, 'GBP'), '£1.00');
    expect(formatMoney(79.99, 'GBP'), '£79.99');
    expect(formatMoney(4.49, 'EUR'), '€4.49');
    expect(formatMoney(1, 'EUR'), '€1.00');
    expect(formatMoney(92.99, 'EUR'), '€92.99');
    expect(formatMoney(1, 'USD'), r'$1.00');
    expect(formatMoney(1234.5, 'GBP'), '£1,234.50');
  });
}
