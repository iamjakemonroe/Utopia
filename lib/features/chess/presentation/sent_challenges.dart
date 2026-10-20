import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/utopia_toast.dart';
import 'controllers/chess_match_controller.dart';

/// When [invite] (a challenge) runs out, if it says.
DateTime? challengeExpiresAt(Map<String, dynamic> invite) =>
    DateTime.tryParse(invite['expires_at'] as String? ?? '')?.toLocal();

/// The challenges in [invites] still waiting for an answer (and not yet
/// run out, even if the server's sweep hasn't said so), newest first.
List<Map<String, dynamic>> waitingChallenges(
  List<Map<String, dynamic>> invites, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  return [
    for (final invite in invites.reversed)
      if (invite['status'] == 'pending' &&
          (challengeExpiresAt(invite)?.isAfter(at) ?? true))
        invite,
  ];
}

/// Whole minutes left on [invite], at least 1, or null if it doesn't say.
int? challengeMinutesLeft(Map<String, dynamic> invite) {
  final expires = challengeExpiresAt(invite);
  if (expires == null) return null;
  final seconds = expires.difference(DateTime.now()).inSeconds;
  return seconds <= 0 ? 1 : (seconds / 60).ceil();
}

/// Takes back a challenge the player sent to [name], and says how it went.
/// Returns whether it's cancelled (it goes from both screens as the
/// invites are watched).
Future<bool> cancelChallenge(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> invite,
  String name,
) async {
  try {
    await ref
        .read(chessRepositoryProvider)
        .cancelMatchInvite(invite['id'] as String);
    if (context.mounted) {
      showUtopiaToast(
        context,
        'Challenge to $name cancelled.',
        icon: Icons.undo_rounded,
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      showUtopiaToast(
        context,
        friendlyError(e, fallback: "Couldn't cancel it. Try again."),
        kind: ToastKind.error,
      );
    }
    return false;
  }
}
