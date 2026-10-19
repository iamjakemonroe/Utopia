import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Kept by index.html when the browser offers to install (it can come
/// before the game has loaded).
@JS('utopiaInstallPrompt')
external _InstallPrompt? get _installPrompt;

@JS('utopiaInstallPrompt')
external set _installPrompt(_InstallPrompt? value);

extension type _InstallPrompt._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
  external JSPromise<_Choice> get userChoice;
}

extension type _Choice._(JSObject _) implements JSObject {
  external String get outcome;
}

bool installed() {
  try {
    final standalone = web.window
        .matchMedia('(display-mode: standalone)')
        .matches;
    final iosHome = web.window.navigator.getProperty<JSAny?>('standalone'.toJS);
    return standalone ||
        (iosHome != null &&
            iosHome.isA<JSBoolean>() &&
            (iosHome as JSBoolean).toDart);
  } catch (_) {
    return false;
  }
}

bool canPrompt() {
  try {
    return _installPrompt != null;
  } catch (_) {
    return false;
  }
}

Future<bool> prompt() async {
  final offer = _installPrompt;
  if (offer == null) return false;
  try {
    await offer.prompt().toDart;
    final choice = await offer.userChoice.toDart;
    // A prompt can only be shown once.
    _installPrompt = null;
    return choice.outcome == 'accepted';
  } catch (_) {
    return false;
  }
}

bool macSafari() {
  final agent = web.window.navigator.userAgent;
  return agent.contains('Macintosh') &&
      agent.contains('Safari') &&
      !agent.contains('Chrome') &&
      !agent.contains('Chromium') &&
      !agent.contains('Edg');
}
