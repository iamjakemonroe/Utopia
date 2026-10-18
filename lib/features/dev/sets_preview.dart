import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/utopia_themes.dart';
import '../../core/widgets/coin_buddy.dart';
import '../../core/widgets/utopia_world.dart';
import '../../core/widgets/world_sets.dart';

/// Debug builds only (the "sets" debug route): each set's world with its
/// set on and Chip in its costume, a few seconds each.
class SetsPreview extends StatefulWidget {
  const SetsPreview({super.key});

  @override
  State<SetsPreview> createState() => _SetsPreviewState();
}

class _SetsPreviewState extends State<SetsPreview> {
  static final _stops = [
    (UtopiaThemes.utopiaDojo, WorldSets.dragon),
    (UtopiaThemes.utopiaZombie, WorldSets.zombie),
    (UtopiaThemes.utopiaHeaven, WorldSets.heaven),
    (UtopiaThemes.utopiaHell, WorldSets.hell),
    (UtopiaThemes.utopiaMusic, WorldSets.music),
    (UtopiaThemes.utopiaHalloween, WorldSets.halloween),
  ];
  int _at = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _show(0);
    _timer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _show((_at + 1) % _stops.length),
    );
  }

  void _show(int i) {
    for (final (_, set) in _stops) {
      set.on.value = false;
      set.settle();
    }
    final set = _stops[i].$2;
    set.on.value = true;
    set.settle();
    setState(() => _at = i);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final (_, set) in _stops) {
      set.on.value = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (theme, _) = _stops[_at];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          UtopiaWorld(key: ValueKey(theme.id), style: theme.world),
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoinBuddy(size: 150),
                CoinBuddy(mood: BuddyMood.hot, size: 150),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
