import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/platform/currency_rule.dart';

void main() {
  group('from the country', () {
    test('Nigeria pays in naira', () {
      expect(currencyFor(country: 'NG', timeZone: 'Europe/London'), 'NGN');
    });

    test('the UK and the Crown Dependencies pay in pounds', () {
      for (final c in ['GB', 'IM', 'JE', 'GG', 'gb']) {
        expect(
          currencyFor(country: c, timeZone: 'Africa/Lagos'),
          'GBP',
          reason: c,
        );
      }
    });

    test('the euro countries pay in euros', () {
      for (final c in [
        'FR',
        'DE',
        'IE',
        'ES',
        'IT',
        'NL',
        'BG',
        'HR',
        'ME',
        'XK',
        'RE',
        'MF',
      ]) {
        expect(
          currencyFor(country: c, timeZone: 'America/New_York'),
          'EUR',
          reason: c,
        );
      }
    });

    test('everyone else pays in dollars, other European countries too', () {
      for (final c in ['US', 'GH', 'KE', 'CH', 'RS', 'NO', 'SE', 'PL', 'CA']) {
        expect(
          currencyFor(country: c, timeZone: 'Europe/London'),
          'USD',
          reason: c,
        );
      }
    });
  });

  group('from the time zone, when the country is unknown', () {
    test('Lagos pays in naira', () {
      expect(currencyFor(country: null, timeZone: 'Africa/Lagos'), 'NGN');
    });

    test('London, Jersey, Guernsey and the Isle of Man pay in pounds', () {
      for (final z in [
        'Europe/London',
        'Europe/Jersey',
        'Europe/Guernsey',
        'Europe/Isle_of_Man',
      ]) {
        expect(currencyFor(timeZone: z), 'GBP', reason: z);
      }
    });

    test('the euro time zones pay in euros', () {
      for (final z in [
        'Europe/Paris',
        'Europe/Berlin',
        'Europe/Dublin',
        'Europe/Sofia',
        'Atlantic/Canary',
        'Indian/Reunion',
        'Asia/Nicosia',
        'Europe/Podgorica',
      ]) {
        expect(currencyFor(timeZone: z), 'EUR', reason: z);
      }
    });

    test('anywhere else, and no time zone, pays in dollars', () {
      for (final z in [
        'America/New_York',
        'Europe/Zurich',
        'Europe/Belgrade',
        'Africa/Accra',
        '',
      ]) {
        expect(currencyFor(timeZone: z), 'USD', reason: z);
      }
    });

    test("Cloudflare's unknown and Tor codes, or junk, fall back to it", () {
      expect(currencyFor(country: 'XX', timeZone: 'Europe/London'), 'GBP');
      expect(currencyFor(country: 'T1', timeZone: 'Europe/Paris'), 'EUR');
      expect(currencyFor(country: '', timeZone: 'Africa/Lagos'), 'NGN');
      expect(currencyFor(country: 'GBR', timeZone: 'Europe/Paris'), 'EUR');
    });
  });
}
