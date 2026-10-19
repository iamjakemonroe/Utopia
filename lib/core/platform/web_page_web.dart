import 'dart:js_interop';

import 'package:web/web.dart' as web;

Map<String, String> pageQuery() {
  try {
    return Uri.parse(web.window.location.href).queryParameters;
  } catch (_) {
    return const {};
  }
}

void clearPageQuery() {
  try {
    final l = web.window.location;
    web.window.history.replaceState(null, '', '${l.pathname}${l.hash}');
  } catch (_) {}
}

@JS('Intl.DateTimeFormat')
external _DateFormat _dateFormat();

extension type _DateFormat._(JSObject _) implements JSObject {
  external _Resolved resolvedOptions();
}

extension type _Resolved._(JSObject _) implements JSObject {
  external String? get timeZone;
}

String timeZone() {
  try {
    return _dateFormat().resolvedOptions().timeZone ?? '';
  } catch (_) {
    return '';
  }
}
