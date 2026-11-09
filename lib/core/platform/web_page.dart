import 'currency_rule.dart';
import 'web_page_native.dart'
    if (dart.library.js_interop) 'web_page_web.dart'
    as impl;

/// The page Utopia was opened at, in a browser.
abstract final class WebPage {
  static Map<String, String> _query = const {};

  /// What the address said when the game opened (?install=1, or a
  /// payment coming back: ?status=…&tx_ref=…&transaction_id=…). Empty in
  /// the apps.
  static Map<String, String> get query => _query;

  /// Reads the address's query, then takes it out of the address, so a
  /// refresh doesn't act on it twice. Call once, at startup.
  static void captureQuery() {
    _query = impl.pageQuery();
    if (_query.isNotEmpty) impl.clearPageQuery();
  }

  /// The loading page (web/index.html) stays up past the game's first
  /// frame, until [releaseLoading]: the splash draws everything once out
  /// of sight first, a moment that page's own animation covers.
  static void holdLoading() => impl.pageEvent('utopia-hold');

  static void releaseLoading() => impl.pageEvent('utopia-ready');

  static Future<String>? _currency;

  /// The currency prices are shown and charged in ([currencyFor]): from the
  /// buyer's country (GET /api/geo on this site, Cloudflare's answer, given
  /// 1.5 seconds), or from the browser's time zone when that isn't there
  /// (running locally). Asked once a session.
  static Future<String> currency() => _currency ??= _pickCurrency();

  static Future<String> _pickCurrency() async {
    String? country;
    try {
      country = await impl.geoCountry().timeout(
        const Duration(milliseconds: 1500),
      );
    } catch (_) {}
    return currencyFor(country: country, timeZone: impl.timeZone());
  }
}
