import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';

/// Something that happened that the player should hear about. Written by
/// the server (see the notifications migration).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.actorId,
    required this.refId,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final int id;

  /// 'friend_request', 'friend_accepted' or 'game_invite'.
  final String kind;

  /// Who did it.
  final String? actorId;

  /// The friend request or invite it's about.
  final String? refId;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get unread => readAt == null;

  factory AppNotification.fromRow(Map<String, dynamic> row) => AppNotification(
    id: (row['id'] as num).toInt(),
    kind: row['kind'] as String,
    actorId: row['actor_id'] as String?,
    refId: row['ref_id'] as String?,
    data: Map<String, dynamic>.from(row['data'] as Map? ?? const {}),
    readAt: DateTime.tryParse(row['read_at'] as String? ?? '')?.toLocal(),
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );
}

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  /// The player's latest notifications, newest first, live.
  Stream<List<AppNotification>> watch(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('id', ascending: false)
        .limit(60)
        .map((rows) => rows.map(AppNotification.fromRow).toList());
  }

  /// Marks [ids] read, or all of them when null.
  Future<void> markRead([List<int>? ids]) {
    return _client.rpc('mark_notifications_read', params: {'p_ids': ids});
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in player's notifications, kept live for the whole session.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final me = ref.watch(currentUserProvider)?.id;
  if (me == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watch(me);
});

final unreadNotificationsProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return list.where((n) => n.unread).length;
});
