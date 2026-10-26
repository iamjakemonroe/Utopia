import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = AuthRepository(ref.watch(supabaseClientProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

/// Emits on every auth transition (sign in, sign out, token refresh, link).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// The current user, derived from auth state changes so it updates reactively
/// (falls back to the synchronous current session for the first frame, before
/// the stream has emitted).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => ref.watch(authRepositoryProvider).currentUser,
  );
});

final isAnonymousProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isAnonymous ?? false;
});
