import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/pop_card.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/chat_filter.dart';
import '../domain/chat_message.dart';
import '../domain/voice_note.dart';
import 'chat_sticker.dart';
import 'voice_notes.dart';
import '../../../core/audio/sound_controls.dart';

/// A centered note in the chat instead of a bubble ("Red chose war!").
class ChatSystemLine {
  const ChatSystemLine(this.text, {this.sticker});

  final String text;
  final String? sticker;
}

/// What a game hands its chat sheet: where the messages come from and how
/// to send. Ludo and chess each build one from their match controllers.
class GameChatConfig {
  const GameChatConfig({
    required this.messages,
    required this.friends,
    required this.send,
    required this.sendVoice,
    required this.setOpen,
    this.accentFor,
    this.systemLine,
  });

  /// The conversation, oldest first.
  final ProviderListenable<List<ChatMessage>> messages;

  /// Friends chat freely; public games are kept friendly.
  final bool friends;

  /// Sends a message of [kind]; returns an error to show, or null.
  final Future<String?> Function(String text, String kind) send;
  final VoiceSender sendVoice;

  /// Told when the sheet opens and closes, so unread counts can reset.
  final void Function(bool open) setOpen;

  /// A sender's color (their seat or side), for their name and bubble rim.
  final Color? Function(String userId)? accentFor;

  /// Shows some messages as a system line rather than a bubble.
  final ChatSystemLine? Function(ChatMessage message)? systemLine;
}

/// In-game chat. Friends chat freely; public games are kept friendly (the
/// filter masks offensive words) and lean on quick phrases and stickers.
Future<void> showGameChat({
  required BuildContext context,
  required GameChatConfig config,
  required Set<String> muted,
}) {
  closeSoundTray();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ChatSheet(config: config, muted: muted),
  );
}

class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet({required this.config, required this.muted});

  final GameChatConfig config;
  final Set<String> muted;

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _recorderKey = GlobalKey();
  bool _recording = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final setOpen = widget.config.setOpen;
    // Providers can't change while widgets build, so mark the chat read
    // just after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => setOpen(true));
  }

  @override
  void dispose() {
    final setOpen = widget.config.setOpen;
    WidgetsBinding.instance.addPostFrameCallback((_) => setOpen(false));
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Back down to the newest message. The list runs bottom-up, so the
  /// newest is at offset 0: the chat opens there and stays there as
  /// messages come in.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || _scroll.offset <= 0) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text, {String kind = 'text'}) async {
    if (!widget.config.friends && kind == 'text' && !ChatFilter.isClean(text)) {
      setState(() => _notice = 'Some words were hidden. Keep it friendly.');
    } else {
      setState(() => _notice = null);
    }
    final error = await widget.config.send(text, kind);
    if (!mounted) return;
    if (error != null) {
      setState(() => _notice = error);
    } else {
      ref.read(gameAudioProvider).play(Sfx.chat);
      _text.clear();
      _scrollToEnd();
    }
  }

  Future<String?> _sendVoice(
    Uint8List bytes, {
    required int ms,
    required List<int> wave,
  }) async {
    final error = await widget.config.sendVoice(bytes, ms: ms, wave: wave);
    if (error == null) _scrollToEnd();
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final me = ref.watch(currentUserProvider)?.id;
    final friends = config.friends;
    final messages = [
      for (final m in ref.watch(config.messages))
        if (!widget.muted.contains(m.senderId)) m,
    ];
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.62,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: sheetRadius(28),
          border: sheetBorder(AppColors.goldBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.glowRing.withValues(alpha: 0.35),
              blurRadius: 18,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    Text('Chat', style: AppTextStyles.display(fontSize: 22)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: (friends ? AppColors.success : AppColors.accent)
                            .withValues(alpha: 0.2),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            friends
                                ? Icons.people_rounded
                                : Icons.shield_rounded,
                            size: 14,
                            color: friends
                                ? AppColors.success
                                : AppColors.glowRing,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            friends ? 'Friends chat' : 'Friendly chat',
                            style: AppTextStyles.body(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ChatSticker(id: 'chip:happy', size: 64),
                            const SizedBox(height: 6),
                            Text(
                              'Say hi',
                              style: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        // Newest at the bottom, where the chat opens.
                        reverse: true,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final m = messages[messages.length - 1 - i];
                          final line = config.systemLine?.call(m);
                          if (line != null) {
                            return _SystemLine(
                              text: line.text,
                              sticker: line.sticker,
                            );
                          }
                          return _Bubble(
                            message: m,
                            mine: m.senderId == me,
                            accent: config.accentFor?.call(m.senderId),
                          );
                        },
                      ),
              ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _notice!,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.accentSecondary,
                    ),
                  ),
                ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: [
                    for (final sticker in kChatStickers)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkResponse(
                          onTap: () => _send(sticker, kind: 'emote'),
                          radius: 26,
                          child: ChatSticker(id: sticker, size: 46),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: [
                    for (final phrase in ChatFilter.quickPhrases)
                      _QuickChip(
                        label: phrase,
                        onTap: () => _send(phrase, kind: 'quick'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    // The recorder keeps its state (via the key) as it grows
                    // from a mic button into the full-width recording bar.
                    if (_recording)
                      Expanded(
                        child: VoiceRecorderButton(
                          key: _recorderKey,
                          onSend: _sendVoice,
                          onRecordingChanged: (r) =>
                              setState(() => _recording = r),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: TextField(
                          controller: _text,
                          maxLength: 200,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (v) => _send(v),
                          // A tap on the messages (or anywhere else) puts
                          // the keyboard away: iPhone keyboards have no
                          // close key.
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: friends
                                ? 'Message your friends'
                                : 'Say something nice',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      VoiceRecorderButton(
                        key: _recorderKey,
                        onSend: _sendVoice,
                        onRecordingChanged: (r) =>
                            setState(() => _recording = r),
                      ),
                      const SizedBox(width: 4),
                      // Sending keeps the keyboard up.
                      TextFieldTapRegion(
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => _send(_text.text),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.accent,
  });

  final ChatMessage message;
  final bool mine;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(profileByIdProvider(message.senderId))
        .valueOrNull;
    final name = mine ? 'You' : profileDisplayName(profile, message.senderId);
    final seat = accent ?? AppColors.glowRing;
    final emoteOnly = message.kind == 'emote';
    final voice = message.kind == 'voice'
        ? VoiceNote.parse(message.body)
        : null;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: emoteOnly
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: emoteOnly
          ? null
          : BoxDecoration(
              color: mine ? AppColors.accent : AppColors.surfaceElevated,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              border: Border.all(color: seat.withValues(alpha: 0.6)),
            ),
      child: voice != null
          ? VoiceNoteBubble(note: voice, mine: mine)
          : emoteOnly
          ? ChatSticker(id: message.body, size: 52)
          : Text(
              message.body,
              style: AppTextStyles.body(fontSize: 14, color: Colors.white),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            UserAvatar.fromProfile(profile, fallbackInitial: name, radius: 14),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(
                  name,
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: seat,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              bubble,
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.text, this.sticker});

  final String text;
  final String? sticker;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sticker != null) ...[
                ChatSticker(id: sticker!, size: 22),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(label: Text(label), onPressed: onTap),
    );
  }
}
