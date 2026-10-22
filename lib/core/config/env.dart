/// Reads build-time config injected via `--dart-define-from-file=env/local.json`.
///
/// The publishable key (formerly "anon key") is safe to ship in the client
/// (it's protected by Postgres RLS) — this is why we use dart-define instead
/// of bundling a secrets-shaped asset file. The secret/service role key must
/// NEVER be read here; it only ever lives server-side (Supabase CLI / Edge
/// Function runtime env).
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Tester builds (`--dart-define=UTOPIA_TEST_STORE=true`): while the store
  /// products aren't live, "Buy" unlocks items and adds coins for free so
  /// testers can try everything. Never set this for a store release.
  static const bool testStore = bool.fromEnvironment('UTOPIA_TEST_STORE');

  /// Coin top-ups for real money through the App Store and Play Store
  /// (`--dart-define=UTOPIA_REAL_MONEY_STORE=true`). Turn it on once the
  /// coin products exist in both stores and the verify-purchase function
  /// has the store keys; until then the coin shop says top-ups are coming
  /// soon. Worlds and piece sets are always bought with coins.
  static const bool realMoneyStore = bool.fromEnvironment(
    'UTOPIA_REAL_MONEY_STORE',
  );

  /// Where crash reports go (a Sentry project's DSN, `SENTRY_DSN` in
  /// env/local.json). Empty: no crash reporting at all.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// PostHog's public client configuration, passed at build time alongside
  /// the other values in env/local.json.
  static const String posthogProjectToken = String.fromEnvironment(
    'POSTHOG_PROJECT_TOKEN',
  );
  static const String posthogHost = String.fromEnvironment('POSTHOG_HOST');

  /// Non-null when the app was built without `--dart-define-from-file`.
  /// main.dart shows this on screen instead of throwing: a throw before
  /// runApp leaves the device on the blank native launch screen, which
  /// looks like the app is broken rather than misconfigured.
  static String? get configError {
    if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
      return null;
    }
    return 'Missing Supabase config.\n\n'
        'Run with:\n'
        'flutter run --dart-define-from-file=env/local.json\n\n'
        'See env/local.example.json for the expected keys.';
  }
}
