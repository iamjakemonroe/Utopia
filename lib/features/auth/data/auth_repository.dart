import 'dart:async';

import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../friends/data/presence.dart';

/// Thin wrapper around Supabase auth calls used by this app.
///
/// Account upgrade (anonymous -> permanent) is email-only for Step 1; phone
/// auth is deferred since it requires a paid SMS provider to be configured
/// in the Supabase dashboard first.
///
/// Two distinct email flows exist and must not be conflated:
///  - "Log in or sign up" from a signed-out state uses [signInWithEmailOtp] /
///    [verifySignInOtp] (`OtpType.email`) — this may sign into an existing
///    account or create a new one.
///  - "Save your account" from an active anonymous session uses [linkEmail] /
///    [verifyLinkOtp] (`OtpType.emailChange`) — this attaches the email to the
///    *current* `auth.users.id` via Supabase's anonymous-linking flow, which
///    is what carries the coin balance over instead of losing it. When the
///    email already has an account, the guest signs in to that instead, and
///    [startGuestTransfer] / [finishGuestTransfer] bring the guest's things.
class AuthRepository {
  AuthRepository(this._client) {
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      unawaited(_syncPostHogIdentity(state.session?.user));
    });
    // Supabase restores persisted sessions before this repository is created.
    // Sync it immediately so startup errors and screens have the same person.
    unawaited(_syncPostHogIdentity(_client.auth.currentUser));
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _authSubscription;
  String? _postHogUserId;
  String? _postHogEmail;
  bool? _postHogIsAnonymous;

  /// Keeps PostHog identity at the auth boundary, rather than repeating it
  /// at event and error call sites. Supabase [User.id] is a stable UUID; email
  /// remains a person property and is never used as the distinct ID.
  Future<void> _syncPostHogIdentity(User? user) async {
    if (user == null) {
      if (_postHogUserId == null) {
        // A clean launch with no Supabase session must not retain a previous
        // device user's PostHog identity.
        await Posthog().reset();
        return;
      }
      _postHogUserId = null;
      _postHogEmail = null;
      _postHogIsAnonymous = null;
      await Posthog().reset();
      return;
    }

    final email = user.email;
    if (_postHogUserId == user.id &&
        _postHogEmail == email &&
        _postHogIsAnonymous == user.isAnonymous) {
      return;
    }
    _postHogUserId = user.id;
    _postHogEmail = email;
    _postHogIsAnonymous = user.isAnonymous;

    await Posthog().identify(
      userId: user.id,
      userProperties: {
        'is_anonymous': user.isAnonymous,
        if (email != null && email.isNotEmpty) r'$email': email,
      },
    );
  }

  /// Stops the auth listener when Riverpod disposes this repository.
  void dispose() => _authSubscription.cancel();

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signInAnonymously() {
    return _client.auth.signInAnonymously();
  }

  /// Sends a one-time code to sign in (existing account) or sign up (new
  /// account) with [email]. Only valid when there is no anonymous session to
  /// preserve.
  Future<void> signInWithEmailOtp(String email) {
    return _client.auth.signInWithOtp(email: email);
  }

  Future<void> verifySignInOtp({required String email, required String token}) {
    return _client.auth.verifyOTP(
      type: OtpType.email,
      email: email,
      token: token,
    );
  }

  /// Attaches [email] to the current (anonymous) session, sending a one-time
  /// code to confirm. Requires an active session.
  Future<void> linkEmail(String email) {
    return _client.auth.updateUser(UserAttributes(email: email));
  }

  Future<void> verifyLinkOtp({required String email, required String token}) {
    return _client.auth.verifyOTP(
      type: OtpType.emailChange,
      email: email,
      token: token,
    );
  }

  /// As a guest about to sign in to an account that already exists: a
  /// one-time ticket to everything the guest has, for [finishGuestTransfer]
  /// once signed in.
  Future<String> startGuestTransfer() async =>
      (await _client.rpc('guest_transfer_start')) as String;

  /// Signed in now: moves everything the guest with [ticket] had (coins,
  /// purchases, worlds, frames, progress, games, friends...) into this
  /// account. Whether anything moved.
  Future<bool> finishGuestTransfer(String ticket) async {
    final result = await _client.rpc(
      'guest_transfer_finish',
      params: {'p_ticket': ticket},
    );
    return result is Map && result['moved'] == true;
  }

  /// Friends see them go at once (while still signed in to say so).
  Future<void> signOut() async {
    await goOffline(_client);
    await _client.auth.signOut();
  }
}
