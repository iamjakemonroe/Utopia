import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/now_playing/now_playing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/popup_tracker.dart';
import '../../../core/settings/gameplay_settings.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../notifications/presentation/notification_actions.dart';
import 'chip_chat_controller.dart';
import 'chip_chat_sheet.dart';
import '../../../core/widgets/frame_island.dart';
import '../../../l10n/strings.dart';

/// Chip in a little glass bubble, floating over the app's screens. Drag
/// him anywhere (he settles against the nearest edge); tap to chat. He
/// vibes to the player's music like he does on home, and steps aside on
/// home itself (he's already there), during games, on the sign-in screens
/// and while a drawer or dialog is open.
class FloatingChip extends ConsumerStatefulWidget {
  const FloatingChip({super.key});

  @override
  ConsumerState<FloatingChip> createState() => _FloatingChipState();
}

class _FloatingChipState extends ConsumerState<FloatingChip>
    with SingleTickerProviderStateMixin {
  static const _size = 68.0;

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  /// Where the bubble sits, as a fraction of the screen (so rotation and
  /// different screens keep him in a sensible place).
  Offset _at = const Offset(1, 0.96);
  Offset? _drag;
  String _path = '/splash';
  bool _shown = false;

  // Kept from initState: ref can't be read any more by dispose.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = ref.read(goRouterProvider);
    _router.routerDelegate.addListener(_onRoute);
    PopupTracker.instance.open.addListener(_onRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRoute());
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRoute);
    PopupTracker.instance.open.removeListener(_onRoute);
    _float.dispose();
    super.dispose();
  }

  void _onRoute() {
    if (!mounted) return;
    final path = currentPath(ref.read(goRouterProvider));
    if (path != _path) setState(() => _path = path);
    if (PopupTracker.instance.open.value >= 0) setState(() {});
  }

  /// Screens Chip floats over.
  static bool _floatsOver(String path) {
    if (path == '/splash' || path == '/home') return false;
    if (path.startsWith('/auth')) return false;
    // Drawing: the page needs every inch, and he'd be under the pencil.
    if (path.startsWith('/sketchbook/')) return false;
    // Live games: the board needs the whole screen.
    if (RegExp(r'^/(chess|checkers)/[^/]+$').hasMatch(path)) return false;
    if (RegExp(r'^/(ludo|eights)/[^/]+$').hasMatch(path) &&
        !path.startsWith(RegExp('/(ludo|eights)/room'))) {
      return false;
    }
    // A pool table (two on one phone, or Chip's coin tables).
    if (RegExp(r'^/pool/[^/]+$').hasMatch(path)) return false;
    // Guess My Doodle: he'd sit on the chat and the guess box.
    if (path.startsWith('/doodle-game/')) return false;
    return true;
  }

  void _open() {
    HapticFeedback.lightImpact();
    final ctx = appNavigatorContext(ref);
    if (ctx != null && ctx.mounted) showChipChat(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(currentUserProvider) != null;
    final enabled = ref.watch(
      gameplaySettingsProvider.select((s) => s.floatingChip),
    );
    final shown =
        signedIn &&
        enabled &&
        _floatsOver(_path) &&
        PopupTracker.instance.open.value == 0;
    if (shown != _shown) {
      _shown = shown;
      // Chip keeps listening for music while he's out.
      ref.read(nowPlayingProvider.notifier).setWatching(shown, who: 'bubble');
    }

    final music = ref.watch(nowPlayingProvider);
    final vibing =
        music.listening && ref.watch(gameplaySettingsProvider).showNowPlaying;
    final chatMood = ref.watch(chipChatProvider.select((s) => s.mood));
    final mood = vibing ? music.chipLine.mood : chatMood;

    final media = MediaQuery.of(context);
    final area = media.size;
    final pad = media.padding;
    final minY = pad.top + 60;
    final maxY = area.height - pad.bottom - _size - 24;
    final restX = _at.dx < 0.5 ? 10.0 : area.width - _size - 10;
    final restY = (minY + (maxY - minY) * _at.dy).clamp(minY, maxY);
    final pos = _drag ?? Offset(restX, restY);

    return IgnorePointer(
      ignoring: !shown,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: _drag == null
                ? const Duration(milliseconds: 420)
                : Duration.zero,
            curve: Curves.easeOutBack,
            left: pos.dx,
            top: pos.dy,
            child: AnimatedScale(
              scale: shown ? 1 : 0,
              duration: const Duration(milliseconds: 380),
              curve: shown ? Curves.easeOutBack : Curves.easeIn,
              child: GestureDetector(
                onTap: _open,
                onPanStart: (_) => setState(() => _drag = pos),
                onPanUpdate: (d) => setState(() {
                  final p = (_drag ?? pos) + d.delta;
                  _drag = Offset(
                    p.dx.clamp(0, area.width - _size),
                    p.dy.clamp(minY, maxY),
                  );
                }),
                onPanEnd: (_) => setState(() {
                  final p = _drag ?? pos;
                  _at = Offset(
                    p.dx + _size / 2 < area.width / 2 ? 0 : 1,
                    ((p.dy - minY) / (maxY - minY)).clamp(0, 1),
                  );
                  _drag = null;
                  HapticFeedback.selectionClick();
                }),
                child: Semantics(
                  button: true,
                  label: strings.floatingChipChatWithChip,
                  child: FrameIsland(
                    size: Size.square(_size),
                    child: AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) {
                        final bob = math.sin(_float.value * 2 * math.pi);
                        return SizedBox.square(
                          dimension: _size,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // His shadow, tighter as he dips toward it.
                              Positioned(
                                bottom: -2,
                                child: Container(
                                  width: _size * (0.5 - 0.05 * bob),
                                  height: _size * 0.1,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(_size),
                                    color: Colors.black.withValues(
                                      alpha: 0.22 + 0.06 * bob,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(0, -4 - bob * 4),
                                child: child,
                              ),
                            ],
                          ),
                        );
                      },
                      child: CoinBuddy(
                        mood: mood,
                        flavor: vibing
                            ? music.chipLine.flavor
                            : ChipFlavor.none,
                        size: _size,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
