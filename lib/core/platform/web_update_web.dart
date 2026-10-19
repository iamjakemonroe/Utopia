import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String?> liveWebBuild() async {
  try {
    final response = await web.window
        .fetch('build.json'.toJS, web.RequestInit(cache: 'no-store'))
        .toDart;
    if (!response.ok) return null;
    final text = (await response.text().toDart).toDart;
    final build = jsonDecode(text)['build'];
    return build is String ? build : null;
  } catch (_) {
    return null;
  }
}

void reloadPage() => web.window.location.reload();

void Function() onPageShown(void Function() callback) {
  final onVisible = ((web.Event _) {
    if (web.document.visibilityState == 'visible') callback();
  }).toJS;
  final onShow = ((web.Event _) => callback()).toJS;
  web.document.addEventListener('visibilitychange', onVisible);
  web.window.addEventListener('pageshow', onShow);
  web.window.addEventListener('focus', onShow);
  return () {
    web.document.removeEventListener('visibilitychange', onVisible);
    web.window.removeEventListener('pageshow', onShow);
    web.window.removeEventListener('focus', onShow);
  };
}
