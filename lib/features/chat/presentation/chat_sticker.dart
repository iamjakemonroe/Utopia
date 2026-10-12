import 'package:flutter/material.dart';

import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/utopia_icons.dart';

/// Stickers players can send in chat: Chip in a mood, or a glossy icon.
/// Sent as the message body ("chip:happy", "icon:heart").
const kChatStickers = [
  'chip:happy',
  'chip:excited',
  'chip:thinking',
  'chip:sad',
  'chip:evil',
  'chip:peaceful',
  'icon:heart',
  'icon:fire',
  'icon:thumb',
  'icon:party',
];

bool isChatSticker(String body) =>
    body.startsWith('chip:') || body.startsWith('icon:');

const _icons = {
  'heart': (Icons.favorite_rounded, Color(0xFFFF5C9C)),
  'fire': (Icons.local_fire_department_rounded, Color(0xFFFF8A3D)),
  'thumb': (Icons.thumb_up_rounded, Color(0xFF4DA3FF)),
  'party': (Icons.celebration_rounded, Color(0xFFB27BFF)),
};

class ChatSticker extends StatelessWidget {
  const ChatSticker({super.key, required this.id, this.size = 44});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (id.startsWith('chip:')) {
      final mood = BuddyMood.values
          .where((m) => m.name == id.substring(5))
          .firstOrNull;
      return CoinBuddy(mood: mood ?? BuddyMood.happy, size: size);
    }
    final icon = _icons[id.startsWith('icon:') ? id.substring(5) : ''];
    if (icon != null) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: GlossyBadge(icon: icon.$1, color: icon.$2, size: size * 0.8),
        ),
      );
    }
    // Anything else (older messages) is shown as sent.
    return Text(id, style: TextStyle(fontSize: size * 0.7));
  }
}
