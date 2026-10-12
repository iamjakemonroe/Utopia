import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../chat/domain/chat_filter.dart';
import '../../domain/doodle_game.dart';

/// A player's name in the game: "You" for this player.
String doodleName(WidgetRef ref, String? id, String? me) {
  if (id == null) return 'Someone';
  if (id == me) return 'You';
  return profileDisplayName(ref.watch(profileByIdProvider(id)).valueOrNull, id);
}

/// The chat, floating under the drawing rather than boxed in a panel:
/// newest at the bottom, each line rising in, older ones fading out toward
/// the top. Guesses are chat; a right one shows as "got it", a near miss
/// as "so close" (to the guesser only), the word once the turn ends.
class DoodleChatFeed extends ConsumerWidget {
  const DoodleChatFeed({
    super.key,
    required this.messages,
    required this.me,
    required this.colorOf,
    required this.filter,
  });

  final List<DoodleMessage> messages;
  final String? me;
  final Color Function(String? userId) colorOf;

  /// Mask rude words (public games).
  final bool filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white],
        stops: [0, 0.32],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 4),
        itemCount: messages.length,
        itemBuilder: (context, i) {
          final m = messages[messages.length - 1 - i];
          return _Arrive(
            key: ValueKey(m.id),
            child: _Line(
              message: m,
              me: me,
              color: colorOf(m.senderId),
              filter: filter,
            ),
          );
        },
      ),
    );
  }
}

/// Rises and fades in once, when the line first appears.
class _Arrive extends StatefulWidget {
  const _Arrive({super.key, required this.child});

  final Widget child;

  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

class _Line extends ConsumerWidget {
  const _Line({
    required this.message,
    required this.me,
    required this.color,
    required this.filter,
  });

  final DoodleMessage message;
  final String? me;
  final Color color;
  final bool filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = doodleName(ref, message.senderId, me);
    final mine = message.senderId == me;
    switch (message.kind) {
      case DoodleMessageKind.chat:
        final text = filter ? ChatFilter.filter(message.body) : message.body;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
              decoration: BoxDecoration(
                color: message.guessedOnly
                    ? const Color(0xFF1F8F55).withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: mine ? 0.42 : 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: message.guessedOnly
                      ? const Color(0xFF6BF0B0).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    if (message.guessedOnly)
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF6BF0B0),
                          ),
                        ),
                      ),
                    TextSpan(
                      text: '$name  ',
                      style: AppTextStyles.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    TextSpan(
                      text: text,
                      style: AppTextStyles.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case DoodleMessageKind.guessed:
        return _Pill(
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF2FD98E),
          text: mine ? 'You got it!' : '$name got it!',
        );
      case DoodleMessageKind.close:
        final text = filter ? ChatFilter.filter(message.body) : message.body;
        return _Pill(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFFB020),
          text: '"$text" is so close!',
        );
      case DoodleMessageKind.reveal:
        return _Pill(
          icon: Icons.lightbulb_rounded,
          color: AppColors.coinGold,
          text: 'The word was ${message.body}',
        );
      case DoodleMessageKind.drawing:
        return _Note(
          icon: Icons.brush_rounded,
          text: mine ? 'Your turn to draw' : '$name is drawing',
          color: color,
        );
      case DoodleMessageKind.joined:
        return _Note(
          icon: Icons.login_rounded,
          text: '$name joined',
          color: AppColors.textSecondary,
        );
      case DoodleMessageKind.left:
        return _Note(
          icon: Icons.logout_rounded,
          text: '$name left',
          color: AppColors.textSecondary,
        );
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              text,
              style: AppTextStyles.body(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where guesses (and chat) are typed. Stays open after sending, so quick
/// guesses can follow each other.
class DoodleGuessField extends StatefulWidget {
  const DoodleGuessField({
    super.key,
    required this.hint,
    required this.onSend,
    this.focusNode,
    this.glow,
  });

  final String hint;

  /// Sends the line; returns false if it didn't go (the text stays).
  final Future<bool> Function(String text) onSend;
  final FocusNode? focusNode;

  /// Tints the field: green once you've guessed.
  final Color? glow;

  @override
  State<DoodleGuessField> createState() => _DoodleGuessFieldState();
}

class _DoodleGuessFieldState extends State<DoodleGuessField> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    _sending = true;
    HapticFeedback.lightImpact();
    _text.clear();
    final ok = await widget.onSend(text);
    _sending = false;
    if (!ok && mounted && _text.text.isEmpty) _text.text = text;
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glow;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: glow ?? Colors.white.withValues(alpha: 0.2),
          width: glow == null ? 1.5 : 2,
        ),
        boxShadow: glow == null
            ? null
            : [BoxShadow(color: glow.withValues(alpha: 0.35), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: widget.focusNode,
              maxLength: 100,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              style: AppTextStyles.body(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              cursorColor: AppColors.coinGold,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.body(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                counterText: '',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) {
                _send();
                widget.focusNode?.requestFocus();
              },
              // A tap anywhere else (the drawing, the chat, the players)
              // puts the keyboard away: iPhone keyboards have no close key.
              onTapOutside: (_) =>
                  (widget.focusNode ?? FocusManager.instance.primaryFocus)
                      ?.unfocus(),
            ),
          ),
          // Part of the field as far as taps go, so sending keeps the
          // keyboard up for the next guess.
          TextFieldTapRegion(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (context, value, _) {
                final ready = value.text.trim().isNotEmpty;
                return AnimatedScale(
                  scale: ready ? 1 : 0.85,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: GestureDetector(
                    onTap: ready ? _send : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ready
                            ? AppColors.accent
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
