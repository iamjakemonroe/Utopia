import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/notification_repository.dart';
import '../../../core/widgets/frame_island.dart';
import '../../../l10n/strings.dart';

/// The bell in the home app bar: opens notifications, shows how many are
/// unread, and gives a little ring now and then while there are some.
class NotificationBellButton extends ConsumerStatefulWidget {
  const NotificationBellButton({super.key});

  @override
  ConsumerState<NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState extends ConsumerState<NotificationBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider);
    // Only swings (and only asks for frames) while something is unread.
    if (unread > 0 && !_ring.isAnimating) {
      _ring.repeat();
    } else if (unread == 0 && _ring.isAnimating) {
      _ring.stop();
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: strings.notificationBellNotifications,
          onPressed: () => context.push('/notifications'),
          icon: FrameIsland(
            size: const Size.square(24),
            child: AnimatedBuilder(
              animation: _ring,
              builder: (context, child) {
                // A quick swing at the start of each cycle.
                final t = _ring.value;
                final swing = unread == 0 || t > 0.25
                    ? 0.0
                    : math.sin(t / 0.25 * math.pi * 4) * (1 - t / 0.25) * 0.45;
                return Transform.rotate(
                  angle: swing,
                  alignment: Alignment.topCenter,
                  child: child,
                );
              },
              child: Icon(
                unread > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
              ),
            ),
          ),
        ),
        if (unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
