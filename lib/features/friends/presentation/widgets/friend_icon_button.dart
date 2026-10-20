import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/friends_providers.dart';
import 'friends_popup.dart';
import '../../../../l10n/strings.dart';

/// The person-icon in the home app bar that opens the friends popup. Shows
/// a small badge when there are pending incoming friend requests, so
/// "someone wants to add you" is visible without opening the sheet.
class FriendIconButton extends ConsumerWidget {
  const FriendIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserProvider)?.id;
    final pendingCount = myId == null
        ? 0
        : ref
              .watch(friendsPopupControllerProvider(myId))
              .incomingRequests
              .length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.people_alt_outlined),
          tooltip: strings.friendIconButtonFriends,
          onPressed: () => showFriendsPopup(context),
        ),
        if (pendingCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$pendingCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
