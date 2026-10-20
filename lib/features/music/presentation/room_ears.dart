import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/audio/room_sound.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../notifications/presentation/notification_actions.dart';

/// Lets the Music world hear the room: while it's turned on (Settings >
/// Sound), the Music world is on screen (being drawn, not just chosen: not
/// under a game), the app is open and nothing else needs the microphone (a
/// voice note), it listens (RoomListener) and the show dances to what it
/// hears. The first time a player is home in the Music world, it asks.
class RoomEars extends ConsumerStatefulWidget {
  const RoomEars({super.key});

  @override
  ConsumerState<RoomEars> createState() => _RoomEarsState();
}

class _RoomEarsState extends ConsumerState<RoomEars>
    with WidgetsBindingObserver {
  final _listener = RoomListener();
  bool _open = true;
  bool _asking = false;

  /// Looks every couple of seconds whether the world's still on screen.
  Timer? _look;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _open = state == null || state == AppLifecycleState.resumed;
    RoomSound.hold.addListener(_sync);
    _look = Timer.periodic(const Duration(seconds: 2), (_) => _sync());
    ref.read(goRouterProvider).routerDelegate.addListener(_maybeAsk);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync();
      _maybeAsk();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RoomSound.hold.removeListener(_sync);
    _look?.cancel();
    ref.read(goRouterProvider).routerDelegate.removeListener(_maybeAsk);
    _listener.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _open = state == AppLifecycleState.resumed;
    _sync();
  }

  bool get _inMusicWorld =>
      ref.read(themeControllerProvider).world.biome == WorldBiome.music;

  /// Listening exactly when it should be.
  Future<void> _sync() async {
    if (!mounted) return;
    final wanted =
        ref.read(musicWorldListensProvider) &&
        _inMusicWorld &&
        RoomSound.onScreen &&
        _open &&
        RoomSound.hold.value == 0;
    if (wanted && !RoomSound.listening) {
      final ok = await _listener.start();
      // Not allowed the microphone: off, so it isn't asked again and again.
      if (!ok && mounted) {
        ref.read(musicWorldListensProvider.notifier).set(false);
      }
    } else if (!wanted && RoomSound.listening) {
      await _listener.stop();
      // The microphone switched the phone's audio over: put it back.
      if (mounted) ref.read(gameAudioProvider).reclaimSession();
    }
  }

  /// Home in the Music world, never asked: would they like it to listen?
  Future<void> _maybeAsk() async {
    if (_asking || !mounted || !_inMusicWorld) return;
    final listens = ref.read(musicWorldListensProvider.notifier);
    if (listens.asked || ref.read(musicWorldListensProvider)) return;
    final router = ref.read(goRouterProvider);
    if (currentPath(router) != '/home') return;
    final context = appNavigatorContext(ref);
    if (context == null || !context.mounted) return;
    _asking = true;
    listens.markAsked();
    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AskSheet(),
    );
    _asking = false;
    if (yes == true && mounted) {
      listens.set(true);
      await _sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(musicWorldListensProvider, (_, _) => _sync());
    ref.listen(themeControllerProvider, (_, _) {
      _sync();
      _maybeAsk();
    });
    return const SizedBox.shrink();
  }
}

/// "Let the Music world hear the room?"
class _AskSheet extends StatelessWidget {
  const _AskSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: PopCard(
          borderRadius: 28,
          tint: const Color(0xFFFF4FD8),
          glow: const Color(0xFFFF4FD8),
          sheet: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                size: 48,
                color: Color(0xFFFF4FD8),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Let the Music world hear the room?',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                'Play music, sing or clap, and the show dances to it: the '
                'lights, the lasers, the speakers and the crowd. It only '
                'listens for how loud it is and where the beat is. Nothing '
                'is recorded or sent anywhere. Turn it off any time in '
                'Settings.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Turn it on',
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
