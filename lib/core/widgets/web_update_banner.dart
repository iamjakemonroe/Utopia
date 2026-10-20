import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../platform/session_memory.dart';
import '../platform/web_install.dart';
import '../platform/web_update.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// In a browser: a game left open keeps the version it loaded, so it checks
/// for a newer one every few minutes and whenever the page comes back into
/// view, and offers to refresh. Never in the middle of a game.
///
/// Installed on a phone (the PWA), it updates by itself: a phone often
/// only un-pauses an installed app, so it could run an old version for
/// days. It reloads as soon as the player is somewhere calm (not in a
/// game, a drawing or a half-written report), at most once a version a
/// session (so a slow server can't make it reload over and over); until
/// then, the banner.
class WebUpdateBanner extends ConsumerStatefulWidget {
  const WebUpdateBanner({super.key});

  @override
  ConsumerState<WebUpdateBanner> createState() => _WebUpdateBannerState();
}

class _WebUpdateBannerState extends ConsumerState<WebUpdateBanner> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  void Function()? _stopWatching;
  GoRouter? _router;
  String? _live;
  bool _ready = false;
  bool _dismissed = false;

  static const _reloadedKey = 'utopia_updated_to';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb || kWebBuild.isEmpty) return;
    _timer = Timer.periodic(
      Duration(minutes: WebInstall.installed ? 2 : 5),
      (_) => _check(),
    );
    _lifecycle = AppLifecycleListener(onResume: _check);
    _stopWatching = onPageShown(_check);
    // Somewhere calm again: the installed app updates then.
    final router = ref.read(goRouterProvider);
    router.routerDelegate.addListener(_update);
    _router = router;
  }

  Future<void> _check() async {
    if (_ready) return _update();
    final live = await liveWebBuild();
    if (!mounted || live == null || live == kWebBuild) return;
    _live = live;
    setState(() => _ready = true);
    _update();
  }

  /// In the installed app, with a new version out and nothing to lose:
  /// reload into it (once per version a session).
  void _update() {
    final live = _live;
    if (!_ready || live == null || !WebInstall.installed || _busy()) return;
    if (SessionMemory.read(_reloadedKey) == live) return;
    SessionMemory.write(_reloadedKey, live);
    reloadPage();
  }

  /// In a game, a drawing, signing in or writing a report.
  bool _busy() {
    final path = _router?.routerDelegate.currentConfiguration.uri.path ?? '';
    const busy = [
      '/chess/',
      '/checkers/',
      '/ludo/',
      '/doodle-game/',
      '/guess-my-doodle/',
      '/sketchbook/',
      '/report-bug',
      '/auth',
      '/names',
      '/birthday',
    ];
    return busy.any(path.startsWith);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    _stopWatching?.call();
    _router?.routerDelegate.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = _ready && !_dismissed;
    final top = MediaQuery.paddingOf(context).top + 12;
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          top: show ? top : -120,
          left: 16,
          right: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Material(
                color: AppColors.surface,
                elevation: 12,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.goldBorderBright,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'A new version of Utopia is ready.',
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: reloadPage,
                        child: const Text('Refresh'),
                      ),
                      IconButton(
                        tooltip: 'Later',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.textSecondary,
                        onPressed: () => setState(() => _dismissed = true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
