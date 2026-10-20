import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../chess/data/chess_repository.dart';
import '../../chess/presentation/controllers/chess_match_controller.dart';
import '../../coins/presentation/providers/coin_balance_provider.dart';
import '../../friends/presentation/providers/friends_providers.dart';
import '../../store/presentation/coin_shop.dart';
import '../data/notification_repository.dart';
import '../../../l10n/strings.dart';

/// A context under the app's navigator, for toasts and sheets started from
/// places above it (the alert banner lives above the router).
BuildContext? appNavigatorContext(WidgetRef ref) =>
    ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;

void _toast(
  WidgetRef ref,
  String text, {
  ToastKind kind = ToastKind.info,
  IconData? icon,
}) {
  final ctx = appNavigatorContext(ref);
  if (ctx != null && ctx.mounted) {
    showUtopiaToast(ctx, text, kind: kind, icon: icon);
  }
}

String _nameOf(WidgetRef ref, String? userId) {
  if (userId == null) return strings.notificationActionsSomeone;
  return profileDisplayName(
    ref.read(profileByIdProvider(userId)).valueOrNull,
    userId,
  );
}

/// Accepts or declines a friend request. Returns whether it went through.
Future<bool> answerFriendRequest(
  WidgetRef ref, {
  required String requestId,
  required String? fromId,
  required bool accept,
}) async {
  final me = ref.read(currentUserProvider)?.id;
  if (me == null) return false;
  try {
    await ref
        .read(friendsPopupControllerProvider(me).notifier)
        .respondFriendRequest(requestId: requestId, accept: accept);
    ref.read(gameAudioProvider).play(accept ? Sfx.reaction : Sfx.toggleOff);
    if (accept) {
      _toast(
        ref,
        strings.notificationActionsYouAndAreFriendsNow(_nameOf(ref, fromId)),
        kind: ToastKind.success,
        icon: Icons.people_rounded,
      );
    }
    return true;
  } catch (e) {
    _toast(
      ref,
      friendlyError(
        e,
        fallback: strings.notificationActionsThatRequestIsNoLonger,
      ),
      kind: ToastKind.error,
    );
    ref.read(friendsPopupControllerProvider(me).notifier).refresh();
    return false;
  }
}

/// Accepts a chess or checkers challenge and opens the game, or declines
/// it. [game] is the invite's game ('chess' when missing).
Future<bool> answerGameInvite(
  WidgetRef ref, {
  required String inviteId,
  required int stake,
  required bool accept,
  String? game,
}) async {
  final repository = ref.read(chessRepositoryProvider);
  if (!accept) {
    try {
      await repository.respondMatchInvite(inviteId: inviteId, accept: false);
      return true;
    } catch (_) {
      return false;
    }
  }
  final balance = ref.read(coinBalanceProvider).valueOrNull ?? 0;
  if (stake > balance) {
    final ctx = appNavigatorContext(ref);
    if (ctx != null && ctx.mounted) showCoinShop(ctx, needed: stake);
    return false;
  }
  try {
    final matchId = await repository.respondMatchInvite(
      inviteId: inviteId,
      accept: true,
    );
    if (matchId != null) {
      ref.read(goRouterProvider).push(boardMatchRoute(game, matchId));
    }
    return true;
  } catch (e) {
    _toast(
      ref,
      friendlyError(
        e,
        fallback: strings.notificationActionsThatChallengeIsNoLonger,
      ),
      kind: ToastKind.error,
    );
    return false;
  }
}

/// Marks [ids] read (all when null), quietly.
void markNotificationsRead(WidgetRef ref, [List<int>? ids]) {
  ref.read(notificationRepositoryProvider).markRead(ids).catchError((_) {});
}
