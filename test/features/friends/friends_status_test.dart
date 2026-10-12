import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/friends/data/friend_repository.dart';
import 'package:utopia/features/friends/presentation/providers/friends_providers.dart';

SocialProfile _person(String id) => SocialProfile(
  id: id,
  name: id,
  username: id,
  avatarUrl: null,
  avatarKind: null,
  avatarSeed: null,
);

void main() {
  final data = FriendsPopupData(
    friends: [_person('ana')],
    incomingRequests: const [
      {'id': 'req-1', 'from_user': 'ben'},
    ],
    outgoing: const {'cleo'},
    loading: false,
  );

  test('each person shows where you stand, so nobody gets two requests', () {
    expect(data.statusOf('ana'), FriendshipStatus.friends);
    expect(data.statusOf('cleo'), FriendshipStatus.requested);
    expect(data.statusOf('ben'), FriendshipStatus.incoming);
    expect(data.statusOf('dev'), FriendshipStatus.none);
  });

  test('an incoming request can be found to accept it', () {
    expect(data.incomingRequestFrom('ben'), 'req-1');
    expect(data.incomingRequestFrom('ana'), isNull);
  });
}
