import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/profiles/profile_freshness.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/entry_selector.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/ludo_repository.dart';
import '../../domain/ludo_engine.dart';
import '../controllers/ludo_match_controller.dart';
import '../widgets/ludo_pieces.dart';
import '../widgets/ludo_setup_widgets.dart';
import 'ludo_lobby_screen.dart';
import '../../../invites/domain/game_invite.dart';

/// A friends' room: the code to share, a seat for each color filling up as
/// friends join, and the host's start button. Everyone is taken to the game
/// the moment the host starts it.
class LudoRoomScreen extends ConsumerStatefulWidget {
  const LudoRoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<LudoRoomScreen> createState() => _LudoRoomScreenState();
}

class _LudoRoomScreenState extends ConsumerState<LudoRoomScreen> {
  StreamSubscription<Map<String, dynamic>?>? _roomSub;
  StreamSubscription<List<Map<String, dynamic>>>? _membersSub;
  Map<String, dynamic>? _room;
  List<Map<String, dynamic>> _members = const [];
  bool _starting = false;
  bool _left = false;
  late final LudoRepository _repo;

  @override
  void initState() {
    super.initState();
    final repo = _repo = ref.read(ludoRepositoryProvider);
    _roomSub = repo.watchRoom(widget.roomId).listen((room) {
      if (!mounted) return;
      setState(() => _room = room);
      final matchId = room?['match_id'] as String?;
      if (room?['status'] == 'started' && matchId != null) {
        _left = true; // the room is done; don't "leave" it on the way out
        context.go('/ludo/$matchId');
      }
    });
    _membersSub = repo.watchRoomMembers(widget.roomId).listen((rows) {
      if (!mounted) return;
      final joined = rows.length > _members.length && _members.isNotEmpty;
      setState(() => _members = rows);
      if (joined) ref.read(gameAudioProvider).play(Sfx.reaction);
    });
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _membersSub?.cancel();
    if (!_left) _repo.leaveRoom(widget.roomId).ignore();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await _repo.startRoom(widget.roomId);
      // The room stream takes everyone (including us) to the match.
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      final text = e.toString();
      showUtopiaToast(
        context,
        text.contains('insufficient balance:')
            ? 'Someone needs more coins for this game.'
            : text.contains('at least 2')
            ? 'Wait for at least one friend to join.'
            : "Couldn't start the game. Try again.",
        kind: ToastKind.error,
      );
    }
  }

  /// The drawer for an open seat: sit there (and play that color), or
  /// invite someone into it.
  Future<void> _openSeat(int seat, LudoColor color, String code) async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SeatDrawer(color: color),
    );
    if (!mounted || action == null) return;
    if (action == 'share') {
      await _share(code);
      return;
    }
    try {
      await _repo.takeSeat(widget.roomId, seat);
      ref.read(gameAudioProvider).play(Sfx.drop);
    } catch (e) {
      if (!mounted) return;
      showUtopiaToast(
        context,
        e.toString().contains('taken')
            ? 'Someone just took that seat.'
            : "Couldn't change seats. Try again.",
        kind: ToastKind.error,
      );
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ref.read(gameAudioProvider).play(Sfx.tap);
    showUtopiaToast(
      context,
      'Code copied',
      icon: Icons.content_copy_rounded,
      kind: ToastKind.success,
    );
  }

  Future<void> _share(String code) async {
    ref.read(gameAudioProvider).play(Sfx.tap);
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Come play Ludo with me in Utopia! Tap to join, or use room code '
            '$code: ${GameInvite(InviteGame.ludo, code).link}',
        subject: 'Ludo in Utopia',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final me = ref.watch(currentUserProvider)?.id;

    if (room == null) {
      return const Scaffold(
        body: AppBackground(
          child: Center(
            child: UtopiaLoader(size: 80, label: 'Opening the room'),
          ),
        ),
      );
    }

    final code = room['code'] as String;
    final max = (room['max_players'] as num).toInt();
    final entry = (room['stake'] as num).toInt();
    final hostId = room['host_id'] as String;
    final isHost = hostId == me;
    final bySeat = {
      for (final m in _members)
        (m['seat'] as num).toInt(): m['user_id'] as String,
    };
    final colors = ludoSeatColors(max);
    final ready = _members.length >= 2;
    // Seated players' avatars, names and piece sets stay current.
    ref.watch(liveProfilesProvider(liveProfilesKey(bySeat.values)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Private room'),
        actions: [
          IconButton(
            tooltip: 'Share code',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _share(code),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              _CodeCard(
                code: code,
                onCopy: () => _copy(code),
                onShare: () => _share(code),
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoChips(players: max, entry: entry),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(
                    Icons.event_seat_rounded,
                    size: 20,
                    color: AppColors.accentSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text('Players', style: AppTextStyles.display(fontSize: 18)),
                  const Spacer(),
                  Text(
                    '${_members.length} / $max',
                    style: AppTextStyles.display(
                      fontSize: 18,
                      color: ready
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Equal seats: two across for up to four players, three
              // across for five or six; a short last row is centered.
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = AppSpacing.sm;
                  final columns = max <= 4 ? 2 : 3;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var seat = 0; seat < max; seat++)
                        SizedBox(
                          width: width,
                          height: columns == 2 ? width * 0.86 : width * 1.12,
                          child: _Seat(
                            color: colors[seat],
                            userId: bySeat[seat],
                            isHost: bySeat[seat] == hostId,
                            isMe: bySeat[seat] == me,
                            onOpen: () => _openSeat(seat, colors[seat], code),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              if (isHost)
                PrimaryButton(
                  label: ready ? 'Start game' : 'Waiting for friends',
                  color: ready ? AppColors.success : null,
                  isLoading: _starting,
                  onPressed: ready ? _start : null,
                )
              else
                Column(
                  children: [
                    const UtopiaLoader(size: 40, bubbles: false),
                    const SizedBox(height: 4),
                    Text(
                      'The host will start the game',
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(isHost ? 'Close room' : 'Leave room'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });

  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 28,
      tint: AppColors.accent,
      glow: AppColors.accent,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.coinGold),
              const SizedBox(width: 6),
              Text(
                'ROOM CODE',
                style: AppTextStyles.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ).copyWith(letterSpacing: 2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: onCopy,
            child: FittedBox(child: CodeTiles(code: code, size: 46)),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  icon: Icons.content_copy_rounded,
                  label: 'Copy',
                  color: AppColors.sky,
                  onTap: onCopy,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PillButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: AppColors.success,
                  onTap: onShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.18),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.body(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  const _InfoChips({required this.players, required this.entry});

  final int players;
  final int entry;

  @override
  Widget build(BuildContext context) {
    Widget chip(Widget leading, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: AppColors.glowRing.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.body(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          Icon(
            players <= 4 ? Icons.add_box_rounded : Icons.star_rounded,
            size: 16,
            color: AppColors.sky,
          ),
          players <= 4 ? 'Classic' : 'Star board',
        ),
        if (entry == 0)
          chip(
            Icon(Icons.favorite_rounded, size: 16, color: AppColors.coral),
            'Free',
          )
        else ...[
          chip(const CoinIcon(size: 16), formatCoins(entry)),
          chip(
            const CrownIcon(size: 16),
            formatCoins(prizeFor(entry, players)),
          ),
        ],
        chip(
          const Icon(Icons.timer_rounded, size: 16, color: Color(0xFFFF5C9C)),
          '40s turns',
        ),
      ],
    );
  }
}

/// One seat: a tile in that seat's Ludo color, like the yard on the board,
/// with the player who took it (or an open spot to invite someone into).
class _Seat extends ConsumerStatefulWidget {
  const _Seat({
    required this.color,
    required this.userId,
    required this.isHost,
    required this.isMe,
    required this.onOpen,
  });

  final LudoColor color;
  final String? userId;
  final bool isHost;
  final bool isMe;

  /// Opens the drawer for an open seat.
  final VoidCallback onOpen;

  @override
  ConsumerState<_Seat> createState() => _SeatState();
}

class _SeatState extends ConsumerState<_Seat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.userId;
    final profile = id == null
        ? null
        : ref.watch(profileByIdProvider(id)).valueOrNull;
    final name = id == null
        ? 'Seat'
        : (widget.isMe ? 'You' : profileDisplayName(profile, id));
    final seat = ludoColorPalette[widget.color]!;
    final filled = id != null;

    return GestureDetector(
      onTap: filled ? null : widget.onOpen,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: Curves.elasticOut,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        // AnimatedSwitcher hands its child loose constraints; fill the
        // seat's slot explicitly so every seat is the same size.
        child: Container(
          key: ValueKey(id),
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: filled
                  ? [Color.lerp(seat, Colors.white, 0.3)!, seat]
                  : [
                      seat.withValues(alpha: 0.28),
                      seat.withValues(alpha: 0.12),
                    ],
            ),
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: 0.85)
                  : seat.withValues(alpha: 0.6),
              width: filled ? 2.2 : 1.5,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: AppColors.depthShade(seat),
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: seat.withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final r = math.min(c.maxWidth, c.maxHeight) * 0.26;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                        child: filled
                            ? UserAvatar.fromProfile(
                                profile,
                                fallbackInitial: name,
                                radius: r,
                              )
                            : AnimatedBuilder(
                                animation: _pulse,
                                builder: (context, _) => SizedBox.square(
                                  dimension: r * 2,
                                  child: Icon(
                                    Icons.event_seat_rounded,
                                    size: r * (0.9 + 0.12 * _pulse.value),
                                    color: seat.withValues(
                                      alpha: 0.55 + 0.4 * _pulse.value,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      if (widget.isHost)
                        Positioned(
                          top: -r * 0.55,
                          child: CrownIcon(size: r * 0.9),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: filled
                            ? Colors.white
                            : seat.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What you can do with an open seat, in a drawer just tall enough for it:
/// that seat's token hops at the top, and the choices pop in one by one.
class _SeatDrawer extends StatelessWidget {
  const _SeatDrawer({required this.color});

  final LudoColor color;

  @override
  Widget build(BuildContext context) {
    final seat = ludoColorPalette[color]!;
    final name = ludoColorName(color);
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              seat.withValues(alpha: 0.22),
              AppColors.surfaceElevated,
            ),
            AppColors.background,
          ],
        ),
        border: sheetBorder(seat.withValues(alpha: 0.7), width: 1.6),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _HoppingToken(color: color),
              const SizedBox(height: 6),
              Text('$name seat', style: AppTextStyles.display(fontSize: 22)),
              const SizedBox(height: AppSpacing.md),
              _DrawerOption(
                index: 0,
                icon: Icons.event_seat_rounded,
                color: seat,
                label: 'Take this seat',
                caption: 'Play as $name',
                onTap: () => Navigator.of(context).pop('take'),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DrawerOption(
                index: 1,
                icon: Icons.share_rounded,
                color: AppColors.success,
                label: 'Share invite',
                caption: 'Send the room code to a friend',
                onTap: () => Navigator.of(context).pop('share'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoppingToken extends StatefulWidget {
  const _HoppingToken({required this.color});

  final LudoColor color;

  @override
  State<_HoppingToken> createState() => _HoppingTokenState();
}

class _HoppingTokenState extends State<_HoppingToken>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46 * LudoTokenPainter.aspect + 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final hop = math.sin(_c.value * math.pi);
          return Transform.translate(
            offset: Offset(0, -14 * hop),
            child: Transform.scale(
              scaleX: 1 + 0.06 * (1 - hop),
              scaleY: 1 - 0.06 * (1 - hop),
              alignment: Alignment.bottomCenter,
              child: CustomPaint(
                painter: LudoTokenPainter(
                  setId: 'classic',
                  color: widget.color,
                  t: _c.value * 3,
                  lift: hop,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DrawerOption extends StatelessWidget {
  const _DrawerOption({
    required this.index,
    required this.icon,
    required this.color,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final Color color;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + index * 140),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - v)),
          child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
        ),
      ),
      child: Material(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                GlossyBadge(icon: icon, color: color, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.body(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        caption,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
