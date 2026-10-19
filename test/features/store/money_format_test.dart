import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/store/data/store_repository.dart';

void main() {
  test('prices read the way people write them', () {
    expect(formatMoney(7500, 'NGN'), '₦7,500');
    expect(formatMoney(150000, 'NGN'), '₦150,000');
    expect(formatMoney(4.99, 'USD'), r'$4.99');
    expect(formatMoney(99.99, 'USD'), r'$99.99');
    expect(formatMoney(1500, 'XOF'), 'XOF 1,500');
  });
}
