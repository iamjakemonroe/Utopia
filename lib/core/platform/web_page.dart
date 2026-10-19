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

  /// The player's currency, from their time zone: naira in Nigeria, cedis
  /// in Ghana... and US dollars elsewhere (or in the apps).
  static String currency() => switch (impl.timeZone()) {
    'Africa/Lagos' => 'NGN',
    'Africa/Accra' => 'GHS',
    'Africa/Nairobi' => 'KES',
    'Africa/Johannesburg' => 'ZAR',
    'Europe/London' => 'GBP',
    _ => 'USD',
  };
}
