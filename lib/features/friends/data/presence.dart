import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';

/// How often the app says the player's around while it's open (the server
/// counts anyone quiet for a minute as gone).
const _beat = Duration(seconds: 25);

/// How often an open friends list looks again, besides hearing friends
/// come and go live (in case a message was missed).
const _look = Duration(seconds: 60);

/// Tells the server the player's around, so their friends see them
/// online: at once on opening the app or coming back to it, then every 25
/// seconds while it's open. Leaving it (to the background, or closing it)
/// says so at once, so friends see them go straight away.
class PresenceBeat extends ConsumerStatefulWidget {
  const PresenceBeat({super.key});

  @override
  ConsumerState<PresenceBeat> createState() => _PresenceBeatState();
}

class _PresenceBeatState extends ConsumerState<PresenceBeat>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _open = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _open = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A glance at the notifications or control center (inactive) isn't
    // leaving.
    if (state == AppLifecycleState.inactive) return;
    _open = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final signedIn = ref.read(currentUserProvider) != null;
    if (signedIn && _open) {
      if (_timer != null) return;
      _touch();
      _timer = Timer.periodic(_beat, (_) => _touch());
    } else if (_timer != null) {
      _timer?.cancel();
      _timer = null;
      if (signedIn) unawaited(goOffline(ref.read(supabaseClientProvider)));
    }
  }

  Future<void> _touch() async {
    try {
      await ref.read(supabaseClientProvider).rpc('touch_presence');
    } catch (_) {
      // Offline for a moment: the next beat tries again.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (previous, next) {
      if (previous?.id != next?.id) {
        _timer?.cancel();
        _timer = null;
      }
      _sync();
    });
    return const SizedBox.shrink();
  }
}

/// Tells the server the player's gone (leaving the app, signing out), so
/// friends see it at once. Never throws: if it doesn't get through, the
/// server notices within a minute anyway.
Future<void> goOffline(SupabaseClient client) async {
  try {
    await client.rpc('go_offline').timeout(const Duration(seconds: 3));
  } catch (_) {}
}

/// The player's friends who are around now (their ids): looked up, then
/// kept live as they come and go (presence_status), and looked up again
/// every minute and on reconnecting, in case anything was missed.
final friendsOnlineProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final me = ref.watch(currentUserProvider)?.id;
  var online = <String>{};
  late final StreamController<Set<String>> out;
  RealtimeChannel? channel;
  Timer? poll;

  Future<void> look() async {
    try {
      final ids = await client.rpc('friends_online');
      online = {for (final id in ids as List) id as String};
      if (!out.isClosed) out.add(online);
    } catch (_) {
      // Kept as it was until the next look.
    }
  }

  void heard(PostgresChangePayload change) {
    final row = change.newRecord;
    final id = row['user_id'] as String?;
    if (id == null || id == me) return;
    final now = row['online'] == true
        ? ({...online, id})
        : ({...online}..remove(id));
    if (now.length == online.length && now.containsAll(online)) return;
    online = now;
    if (!out.isClosed) out.add(online);
  }

  out = StreamController<Set<String>>(
    onListen: () {
      unawaited(look());
      channel = client
          .channel('friends-online-${me ?? 'none'}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'presence_status',
            callback: heard,
          )
          .subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed) unawaited(look());
          });
      poll = Timer.periodic(_look, (_) => look());
    },
    onCancel: () {
      poll?.cancel();
      final c = channel;
      if (c != null) unawaited(client.removeChannel(c));
    },
  );
  ref.onDispose(out.close);
  return out.stream;
});
