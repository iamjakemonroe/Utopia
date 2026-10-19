import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auras/data/aura_repository.dart';
import '../../birthday/presentation/birthday_providers.dart';
import '../../events/data/events_repository.dart';
import '../../events/presentation/events_controller.dart';
import '../../maestro/presentation/maestro_providers.dart';
import '../../store/presentation/store_controller.dart';
import 'providers/auth_providers.dart';

/// A guest who signs in to an account that already exists brings everything
/// with them: a ticket is taken as the guest ([holdGuestTicket]), kept on
/// the device, and used once signed in ([finishGuestTransfer]).
const _ticketKey = 'guest_transfer_ticket';

/// As the guest, before the sign-in code is sent. Never throws: without a
/// ticket they still sign in, the guest's things just stay behind.
Future<void> holdGuestTicket(WidgetRef ref) async {
  try {
    final ticket = await ref.read(authRepositoryProvider).startGuestTransfer();
    await _prefs(ref)?.setString(_ticketKey, ticket);
  } catch (_) {}
}

/// Signed in: moves what the held guest had into this account, then has the
/// app load it all again. Whether anything moved. Never throws; a ticket
/// that couldn't be used yet (offline) is kept and tried again later.
Future<bool> finishGuestTransfer(WidgetRef ref) async {
  final prefs = _prefs(ref);
  final ticket = prefs?.getString(_ticketKey);
  if (prefs == null || ticket == null) return false;
  final repo = ref.read(authRepositoryProvider);
  final me = repo.currentUser;
  if (me == null || me.isAnonymous) return false;
  final bool moved;
  try {
    moved = await repo.finishGuestTransfer(ticket);
  } catch (_) {
    return false;
  }
  await prefs.remove(_ticketKey);
  if (moved) {
    // Loaded for the account a moment ago, before the guest's things came.
    ref.invalidate(profileByIdProvider(me.id));
    ref.invalidate(myAurasProvider);
    ref.invalidate(seasonItemsProvider);
    ref.invalidate(maestroProvider);
    ref.invalidate(myBirthdayProvider);
    await ref.read(storeControllerProvider.notifier).refresh();
    await ref.read(eventsProvider.notifier).visit();
  }
  return moved;
}

SharedPreferences? _prefs(WidgetRef ref) {
  try {
    return ref.read(sharedPreferencesProvider);
  } catch (_) {
    return null;
  }
}
