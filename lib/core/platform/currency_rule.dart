/// Which currency a buyer sees prices in and pays in, the rule every Kaivon
/// website shares: naira in Nigeria, pounds in the UK and the Crown
/// Dependencies, euros in the euro countries, US dollars everywhere else
/// (supabase/migrations/20261109120000_pound_and_euro_prices.sql).
///
/// [country] is the buyer's country as Cloudflare has it (ISO 3166-1
/// alpha-2, from /api/geo). When that's missing or unknown ('XX', or 'T1'
/// for Tor), the browser's [timeZone] decides instead.
String currencyFor({String? country, required String timeZone}) {
  final code = country?.trim().toUpperCase();
  if (code != null &&
      RegExp(r'^[A-Z]{2}$').hasMatch(code) &&
      !_unknown.contains(code)) {
    if (code == 'NG') return 'NGN';
    if (_poundCountries.contains(code)) return 'GBP';
    if (_euroCountries.contains(code)) return 'EUR';
    return 'USD';
  }
  if (timeZone == 'Africa/Lagos') return 'NGN';
  if (_poundZones.contains(timeZone)) return 'GBP';
  if (_euroZones.contains(timeZone)) return 'EUR';
  return 'USD';
}

/// Cloudflare's codes for "we don't know": no country, and Tor.
const _unknown = {'XX', 'T1'};

/// The UK, the Isle of Man, Jersey and Guernsey.
const _poundCountries = {'GB', 'IM', 'JE', 'GG'};

/// The euro area (Bulgaria from 2026), and the microstates and territories
/// that use the euro. Switzerland, Serbia and Europe's other non-euro
/// countries pay in dollars.
const _euroCountries = {
  'AT', 'BE', 'BG', 'HR', 'CY', 'EE', 'FI', 'FR', 'DE', 'GR', 'IE', //
  'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PT', 'SK', 'SI', 'ES', //
  'AD', 'MC', 'SM', 'VA', 'ME', 'XK', 'AX', 'GF', 'GP', 'MQ', 'RE', //
  'YT', 'PM', 'BL', 'MF',
};

const _poundZones = {
  'Europe/London',
  'Europe/Jersey',
  'Europe/Guernsey',
  'Europe/Isle_of_Man',
};

const _euroZones = {
  'Europe/Vienna',
  'Europe/Brussels',
  'Europe/Zagreb',
  'Europe/Nicosia',
  'Europe/Tallinn',
  'Europe/Helsinki',
  'Europe/Mariehamn',
  'Europe/Paris',
  'Europe/Berlin',
  'Europe/Busingen',
  'Europe/Athens',
  'Europe/Dublin',
  'Europe/Rome',
  'Europe/Riga',
  'Europe/Vilnius',
  'Europe/Luxembourg',
  'Europe/Malta',
  'Europe/Amsterdam',
  'Europe/Lisbon',
  'Europe/Bratislava',
  'Europe/Ljubljana',
  'Europe/Madrid',
  'Europe/Sofia',
  'Europe/Andorra',
  'Europe/Monaco',
  'Europe/San_Marino',
  'Europe/Vatican',
  'Europe/Podgorica',
  'Asia/Nicosia',
  'Asia/Famagusta',
  'Atlantic/Madeira',
  'Atlantic/Azores',
  'Atlantic/Canary',
  'Africa/Ceuta',
  'America/Cayenne',
  'America/Guadeloupe',
  'America/Martinique',
  'America/Miquelon',
  'America/St_Barthelemy',
  'America/Marigot',
  'Indian/Reunion',
  'Indian/Mayotte',
};
