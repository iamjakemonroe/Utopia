import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../data/art_store.dart';
import '../data/picture_library.dart';
import '../domain/art_doc.dart';
import '../domain/coloring_pages.dart';
import 'art_render.dart';
import 'studio_toolbar.dart';

/// The Doodle world's sketchbook: start a new sketch or pick a picture to
/// color, and everything made so far, newest first (tap to carry on, hold
/// to delete). It's all kept in Utopia, so it's here whichever world
/// you're in.
class SketchbookScreen extends ConsumerStatefulWidget {
  const SketchbookScreen({super.key, this.pick = false});

  /// Opens straight onto picking a picture to color.
  final bool pick;

  @override
  ConsumerState<SketchbookScreen> createState() => _SketchbookScreenState();
}

class _SketchbookScreenState extends ConsumerState<SketchbookScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.pick) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickPage(context, ref);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final art = ref.watch(myArtProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = (width / 190).floor().clamp(2, 6);
    return Scaffold(
      backgroundColor: kStudioDesk,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  children: [
                    StudioButton(
                      tooltip: 'Back',
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sketchbook',
                        style: AppTextStyles.display(
                          fontSize: 26,
                          color: kStudioInk,
                        ),
                      ),
                    ),
                    const CoinBuddy(mood: BuddyMood.happy, size: 54),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Draw anything, or color a picture. Everything saves as you go.',
                  style: AppTextStyles.body(
                    color: kStudioInk.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _Pop(
                        index: 0,
                        child: _StartCard(
                          icon: Icons.draw_rounded,
                          title: 'New sketch',
                          subtitle: 'A blank page',
                          onTap: () {
                            ref.read(gameAudioProvider).play(Sfx.drawer);
                            context.push('/sketchbook/new');
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Pop(
                        index: 1,
                        child: _StartCard(
                          icon: Icons.palette_rounded,
                          title: 'Color a picture',
                          subtitle: 'Or search any picture',
                          onTap: () => _pickPage(context, ref),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'My art',
                  style: AppTextStyles.display(fontSize: 20, color: kStudioInk),
                ),
              ),
            ),
            ...switch (art) {
              AsyncData(:final value) when value.isEmpty => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'Nothing here yet. What you draw and color shows up here.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        color: kStudioInk.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
              AsyncData(:final value) => [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: kPageSize.width / kPageSize.height,
                    ),
                    itemCount: value.length,
                    itemBuilder: (context, i) => _Pop(
                      index: i + 2,
                      child: _ArtTile(summary: value[i]),
                    ),
                  ),
                ),
              ],
              _ => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: CircularProgressIndicator(color: kStudioInk),
                    ),
                  ),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }

  Future<void> _pickPage(BuildContext context, WidgetRef ref) async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final page = await showModalBottomSheet<ColoringPage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PagePicker(),
    );
    if (page == null || !context.mounted) return;
    context.push(
      '/sketchbook/new?kind=coloring&page=${Uri.encodeQueryComponent(page.id)}',
    );
  }
}

/// Pops in, one after another.
class _Pop extends StatelessWidget {
  const _Pop({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index.clamp(0, 10) * 70)),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: 0.85 + 0.15 * v,
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}

/// A sheet of paper with an ink outline that sinks when pressed.
class _Paper extends StatefulWidget {
  const _Paper({required this.child, required this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_Paper> createState() => _PaperState();
}

class _PaperState extends State<_Paper> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: Duration(milliseconds: _down ? 90 : 380),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: Container(
          decoration: BoxDecoration(
            color: kStudioPaper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kStudioInk, width: 2),
            boxShadow: [
              BoxShadow(
                color: kStudioInk.withValues(alpha: _down ? 0.08 : 0.16),
                offset: Offset(0, _down ? 2 : 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Paper(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: kStudioInk,
              ),
              child: Icon(icon, color: kStudioPaper, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.display(fontSize: 17, color: kStudioInk),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.body(
                fontSize: 13,
                color: kStudioInk.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One saved piece: its little picture; tap to carry on, hold to delete.
class _ArtTile extends ConsumerWidget {
  const _ArtTile({required this.summary});

  final ArtSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(artStoreProvider).valueOrNull;
    return _Paper(
      onTap: () => context.push('/sketchbook/${summary.id}'),
      onLongPress: () => _delete(context, ref),
      child: store == null
          ? const SizedBox.expand()
          : _Thumb(
              // A new key whenever it changes, so the picture is fresh.
              key: ValueKey('${summary.id}@${summary.updated}'),
              load: () => store.thumbnail(summary.id).readAsBytes(),
            ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kStudioPaper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: kStudioInk, width: 2),
        ),
        title: Text(
          'Delete this?',
          style: AppTextStyles.display(fontSize: 20, color: kStudioInk),
        ),
        content: Text(
          "It'll be gone from your sketchbook for good.",
          style: AppTextStyles.body(color: kStudioInk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it', style: TextStyle(color: kStudioInk)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFE0361A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final store = await ref.read(artStoreProvider.future);
    await store.delete(summary.id);
    ref.invalidate(myArtProvider);
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({super.key, required this.load});

  final Future<Uint8List> Function() load;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<Uint8List> _bytes = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        final bytes = snap.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: bytes == null
              ? const ColoredBox(color: kPaper, child: SizedBox.expand())
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                ),
        );
      },
    );
  }
}

/// Pick a picture to color: Utopia's own, the ones you asked Chip for, and
/// the library every player shares. Search for anything: if nobody has
/// asked for it yet, Chip draws it.
class _PagePicker extends ConsumerStatefulWidget {
  const _PagePicker();

  @override
  ConsumerState<_PagePicker> createState() => _PagePickerState();
}

class _PagePickerState extends ConsumerState<_PagePicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _asking = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  Future<void> _open(ColoringPage page, {LibraryPicture? from}) async {
    // Kept on the phone first, so the art opens again even offline.
    if (from != null) await ref.read(pictureLibraryProvider).keep(from);
    if (mounted) Navigator.of(context).pop(page);
  }

  Future<void> _ask() async {
    final subject = _query;
    if (subject.isEmpty || _asking) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _asking = true);
    final library = ref.read(pictureLibraryProvider);
    final ask = await library.ask(subject);
    if (!mounted) return;
    setState(() => _asking = false);
    void say(String text, {ToastKind kind = ToastKind.info}) =>
        showUtopiaToast(context, text, kind: kind, icon: Icons.brush_rounded);
    switch (ask.status) {
      case 'ready':
        final p = await library.fetch(ask.id!);
        if (p != null && p.ready) return _open(p.page, from: p);
        say("Couldn't open that one. Try again?", kind: ToastKind.error);
      case 'drawing':
        ref.invalidate(myPicturesProvider);
        _search.clear();
        setState(() => _query = '');
        say("Chip's drawing it. It'll be in Yours in about a minute.");
      case 'refused':
        say("Chip can't draw that one. Try something else?");
      case 'limited':
        say('Chip has drawn all he can today. Ask again tomorrow!');
      case 'off':
        say("Chip's pencil isn't ready yet. Try again later.");
      default:
        say(
          "Couldn't reach Chip. Check your connection and try again.",
          kind: ToastKind.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final columns = (size.width / 170).floor().clamp(2, 5);
    final query = _query.toLowerCase();
    final builtIn = [
      for (final p in kColoringPages)
        if (query.isEmpty || p.name.toLowerCase().contains(query)) p,
    ];
    final mine = query.isEmpty
        ? ref.watch(myPicturesProvider).valueOrNull ?? const <LibraryPicture>[]
        : const <LibraryPicture>[];
    final library = ref.watch(pictureSearchProvider(_query));
    final found = library.valueOrNull ?? const <LibraryPicture>[];
    final mineIds = {for (final p in mine) p.id};
    final shared = [
      for (final p in found)
        if (!mineIds.contains(p.id)) p,
    ];
    final nothing =
        query.isNotEmpty &&
        !library.isLoading &&
        builtIn.isEmpty &&
        found.isEmpty;

    var n = 0;
    SliverGrid grid(List<Widget> tiles) => SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: kPageSize.width / (kPageSize.height + 120),
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) => tiles[i],
    );
    Widget heading(String text) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
        child: Text(
          text,
          style: AppTextStyles.display(fontSize: 17, color: kStudioInk),
        ),
      ),
    );
    final askCard = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _AskChip(
          subject: _query,
          busy: _asking,
          prominent: nothing,
          onTap: _ask,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        height: math.max(260.0, size.height * 0.86 - insets),
        decoration: const BoxDecoration(
          color: kStudioDesk,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: kStudioInk, width: 2)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: kStudioInk.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Text(
                'Pick a picture to color',
                style: AppTextStyles.display(fontSize: 20, color: kStudioInk),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SearchBox(
                controller: _search,
                onChanged: _typed,
                onSubmitted: (text) {
                  _debounce?.cancel();
                  setState(() => _query = text.trim());
                },
              ),
            ),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        if (nothing) askCard,
                        if (mine.isNotEmpty) ...[
                          heading('Yours'),
                          grid([
                            for (final p in mine)
                              _Pop(
                                index: n++,
                                child: _LibraryTile(
                                  picture: p,
                                  onOpen: (ready) =>
                                      _open(ready.page, from: ready),
                                ),
                              ),
                          ]),
                        ],
                        if (builtIn.isNotEmpty) ...[
                          heading("Utopia's pictures"),
                          grid([
                            for (final page in builtIn)
                              _Pop(
                                index: n++,
                                child: _PickTile(
                                  page: page,
                                  onTap: () => _open(page),
                                ),
                              ),
                          ]),
                        ],
                        if (shared.isNotEmpty) ...[
                          heading(
                            query.isEmpty
                                ? 'Drawn for players'
                                : 'From the library',
                          ),
                          grid([
                            for (final p in shared)
                              _Pop(
                                index: n++,
                                child: _PickTile(
                                  page: p.page,
                                  onTap: () => _open(p.page, from: p),
                                ),
                              ),
                          ]),
                        ],
                        if (library.isLoading && query.isNotEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: kStudioInk,
                                ),
                              ),
                            ),
                          ),
                        if (query.isNotEmpty && !nothing && !library.isLoading)
                          askCard,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The search box, on paper.
class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kStudioPaper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kStudioInk, width: 2),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        maxLength: 60,
        style: AppTextStyles.body(
          color: kStudioInk,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: kStudioInk,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded, color: kStudioInk),
          hintText: 'Search any picture: a lion, a castle...',
          hintStyle: AppTextStyles.body(
            color: kStudioInk.withValues(alpha: 0.45),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// A page to pick, drawn small, with its name.
class _PickTile extends StatelessWidget {
  const _PickTile({required this.page, required this.onTap});

  final ColoringPage page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _Paper(
            onTap: onTap,
            child: CustomPaint(
              painter: _PagePreview(page),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          page.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: kStudioInk,
          ),
        ),
      ],
    );
  }
}

/// A picture the player asked for: Chip at work while it's being drawn,
/// then the page itself.
class _LibraryTile extends ConsumerWidget {
  const _LibraryTile({required this.picture, required this.onOpen});

  final LibraryPicture picture;
  final ValueChanged<LibraryPicture> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var p = picture;
    if (p.status == 'drawing') {
      p = ref.watch(pictureWatchProvider(p.id)).valueOrNull ?? p;
    }
    if (p.ready) {
      return _PickTile(page: p.page, onTap: () => onOpen(p));
    }
    final failed = p.status != 'drawing';
    return Column(
      children: [
        Expanded(
          child: _Paper(
            onTap: () {},
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CoinBuddy(
                  mood: failed ? BuddyMood.sad : BuddyMood.thinking,
                  size: 64,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    failed ? "Didn't work out" : 'Chip is drawing...',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kStudioInk.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          p.title.isEmpty ? 'New picture' : p.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: kStudioInk,
          ),
        ),
      ],
    );
  }
}

/// "Ask Chip to draw it": big when the search found nothing.
class _AskChip extends StatelessWidget {
  const _AskChip({
    required this.subject,
    required this.busy,
    required this.prominent,
    required this.onTap,
  });

  final String subject;
  final bool busy;
  final bool prominent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Paper(
      onTap: busy ? () {} : onTap,
      child: Padding(
        padding: EdgeInsets.all(prominent ? 18 : 12),
        child: Row(
          children: [
            CoinBuddy(
              mood: busy ? BuddyMood.thinking : BuddyMood.excited,
              size: prominent ? 70 : 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (prominent)
                    Text(
                      'Nobody has asked for that yet.',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: kStudioInk.withValues(alpha: 0.65),
                      ),
                    ),
                  Text(
                    busy
                        ? 'Asking Chip...'
                        : prominent
                        ? 'Ask Chip to draw "$subject"'
                        : 'Not quite? Ask Chip to draw "$subject"',
                    style: AppTextStyles.display(
                      fontSize: prominent ? 17 : 15,
                      color: kStudioInk,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.brush_rounded, color: kStudioInk),
          ],
        ),
      ),
    );
  }
}

class _PagePreview extends CustomPainter {
  _PagePreview(this.page);

  final ColoringPage page;
  static final _paths = <String, List<Path>>{};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kPaper);
    final s = size.width / kPageSize.width;
    canvas.scale(s);
    ColoringPage.paintLines(canvas, _paths[page.id] ??= page.draw(), kLineInk);
  }

  @override
  bool shouldRepaint(_PagePreview old) => old.page != page;
}
