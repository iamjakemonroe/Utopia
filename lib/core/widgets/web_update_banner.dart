import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../platform/web_update.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// In a browser: a game left open keeps the version it loaded, so it checks
/// for a newer one every few minutes (and on coming back to the tab), and
/// offers to refresh. Never reloads by itself, so no game is cut short.
class WebUpdateBanner extends StatefulWidget {
  const WebUpdateBanner({super.key});

  @override
  State<WebUpdateBanner> createState() => _WebUpdateBannerState();
}

class _WebUpdateBannerState extends State<WebUpdateBanner> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _ready = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb || kWebBuild.isEmpty) return;
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
    _lifecycle = AppLifecycleListener(onResume: _check);
  }

  Future<void> _check() async {
    if (_ready) return;
    final live = await liveWebBuild();
    if (!mounted || live == null || live == kWebBuild) return;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
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
