import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../../core/widgets/utopia_world.dart';
import '../../auras/data/aura_repository.dart';
import '../../auras/domain/aura.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../events/data/events_repository.dart';
import '../../events/domain/game_event.dart';
import '../../store/domain/store_catalog.dart';
import '../../store/presentation/store_controller.dart';
import '../../store/presentation/store_screen.dart';
import '../../store/presentation/theme_teleport.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/layout/responsive.dart';

/// Everything the player has, apart from the store: their worlds (bought,
/// rented, free, and event or birthday worlds while they're open), their
/// frames, and their piece sets. Event items out of season wait in "Back
/// next season". Change world or frame from here.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Collection'),
          bottom: TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.goldBorder,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.body(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.public_rounded), text: 'Worlds'),
              Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'Frames'),
              Tab(icon: Icon(Icons.casino_rounded), text: 'Ludo'),
              Tab(icon: Icon(Icons.extension_rounded), text: 'Chess'),
            ],
          ),
        ),
        body: const AppBackground(
          child: TabBarView(
            children: [
              _WorldsTab(),
              _FramesTab(),
              LudoPiecesTab(ownedOnly: true),
              ChessPiecesTab(ownedOnly: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// A world the player has, and what kind of "has".
enum _Hold { here, special, owned, rented, free }

class _WorldsTab extends ConsumerWidget {
  const _WorldsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final here = ref.watch(themeControllerProvider).id;
    final seasonal = ref.watch(seasonItemsProvider).valueOrNull ?? const [];

    _Hold? hold(UtopiaTheme t) {
      if (t.id == here) return _Hold.here;
      if (!UtopiaThemes.sold(t.id)) {
        return store.rentedUntil(t.id) != null ? _Hold.special : null;
      }
      final item = StoreCatalog.themes.where((i) => i.id == t.id).firstOrNull;
      if (item == null) return null;
      if (item.free) return _Hold.free;
      if (store.isOwnedForever(item)) return _Hold.owned;
      if (store.rentedUntil(t.id) != null) return _Hold.rented;
      return null;
    }

    List<(UtopiaTheme, _Hold)> held(List<UtopiaTheme> themes) => [
      for (final t in themes)
        if (hold(t) case final h?) (t, h),
    ]..sort((a, b) => a.$2.index.compareTo(b.$2.index));
    // Worlds and colors apart: a color is a recolor, not a world of its own.
    final worlds = held([...UtopiaThemes.secret, ...UtopiaThemes.utopia]);
    final colors = held(UtopiaThemes.colors);
    final waiting = [
      for (final s in seasonal)
        if (s.isWorld && store.rentedUntil(s.itemId) == null) s,
    ];

    return _LiveWorldArea(
      child: CustomScrollView(
        slivers: [
          _Header(
            title: 'Your worlds',
            subtitle:
                'Tap one to travel there. Chip takes you through a portal!',
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverGrid.count(
              crossAxisCount: context.gridColumns(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.78,
              children: [
                for (final (theme, h) in worlds)
                  _WorldCard(theme: theme, hold: h),
              ],
            ),
          ),
          if (colors.isNotEmpty) ...[
            const _Header(
              title: 'Your colors',
              subtitle: 'Utopia recolored, at dawn, dusk or midnight.',
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverGrid.count(
                crossAxisCount: context.gridColumns(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.78,
                children: [
                  for (final (theme, h) in colors)
                    _WorldCard(theme: theme, hold: h),
                ],
              ),
            ),
          ],
          if (waiting.isNotEmpty) ...[
            const _Header(
              title: 'Back next season',
              subtitle:
                  "Yours for good. They open again when their event's on.",
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverGrid.count(
                crossAxisCount: context.gridColumns(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.78,
                children: [
                  for (final s in waiting)
                    _WorldCard(
                      theme: UtopiaThemes.byId(s.itemId),
                      hold: null,
                      season: s,
                    ),
                ],
              ),
            ),
          ],
          const _MoreInStore(
            text: 'Find more worlds in the store',
            location: '/store?tab=worlds',
          ),
        ],
      ),
    );
  }
}

/// In a browser, only the world card nearest the middle of the screen
/// moves; the rest hold still. Every live world is a whole scene to draw
/// each frame, and a browser can't keep up with a screenful of them. The
/// apps animate them all.
class _LiveWorldArea extends StatefulWidget {
  const _LiveWorldArea({required this.child});

  final Widget child;

  @override
  State<_LiveWorldArea> createState() => _LiveWorldAreaState();
}

class _LiveWorldAreaState extends State<_LiveWorldArea> {
  final _live = _LiveWorld();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _live.pick());
    }
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _LiveWorldScope(live: _live, child: widget.child);
    if (!kIsWeb) return scope;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
          _live.pick();
        }
        return false;
      },
      child: scope,
    );
  }
}

/// The world cards on screen, and which one is live.
class _LiveWorld extends ChangeNotifier {
  final _cards = <Object, BuildContext>{};
  Object? live;

  void add(Object id, BuildContext context) => _cards[id] = context;

  void remove(Object id) => _cards.remove(id);

  /// The card nearest the middle of the screen goes live.
  void pick() {
    Object? best;
    var nearest = double.infinity;
    for (final MapEntry(key: id, value: context) in _cards.entries) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final middle = MediaQuery.sizeOf(context).height / 2;
      final centre = box.localToGlobal(box.size.center(Offset.zero)).dy;
      final away = (centre - middle).abs();
      if (away < nearest) {
        nearest = away;
        best = id;
      }
    }
    if (best != live) {
      live = best;
      notifyListeners();
    }
  }
}

class _LiveWorldScope extends InheritedNotifier<_LiveWorld> {
  const _LiveWorldScope({required _LiveWorld live, required super.child})
    : super(notifier: live);

  static _LiveWorld? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LiveWorldScope>()?.notifier;
}

/// A world card's moving world: in a browser it moves only while it's the
/// live one (and holds its last frame otherwise).
class _LiveWorldCard extends StatefulWidget {
  const _LiveWorldCard({required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  State<_LiveWorldCard> createState() => _LiveWorldCardState();
}

class _LiveWorldCardState extends State<_LiveWorldCard> {
  _LiveWorld? _live;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final live = _LiveWorldScope.of(context);
    if (live != _live) {
      _live?.remove(widget.id);
      _live = live?..add(widget.id, context);
    }
  }

  @override
  void dispose() {
    _live?.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = _LiveWorldScope.of(context);
    if (!kIsWeb || live == null) return widget.child;
    return TickerMode(enabled: live.live == widget.id, child: widget.child);
  }
}

class _WorldCard extends ConsumerWidget {
  const _WorldCard({required this.theme, required this.hold, this.season});

  final UtopiaTheme theme;

  /// Null: an event world that's out of season ([season]).
  final _Hold? hold;
  final SeasonItem? season;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final asleep = hold == null;
    final until = store.rentedUntil(theme.id);
    final (label, icon) = switch (hold) {
      _Hold.here => ("You're here", Icons.check_rounded),
      _Hold.special when theme.id == UtopiaThemes.utopiaBirthday.id => (
        'Birthday · today',
        Icons.cake_rounded,
      ),
      _Hold.special => (
        '${UtopiaThemes.seasonal[theme.id] == 'halloween' ? 'Halloween' : 'Event'} · ${auraTimeLeft(until!).replaceAll(' left', '')}',
        Icons.celebration_rounded,
      ),
      _Hold.owned => ('Owned', Icons.verified_rounded),
      _Hold.rented => (
        'Rented · ${auraTimeLeft(until!).replaceAll(' left', '')}',
        Icons.timer_rounded,
      ),
      _Hold.free => ('Free', Icons.favorite_rounded),
      null => (
        'Back next ${season?.seasonName ?? 'season'}',
        Icons.bedtime_rounded,
      ),
    };

    void travel() {
      if (asleep) {
        showUtopiaToast(
          context,
          '${theme.name} opens again next ${season?.seasonName ?? 'season'}.',
          icon: Icons.bedtime_rounded,
        );
        return;
      }
      if (hold == _Hold.here) return;
      ref.read(themeTeleportProvider.notifier).travelTo(theme);
    }

    return GestureDetector(
      onTap: travel,
      child: Opacity(
        opacity: asleep ? 0.55 : 1,
        child: PopCard(
          borderRadius: 22,
          glow: hold == _Hold.here ? AppColors.success : null,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _LiveWorldCard(
                  id: theme.id,
                  child: UtopiaWorld(style: theme.world),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: asleep ? 0.75 : 0.55),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _Pill(
                        label: label,
                        icon: icon,
                        highlight: hold == _Hold.here,
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

class _FramesTab extends ConsumerWidget {
  const _FramesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    final mine = ref.watch(myAurasProvider).valueOrNull ?? const {};
    final seasonal = ref.watch(seasonItemsProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final wearing = activeAura(profile);

    final frames =
        [
          for (final a in Aura.all)
            if (mine[a.id]?.isAfter(now) ?? false) (a, mine[a.id]!),
        ]..sort(
          (x, y) => (x.$1.id == wearing ? 0 : 1).compareTo(
            y.$1.id == wearing ? 0 : 1,
          ),
        );
    final waiting = [
      for (final s in seasonal)
        if (!s.isWorld && !(mine[s.itemId]?.isAfter(now) ?? false)) s,
    ];

    return CustomScrollView(
      slivers: [
        _Header(
          title: 'Your frames',
          subtitle: frames.isEmpty
              ? "You don't have a frame right now."
              : 'Wear one around your picture, for everyone to see.',
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverGrid.count(
            crossAxisCount: context.gridColumns(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.82,
            children: [
              for (final (aura, until) in frames)
                _FrameCard(
                  aura: aura,
                  profile: profile,
                  name: me == null ? '?' : profileDisplayName(profile, me),
                  wearing: aura.id == wearing,
                  until: until,
                ),
            ],
          ),
        ),
        if (waiting.isNotEmpty) ...[
          const _Header(
            title: 'Back next season',
            subtitle: "Yours for good. Wear them again when their event's on.",
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverGrid.count(
              crossAxisCount: context.gridColumns(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.82,
              children: [
                for (final s in waiting)
                  if (Aura.byId(s.itemId) case final aura?)
                    _FrameCard(
                      aura: aura,
                      profile: profile,
                      name: me == null ? '?' : profileDisplayName(profile, me),
                      wearing: false,
                      season: s,
                    ),
              ],
            ),
          ),
        ],
        const _MoreInStore(
          text: 'Find more frames in the store',
          location: '/store?tab=auras',
        ),
      ],
    );
  }
}

class _FrameCard extends ConsumerStatefulWidget {
  const _FrameCard({
    required this.aura,
    required this.profile,
    required this.name,
    required this.wearing,
    this.until,
    this.season,
  });

  final Aura aura;
  final Map<String, dynamic>? profile;
  final String name;
  final bool wearing;

  /// When the player's time in it runs out (null: out of season).
  final DateTime? until;
  final SeasonItem? season;

  @override
  ConsumerState<_FrameCard> createState() => _FrameCardState();
}

class _FrameCardState extends ConsumerState<_FrameCard> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (widget.season != null) {
      showUtopiaToast(
        context,
        'You can wear ${widget.aura.name} again next ${widget.season!.seasonName}.',
        icon: Icons.bedtime_rounded,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(auraRepositoryProvider)
          .equip(widget.wearing ? null : widget.aura.id);
      final me = ref.read(currentUserProvider)?.id;
      if (me != null) ref.invalidate(profileByIdProvider(me));
      ref.read(gameAudioProvider).play(Sfx.reaction);
    } catch (_) {
      if (mounted) {
        showUtopiaToast(
          context,
          "Couldn't change your frame. Try again?",
          kind: ToastKind.error,
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final aura = widget.aura;
    final asleep = widget.season != null;
    final kind = aura.birthday
        ? 'Birthday · today'
        : aura.season != null
        ? (asleep
              ? 'Back next ${widget.season!.seasonName}'
              : '${widget.season?.seasonName ?? 'Event'} · ${auraTimeLeft(widget.until!).replaceAll(' left', '')}')
        : widget.until != null
        ? auraTimeLeft(widget.until!)
        : '';
    return Opacity(
      opacity: asleep ? 0.55 : 1,
      child: PopCard(
        borderRadius: 22,
        tint: aura.color,
        glow: widget.wearing ? aura.color : null,
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: UserAvatar.fromProfile(
                  widget.profile,
                  fallbackInitial: widget.name,
                  radius: 34,
                  aura: aura.id,
                ),
              ),
            ),
            Text(
              aura.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontWeight: FontWeight.w800),
            ),
            Text(
              kind,
              style: AppTextStyles.body(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.wearing
                      ? AppColors.surfaceElevated
                      : AppColors.success,
                  minimumSize: const Size(0, 32),
                ),
                onPressed: _busy ? null : _toggle,
                child: Text(
                  asleep
                      ? 'Out of season'
                      : widget.wearing
                      ? 'Take off'
                      : 'Wear',
                  style: AppTextStyles.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      sliver: SliverList.list(
        children: [
          Text(title, style: AppTextStyles.display(fontSize: 20)),
          Text(
            subtitle,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreInStore extends StatelessWidget {
  const _MoreInStore({required this.text, required this.location});

  final String text;
  final String location;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.md),
      sliver: SliverToBoxAdapter(
        child: Center(
          child: TextButton.icon(
            onPressed: () => context.push(location),
            icon: const Icon(Icons.storefront_rounded),
            label: Text(text),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.success
            : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
