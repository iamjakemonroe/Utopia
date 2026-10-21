import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/profiles/profile_freshness.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/entry_selector.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/share_invite.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../../l10n/strings.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../invites/domain/game_invite.dart';
import '../../../ludo/presentation/screens/ludo_lobby_screen.dart';
import '../../../ludo/presentation/screens/ludo_room_screen.dart';
import '../../data/eights_repository.dart';
import '../controllers/eights_match_controller.dart';
import 'eights_match_screen.dart';

/// A friends' card table: the code to share, a seat filling up as each
/// friend joins, and the host's start button. Everyone goes to the game
/// the moment the host deals.
class EightsRoomScreen extends ConsumerStatefulWidget {
  const EightsRoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<EightsRoomScreen> createState() => _EightsRoomScreenState();
}

class _EightsRoomScreenState extends ConsumerState<EightsRoomScreen> {
  StreamSubscription<Map<String, dynamic>?>? _roomSub;
  StreamSubscription<List<Map<String, dynamic>>>? _membersSub;
  Map<String, dynamic>? _room;
  List<Map<String, dynamic>> _members = const [];
  bool _starting = false;
  bool _left = false;
  Timer? _recheck;
  Timer? _syncTimer;
  late final EightsRepository _repo;

  @override
  void initState() {
    super.initState();
    final repo = _repo = ref.read(eightsRepositoryProvider);
    _roomSub = repo.watchRoom(widget.roomId).listen(_onRoom);
    // Seats come from the database itself (an update only says something
    // changed), and every few seconds too, for an update that never comes.
    _membersSub = repo
        .watchRoomMembers(widget.roomId)
        .listen((_) => _syncSoon());
    _recheck = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        _onRoom(await _repo.fetchRoom(widget.roomId));
      } catch (_) {}
      await _syncMembers();
    });
    _syncMembers();
  }

  void _syncSoon() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 120), _syncMembers);
  }

  Future<void> _syncMembers() async {
    try {
      final rows = await _repo.fetchRoomMembers(widget.roomId);
      if (!mounted) return;
      final joined = rows.length > _members.length && _members.isNotEmpty;
      setState(() => _members = rows);
      if (joined) ref.read(gameAudioProvider).play(Sfx.reaction);
    } catch (_) {}
  }

  void _onRoom(Map<String, dynamic>? room) {
    if (!mounted || _left) return;
    setState(() => _room = room);
    final matchId = room?['match_id'] as String?;
    if (room?['status'] == 'started' && matchId != null) {
      _left = true;
      _recheck?.cancel();
      context.go('/eights/$matchId');
    }
  }

  @override
  void dispose() {
    _recheck?.cancel();
    _syncTimer?.cancel();
    _roomSub?.cancel();
    _membersSub?.cancel();
    if (!_left) _repo.leaveRoom(widget.roomId).ignore();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await _repo.startRoom(widget.roomId);
      // The room's update takes everyone (us too) to the game.
    } catch (e) {
      if (mounted) {
        showUtopiaToast(context, ludoErrorText(e), kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ref.read(gameAudioProvider).play(Sfx.tap);
    showUtopiaToast(
      context,
      strings.ludoRoomCodeCopied,
      icon: Icons.content_copy_rounded,
      kind: ToastKind.success,
    );
  }

  Future<void> _share(String code) async {
    ref.read(analyticsProvider).log('invite_shared', {'game': 'eights'});
    ref.read(gameAudioProvider).play(Sfx.tap);
    final box = context.findRenderObject() as RenderBox?;
    await shareInvite(
      context,
      text: strings.eightsRoomComePlay(
        code,
        GameInvite(InviteGame.eights, code).link,
      ),
      subject: strings.eightsRoomInUtopia,
      origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final me = ref.watch(currentUserProvider)?.id;
    if (room == null) {
      return Scaffold(
        body: AppBackground(
          child: Center(
            child: UtopiaLoader(
              size: 80,
              label: strings.ludoRoomOpeningTheRoom,
            ),
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
    final ready = _members.length >= 2;
    ref.watch(liveProfilesProvider(liveProfilesKey(bySeat.values)));

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.ludoRoomPrivateRoom),
        actions: [
          IconButton(
            tooltip: strings.ludoRoomShareCode,
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _share(code),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: context.readablePadding(
              top: AppSpacing.xs,
              bottom: AppSpacing.xl,
            ),
            children: [
              RoomCodeCard(
                code: code,
                onCopy: () => _copy(code),
                onShare: () => _share(code),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: const Icon(
                      Icons.style_rounded,
                      size: 16,
                      color: AppColors.sky,
                    ),
                    text: strings.homeCrazyEights,
                  ),
                  if (entry == 0)
                    _Chip(
                      icon: Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: AppColors.coral,
                      ),
                      text: strings.ludoRoomFree,
                    )
                  else ...[
                    _Chip(
                      icon: const CoinIcon(size: 16),
                      text: formatCoins(entry),
                    ),
                    _Chip(
                      icon: const CrownIcon(size: 16),
                      text: formatCoins(prizeFor(entry, max)),
                    ),
                  ],
                  _Chip(
                    icon: const Icon(
                      Icons.timer_rounded,
                      size: 16,
                      color: Color(0xFFFF5C9C),
                    ),
                    text: strings.ludoRoom40sTurns,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(
                    Icons.event_seat_rounded,
                    size: 20,
                    color: AppColors.accentSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings.ludoRoomPlayers,
                    style: AppTextStyles.display(fontSize: 18),
                  ),
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
                          height: 96,
                          child: _Seat(
                            color: kEightsSeatColors[seat],
                            userId: bySeat[seat],
                            isHost: bySeat[seat] == hostId,
                            isMe: bySeat[seat] == me,
                            onInvite: () => _share(code),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              if (isHost)
                PrimaryButton(
                  label: ready
                      ? strings.eightsRoomDeal
                      : strings.ludoRoomWaitingForFriends,
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
                      strings.ludoRoomTheHostWillStartThe,
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(
                    isHost
                        ? strings.ludoRoomCloseRoom
                        : strings.ludoRoomLeaveRoom,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: AppColors.glowRing.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
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
  }
}

/// One seat: the player who took it, or an open spot (tap to invite).
class _Seat extends ConsumerWidget {
  const _Seat({
    required this.color,
    required this.userId,
    required this.isHost,
    required this.isMe,
    required this.onInvite,
  });

  final Color color;
  final String? userId;
  final bool isHost;
  final bool isMe;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    final profile = id == null
        ? null
        : ref.watch(profileByIdProvider(id)).valueOrNull;
    final name = id == null
        ? strings.ludoSeatPanelOpenSeat
        : isMe
        ? strings.ludoMatchYou
        : profileDisplayName(profile, id);
    return GestureDetector(
      onTap: id == null ? onInvite : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: id == null ? 0.1 : 0.28),
          border: Border.all(
            color: color.withValues(alpha: id == null ? 0.35 : 0.9),
            width: isMe ? 2.2 : 1.4,
          ),
        ),
        child: Row(
          children: [
            if (id == null)
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.25),
                child: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              )
            else
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar.fromProfile(
                    profile,
                    fallbackInitial: name,
                    radius: 20,
                  ),
                  if (isHost)
                    const Positioned(
                      top: -12,
                      left: 8,
                      child: CrownIcon(size: 18),
                    ),
                ],
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w800,
                  color: id == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
