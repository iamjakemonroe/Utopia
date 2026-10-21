import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'web_install_web.dart' as install;

bool _apple() {
  final agent = web.window.navigator.userAgent;
  // An iPad asks for the desktop site: it says Macintosh, with touch.
  return RegExp('iPhone|iPad|iPod').hasMatch(agent) ||
      (agent.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);
}

bool available() {
  try {
    return web.document.fullscreenEnabled && !install.installed() && !_apple();
  } catch (_) {
    return false;
  }
}

bool touch() {
  try {
    return web.window.matchMedia('(pointer: coarse)').matches;
  } catch (_) {
    return false;
  }
}

bool _now() {
  try {
    return web.document.fullscreenElement != null;
  } catch (_) {
    return false;
  }
}

/// Leaving full screen because the game asked ([exit]), not the browser.
bool _leaving = false;
final _leftByBrowser = <void Function()>[];
final _active = ValueNotifier(_now());
bool _listening = false;

/// Hears the browser go in and out of full screen (once, however many
/// ask).
void _listen() {
  if (_listening) return;
  _listening = true;
  try {
    web.document.addEventListener(
      'fullscreenchange',
      ((web.Event _) {
        final now = _now();
        _active.value = now;
        if (now) return;
        if (_leaving) {
          _leaving = false;
          return;
        }
        for (final action in List.of(_leftByBrowser)) {
          action();
        }
      }).toJS,
    );
  } catch (_) {}
}

ValueNotifier<bool> watch() {
  _listen();
  return _active;
}

void onLeftByBrowser(void Function() action) {
  _listen();
  _leftByBrowser.add(action);
}

void enter() {
  if (_now()) return;
  try {
    web.document.documentElement
        ?.requestFullscreen(web.FullscreenOptions(navigationUI: 'hide'))
        .toDart
        .catchError((_) => null);
  } catch (_) {}
}

void exit() {
  if (!_now()) return;
  _leaving = true;
  try {
    web.document.exitFullscreen().toDart.catchError((_) => null);
  } catch (_) {}
}

void onNextTouch(void Function() action) {
  const types = ['pointerup', 'keydown'];
  late final JSFunction listener;
  var done = false;
  void handle(web.Event _) {
    if (done) return;
    done = true;
    for (final type in types) {
      web.document.removeEventListener(
        type,
        listener,
        web.EventListenerOptions(capture: true),
      );
    }
    action();
  }

  listener = handle.toJS;
  for (final type in types) {
    web.document.addEventListener(
      type,
      listener,
      web.AddEventListenerOptions(capture: true),
    );
  }
}
