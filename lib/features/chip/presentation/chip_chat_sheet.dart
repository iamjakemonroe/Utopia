import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
import '../../../core/widgets/utopia_toast.dart';
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
import '../../maestro/presentation/maestro_providers.dart';
import '../../maestro/presentation/maestro_sheet.dart';
import 'chip_chat_controller.dart';
import '../../../l10n/strings.dart';
import '../../maestro/presentation/maestro_widgets.dart';

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

/// How wide the chat is: the screen's width, up to the widest a sheet
/// grows (on a tablet or a computer). Its bubbles and pictures are sized
/// from this, not the screen, or they'd outgrow it.
double _chatWidth(BuildContext context) => math.min(
  MediaQuery.sizeOf(context).width,
  Theme.of(context).bottomSheetTheme.constraints?.maxWidth ?? double.infinity,
);

class _ChipChatSheet extends ConsumerStatefulWidget {
  const _ChipChatSheet();

  @override
  ConsumerState<_ChipChatSheet> createState() => _ChipChatSheetState();
}

class _ChipChatSheetState extends ConsumerState<_ChipChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// A photo picked to send with the next message.
  Uint8List? _attached;

  static final _starters = [
    'Draw me something to color',
    strings.chipChatTurnMyPhotoIntoA,
    strings.chipChatTellMeAJoke,
    strings.chipChatWhichWorldShouldITry,
    strings.chipChatHowDoIPlayLudo,
    strings.chipChatHelpMeWithMyHomework,
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
    final photo = text == null ? _attached : null;
    if (message.isEmpty && photo == null) return;
    HapticFeedback.selectionClick();
    _input.clear();
    if (photo != null) setState(() => _attached = null);
    ref.read(chipChatProvider.notifier).send(message, photo: photo);
    _toBottom();
  }

  /// Picks a photo from the phone to send Chip (to draw, or to talk about).
  Future<void> _pickPhoto() async {
    HapticFeedback.selectionClick();
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _attached = bytes);
    } catch (_) {
      if (mounted) {
        showUtopiaToast(context, strings.chipChatCouldnTOpenThatPhoto);
      }
    }
  }

  /// Off to the coloring screen, where Chip colors picture [pictureId] in
  /// [style] (in the Doodle world).
  Future<void> _paint(String pictureId, String style) async {
    HapticFeedback.selectionClick();
    final library = ref.read(pictureLibraryProvider);
    LibraryPicture? picture;
    try {
      picture = await library.fetch(pictureId);
    } catch (_) {}
    if (!mounted) return;
    if (picture == null || !picture.ready) {
      showUtopiaToast(context, strings.chipChatThatPictureIsnTReady);
      return;
    }
    await library.keep(picture);
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    Navigator.of(context).pop();
    openInDoodleWorld(
      container,
      '/sketchbook/new?kind=coloring'
      '&page=${Uri.encodeQueryComponent(picture.pageId)}'
      '&paint=${Uri.encodeQueryComponent(style)}',
    );
  }

  /// Takes Chip's real-portrait offer in line [index]: a member's goes
  /// straight ahead, a first-timer confirms their free one, and anyone
  /// else sees Chip Maestro.
  Future<void> _takePortrait(int index, ChipPortraitOffer offer) async {
    HapticFeedback.selectionClick();
    if (offer.state == 'locked') {
      await showMaestroSheet(context);
      return;
    }
    if (offer.state == 'free') {
      final who = offer.fromPhoto ? strings.chipChatYourPhoto : offer.subject;
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.chipChatYourFreeRealPortrait),
          content: Text(strings.chipChatChipHasAPhotoQuality(who)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.chipChatNotNow),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.chipChatDrawItFree),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    final ask = await ref.read(chipChatProvider.notifier).takePortrait(index);
    if (!mounted) return;
    ref.invalidate(maestroProvider);
    switch (ask.status) {
      case 'drawing' || 'ready':
        _toBottom();
      case 'maestro':
        await showMaestroSheet(context);
      case 'limited':
        showUtopiaToast(
          context,
          ask.month
              ? strings.chipChatThatSThisMonthS
              : strings.chipChatThatSAllTheReal,
        );
      case 'off':
        showUtopiaToast(context, strings.chipChatRealPortraitsAreComingSoon);
      case 'photo':
        showUtopiaToast(context, strings.chipChatSendChipThePhotoAgain);
      case 'busy':
        break;
      default:
        showUtopiaToast(context, strings.chipChatCouldnTStartThePortrait);
    }
  }

  /// The latest picture Chip drew in the chat, up to line [upTo].
  String? _latestPicture(List<ChipLine> lines, int upTo) {
    for (var i = upTo; i >= 0; i--) {
      final id = lines[i].picture?.id;
      if (id != null) return id;
    }
    return null;
  }

  /// Back down to the newest line. The list runs bottom-up, so the newest
  /// is at offset 0: it opens there, and pictures loading above never push
  /// it out of view.
  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || _scroll.offset <= 0) return;
      _scroll.animateTo(
        0,
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
        title: Text(strings.chipChatStartANewChat),
        content: Text(strings.chipChatChipWillForgetThisConversation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.chipChatKeepIt),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.chipChatNewChat),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(chipChatProvider.notifier).clear();
  }

  /// Where Chip's buttons go: the label, and the screen (or null for the
  /// ones that open over the current screen).
  static final _places = <String, (String, String?)>{
    'store': (strings.chipChatOpenTheStore, '/store'),
    'auras': (strings.chipChatSeeAuras, '/store?tab=auras'),
    'worlds': (strings.chipChatChangeWorld, '/collection'),
    'coins': (strings.chipChatGetCoins, null),
    'friends': (strings.chipChatOpenFriends, null),
    'notifications': (strings.chipChatNotifications, '/notifications'),
    'settings': (strings.chipChatSettings, '/settings'),
    'profile': (strings.chipChatYourProfile, '/profile'),
    'sketchbook': (strings.chipChatOpenTheSketchbook, '/sketchbook'),
    'how_to_play_chess': (strings.chipChatHowToPlayChess, '/how-to-play'),
    'how_to_play_checkers': (
      strings.chipChatHowToPlayCheckers,
      '/how-to-play?game=checkers',
    ),
    'how_to_play_ludo': (
      strings.chipChatHowToPlayLudo,
      '/how-to-play?game=ludo',
    ),
    'chess': (strings.chipChatPlayChess, '/chess'),
    'checkers': (strings.chipChatPlayCheckers, '/checkers'),
    'ludo': (strings.chipChatPlayLudo, '/ludo'),
    'guess_my_doodle': (strings.chipChatPlayGuessMyDoodle, '/guess-my-doodle'),
    'save_account': (strings.chipChatSaveYourAccount, '/auth/link'),
    'report_bug': (strings.chipChatReportABug, null),
    'suggest_feature': (strings.chipChatSuggestAFeature, null),
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
    // Most of a phone's height; on a tablet or a computer, no taller than
    // a big phone's (it ran nearly from the top of the screen).
    final height = math.min(MediaQuery.sizeOf(context).height * 0.78, 720.0);

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
                            Row(
                              children: [
                                Text(
                                  strings.chipChatChip,
                                  style: AppTextStyles.display(fontSize: 24),
                                ),
                                const SizedBox(width: 10),
                                // The way to Chip Maestro, right by his name
                                // (it gives way on a narrow screen).
                                const Flexible(child: MaestroPill()),
                              ],
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                chat.thinking
                                    ? strings.chipChatThinking
                                    : strings.chipChatYourBuddyInUtopiaAsk,
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
                          tooltip: strings.chipChatNewChat,
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
                          // Newest at the bottom, where the chat opens.
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          itemCount:
                              chat.lines.length + (chat.thinking ? 1 : 0),
                          itemBuilder: (context, at) {
                            if (chat.thinking && at == 0) {
                              return const _Bubble.typing();
                            }
                            final i =
                                chat.lines.length -
                                1 -
                                (at - (chat.thinking ? 1 : 0));
                            final line = chat.lines[i];
                            final open = line.open;
                            final picture = line.picture;
                            final paintStyle = line.paint;
                            final paintId = paintStyle == null
                                ? null
                                : _latestPicture(chat.lines, i);
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
                                if (line.portrait case final offer?)
                                  _GoButton(
                                    label: switch (offer.state) {
                                      'free' =>
                                        strings.chipChatDrawItForRealFree,
                                      'maestro' =>
                                        strings.chipChatDrawItForRealLeft(
                                          offer.left,
                                        ),
                                      _ => strings.chipChatDrawItForRealWith,
                                    },
                                    icon: Icons.auto_awesome_rounded,
                                    onTap: () => _takePortrait(i, offer),
                                  ),
                                if (paintStyle != null && paintId != null)
                                  _GoButton(
                                    label: strings.chipChatColorItWithChip,
                                    icon: Icons.palette_rounded,
                                    onTap: () => _paint(paintId, paintStyle),
                                  ),
                                if (line.limit == 'coins' &&
                                    i == chat.lines.length - 1)
                                  _GoButton(
                                    label: strings.chipChatKeepChattingCoins(
                                      line.price ?? 20,
                                    ),
                                    icon: Icons.monetization_on_rounded,
                                    onTap: () => ref
                                        .read(chipChatProvider.notifier)
                                        .keepChattingForCoins(),
                                  ),
                                // Out of today's chats: Chip Maestro has
                                // ten times as many.
                                if (line.limit == 'coins' &&
                                    i == chat.lines.length - 1 &&
                                    !(ref
                                            .watch(maestroProvider)
                                            .valueOrNull
                                            ?.active ??
                                        false))
                                  _GoButton(
                                    label: strings.chipChatGetMaestro,
                                    icon: Icons.auto_awesome_rounded,
                                    onTap: () => showMaestroSheet(context),
                                  ),
                                if (open != null &&
                                    _places.containsKey(open) &&
                                    !(open == 'friends' && isGuest) &&
                                    !(open == 'save_account' && !isGuest))
                                  _GoButton(
                                    label: _places[open]!.$1,
                                    onTap: () => _go(open),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
                if (_attached case final photo?)
                  _AttachedPhoto(
                    bytes: photo,
                    onRemove: () => setState(() => _attached = null),
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
                      TextFieldTapRegion(
                        child: _PhotoButton(
                          onTap: chat.thinking ? null : _pickPhoto,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                            hintText: _attached != null
                                ? strings.chipChatTellChipAboutThePhoto
                                : strings.chipChatSaySomethingToChip,
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
          strings.chipChatHiIKnowEveryCorner,
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
          strings.chipChatFoundABugOrGot,
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
              label: Text(strings.chipChatReportABug),
              labelStyle: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              onPressed: () => onReport(false),
            ),
            ActionChip(
              avatar: const Icon(Icons.lightbulb_rounded, size: 18),
              label: Text(strings.chipChatSuggestAFeature),
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
          constraints: BoxConstraints(maxWidth: _chatWidth(context) * 0.74),
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (l.photo != null) _SentPhoto(path: l.photo!),
                    if (l.photo != null && l.text.isNotEmpty)
                      const SizedBox(height: 8),
                    if (l.text.isNotEmpty)
                      Text(
                        l.text,
                        style: AppTextStyles.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: fromChip
                              ? AppColors.textPrimary
                              : Colors.white,
                        ),
                      ),
                  ],
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
      label: strings.chipChatSend,
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

/// The photo button beside the message box.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: strings.chipChatSendChipAPhoto,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceElevated,
            border: Border.all(
              color: AppColors.glowRing.withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            Icons.add_photo_alternate_rounded,
            color: onTap == null ? AppColors.textSecondary : AppColors.accent,
          ),
        ),
      ),
    );
  }
}

/// The photo waiting to go with the next message, with a way to drop it.
class _AttachedPhoto extends StatelessWidget {
  const _AttachedPhoto({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 6, AppSpacing.md, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.chipChatPhotoForChip,
              style: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            tooltip: strings.chipChatRemoveThePhoto,
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A photo the player sent, as it shows in their message.
class _SentPhoto extends StatelessWidget {
  const _SentPhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final missing = Container(
      width: 150,
      height: 110,
      color: Colors.white.withValues(alpha: 0.15),
      child: const Icon(Icons.image_rounded, color: Colors.white, size: 36),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: path.isEmpty
          ? missing
          : path.startsWith('web:')
          ? switch (ChipChatController.webPhoto(path)) {
              final bytes? => Image.memory(
                bytes,
                width: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => missing,
              ),
              null => missing,
            }
          : Image.file(
              File(path),
              width: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => missing,
            ),
    );
  }
}

/// A button under Chip's message that takes the player where he said.
class _GoButton extends StatelessWidget {
  const _GoButton({
    required this.label,
    required this.onTap,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;

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
        child: _ActionPill(label: label, icon: icon, onTap: onTap),
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
      return (strings.chipChatColorIt, Icons.palette_rounded);
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
      return (
        strings.chipChatTravelToDoodleToColor,
        Icons.rocket_launch_rounded,
      );
    }
    return (strings.chipChatGetTheDoodleWorldTo, Icons.storefront_rounded);
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
      'drawing' => (BuddyMood.thinking, strings.chipChatDrawing(subject)),
      'ready' => (BuddyMood.excited, drawn!.title),
      'refused' => (BuddyMood.sad, strings.chipChatICanTDrawThat),
      'limited' => (BuddyMood.sad, strings.chipChatIVeDrawnAllI),
      'off' => (BuddyMood.thinking, strings.chipChatMyPencilIsnTReady),
      _ => (BuddyMood.sad, strings.chipChatThatDrawingDidnTWork),
    };
    final width = _chatWidth(context) * 0.58;
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
