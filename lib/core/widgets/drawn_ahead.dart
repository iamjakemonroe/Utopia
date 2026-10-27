import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// In a browser, the first time anything is drawn the GPU has to work out
/// how (it builds shaders for it), and whatever showed it froze meanwhile:
/// the side menu took most of a second to open the first time. This draws
/// [ahead] for a moment, once per visit, where it can't be seen (put it
/// under something that covers it, like the world: see AppBackground's
/// `under`), when the screen has been up a few seconds and nobody has
/// touched it for a little while. Then its first real showing has nothing
/// new to work out. Nothing on screen changes.
class DrawnAhead extends StatefulWidget {
  const DrawnAhead({super.key, required this.ahead});

  final Widget ahead;

  @override
  State<DrawnAhead> createState() => _DrawnAheadState();
}

class _DrawnAheadState extends State<DrawnAhead> {
  /// Drawn ahead already this visit (shaders last as long as the page).
  static bool _done = false;

  bool _drawing = false;
  Timer? _wait;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb || _done) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _listening = true;
    _later(const Duration(seconds: 3));
  }

  /// A touch puts it off: the hitch should land while nothing's happening.
  void _onPointer(PointerEvent event) {
    if (!_drawing) _later(const Duration(milliseconds: 1500));
  }

  void _later(Duration wait) {
    _wait?.cancel();
    _wait = Timer(wait, _draw);
  }

  void _stopListening() {
    if (!_listening) return;
    _listening = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }

  void _draw() {
    if (!mounted || _done) return;
    _done = true;
    _stopListening();
    setState(() => _drawing = true);
    // Long enough for a frame with it in to be drawn, however slowly.
    _wait = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _drawing = false);
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _drawing ? widget.ahead : const SizedBox.shrink();
}
