import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';

/// How often the app says the player's around while it's open (friends
/// see anyone from the last two minutes as online).
const _beat = Duration(seconds: 60);

/// How often an open friends list asks who's around.
const _look = Duration(seconds: 30);

/// Tells the server the player's around, so their friends see them
/// online: on opening the app, then once a minute while it's open (not
/// while it's in the background, or signed out).
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
    } else {
      _timer?.cancel();
      _timer = null;
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

/// The player's friends who are around now (their ids), asked every 30
/// seconds while something shows it.
final friendsOnlineProvider = StreamProvider.autoDispose<Set<String>>((
  ref,
) async* {
  final client = ref.watch(supabaseClientProvider);
  while (true) {
    try {
      final ids = await client.rpc('friends_online');
      yield {for (final id in ids as List) id as String};
    } catch (_) {
      // Kept as it was until the next look.
    }
    await Future<void>.delayed(_look);
  }
});
