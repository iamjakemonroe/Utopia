import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Keeps a game from being left by accident: the screen's own question
/// ("leave this game?") comes up whichever way the player goes back.
///
/// The app's own back (Android's back button, the back swipe) comes to the
/// screen, and a PopScope catches it. In a browser, the browser's Back
/// button and a phone's edge swipe go back in the page's history instead,
/// which only the router hears: game routes ask [onExit] first, and it
/// keeps the game and asks too.
class LeaveGuard extends StatefulWidget {
  const LeaveGuard({
    super.key,
    required this.canLeave,
    required this.onAsk,
    required this.child,
    this.onPopped,
  });

  /// Nothing to lose by going (the game's over, or never started).
  final bool canLeave;

  /// Asks whether to leave, and goes if they say so: the screen's own
  /// question, which calls [release] before it leaves.
  final Future<void> Function() onAsk;

  /// The screen was popped (with nothing to ask).
  final VoidCallback? onPopped;
  final Widget child;

  static final List<_LeaveGuardState> _guards = [];

  /// The screen on top is going on purpose (the player said yes, or the
  /// game is over): let it.
  static void release() {
    if (_guards.isNotEmpty) _guards.last._released = true;
  }

  /// For [GoRoute.onExit] on game routes: leaving a game in progress asks
  /// first (and stays, for now).
  static bool onExit(BuildContext context, GoRouterState state) {
    if (_guards.isEmpty) return true;
    final guard = _guards.last;
    if (guard._released || guard.widget.canLeave) return true;
    guard._ask();
    return false;
  }

  @override
  State<LeaveGuard> createState() => _LeaveGuardState();
}

class _LeaveGuardState extends State<LeaveGuard> {
  bool _released = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    LeaveGuard._guards.add(this);
  }

  @override
  void dispose() {
    LeaveGuard._guards.remove(this);
    super.dispose();
  }

  /// One question at a time (a second back while it's up does nothing).
  Future<void> _ask() async {
    if (_asking) return;
    _asking = true;
    try {
      await widget.onAsk();
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.canLeave || _released,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) {
        widget.onPopped?.call();
      } else {
        _ask();
      }
    },
    child: widget.child,
  );
}
