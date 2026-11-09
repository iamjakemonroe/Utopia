import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Map<String, String> pageQuery() {
  try {
    return Uri.parse(web.window.location.href).queryParameters;
  } catch (_) {
    return const {};
  }
}

/// The address with only [query] after the path (none when it's empty),
/// without a reload or a new history entry.
void setPageQuery(Map<String, String> query) {
  try {
    final l = web.window.location;
    final search = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    web.window.history.replaceState(null, '', '${l.pathname}$search${l.hash}');
  } catch (_) {}
}

void pageEvent(String name) {
  try {
    web.window.dispatchEvent(web.Event(name));
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

const _geoKey = 'utopia.geo';

/// The buyer's country as Cloudflare has it ({"country":"GB"} from
/// /api/geo on this site), kept for the rest of the browser session. Null
/// when the site doesn't answer that (running locally).
Future<String?> geoCountry() async {
  try {
    final kept = web.window.sessionStorage.getItem(_geoKey);
    if (kept != null && kept.isNotEmpty) return kept;
  } catch (_) {}
  try {
    final res = await web.window.fetch('/api/geo'.toJS).toDart;
    if (!res.ok) return null;
    final body = jsonDecode((await res.text().toDart).toDart);
    final country = body is Map ? body['country'] : null;
    if (country is! String || country.isEmpty) return null;
    try {
      web.window.sessionStorage.setItem(_geoKey, country);
    } catch (_) {}
    return country;
  } catch (_) {
    return null;
  }
}
