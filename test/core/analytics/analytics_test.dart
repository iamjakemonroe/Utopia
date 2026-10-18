import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/analytics/analytics.dart';

void main() {
  test('screens group together without their ids', () {
    expect(
      screenName('/ludo/7e1c2a3b-1d2e-4f5a-8b9c-0d1e2f3a4b5c'),
      '/ludo/:id',
    );
    expect(
      screenName('/ludo/room/7e1c2a3b-1d2e-4f5a-8b9c-0d1e2f3a4b5c'),
      '/ludo/room/:id',
    );
    expect(screenName('/ludo/local-1729'), '/ludo/:id');
    expect(screenName('/home'), '/home');
  });
}
