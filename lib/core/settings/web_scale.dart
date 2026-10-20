import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_controller.dart';

/// How big Utopia is drawn in a browser, as a share of its normal size
/// (Settings > Screen size): 85% on a phone's browser, 90% on a tablet's or
/// a computer's, up to 120%. The apps are always 100%.
class WebScaleController extends StateNotifier<double> {
  WebScaleController(this._prefs)
    : super(
        kIsWeb
            ? (_prefs?.getDouble(_key)?.clamp(min, max).toDouble() ??
                  defaultScale)
            : 1,
      );

  final SharedPreferences? _prefs;

  static const _key = 'web_scale';
  static const min = 0.5;
  static const max = 1.2;

  /// The size it starts at: 85% on a phone (more of the game fits, still
  /// easy to tap), 90% on anything bigger. The screen's size decides, not
  /// what the browser says it is: a tablet's says it's a computer.
  static double get defaultScale {
    final view = ui.PlatformDispatcher.instance.views.firstOrNull;
    if (view == null || view.devicePixelRatio == 0) return 0.9;
    final size = view.physicalSize / view.devicePixelRatio;
    return size.shortestSide < 600 ? 0.85 : 0.9;
  }

  void set(double scale) {
    if (!kIsWeb) return;
    state = (scale.clamp(min, max) * 20).round() / 20;
    _prefs?.setDouble(_key, state);
  }

  void reset() => set(defaultScale);
}

final webScaleProvider = StateNotifierProvider<WebScaleController, double>((
  ref,
) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}
  return WebScaleController(prefs);
});

/// Draws [child] at [scale]: laid out on a screen 1/[scale] the size, then
/// scaled to fill this one (touches land where they look).
class WebScale extends StatelessWidget {
  const WebScale({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale == 1) return child;
    final media = MediaQuery.of(context);
    final size = media.size / scale;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: MediaQuery(
            data: media.copyWith(
              size: size,
              padding: media.padding / scale,
              viewPadding: media.viewPadding / scale,
              viewInsets: media.viewInsets / scale,
              devicePixelRatio: media.devicePixelRatio * scale,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
