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

ValueNotifier<bool> watch() {
  final active = ValueNotifier(_now());
  try {
    web.document.addEventListener(
      'fullscreenchange',
      ((web.Event _) => active.value = _now()).toJS,
    );
  } catch (_) {}
  return active;
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
