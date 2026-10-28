import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/audio/sound_controls.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../../l10n/strings.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/pool_repository.dart';
import '../domain/pool_cues.dart';
import '../domain/pool_physics.dart';
import '../domain/pool_rules.dart';
import 'pool_art.dart';
import 'pool_cue_art.dart';
import 'pool_match_controller.dart';
import 'pool_names.dart';
import 'pool_providers.dart';
import 'pool_table_view.dart';

/// A game of 8-ball: at a coin table against Chip ([gameId], as the
/// server holds it), or two people on this phone ([friends]).
class PoolMatchScreen extends ConsumerStatefulWidget {
  const PoolMatchScreen.table({super.key, required String this.gameId})
    : friends = false;

  const PoolMatchScreen.friends({super.key}) : gameId = null, friends = true;

  final String? gameId;
  final bool friends;

  @override
  ConsumerState<PoolMatchScreen> createState() => _PoolMatchScreenState();
}

class _PoolMatchScreenState extends ConsumerState<PoolMatchScreen> {
  PoolMatchController? _c;
  PoolBallArt? _art;
  CueArt _cueArt = CueArt.plain;
  String? _problem;
  String? _banner;
  Timer? _bannerTimer;
  List<PoolNews> _seen = const [];
  bool _showResult = false;
  bool _again = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final audio = ref.read(gameAudioProvider);
    try {
      final art = await PoolBallArt.load();
      final cueArt = await CueArt.load();
      final PoolMatchController c;
      if (widget.friends) {
        final (cue, level) = await _myCue();
        c = PoolMatchController.passAndPlay(
          cue: cue,
          cueLevel: level,
          audio: audio,
        );
      } else {
        final repository = ref.read(poolRepositoryProvider);
        final table = await repository.game(widget.gameId!);
        c = PoolMatchController.table(
          table: table,
          repository: repository,
          audio: audio,
        );
      }
      if (!mounted) {
        c.dispose();
        return;
      }
      c.addListener(_changed);
      _changed();
      setState(() {
        _art = art;
        _cueArt = cueArt;
        _c = c;
        _showResult = c.over;
      });
      c.start();
    } catch (e) {
      if (mounted) setState(() => _problem = friendlyError(e));
    }
  }

  /// The cue the player plays with on this phone, at its level.
  Future<(PoolCue, int)> _myCue() async {
    // Their levels, if they're not in yet.
    await ref
        .read(poolCueLevelsProvider.future)
        .catchError((Object _) => const <String, int>{});
    final mine = ref.read(myPoolCueProvider);
    return (mine.cue, mine.level);
  }

  void _changed() {
    final c = _c;
    if (c == null || !mounted) return;
    if (!identical(c.news, _seen)) {
      _seen = c.news;
      final text = _newsLine(c);
      if (text != null) {
        _bannerTimer?.cancel();
        setState(() => _banner = text);
        _bannerTimer = Timer(const Duration(milliseconds: 2600), () {
          if (mounted) setState(() => _banner = null);
        });
      }
    }
    if (c.over && !_showResult) {
      // A beat to see the last ball drop.
      Timer(const Duration(milliseconds: 700), () {
        if (mounted && (_c?.over ?? false)) setState(() => _showResult = true);
      });
    }
    if (c.over && c.won) ref.invalidate(poolCueLevelsProvider);
  }

  String? _newsLine(PoolMatchController c) {
    final lines = <String>[];
    for (final n in c.news) {
      switch (n) {
        case PoolNews.foulScratch:
          lines.add(strings.poolFoulScratch);
        case PoolNews.foulNoContact:
          lines.add(strings.poolFoulNoContact);
        case PoolNews.foulWrongBall:
          lines.add(strings.poolFoulWrongBall);
        case PoolNews.foulNoCushion:
          lines.add(strings.poolFoulNoCushion);
        case PoolNews.groupsSet:
          final g = c.game.groups[0];
          if (g != null) {
            lines.add(
              c.atTable
                  ? (g == PoolGroup.solids
                        ? strings.poolYouAreSolids
                        : strings.poolYouAreStripes)
                  : (g == PoolGroup.solids
                        ? strings.poolPlayerOneSolids
                        : strings.poolPlayerOneStripes),
            );
          }
        case PoolNews.callPocket:
          lines.add(strings.poolCallAPocket);
        case PoolNews.ballInHand:
          lines.add(strings.poolBallInHand);
        case PoolNews.breakHint:
          lines.add(strings.poolBreakHint);
        case PoolNews.yourTurn:
        case PoolNews.theirTurn:
          break;
      }
    }
    return lines.isEmpty ? null : lines.join('  ·  ');
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _c?.removeListener(_changed);
    _c?.dispose();
    super.dispose();
  }

  Future<void> _resign() async {
    final c = _c;
    if (c == null || c.over) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.poolResignTitle),
        content: Text(
          c.atTable
              ? strings.poolResignTableBody
              : strings.poolResignFriendsBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.poolKeepPlaying),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.poolResign),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await c.resign();
    } catch (e) {
      if (mounted) {
        showUtopiaToast(context, friendlyError(e), kind: ToastKind.error);
      }
    }
  }

  Future<void> _playAgain() async {
    final c = _c;
    if (c == null || _again) return;
    setState(() => _again = true);
    final problem = await c.playAgain();
    if (!mounted) return;
    setState(() {
      _again = false;
      if (problem == null) _showResult = false;
    });
    if (problem != null) {
      showUtopiaToast(context, friendlyError(problem), kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final art = _art;
    final title = c == null
        ? strings.poolEightBall
        : c.atTable
        ? poolTableName(c.tableId ?? '')
        : strings.poolOnThisPhone;

    final body = c == null || art == null
        ? Center(
            child: _problem == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      _problem!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(),
                    ),
                  ),
          )
        : ListenableBuilder(
            listenable: c,
            builder: (context, _) => _Table(
              c: c,
              art: art,
              cueArt: _cueArt,
              banner: _banner,
              onRetry: c.retry,
            ),
          );

    return MusicTrackScope(
      track: MusicTrack.game,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: strings.poolClose,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(title),
              actions: [
                const SoundQuickToggle(),
                IconButton(
                  tooltip: strings.poolResign,
                  icon: const Icon(Icons.flag_rounded),
                  onPressed: c == null || c.over ? null : _resign,
                ),
              ],
            ),
            body: AppBackground(child: SafeArea(child: body)),
          ),
          if (c != null && _showResult && c.over) ...[
            Positioned.fill(
              child: _Result(
                c: c,
                busy: _again,
                onAgain: _playAgain,
                onTables: () =>
                    context.canPop() ? context.pop() : context.go('/pool'),
                onLook: () => setState(() => _showResult = false),
              ),
            ),
            if (c.atTable ? c.won : true)
              const Positioned.fill(
                child: IgnorePointer(child: ConfettiBurst(pieces: 90)),
              ),
          ],
        ],
      ),
    );
  }
}

/// The game: the players up top, the table between the power bar and the
/// fine aim, the spin and the word on the shot below.
class _Table extends StatelessWidget {
  const _Table({
    required this.c,
    required this.art,
    required this.cueArt,
    required this.banner,
    required this.onRetry,
  });

  final PoolMatchController c;
  final PoolBallArt art;
  final CueArt cueArt;
  final String? banner;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          _Players(c: c),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PowerBar(c: c, cueArt: cueArt),
                const SizedBox(width: 6),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: PoolTableView(controller: c, art: art),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 4,
                        child: IgnorePointer(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: banner == null
                                ? const SizedBox.shrink()
                                : _Banner(key: ValueKey(banner), text: banner!),
                          ),
                        ),
                      ),
                      if (c.trouble != null)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: _Trouble(text: c.trouble!, onRetry: onRetry),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _FineAim(c: c),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _SpinButton(c: c),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _Status(c: c)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final foul = text.startsWith(strings.poolFoulPrefix);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: (foul ? const Color(0xFF3A0E16) : AppColors.surfaceElevated)
              .withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (foul ? const Color(0xFFFF6B6B) : AppColors.glowRing)
                .withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }
}

class _Trouble extends StatelessWidget {
  const _Trouble({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 18,
      glow: AppColors.error,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              friendlyError(text, fallback: strings.poolCouldNotReach),
              style: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(strings.poolTryAgain)),
        ],
      ),
    );
  }
}

// ── The players ─────────────────────────────────────────────────────────

class _Players extends ConsumerWidget {
  const _Players({required this.c});

  final PoolMatchController c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    final game = c.game;
    final shooting = c.over ? -1 : game.turn;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: _Player(
              name: c.atTable ? strings.poolYou : strings.poolPlayerOne,
              avatar: UserAvatar.fromProfile(
                profile,
                fallbackInitial: strings.poolYou,
                radius: 18,
              ),
              game: game,
              player: 0,
              active: shooting == 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: c.atTable
                ? _Pot(prize: c.prize)
                : Icon(
                    Icons.sports_esports_rounded,
                    color: AppColors.textSecondary,
                  ),
          ),
          Expanded(
            child: _Player(
              name: c.atTable ? strings.poolChip : strings.poolPlayerTwo,
              avatar: c.atTable
                  ? CoinBuddy(
                      mood: c.chipBusy ? BuddyMood.thinking : BuddyMood.idle,
                      size: 40,
                    )
                  : UserAvatar.fromProfile(
                      null,
                      fallbackInitial: '2',
                      radius: 18,
                    ),
              game: game,
              player: 1,
              active: shooting == 1,
              mirrored: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pot extends StatelessWidget {
  const _Pot({required this.prize});

  final int prize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.poolPot,
            style: AppTextStyles.body(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          CoinAmount(prize, size: 13),
        ],
      ),
    );
  }
}

/// A player's strip: their picture and name, glowing when it's their
/// shot, and their group's balls (dim once potted).
class _Player extends StatelessWidget {
  const _Player({
    required this.name,
    required this.avatar,
    required this.game,
    required this.player,
    required this.active,
    this.mirrored = false,
  });

  final String name;
  final Widget avatar;
  final PoolGame game;
  final int player;
  final bool active;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final group = game.groups[player];
    final onEight = game.onTheEight(player);
    final balls = group == null
        ? const <int>[]
        : [
            for (var b = 1; b < kBalls; b++)
              if (b != kEightBall && group.has(b)) b,
          ];
    final info = Column(
      crossAxisAlignment: mirrored
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ).copyWith(height: 1.15),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 13,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: mirrored ? Alignment.centerRight : Alignment.centerLeft,
            child: group == null
                ? Text(
                    strings.poolOpenTable,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ).copyWith(height: 1.1),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final b in onEight ? const [kEightBall] : balls)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: _MiniBall(
                            ball: b,
                            potted: !game.balls.on[b],
                            size: 12,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: active ? 0.92 : 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? AppColors.goldBorderBright
              : AppColors.glowRing.withValues(alpha: 0.25),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.goldBorderBright.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        textDirection: mirrored ? TextDirection.rtl : TextDirection.ltr,
        children: [
          avatar,
          const SizedBox(width: 8),
          Expanded(child: info),
        ],
      ),
    );
  }
}

/// A pool ball, small: its colour, a stripe's band, dim once potted.
class _MiniBall extends StatelessWidget {
  const _MiniBall({
    required this.ball,
    required this.potted,
    required this.size,
  });

  final int ball;
  final bool potted;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _MiniBallPainter(ball, potted),
  );
}

class _MiniBallPainter extends CustomPainter {
  _MiniBallPainter(this.ball, this.potted);

  final int ball;
  final bool potted;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final color = poolBallColor(ball);
    final alpha = potted ? 0.22 : 1.0;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawRect(
      rect,
      Paint()
        ..color = (ball > 8 ? const Color(0xFFF7F4EC) : color).withValues(
          alpha: alpha,
        ),
    );
    if (ball > 8) {
      canvas.drawRect(
        Rect.fromCenter(
          center: c,
          width: size.width,
          height: size.height * 0.55,
        ),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
    canvas.restore();
    canvas.drawCircle(
      c.translate(-r * 0.3, -r * 0.3),
      r * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.5 * alpha),
    );
  }

  @override
  bool shouldRepaint(_MiniBallPainter old) =>
      old.ball != ball || old.potted != potted;
}

// ── The controls ────────────────────────────────────────────────────────

/// The power: drag down to draw the cue back, let go to shoot. The
/// player's own cue rides in it.
class _PowerBar extends StatefulWidget {
  const _PowerBar({required this.c, required this.cueArt});

  final PoolMatchController c;
  final CueArt cueArt;

  @override
  State<_PowerBar> createState() => _PowerBarState();
}

class _PowerBarState extends State<_PowerBar> {
  double? _start;

  PoolMatchController get c => widget.c;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      label: strings.poolPower,
      child: LayoutBuilder(
        builder: (context, box) {
          final h = box.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (d) {
              if (!c.canPlay) return;
              _start = d.localPosition.dy;
              HapticFeedback.selectionClick();
            },
            onVerticalDragUpdate: (d) {
              final start = _start;
              if (start == null) return;
              final before = c.power;
              c.setPower((d.localPosition.dy - start) / (h * 0.8));
              if ((c.power * 10).floor() != (before * 10).floor()) {
                HapticFeedback.selectionClick();
              }
            },
            onVerticalDragEnd: (_) {
              if (_start == null) return;
              _start = null;
              if (c.power >= 0.02) {
                HapticFeedback.mediumImpact();
                c.shoot();
              } else {
                c.setPower(0);
              }
            },
            child: SizedBox(
              width: 46,
              child: CustomPaint(
                painter: _PowerPainter(c, widget.cueArt, dpr, c.canPlay),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PowerPainter extends CustomPainter {
  _PowerPainter(this.c, this.cueArt, this.dpr, this.live) : super(repaint: c);

  final PoolMatchController c;
  final CueArt cueArt;
  final double dpr;
  final bool live;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(23),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.surface],
        ).createShader(Offset.zero & size),
    );
    final power = c.striking != null ? c.strikeFrom : c.power;
    // The fill: green to gold to red, as far down as the power.
    if (power > 0) {
      final fill = Rect.fromLTWH(
        4,
        4,
        size.width - 8,
        (size.height - 8) * power,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill, const Radius.circular(19)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2FD98E), Color(0xFFFFC93D), Color(0xFFFF5C6C)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }
    // Ticks.
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.2;
    for (var i = 1; i < 10; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(
        Offset(size.width * 0.32, y),
        Offset(size.width * 0.68, y),
        tick,
      );
    }
    // The cue, tip up, drawn down as far as the power.
    final cue = c.cue;
    final length = size.height * 0.86;
    final top = 10 + (size.height - 20) * 0.12 * power;
    cueArt.draw(
      canvas,
      cue,
      c.cueLevel,
      tip: Offset(size.width / 2, top),
      back: const Offset(0, 1),
      length: length,
      thick: size.width * 0.13,
      time: c.clock,
      dpr: dpr,
      opacity: live ? 1 : 0.45,
      shadow: false,
    );
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = (live ? AppColors.goldBorderBright : AppColors.glowRing)
            .withValues(alpha: live ? 0.8 : 0.3),
    );
  }

  @override
  bool shouldRepaint(_PowerPainter old) =>
      old.live != live || old.cueArt != cueArt;
}

/// Fine aim: a wheel to roll, turning the aim a hair at a time.
class _FineAim extends StatefulWidget {
  const _FineAim({required this.c});

  final PoolMatchController c;

  @override
  State<_FineAim> createState() => _FineAimState();
}

class _FineAimState extends State<_FineAim> {
  double _roll = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Semantics(
      label: strings.poolFineAim,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) {
          if (!c.canPlay) return;
          c.nudge(-d.delta.dy * 0.0011);
          setState(() => _roll += d.delta.dy);
          if ((_roll / 9).floor() != ((_roll - d.delta.dy) / 9).floor()) {
            HapticFeedback.selectionClick();
          }
        },
        child: SizedBox(
          width: 40,
          child: CustomPaint(painter: _WheelPainter(_roll, c.canPlay)),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.roll, this.live);

  final double roll;
  final bool live;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface,
            AppColors.surfaceElevated,
            AppColors.surface,
          ],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(rr);
    // Ridges rolling past, closer together towards the ends as on a drum.
    const gap = 9.0;
    final ridge = Paint()..strokeWidth = 2;
    final first = (roll % gap) - gap;
    for (var y = first; y < size.height + gap; y += gap) {
      final k = (y / size.height - 0.5).abs() * 2;
      ridge.color = Colors.white.withValues(
        alpha: (live ? 0.32 : 0.14) * (1 - k * 0.8),
      );
      canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), ridge);
    }
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.glowRing.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.roll != roll || old.live != live;
}

/// The spin: the cue ball with a dot where the tip will strike. Tap it to
/// set the spin on a big one.
class _SpinButton extends StatelessWidget {
  const _SpinButton({required this.c});

  final PoolMatchController c;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: strings.poolSpin,
      child: GestureDetector(
        onTap: c.canPlay
            ? () => showDialog<void>(
                context: context,
                builder: (_) => _SpinPicker(c: c),
              )
            : null,
        child: SizedBox.square(
          dimension: 48,
          child: CustomPaint(
            painter: _SpinPainter(c.spinX, c.spinY, c.canPlay ? 1 : 0.5),
          ),
        ),
      ),
    );
  }
}

class _SpinPainter extends CustomPainter {
  _SpinPainter(this.x, this.y, this.alpha);

  final double x, y, alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Colors.white.withValues(alpha: alpha),
            const Color(0xFFDCD6CA).withValues(alpha: alpha),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final cross = Paint()
      ..color = Colors.black.withValues(alpha: 0.12 * alpha)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(r, r * 0.25), Offset(r, r * 1.75), cross);
    canvas.drawLine(Offset(r * 0.25, r), Offset(r * 1.75, r), cross);
    canvas.drawCircle(
      c + Offset(x, -y) * r * 0.72,
      r * 0.16,
      Paint()..color = const Color(0xFFE8382F).withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_SpinPainter old) =>
      old.x != x || old.y != y || old.alpha != alpha;
}

class _SpinPicker extends StatefulWidget {
  const _SpinPicker({required this.c});

  final PoolMatchController c;

  @override
  State<_SpinPicker> createState() => _SpinPickerState();
}

class _SpinPickerState extends State<_SpinPicker> {
  void _set(Offset p, double size) {
    final r = size / 2;
    final d = (p - Offset(r, r)) / (r * 0.72);
    widget.c.setSpin(d.dx, -d.dy);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final stats = c.shooterStats;
    const size = 220.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: PopCard(
        borderRadius: 28,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.poolSpin, style: AppTextStyles.display(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              strings.poolSpinHelp(stats.spin),
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onPanDown: (d) => _set(d.localPosition, size),
              onPanUpdate: (d) => _set(d.localPosition, size),
              onDoubleTap: () {
                c.setSpin(0, 0);
                setState(() {});
              },
              child: SizedBox.square(
                dimension: size,
                child: CustomPaint(painter: _SpinPainter(c.spinX, c.spinY, 1)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      c.setSpin(0, 0);
                      setState(() {});
                    },
                    child: Text(strings.poolCentre),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(strings.poolDone),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The word on the shot: whose it is, what they're on, what they must do.
class _Status extends StatelessWidget {
  const _Status({required this.c});

  final PoolMatchController c;

  @override
  Widget build(BuildContext context) {
    final game = c.game;
    final String text;
    var warn = false;
    if (c.over) {
      text = strings.poolGameOver;
    } else if (c.chipBusy || c.chipsTurn) {
      text = strings.poolChipIsLiningUp;
    } else if (c.playing != null || c.striking != null) {
      text = '';
    } else if (game.callsPocket && c.called == null) {
      text = strings.poolCallAPocket;
      warn = true;
    } else if (c.placing && !game.breakShot) {
      text = strings.poolBallInHand;
    } else {
      final who = c.atTable
          ? strings.poolYourShot
          : (game.turn == 0
                ? strings.poolPlayerOneShot
                : strings.poolPlayerTwoShot);
      final group = game.groups[game.turn];
      final on = game.breakShot
          ? strings.poolTheBreak
          : game.onTheEight(game.turn)
          ? strings.poolOnTheEight
          : group == null
          ? strings.poolOpenTable
          : group == PoolGroup.solids
          ? strings.poolSolids
          : strings.poolStripes;
      text = '$who · $on';
    }
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body(
        fontWeight: FontWeight.w800,
        color: warn ? const Color(0xFFFFB020) : AppColors.textPrimary,
      ),
    );
  }
}

// ── The end ─────────────────────────────────────────────────────────────

class _Result extends StatelessWidget {
  const _Result({
    required this.c,
    required this.busy,
    required this.onAgain,
    required this.onTables,
    required this.onLook,
  });

  final PoolMatchController c;
  final bool busy;
  final VoidCallback onAgain;
  final VoidCallback onTables;
  final VoidCallback onLook;

  @override
  Widget build(BuildContext context) {
    final game = c.game;
    final win = game.win;
    final iWon = c.atTable ? c.won : null;
    final title = c.atTable
        ? (iWon! ? strings.poolYouWon : strings.poolChipWon)
        : (game.winner == 0
              ? strings.poolPlayerOneWins
              : strings.poolPlayerTwoWins);
    final why = switch (win) {
      PoolWin.eight => null,
      PoolWin.eightEarly => strings.poolWhyEightEarly,
      PoolWin.eightWrongPocket => strings.poolWhyWrongPocket,
      PoolWin.eightFoul => strings.poolWhyEightFoul,
      PoolWin.resign => strings.poolWhyResigned,
      null => null,
    };
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.elasticOut,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: PopCard(
              borderRadius: 28,
              tint: iWon ?? true ? AppColors.success : null,
              glow: iWon ?? true ? AppColors.success : AppColors.accent,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoinBuddy(
                    mood: iWon == null
                        ? BuddyMood.excited
                        : (iWon ? BuddyMood.sad : BuddyMood.happy),
                    size: 90,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(fontSize: 28),
                  ),
                  if (why != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      why,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                  ],
                  if (iWon == true) ...[
                    const SizedBox(height: AppSpacing.md),
                    _Winnings(prize: c.prize),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: c.atTable
                        ? strings.poolPlayAgainFor(formatCoins(c.entry))
                        : strings.poolRematch,
                    color: AppColors.success,
                    isLoading: busy,
                    onPressed: onAgain,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: onLook,
                          child: Text(strings.poolSeeTheTable),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: onTables,
                          child: Text(
                            c.atTable ? strings.poolTables : strings.poolDone,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pot, counting up.
class _Winnings extends StatelessWidget {
  const _Winnings({required this.prize});

  final int prize;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: prize.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Transform.scale(
        scale: 1 + 0.06 * math.sin(v / math.max(prize, 1) * math.pi),
        child: CoinAmount(v.round(), size: 26, prefix: '+'),
      ),
    );
  }
}
