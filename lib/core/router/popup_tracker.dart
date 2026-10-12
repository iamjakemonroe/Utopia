import 'package:flutter/widgets.dart';

/// Counts the drawers, dialogs and pop-ups open on the app's navigator, so
/// things floating above every screen (like Chip's bubble) can step aside
/// while one is up.
class PopupTracker extends NavigatorObserver {
  PopupTracker._();

  static final instance = PopupTracker._();

  /// How many pop-up routes are open right now.
  final ValueNotifier<int> open = ValueNotifier(0);

  void _change(Route<dynamic>? route, int by) {
    if (route is! PopupRoute) return;
    // Navigator callbacks can land mid-build; update after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      open.value = (open.value + by).clamp(0, 999);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);
}
