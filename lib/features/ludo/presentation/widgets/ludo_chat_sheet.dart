import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/game_chat_sheet.dart';
import '../controllers/ludo_match_controller.dart';
import 'ludo_pieces.dart';
import '../../../../l10n/strings.dart';

/// Ludo's chat: the shared game chat, with names in each player's seat
/// color and war/peace reactions shown as system lines.
Future<void> showLudoChat({
  required BuildContext context,
  required String matchId,
  required Set<String> muted,
}) {
  final container = ProviderScope.containerOf(context);
  final provider = ludoMatchControllerProvider(matchId);
  final controller = container.read(provider.notifier);
  LudoMatchState state() => container.read(provider);

  return showGameChat(
    context: context,
    muted: muted,
    config: GameChatConfig(
      messages: provider.select((s) => s.chat),
      friends: state().isFriendsGame,
      send: (text, kind) => controller.sendChat(text, kind: kind),
      sendVoice: controller.sendVoice,
      setOpen: (open) {
        if (controller.mounted) controller.setChatOpen(open);
      },
      accentFor: (userId) {
        final color = state().colorOf(userId);
        return color == null ? null : ludoColorPalette[color];
      },
      systemLine: (m) {
        if (m.kind != 'reaction') return null;
        final color = state().colorOf(m.senderId);
        final who = color == null
            ? strings.ludoChatSomeone
            : ludoColorName(color);
        return m.body == 'war'
            ? ChatSystemLine(
                strings.ludoChatChoseWar(who),
                sticker: 'chip:evil',
              )
            : ChatSystemLine(
                strings.ludoChatMadePeace(who),
                sticker: 'chip:peaceful',
              );
      },
    ),
  );
}
