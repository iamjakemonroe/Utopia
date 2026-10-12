import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/chess/presentation/widgets/bot_clock.dart';

enum _Side { a, b }

void main() {
  test('only the side to move runs, and it flags at zero', () async {
    final clock = BotClock(const Duration(milliseconds: 300), _Side.values);
    // Nothing runs before the first move.
    expect(clock.isRunning(_Side.a), isFalse);
    expect(clock.flagged, isNull);

    clock.start(_Side.b);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(clock.msLeft(_Side.a), 300);
    expect(clock.msLeft(_Side.b), lessThan(300));

    // Switching keeps what b used.
    clock.start(_Side.a);
    final bLeft = clock.msLeft(_Side.b);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(clock.msLeft(_Side.b), bLeft);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(clock.msLeft(_Side.a), 0);
    expect(clock.flagged, _Side.a);

    clock.reset();
    expect(clock.flagged, isNull);
    expect(clock.msLeft(_Side.a), 300);
    expect(clock.msLeft(_Side.b), 300);
  });

  test('time stops while the app is in the background', () async {
    final clock = BotClock(const Duration(seconds: 5), _Side.values);
    clock.start(_Side.a);
    clock.pause();
    final left = clock.msLeft(_Side.a);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(clock.msLeft(_Side.a), left);
    // Still a's move, just not counting.
    expect(clock.isRunning(_Side.a), isTrue);

    // A move made while away doesn't start the next side's time either.
    clock.start(_Side.b);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(clock.msLeft(_Side.b), 5000);

    clock.resume();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(clock.msLeft(_Side.b), lessThan(5000));
  });
}
