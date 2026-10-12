import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../data/friend_repository.dart';

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(profileRepositoryProvider),
  );
});

class FriendsPopupData {
  const FriendsPopupData({
    this.friends = const [],
    this.recents = const [],
    this.incomingRequests = const [],
    this.outgoing = const {},
    this.searchResults = const [],
    this.loading = true,
    this.searching = false,
  });

  final List<SocialProfile> friends;
  final List<SocialProfile> recents;
  final List<Map<String, dynamic>> incomingRequests;

  /// People with a request from this player still waiting on them.
  final Set<String> outgoing;
  final List<Map<String, dynamic>> searchResults;
  final bool loading;
  final bool searching;

  /// Where this player stands with [userId].
  FriendshipStatus statusOf(String userId) {
    if (friends.any((f) => f.id == userId)) return FriendshipStatus.friends;
    if (outgoing.contains(userId)) return FriendshipStatus.requested;
    if (incomingRequests.any((r) => r['from_user'] == userId)) {
      return FriendshipStatus.incoming;
    }
    return FriendshipStatus.none;
  }

  /// The pending request [userId] sent this player, if any.
  String? incomingRequestFrom(String userId) => incomingRequests
      .where((r) => r['from_user'] == userId)
      .map((r) => r['id'] as String)
      .firstOrNull;

  List<SocialProfile> get all {
    final seen = <String>{};
    final combined = <SocialProfile>[];
    for (final person in [...friends, ...recents]) {
      if (seen.add(person.id)) combined.add(person);
    }
    return combined;
  }

  FriendsPopupData copyWith({
    List<SocialProfile>? friends,
    List<SocialProfile>? recents,
    List<Map<String, dynamic>>? incomingRequests,
    Set<String>? outgoing,
    List<Map<String, dynamic>>? searchResults,
    bool? loading,
    bool? searching,
  }) {
    return FriendsPopupData(
      friends: friends ?? this.friends,
      recents: recents ?? this.recents,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoing: outgoing ?? this.outgoing,
      searchResults: searchResults ?? this.searchResults,
      loading: loading ?? this.loading,
      searching: searching ?? this.searching,
    );
  }
}

class FriendsPopupController extends StateNotifier<FriendsPopupData> {
  FriendsPopupController(this._repository, this._userId)
    : super(const FriendsPopupData()) {
    refresh();
  }

  final FriendRepository _repository;
  final String _userId;
  int _searchGeneration = 0;

  Future<void> refresh() async {
    if (state.friends.isEmpty && state.recents.isEmpty) {
      state = state.copyWith(loading: true);
    }
    try {
      final results = await Future.wait([
        _repository.fetchFriends(_userId),
        _repository.fetchRecents(_userId),
        _repository.fetchIncomingFriendRequests(_userId),
        _repository.fetchOutgoingRequestIds(_userId),
      ]);
      if (!mounted) return;
      state = state.copyWith(
        friends: results[0] as List<SocialProfile>,
        recents: results[1] as List<SocialProfile>,
        incomingRequests: results[2] as List<Map<String, dynamic>>,
        outgoing: results[3] as Set<String>,
        loading: false,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(loading: false);
    }
  }

  Future<void> search(String query) async {
    final generation = ++_searchGeneration;
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: const [], searching: false);
      return;
    }
    state = state.copyWith(searching: true);
    final results = await _repository.searchUsers(query, excludeId: _userId);
    if (generation != _searchGeneration) {
      return; // a newer keystroke superseded this search
    }
    state = state.copyWith(searchResults: results, searching: false);
  }

  /// Sends a request, showing it as requested straight away. Does nothing
  /// if one is already out or they're already friends.
  Future<void> sendFriendRequest(String toUserId) async {
    final status = state.statusOf(toUserId);
    if (status == FriendshipStatus.friends ||
        status == FriendshipStatus.requested) {
      return;
    }
    state = state.copyWith(outgoing: {...state.outgoing, toUserId});
    try {
      await _repository.sendFriendRequest(toUserId);
    } catch (_) {
      state = state.copyWith(outgoing: {...state.outgoing}..remove(toUserId));
      rethrow;
    } finally {
      await refresh();
    }
  }

  /// Answers a request. Its card goes away straight away and comes back
  /// only if the answer doesn't go through.
  Future<void> respondFriendRequest({
    required String requestId,
    required bool accept,
  }) async {
    final before = state.incomingRequests;
    state = state.copyWith(
      incomingRequests: [
        for (final r in before)
          if (r['id'] != requestId) r,
      ],
    );
    try {
      await _repository.respondFriendRequest(
        requestId: requestId,
        accept: accept,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(incomingRequests: before);
      rethrow;
    }
    await refresh();
  }
}

final friendsPopupControllerProvider =
    StateNotifierProvider.family<
      FriendsPopupController,
      FriendsPopupData,
      String
    >((ref, userId) {
      return FriendsPopupController(
        ref.watch(friendRepositoryProvider),
        userId,
      );
    });
