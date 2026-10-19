import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/platform/session_memory.dart';
import '../../../core/platform/web_install.dart';
import '../../../core/platform/web_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_toast.dart';

/// The store apps' links, once Utopia is in the stores (build defines);
/// until then, empty, and nobody is pointed there.
const kAppStoreUrl = String.fromEnvironment('APP_STORE_URL');
const kPlayStoreUrl = String.fromEnvironment('PLAY_STORE_URL');

/// Shows how to install Utopia from this browser: the browser's own
/// dialog where it has one (Chrome, Edge, Android), the steps elsewhere
/// (Safari). Whether they chose "Not now" (only offered when [offer]).
Future<bool> showInstallSheet(
  BuildContext context,
  WidgetRef ref, {
  bool offer = false,
}) async {
  ref.read(gameAudioProvider).play(Sfx.drawer);
  final later = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InstallSheet(offer: offer),
  );
  return later ?? false;
}

/// Once a session on the web, after the day's popups: the store app when
/// it's out (on a phone), or, from a third visit (or straight away when
/// the address asked: ?install=1), the offer to install Utopia, at most
/// every two weeks after "Not now".
Future<void> offerWebAppIfDue(BuildContext context, WidgetRef ref) async {
  if (!kIsWeb || SessionMemory.read('app_offered') != null) return;
  final prefs = _prefs(ref);
  if (prefs == null) return;
  if (SessionMemory.read('visit_counted') == null) {
    SessionMemory.write('visit_counted', '1');
    await prefs.setInt('web_visits', (prefs.getInt('web_visits') ?? 0) + 1);
  }
  if (!context.mounted) return;

  final storeUrl = switch (defaultTargetPlatform) {
    TargetPlatform.iOS => kAppStoreUrl,
    TargetPlatform.android => kPlayStoreUrl,
    _ => '',
  };
  if (storeUrl.isNotEmpty && !(prefs.getBool('store_app_offered') ?? false)) {
    SessionMemory.write('app_offered', '1');
    await prefs.setBool('store_app_offered', true);
    if (context.mounted) await _offerStoreApp(context, ref, storeUrl);
    return;
  }

  if (WebInstall.installed) return;
  final asked = WebPage.query['install'] == '1';
  final visits = prefs.getInt('web_visits') ?? 0;
  final laterAt = prefs.getInt('install_later_at');
  final recently =
      laterAt != null &&
      DateTime.now().millisecondsSinceEpoch - laterAt <
          const Duration(days: 14).inMilliseconds;
  if (!asked && (visits < 3 || recently)) return;
  SessionMemory.write('app_offered', '1');
  final later = await showInstallSheet(context, ref, offer: true);
  if (later) {
    await prefs.setInt(
      'install_later_at',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}

Future<void> _offerStoreApp(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  ref.read(gameAudioProvider).play(Sfx.drawer);
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => _SheetFrame(
      title: ios ? 'Utopia is on the App Store' : 'Utopia is on Google Play',
      lead:
          'Get the app for sound in the background, notifications and more. '
          'Sign in with the same email and everything comes with you.',
      children: [
        PrimaryButton(
          label: 'Get the app',
          onPressed: () {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            Navigator.of(sheet).pop();
          },
        ),
        TextButton(
          onPressed: () => Navigator.of(sheet).pop(),
          child: const Text('Keep playing here'),
        ),
      ],
    ),
  );
}

SharedPreferences? _prefs(WidgetRef ref) {
  try {
    return ref.read(sharedPreferencesProvider);
  } catch (_) {
    return null;
  }
}

class _InstallSheet extends ConsumerStatefulWidget {
  const _InstallSheet({required this.offer});

  final bool offer;

  @override
  ConsumerState<_InstallSheet> createState() => _InstallSheetState();
}

class _InstallSheetState extends ConsumerState<_InstallSheet> {
  bool _busy = false;

  Future<void> _install() async {
    setState(() => _busy = true);
    final installed = await WebInstall.prompt();
    if (!mounted) return;
    if (installed) {
      ref.read(gameAudioProvider).play(Sfx.purchase);
      final host = Navigator.of(context);
      showUtopiaToast(
        context,
        'Utopia is on your home screen now.',
        icon: Icons.download_done_rounded,
        kind: ToastKind.success,
      );
      host.pop(false);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final steps = WebInstall.canPrompt
        ? null
        : ios
        ? const [
            (Icons.ios_share_rounded, 'Tap the Share button in Safari'),
            (Icons.add_box_outlined, 'Choose "Add to Home Screen"'),
            (Icons.touch_app_rounded, 'Open Utopia from your home screen'),
          ]
        : WebInstall.macSafari
        ? const [
            (Icons.menu_rounded, 'In the menu bar, open File'),
            (Icons.add_to_queue_rounded, 'Choose "Add to Dock"'),
            (Icons.touch_app_rounded, 'Open Utopia from your Dock'),
          ]
        : const [
            (Icons.more_vert_rounded, "Open your browser's menu"),
            (Icons.install_desktop_rounded, 'Choose "Install Utopia"'),
            (Icons.touch_app_rounded, 'Open Utopia like any app'),
          ];
    return _SheetFrame(
      title: 'Install Utopia',
      lead:
          'Play full screen, straight from your home screen, like any app. '
          "It's free and takes no space.",
      children: [
        if (steps == null)
          PrimaryButton(
            label: 'Install',
            isLoading: _busy,
            onPressed: _busy ? null : _install,
          )
        else
          for (final (i, (icon, text)) in steps.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                    child: Text(
                      '${i + 1}',
                      style: AppTextStyles.body(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(icon, color: AppColors.goldBorderBright),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: AppTextStyles.body())),
                ],
              ),
            ),
        if (widget.offer)
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Not now'),
          ),
      ],
    );
  }
}

/// A sheet with Chip on top, a title and a line, then [children].
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.lead,
    required this.children,
  });

  final String title;
  final String lead;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: CoinBuddy(mood: BuddyMood.excited, size: 72)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text(
              lead,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
