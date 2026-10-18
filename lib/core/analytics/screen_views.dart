import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import 'analytics.dart';

/// Logs each screen the player goes to, for the analytics. Watched at the
/// app's root.
final screenViewsProvider = Provider<void>((ref) {
  final router = ref.watch(goRouterProvider);
  final analytics = ref.read(analyticsProvider);
  String? last;
  void changed() {
    final path = screenName(currentPath(router));
    if (path == last || path == '/splash') return;
    last = path;
    analytics.log('screen', {'path': path});
  }

  router.routerDelegate.addListener(changed);
  ref.onDispose(() => router.routerDelegate.removeListener(changed));
});
