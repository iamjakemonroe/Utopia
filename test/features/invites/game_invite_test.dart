import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/invites/domain/game_invite.dart';

void main() {
  test('a shared link opens the same invite in the app', () {
    const invite = GameInvite(InviteGame.ludo, 'ABC234');
    expect(
      invite.link.toString(),
      'https://utopia.kaivon.app/join?game=ludo&code=ABC234',
    );
    expect(GameInvite.fromUri(invite.link), invite);
    expect(GameInvite.fromUri(Uri.parse(invite.location)), invite);
  });

  test('codes are read in any case', () {
    expect(
      GameInvite.fromUri(Uri.parse('/join?game=doodle&code=xyz789')),
      const GameInvite(InviteGame.doodle, 'XYZ789'),
    );
  });

  test('broken links are turned away', () {
    for (final link in [
      '/join?game=chess&code=ABC234', // not a game with rooms
      '/join?game=ludo&code=ABC23', // too short
      '/join?game=ludo&code=ABC2O4', // O is never in a code
      '/join?game=ludo', // no code
      '/ludo?game=ludo&code=ABC234', // not an invite
    ]) {
      expect(GameInvite.fromUri(Uri.parse(link)), isNull, reason: link);
    }
  });

  test('an invite waits once, then is gone', () {
    const invite = GameInvite(InviteGame.ludo, 'ABC234');
    PendingInvite.hold(invite);
    expect(PendingInvite.take(), invite);
    expect(PendingInvite.take(), isNull);
  });
}
