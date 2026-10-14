import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/chip/chip_brain.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/pop_card.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../doodle_studio/data/picture_library.dart';
import '../../doodle_studio/presentation/coloring_thumb.dart';
import '../../doodle_studio/presentation/doodle_world_gate.dart';
import '../../chat/presentation/chat_sticker.dart';
import '../../store/domain/store_catalog.dart';
import '../../store/presentation/store_controller.dart';
import '../../friends/presentation/widgets/friends_popup.dart';
import '../../notifications/presentation/notification_actions.dart';
import '../../store/presentation/coin_shop.dart';
import 'chip_chat_controller.dart';

/// Opens a chat with Chip: he sits on top making faces at what's said, the
/// conversation floats underneath, and a few starter questions help when
/// it's empty.
Future<void> showChipChat(BuildContext context) {
  ProviderScope.containerOf(context).read(gameAudioProvider).play(Sfx.drawer);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChipChatSheet(),
  );
}

class _ChipChatSheet extends ConsumerStatefulWidget {
  const _ChipChatSheet();

  @override
  ConsumerState<_ChipChatSheet> createState() => _ChipChatSheetState();
}

class _ChipChatSheetState extends ConsumerState<_ChipChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _starters = [
    'Draw me something to color',
    'Tell me a joke',
    'Which world should I try?',
    'How do I play Ludo?',
    'Help me with my homework',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Off to "Report a bug" or "Suggest a feature", noting the screen Chip
  /// was opened over.
  void _report(bool idea) {
    final router = ref.read(goRouterProvider);
    final from = Uri.encodeQueryComponent(currentPath(router));
    Navigator.of(context).pop();
    router.push('/report-bug?${idea ? 'kind=idea&' : ''}from=$from');
  }

  void _send([String? text]) {
    final message = (text ?? _input.text).trim();
    if (message.isEmpty) return;
    HapticFeedback.selectionClick();
    _input.clear();
    ref.read(chipChatProvider.notifier).send(message);
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Starts a new chat, once they're sure.
  Future<void> _newChat() async {
    HapticFeedback.selectionClick();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new chat?'),
        content: const Text('Chip will forget this conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('New chat'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(chipChatProvider.notifier).clear();
  }

  /// Where Chip's buttons go: the label, and the screen (or null for the
  /// ones that open over the current screen).
  static const _places = <String, (String, String?)>{
    'store': ('Open the Store', '/store'),
    'auras': ('See auras', '/store?tab=auras'),
    'worlds': ('Change world', '/store?tab=worlds'),
    'coins': ('Get coins', null),
    'friends': ('Open Friends', null),
    'notifications': ('Notifications', '/notifications'),
    'settings': ('Settings', '/settings'),
    'profile': ('Your profile', '/profile'),
    'sketchbook': ('Open the Sketchbook', '/sketchbook'),
    'how_to_play_chess': ('How to play chess', '/how-to-play'),
    'how_to_play_checkers': (
      'How to play checkers',
      '/how-to-play?game=checkers',
    ),
    'how_to_play_ludo': ('How to play Ludo', '/how-to-play?game=ludo'),
    'chess': ('Play chess', '/chess'),
    'checkers': ('Play checkers', '/checkers'),
    'ludo': ('Play Ludo', '/ludo'),
    'guess_my_doodle': ('Play Guess My Doodle', '/guess-my-doodle'),
    'report_bug': ('Report a bug', null),
    'suggest_feature': ('Suggest a feature', null),
  };

  void _go(String place) {
    HapticFeedback.selectionClick();
    switch (place) {
      case 'report_bug' || 'suggest_feature':
        _report(place == 'suggest_feature');
        return;
      case 'coins' || 'friends':
        final host = appNavigatorContext(ref);
        Navigator.of(context).pop();
        if (host == null || !host.mounted) return;
        place == 'coins' ? showCoinShop(host) : showFriendsPopup(host);
        return;
    }
    final route = _places[place]?.$2;
    if (route == null) return;
    if (place == 'sketchbook') {
      final container = ProviderScope.containerOf(context);
      Navigator.of(context).pop();
      openInDoodleWorld(container, route);
      return;
    }
    final router = ref.read(goRouterProvider);
    Navigator.of(context).pop();
    router.push(route);
  }

  /// Off to color a picture Chip drew, in the Doodle world.
  Future<void> _color(LibraryPicture picture) async {
    HapticFeedback.selectionClick();
    await ref.read(pictureLibraryProvider).keep(picture);
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    Navigator.of(context).pop();
    openInDoodleWorld(
      container,
      '/sketchbook/new?kind=coloring&page=${Uri.encodeQueryComponent(picture.pageId)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chipChatProvider);
    final isGuest = ref.watch(isAnonymousProvider);
    ref.listen(chipChatProvider.select((s) => s.lines.length), (_, _) {
      _toBottom();
    });
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        height: height,
        child: PopCard(
          borderRadius: 30,
          sheet: true,
          padding: EdgeInsets.zero,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: [
                      CoinBuddy(mood: chat.mood, size: 78),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chip',
                              style: AppTextStyles.display(fontSize: 24),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                chat.thinking
                                    ? 'Thinking...'
                                    : 'Your buddy in Utopia. Ask me anything.',
                                key: ValueKey(chat.thinking),
                                style: AppTextStyles.body(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (chat.lines.isNotEmpty && !chat.thinking)
                        IconButton(
                          tooltip: 'New chat',
                          icon: const Icon(Icons.add_comment_rounded),
                          onPressed: _newChat,
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: chat.lines.isEmpty
                      ? _Starters(
                          starters: _starters,
                          onTap: _send,
                          onReport: _report,
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          itemCount:
                              chat.lines.length + (chat.thinking ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == chat.lines.length) {
                              return const _Bubble.typing();
                            }
                            final line = chat.lines[i];
                            final open = line.open;
                            final picture = line.picture;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Bubble(line: line),
                                if (line.sticker case final sticker?)
                                  _StickerPop(id: sticker),
                                if (picture != null)
                                  _PictureCard(
                                    picture: picture,
                                    onColor: _color,
                                  ),
                                if (open != null &&
                                    _places.containsKey(open) &&
                                    !(open == 'friends' && isGuest))
                                  _GoButton(
                                    label: _places[open]!.$1,
                                    onTap: () => _go(open),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 600,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          // A tap on the chat (or anywhere else) puts the
                          // keyboard away: iPhone keyboards have no close
                          // key.
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          style: AppTextStyles.body(),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Say something to Chip',
                            hintStyle: AppTextStyles.body(
                              color: AppColors.textSecondary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Sending keeps the keyboard up.
                      TextFieldTapRegion(
                        child: _SendButton(
                          busy: chat.thinking,
                          onTap: chat.thinking ? null : _send,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Starters extends StatelessWidget {
  const _Starters({
    required this.starters,
    required this.onTap,
    required this.onReport,
  });

  final List<String> starters;
  final ValueChanged<String> onTap;

  /// Opens "Report a bug" (false) or "Suggest a feature" (true).
  final ValueChanged<bool> onReport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          "Hi! I know every corner of Utopia, and plenty outside it. Ask me "
          'anything, have me draw you a picture to color, or just say hello.',
          style: AppTextStyles.body(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < starters.length; i++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + i * 90),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Transform.scale(
                  scale: v,
                  child: Opacity(opacity: v.clamp(0, 1), child: child),
                ),
                child: ActionChip(
                  label: Text(starters[i]),
                  labelStyle: AppTextStyles.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  onPressed: () => onTap(starters[i]),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Found a bug, or got an idea? Pass it on and the team will see it.',
          style: AppTextStyles.body(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.bug_report_rounded, size: 18),
              label: const Text('Report a bug'),
              labelStyle: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              onPressed: () => onReport(false),
            ),
            ActionChip(
              avatar: const Icon(Icons.lightbulb_rounded, size: 18),
              label: const Text('Suggest a feature'),
              labelStyle: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              onPressed: () => onReport(true),
            ),
          ],
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required ChipLine this.line});

  const _Bubble.typing() : line = null;

  final ChipLine? line;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final fromChip = l == null || l.fromChip;
    final fill = fromChip
        ? Color.alphaBlend(
            AppColors.accent.withValues(alpha: 0.12),
            AppColors.surfaceElevated,
          )
        : AppColors.accent;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: 0.85 + 0.15 * v,
        alignment: fromChip ? Alignment.bottomLeft : Alignment.bottomRight,
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: Align(
        alignment: fromChip ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.74,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(fromChip ? 4 : 18),
              bottomRight: Radius.circular(fromChip ? 18 : 4),
            ),
            border: Border.all(
              color: fromChip
                  ? AppColors.glowRing.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: l == null
              ? const _TypingDots()
              : Text(
                  l.text,
                  style: AppTextStyles.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fromChip ? AppColors.textPrimary : Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset(
                0,
                -4 * math.max(0, math.sin((_c.value - i * 0.18) * 2 * math.pi)),
              ),
              child: Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: busy
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.accent,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.45),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

/// A button under Chip's message that takes the player where he said.
class _GoButton extends StatelessWidget {
  const _GoButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(
          scale: 0.8 + 0.2 * v,
          alignment: Alignment.centerLeft,
          child: Opacity(opacity: v.clamp(0, 1), child: child),
        ),
        child: _ActionPill(
          label: label,
          icon: Icons.arrow_forward_rounded,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// A button Chip offers: a solid accent pill with white text, so it reads
/// in every world, light or dark.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              AppColors.accent,
              Color.lerp(AppColors.accent, Colors.black, 0.18)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sticker Chip sent, popping in under his message.
class _StickerPop extends StatelessWidget {
  const _StickerPop({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(
          scale: v,
          alignment: Alignment.bottomLeft,
          child: child,
        ),
        child: ChatSticker(id: id, size: 68),
      ),
    );
  }
}

/// A picture Chip is drawing: him at work while it's being drawn, then
/// the page, ready to color.
class _PictureCard extends ConsumerWidget {
  const _PictureCard({required this.picture, required this.onColor});

  final ChipPicture picture;
  final ValueChanged<LibraryPicture> onColor;

  /// What the button does from here: color it (in the Doodle world),
  /// travel there to color it (they have it), or get the Doodle world.
  (String, IconData) _action(WidgetRef ref) {
    ref.watch(themeControllerProvider);
    if (UtopiaThemes.active.world.biome == WorldBiome.doodle) {
      return ('Color it', Icons.palette_rounded);
    }
    var owned = false;
    try {
      final store = ref.watch(storeControllerProvider);
      final doodle = StoreCatalog.themes
          .where((i) => i.id == UtopiaThemes.utopiaDoodle.id)
          .firstOrNull;
      owned = doodle != null && store.isOwned(doodle);
    } catch (_) {
      // The store can't be read (offline at start, tests): the button still
      // works, and the trip there checks again.
    }
    if (owned) {
      return ('Travel to Doodle to color it', Icons.rocket_launch_rounded);
    }
    return ('Get the Doodle world to color it', Icons.storefront_rounded);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = _action(ref);
    final id = picture.id;
    LibraryPicture? drawn;
    var status = picture.status;
    if (id != null && (status == 'drawing' || status == 'ready')) {
      final watch = ref.watch(pictureWatchProvider(id));
      drawn = watch.valueOrNull;
      status = drawn?.status ?? (watch.isLoading ? status : 'failed');
      if (status == 'ready' && !(drawn?.ready ?? false)) status = 'drawing';
    }
    final subject = picture.subject;
    final (mood, note) = switch (status) {
      'drawing' => (BuddyMood.thinking, 'Drawing $subject...'),
      'ready' => (BuddyMood.excited, drawn!.title),
      'refused' => (
        BuddyMood.sad,
        "I can't draw that one. Try something else?",
      ),
      'limited' => (
        BuddyMood.sad,
        "I've drawn all I can today. Ask me again tomorrow!",
      ),
      'off' => (BuddyMood.thinking, "My pencil isn't ready yet."),
      _ => (BuddyMood.sad, "That drawing didn't work out. Ask me again?"),
    };
    final width = MediaQuery.sizeOf(context).width * 0.58;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glowRing.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: status == 'ready'
                  ? ClipRRect(
                      key: const ValueKey('page'),
                      borderRadius: BorderRadius.circular(12),
                      child: ColoringThumb(drawn!.page),
                    )
                  : Row(
                      key: ValueKey(status),
                      children: [
                        CoinBuddy(mood: mood, size: 54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            style: AppTextStyles.body(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (status == 'drawing') ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  color: AppColors.accent,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                ),
              ),
            ],
            if (status == 'ready') ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: AppTextStyles.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: _ActionPill(
                  label: action.$1,
                  icon: action.$2,
                  onTap: () => onColor(drawn!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
