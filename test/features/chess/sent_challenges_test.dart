import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/chess/presentation/sent_challenges.dart';

Map<String, dynamic> _invite(String id, String status, {Duration? left}) => {
  'id': id,
  'status': status,
  if (left != null)
    'expires_at': DateTime.now().add(left).toUtc().toIso8601String(),
};

void main() {
  test('waiting: pending and not run out, newest first', () {
    final waiting = waitingChallenges([
      _invite('old', 'pending', left: const Duration(minutes: 2)),
      _invite('gone', 'pending', left: const Duration(seconds: -5)),
      _invite('answered', 'declined', left: const Duration(minutes: 9)),
      _invite('taken back', 'cancelled', left: const Duration(minutes: 9)),
      _invite('no clock', 'pending'),
      _invite('new', 'pending', left: const Duration(minutes: 9)),
    ]);
    expect(waiting.map((i) => i['id']), ['new', 'no clock', 'old']);
  });

  test('minutes left round up, and never show 0', () {
    expect(
      challengeMinutesLeft(
        _invite('a', 'pending', left: const Duration(minutes: 7, seconds: 10)),
      ),
      8,
    );
    expect(
      challengeMinutesLeft(
        _invite('b', 'pending', left: const Duration(seconds: 3)),
      ),
      1,
    );
    expect(challengeMinutesLeft(_invite('c', 'pending')), isNull);
  });
}
