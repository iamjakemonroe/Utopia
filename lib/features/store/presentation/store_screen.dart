import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/bouncy_dialog.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_world.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auras/presentation/auras_tab.dart';
import '../../chess/domain/chess_types.dart';
import '../../chess/presentation/widgets/animated_chess_board.dart';
import '../../chess/presentation/widgets/chess_piece_art.dart';
import '../../chess/presentation/widgets/chess_piece_styles.dart';
import '../../ludo/domain/ludo_engine.dart';
import '../../ludo/presentation/widgets/ludo_pieces.dart';
import '../domain/store_catalog.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auras/domain/aura.dart';
import '../../coins/presentation/providers/coin_balance_provider.dart';
import 'coin_shop.dart';
import 'store_controller.dart';
import 'theme_teleport.dart';
import '../../../core/widgets/ambient_tick.dart';
import '../../events/presentation/event_widgets.dart';
import '../../../core/layout/responsive.dart';

/// The store: worlds (themes), Ludo piece sets and chess piece sets.
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen(storeControllerProvider, (prev, next) {
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.message!)));
        ref.read(storeControllerProvider.notifier).clearMessage();
      }
      final unlocked = next.justUnlocked;
      if (unlocked != null && unlocked != prev?.justUnlocked) {
        ref.read(storeControllerProvider.notifier).clearCelebration();
        _celebrate(unlocked, focus: next.unlockedFocus);
      }
    });
    final isGuest = ref.watch(isAnonymousProvider);

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Store'),
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
              Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'Auras'),
              Tab(icon: Icon(Icons.casino_rounded), text: 'Ludo'),
              Tab(icon: Icon(Icons.extension_rounded), text: 'Chess'),
            ],
          ),
        ),
        body: AppBackground(
          child: Column(
            children: [
              if (isGuest)
                _Banner(
                  icon: Icons.shield_rounded,
                  text: 'Save your account so your purchases are never lost.',
                ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _WorldsTab(),
                    AurasTab(),
                    LudoPiecesTab(),
                    ChessPiecesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The unlock celebration. A single world (or the world they were
  /// looking at in a pack) gets a "Travel there" button; a pack bought from
  /// the list lets them pick which of its worlds to visit first.
  Future<void> _celebrate(StoreProduct product, {String? focus}) async {
    final worlds = [
      for (final id in product.itemIds)
        ...UtopiaThemes.all.where((t) => t.id == id),
    ];
    final target =
        worlds.where((t) => t.id == focus).firstOrNull ??
        (worlds.length == 1 ? worlds.first : null);
    final pickOne = target == null && worlds.length > 1 && worlds.length <= 3;
    final here = ref.read(themeControllerProvider).id;

    final choice = await showBouncyDialog<String>(
      context: context,
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Material(
            type: MaterialType.transparency,
            child: PopCard(
              borderRadius: 30,
              glow: AppColors.goldBorderBright,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinBuddy(mood: BuddyMood.happy, size: 110),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Unlocked!', style: AppTextStyles.display(fontSize: 28)),
                  Text(
                    product.title,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (pickOne) ...[
                    Text(
                      'Where to first?',
                      style: AppTextStyles.body(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        for (final (i, world) in worlds.indexed) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(world.id),
                              child: AspectRatio(
                                aspectRatio: 0.8,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _Swatch(style: world.world),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Text(
                                            world.name.split(' ').last,
                                            style: AppTextStyles.body(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ] else
                    PrimaryButton(
                      label: target != null
                          ? (target.id == here
                                ? "You're already here"
                                : 'Travel to ${target.name}')
                          : worlds.isNotEmpty
                          ? 'Pick a world'
                          : 'Equip now',
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(target?.id ?? (worlds.isNotEmpty ? null : 'equip')),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Later'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'equip') {
      final item = [
        ...StoreCatalog.ludoPieceSets,
        ...StoreCatalog.chessPieceSets,
      ].where((i) => i.id == product.itemIds.first).firstOrNull;
      if (item != null) {
        await ref.read(storeControllerProvider.notifier).equipPieces(item);
      }
      return;
    }
    final world = UtopiaThemes.all.where((t) => t.id == choice).firstOrNull;
    if (world != null && world.id != ref.read(themeControllerProvider).id) {
      ref.read(themeTeleportProvider.notifier).travelTo(world);
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body(fontSize: 12))),
        ],
      ),
    );
  }
}

/// The status/price pill on every store card.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.highlight = false, this.icon});

  final String label;
  final bool highlight;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: highlight
            ? AppColors.success.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.45),
        border: Border.all(
          color: highlight ? Colors.white : AppColors.goldBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Worlds ──────────────────────────────────────────────────────────────────

class _WorldsTab extends ConsumerWidget {
  const _WorldsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final bundle = StoreCatalog.products.firstWhere(
      (p) => p.id == 'utopia.themes.all',
    );
    final ownsAll = StoreCatalog.themes
        .where((i) => UtopiaThemes.sold(i.id))
        .every(store.isOwned);

    // A lazy grid: only the live worlds on screen (and a little either
    // side) exist and animate, rather than all of them at once.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          sliver: SliverList.list(
            children: [
              Text('Utopia worlds', style: AppTextStyles.display(fontSize: 20)),
              Text(
                'Every world has its own living sky. Changing worlds sends Chip through a portal!',
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const EventStoreBanner(),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverGrid.count(
            crossAxisCount: context.gridColumns(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.78,
            children: [
              for (final t in UtopiaThemes.utopia)
                if (UtopiaThemes.sold(t.id)) _WorldCard(theme: t, live: true),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          sliver: SliverList.list(
            children: [
              if (!ownsAll) ...[
                const SizedBox(height: AppSpacing.md),
                PopCard(
                  borderRadius: 24,
                  tint: AppColors.accentSecondary,
                  glow: AppColors.goldBorderBright,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      GlossyBadge(
                        icon: Icons.public_rounded,
                        color: AppColors.mint,
                        size: 46,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Every World',
                              style: AppTextStyles.display(fontSize: 18),
                            ),
                            Text(
                              'All ${UtopiaThemes.utopia.where((t) => UtopiaThemes.sold(t.id)).length} worlds and ${UtopiaThemes.colors.length} colors, now and forever.',
                              style: AppTextStyles.body(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _BuyButton(product: bundle),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Color worlds', style: AppTextStyles.display(fontSize: 20)),
              Text(
                '12 colors, each at dawn, dusk and midnight.',
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final family in _families())
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _FamilyRow(family: family.$1, themes: family.$2),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static List<(String, List<UtopiaTheme>)> _families() {
    final out = <String, List<UtopiaTheme>>{};
    for (final t in UtopiaThemes.colors) {
      out.putIfAbsent(t.family, () => []).add(t);
    }
    return [for (final e in out.entries) (e.key, e.value)];
  }
}

class _FamilyRow extends ConsumerWidget {
  const _FamilyRow({required this.family, required this.themes});

  final String family;
  final List<UtopiaTheme> themes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final pack = StoreCatalog.productFor(themes.last.id);
    final ownsPack = themes.every(
      (t) => store.isOwned(StoreCatalog.themes.firstWhere((i) => i.id == t.id)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              family,
              style: AppTextStyles.body(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (ownsPack)
              const _StatusPill(label: 'Owned', icon: Icons.check_rounded)
            else if (pack != null)
              _BuyButton(product: pack, compact: true),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (i, t) in themes.indexed) ...[
              Expanded(
                child: AspectRatio(
                  aspectRatio: 0.8,
                  child: _WorldCard(theme: t, live: false),
                ),
              ),
              if (i < themes.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ],
    );
  }
}

class _WorldCard extends ConsumerWidget {
  const _WorldCard({required this.theme, required this.live});

  final UtopiaTheme theme;

  /// A live animated world, or a still swatch (cheaper for long lists).
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final current = ref.watch(themeControllerProvider).id == theme.id;
    final item = StoreCatalog.themes.firstWhere((i) => i.id == theme.id);
    final owned = store.isOwned(item);
    final product = StoreCatalog.productFor(theme.id);

    // Same 3D card as the piece sets: the world is clipped inside the gold
    // rim, so the picture can never paint over the border.
    return GestureDetector(
      onTap: () => showWorldPreview(context, theme),
      child: PopCard(
        borderRadius: 22,
        depth: live ? 5 : 3,
        borderWidth: live ? 2.5 : 2,
        glow: current ? AppColors.success : null,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(live ? 18 : 18.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (live)
                UtopiaWorld(style: theme.world)
              else
                _Swatch(style: theme.world),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
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
                      live ? theme.name : theme.name.split(' ').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: live ? 15 : 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (current)
                      const _StatusPill(
                        label: 'Current',
                        highlight: true,
                        icon: Icons.check_rounded,
                      )
                    else if (item.free)
                      const _StatusPill(label: 'Free')
                    else if (store.isOwnedForever(item))
                      const _StatusPill(label: 'Owned')
                    else if (owned)
                      _StatusPill(
                        label: live
                            ? 'Rented · ${auraTimeLeft(store.rentedUntil(item.id)!).replaceAll(' left', '')}'
                            : 'Rented',
                        icon: Icons.timer_rounded,
                      )
                    else if (live && product != null)
                      _StatusPill(
                        label: store.priceOf(product),
                        icon: Icons.lock_rounded,
                      )
                    else
                      const _StatusPill(
                        label: 'Locked',
                        icon: Icons.lock_rounded,
                      ),
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

/// A still picture of a world: its sky, a sun or planet, and its ground.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.style});

  final WorldStyle style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SwatchPainter(style));
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.style);

  final WorldStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.sky,
        ).createShader(rect),
    );
    final c = Offset(size.width * 0.7, size.height * 0.32);
    final r = size.width * 0.16;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: style.celestialColors,
          stops: const [0.0, 0.4, 0.8, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.62 + i * 0.12);
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 4) {
        path.lineTo(
          x,
          y -
              math.sin(x / size.width * math.pi * (1.5 + i) + i) *
                  size.height *
                  0.04,
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [style.layers[i].$1, style.layers[i].$2],
          ).createShader(Rect.fromLTRB(0, y - 10, size.width, size.height)),
      );
    }
    final star = Paint()..color = Colors.white.withValues(alpha: 0.8);
    for (var i = 0; i < (12 * style.starDensity).round(); i++) {
      canvas.drawCircle(
        Offset(
          (i * 37 % 100) / 100 * size.width,
          (i * 53 % 45) / 100 * size.height,
        ),
        0.9,
        star,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) => old.style != style;
}

/// A full-screen look at a world before buying or travelling there.
Future<void> showWorldPreview(BuildContext context, UtopiaTheme theme) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => _WorldPreview(theme: theme),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 1.08, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _WorldPreview extends ConsumerWidget {
  const _WorldPreview({required this.theme});

  final UtopiaTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final item = StoreCatalog.themes.firstWhere((i) => i.id == theme.id);
    final owned = store.isOwned(item);
    final current = ref.watch(themeControllerProvider).id == theme.id;
    final product = StoreCatalog.productFor(theme.id);

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          UtopiaWorld(style: theme.world),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Spacer(),
                  // A sample panel in this world's own colors.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      color: theme.surface.withValues(alpha: 0.94),
                      border: Border.all(color: theme.trim, width: 2.4),
                      boxShadow: [
                        BoxShadow(
                          color: theme.glowRing.withValues(alpha: 0.4),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // The panel is in this world's colors, not the
                        // current one's, so its text is too.
                        Text(
                          theme.name,
                          style: AppTextStyles.display(
                            fontSize: 26,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          theme.tagline,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(color: theme.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final c in [
                              theme.accent,
                              theme.trim,
                              theme.glowRing,
                              theme.world.glow,
                            ])
                              Container(
                                width: 26,
                                height: 26,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    width: 2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (current)
                          PrimaryButton(
                            label: "You're here",
                            color: theme.accent,
                            onPressed: null,
                          )
                        else if (owned)
                          PrimaryButton(
                            label: 'Travel to this world',
                            color: theme.accent,
                            onPressed: () {
                              Navigator.of(context).pop();
                              ref
                                  .read(themeTeleportProvider.notifier)
                                  .travelTo(theme);
                            },
                          )
                        else if (product != null)
                          PrimaryButton(
                            label:
                                '${product.itemIds.length > 1 ? 'Unlock ${theme.family} pack' : 'Unlock'} · ${store.priceOf(product)}',
                            color: theme.accent,
                            isLoading: store.busyProduct == product.id,
                            onPressed: () => ref
                                .read(storeControllerProvider.notifier)
                                .buy(product, focus: theme.id),
                          ),
                        if (!store.isOwnedForever(item) &&
                            StoreCatalog.worldRentPrice(theme.id, 3) !=
                                null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _RentWorld(theme: theme),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rent a world with coins: pick how long, then go. While a rental is
/// running it shows the time left and adds more.
class _RentWorld extends ConsumerStatefulWidget {
  const _RentWorld({required this.theme});

  final UtopiaTheme theme;

  @override
  ConsumerState<_RentWorld> createState() => _RentWorldState();
}

class _RentWorldState extends ConsumerState<_RentWorld> {
  /// Worlds are rented by the week (or bought for good).
  static const _days = 7;
  bool _busy = false;

  Future<void> _rent() async {
    final theme = widget.theme;
    final price = StoreCatalog.worldRentPrice(theme.id, _days) ?? 0;
    final balance = ref.read(coinBalanceProvider).valueOrNull ?? 0;
    if (price > balance) {
      showCoinShop(context, needed: price);
      return;
    }
    setState(() => _busy = true);
    final error = await ref
        .read(storeControllerProvider.notifier)
        .rentWorld(theme.id, _days);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      showUtopiaToast(context, error, kind: ToastKind.error);
      return;
    }
    final here = ref.read(themeControllerProvider).id == theme.id;
    if (here) {
      showUtopiaToast(
        context,
        'A week more in ${theme.name}',
        kind: ToastKind.success,
        icon: Icons.timer_rounded,
      );
      return;
    }
    Navigator.of(context).pop();
    ref.read(themeTeleportProvider.notifier).travelTo(theme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final store = ref.watch(storeControllerProvider);
    final until = store.rentedUntil(theme.id);
    final price = StoreCatalog.worldRentPrice(theme.id, _days) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(color: theme.textSecondary.withValues(alpha: 0.3)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                until == null
                    ? 'or rent it for a week'
                    : 'Rented · ${auraTimeLeft(until)}',
                style: AppTextStyles.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: until == null
                      ? theme.textSecondary
                      : AppColors.success,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: theme.textSecondary.withValues(alpha: 0.3)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: until == null
              ? 'Rent for a week · ${formatCoins(price)}'
              : 'Add a week · ${formatCoins(price)}',
          color: AppColors.success,
          isLoading: _busy,
          onPressed: _busy ? null : _rent,
        ),
      ],
    );
  }
}

class _BuyButton extends ConsumerWidget {
  const _BuyButton({required this.product, this.compact = false});

  final StoreProduct product;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final busy = store.busyProduct == product.id;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 6 : 12,
        ),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.goldBorder, width: 1.4),
        ),
      ),
      onPressed: busy
          ? null
          : () => ref.read(storeControllerProvider.notifier).buy(product),
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              compact
                  ? 'Pack · ${store.priceOf(product)}'
                  : store.priceOf(product),
              style: AppTextStyles.body(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
    );
  }
}

// ── Piece sets ──────────────────────────────────────────────────────────────

/// Every Ludo piece set (the store), or only the player's own
/// ([ownedOnly], their collection).
class LudoPiecesTab extends ConsumerWidget {
  const LudoPiecesTab({super.key, this.ownedOnly = false});

  final bool ownedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final me = ref.watch(currentUserProvider)?.id;
    final equipped = me == null
        ? 'classic'
        : (ref
                      .watch(profileByIdProvider(me))
                      .valueOrNull?['equipped_ludo_pieces']
                  as String? ??
              'classic');
    return GridView.count(
      padding: const EdgeInsets.all(AppSpacing.md),
      crossAxisCount: context.gridColumns(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.62,
      children: [
        for (final item in StoreCatalog.ludoPieceSets)
          if (!ownedOnly || store.isOwned(item))
            _PieceSetCard(
              item: item,
              equipped: equipped == item.id,
              preview: _LudoSetPreview(setId: item.id),
            ),
      ],
    );
  }
}

/// Every Chess piece set (the store), or only the player's own
/// ([ownedOnly], their collection).
class ChessPiecesTab extends ConsumerWidget {
  const ChessPiecesTab({super.key, this.ownedOnly = false});

  final bool ownedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final me = ref.watch(currentUserProvider)?.id;
    final equipped = me == null
        ? 'classic'
        : (ref
                      .watch(profileByIdProvider(me))
                      .valueOrNull?['equipped_chess_pieces']
                  as String? ??
              'classic');
    return GridView.count(
      padding: const EdgeInsets.all(AppSpacing.md),
      crossAxisCount: context.gridColumns(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.62,
      children: [
        for (final item in StoreCatalog.chessPieceSets)
          if (!ownedOnly || store.isOwned(item))
            _PieceSetCard(
              item: item,
              equipped: equipped == item.id,
              preview: _ChessSetPreview(setId: item.id),
            ),
      ],
    );
  }
}

class _PieceSetCard extends ConsumerStatefulWidget {
  const _PieceSetCard({
    required this.item,
    required this.equipped,
    required this.preview,
  });

  final StoreItem item;
  final bool equipped;
  final Widget preview;

  @override
  ConsumerState<_PieceSetCard> createState() => _PieceSetCardState();
}

class _PieceSetCardState extends ConsumerState<_PieceSetCard> {
  bool _equipping = false;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeControllerProvider);
    final owned = store.isOwned(widget.item);
    final product = StoreCatalog.productFor(widget.item.id);

    Widget action;
    if (widget.equipped) {
      action = const _StatusPill(
        label: 'Equipped',
        highlight: true,
        icon: Icons.check_rounded,
      );
    } else if (owned) {
      action = FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.success,
          minimumSize: const Size(0, 34),
        ),
        onPressed: _equipping
            ? null
            : () async {
                setState(() => _equipping = true);
                final error = await ref
                    .read(storeControllerProvider.notifier)
                    .equipPieces(widget.item);
                if (!mounted) return;
                setState(() => _equipping = false);
                if (error != null) {
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                }
              },
        child: Text(
          _equipping ? 'Equipping' : 'Equip',
          style: AppTextStyles.body(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      );
    } else if (product != null) {
      action = _BuyButton(product: product);
    } else {
      action = const SizedBox.shrink();
    }

    return PopCard(
      borderRadius: 24,
      glow: widget.equipped ? AppColors.success : null,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // A full-bleed cover: the pieces on a little floating stage in
          // the current world's sky.
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(21),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _CoverPainter(
                      checkered: widget.item.kind == ItemKind.chessPieces,
                    ),
                  ),
                  widget.preview,
                  if (widget.item.free)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: _StatusPill(label: 'Free'),
                    )
                  else if (widget.item.kind == ItemKind.chessPieces &&
                      ChessPieceStyle.byId(widget.item.id).character !=
                          ChessCharacter.none)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: _StatusPill(
                        label: 'Animated',
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              children: [
                Text(
                  widget.item.name,
                  style: AppTextStyles.body(fontWeight: FontWeight.w800),
                ),
                Text(
                  widget.item.tagline,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The backdrop of a piece-set card: the current world's sky with a few
/// stars, and a small floating island stage the pieces stand on.
class _CoverPainter extends CustomPainter {
  _CoverPainter({required this.checkered});

  final bool checkered;

  @override
  void paint(Canvas canvas, Size size) {
    final style = UtopiaThemes.active.world;
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.sky[1], style.sky[3], style.sky[4]],
        ).createShader(rect),
    );
    final glow = Offset(w * 0.5, h * 0.55);
    canvas.drawCircle(
      glow,
      w * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            style.glow.withValues(alpha: 0.35),
            style.glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glow, radius: w * 0.55)),
    );
    final star = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset((i * 47 % 100) / 100 * w, (i * 29 % 45) / 100 * h),
        0.6 + (i % 3) * 0.35,
        star,
      );
    }

    // The floating stage.
    final top = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.8),
      width: w * 0.86,
      height: h * 0.16,
    );
    final rock = Path()
      ..moveTo(top.left, top.center.dy)
      ..quadraticBezierTo(w * 0.3, h * 1.02, w * 0.52, h * 1.08)
      ..quadraticBezierTo(w * 0.72, h * 1.0, top.right, top.center.dy)
      ..close();
    canvas.drawPath(
      rock,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.rock,
        ).createShader(rock.getBounds()),
    );
    canvas.drawOval(
      top.shift(Offset(0, h * 0.015)),
      Paint()..color = style.land[2],
    );
    canvas.drawOval(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.land,
        ).createShader(top),
    );
    if (checkered) {
      canvas.save();
      canvas.clipPath(Path()..addOval(top.deflate(4)));
      final cell = top.width / 10;
      final light = Paint()..color = const Color(0xFFEFDFAE);
      final dark = Paint()..color = const Color(0xFF3A2C70);
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 10; c++) {
          canvas.drawRect(
            Rect.fromLTWH(
              top.left + c * cell,
              top.top + r * cell * 0.5,
              cell,
              cell * 0.5,
            ),
            (r + c).isEven ? light : dark,
          );
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CoverPainter old) => old.checkered != checkered;
}

/// Four tokens of a Ludo piece set, idling in place.
class _LudoSetPreview extends StatefulWidget {
  const _LudoSetPreview({required this.setId});

  final String setId;

  @override
  State<_LudoSetPreview> createState() => _LudoSetPreviewState();
}

class _LudoSetPreviewState extends State<_LudoSetPreview>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _t = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    ambientTick((e) => _t.value = e.inMicroseconds / 1e6),
  );

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Two in back, two in front, standing on the stage.
    const placements = [
      (LudoColor.green, 0.36, 0.7, 0.27),
      (LudoColor.yellow, 0.64, 0.7, 0.27),
      (LudoColor.red, 0.24, 0.86, 0.33),
      (LudoColor.blue, 0.76, 0.86, 0.33),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return ValueListenableBuilder<double>(
          valueListenable: _t,
          builder: (context, t, _) => Stack(
            children: [
              for (final (i, (color, x, ground, scale)) in placements.indexed)
                Positioned(
                  left: w * x - w * scale / 2,
                  top:
                      h * ground -
                      w * scale * LudoTokenPainter.aspect * 0.92 -
                      8 * math.max(0.0, math.sin(t * 3 - i * 0.7)),
                  width: w * scale,
                  height: w * scale * LudoTokenPainter.aspect,
                  child: CustomPaint(
                    painter: LudoTokenPainter(
                      setId: widget.setId,
                      color: color,
                      t: t + i,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChessSetPreview extends StatefulWidget {
  const _ChessSetPreview({required this.setId});

  final String setId;

  @override
  State<_ChessSetPreview> createState() => _ChessSetPreviewState();
}

/// Two pieces on the card's stage. Character sets come alive: they blink,
/// glance at each other and run through their reactions.
class _ChessSetPreviewState extends State<_ChessSetPreview>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    ambientTick((e) => _t.value = e.inMicroseconds / 1e6),
  );

  ChessPieceStyle get _style => ChessPieceStyle.byId(widget.setId);

  @override
  void initState() {
    super.initState();
    if (_style.character != ChessCharacter.none) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  static const _kingMoods = [
    PieceMood.idle,
    PieceMood.panic,
    PieceMood.idle,
    PieceMood.cheer,
  ];
  static const _queenMoods = [
    PieceMood.idle,
    PieceMood.proud,
    PieceMood.scared,
    PieceMood.happy,
  ];

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final faced = style.character != ChessCharacter.none;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * 0.46;
        return ValueListenableBuilder<double>(
          valueListenable: _t,
          builder: (context, t, _) {
            final beat = (t / 1.8).floor();
            return Stack(
              children: [
                for (final (i, (type, color, x, moods)) in [
                  (PieceType.queen, PieceColor.black, 0.66, _queenMoods),
                  (PieceType.king, PieceColor.white, 0.34, _kingMoods),
                ].indexed)
                  () {
                    final mood = faced
                        ? moods[(beat + i) % moods.length]
                        : PieceMood.idle;
                    final hop =
                        mood == PieceMood.cheer ||
                            mood == PieceMood.proud ||
                            mood == PieceMood.happy
                        ? math.max(0.0, math.sin(t * 7 + i)) * size * 0.1
                        : 0.0;
                    final shake = mood == PieceMood.panic
                        ? math.sin(t * 38) * size * 0.03
                        : 0.0;
                    return Positioned(
                      left: constraints.maxWidth * x - size / 2 + shake,
                      top: constraints.maxHeight * 0.8 - size * 0.94 - hop,
                      width: size,
                      height: size,
                      child: ChessPieceGlyph(
                        type: type,
                        color: color,
                        size: size,
                        finish: style.of(color),
                        character: style.character,
                        mood: mood,
                        t: t + i * 1.3,
                        // They keep an eye on each other.
                        look: i == 0 ? -0.8 : 0.8,
                        seed: i * 2.1,
                      ),
                    );
                  }(),
              ],
            );
          },
        );
      },
    );
  }
}
