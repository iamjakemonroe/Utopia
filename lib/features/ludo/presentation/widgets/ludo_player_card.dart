import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bouncy_dialog.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../coins/presentation/providers/coin_balance_provider.dart';
import '../../../friends/data/friend_repository.dart';
import '../../../friends/presentation/providers/friends_providers.dart';
import '../../../store/domain/store_catalog.dart';
import '../../domain/ludo_engine.dart';
import '../controllers/ludo_match_controller.dart';
import 'ludo_pieces.dart';

/// A player's card, popped up from their avatar: who they are, how they
/// play this game, and what you can do about it (add them, mute them,
/// report them). Stats are for the game being played only.
Future<void> showLudoPlayerCard({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required LudoColor color,
  required String matchId,
  required bool muted,
  required VoidCallback onToggleMute,
}) {
  return showBouncyDialog<void>(
    context: context,
    audio: ref.read(gameAudioProvider),
    builder: (context) => _PlayerCard(
      userId: userId,
      game: GameKind.ludo,
      accent: ludoColorPalette[color]!,
      side: ludoColorName(color),
      matchId: matchId,
      muted: muted,
      onToggleMute: onToggleMute,
    ),
  );
}

/// The same card in a chess (or checkers) game: that game's stats, and
/// which side they play. [white] is the side that moves first (dark in
/// checkers).
Future<void> showChessPlayerCard({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required bool white,
  required String matchId,
  required bool muted,
  required VoidCallback onToggleMute,
  bool checkers = false,
}) {
  return showBouncyDialog<void>(
    context: context,
    audio: ref.read(gameAudioProvider),
    builder: (context) => _PlayerCard(
      userId: userId,
      game: checkers ? GameKind.checkers : GameKind.chess,
      accent: white ? const Color(0xFFE9DFC2) : const Color(0xFF7B5CFF),
      side: checkers ? (white ? 'Dark' : 'Light') : (white ? 'White' : 'Black'),
      matchId: matchId,
      muted: muted,
      onToggleMute: onToggleMute,
    ),
  );
}

final _statsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, userId) => ref.watch(ludoRepositoryProvider).playerStats(userId),
    );

final _friendshipProvider = FutureProvider.autoDispose
    .family<FriendshipStatus, String>((ref, userId) {
      final me = ref.watch(currentUserProvider)?.id;
      if (me == null) return FriendshipStatus.none;
      return ref.watch(friendRepositoryProvider).friendshipStatus(me, userId);
    });

class _PlayerCard extends ConsumerStatefulWidget {
  const _PlayerCard({
    required this.userId,
    required this.game,
    required this.accent,
    required this.side,
    required this.matchId,
    required this.muted,
    required this.onToggleMute,
  });

  final String userId;
  final GameKind game;

  /// Their seat or side color.
  final Color accent;

  /// Their seat or side, by name ("Red", "White").
  final String side;
  final String matchId;
  final bool muted;
  final VoidCallback onToggleMute;

  @override
  ConsumerState<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends ConsumerState<_PlayerCard> {
  late bool _muted = widget.muted;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final isMe = me?.id == widget.userId;
    final isGuest = ref.watch(isAnonymousProvider);
    final profile = ref.watch(profileByIdProvider(widget.userId)).valueOrNull;
    final name = isMe ? 'You' : profileDisplayName(profile, widget.userId);
    final username = profile?['username'] as String?;
    final seat = widget.accent;
    final pieces = switch (widget.game) {
      GameKind.ludo =>
        StoreCatalog.ludoSet(pieceSetFor(profile))?.name ?? 'Classic Gloss',
      GameKind.chess || GameKind.checkers || GameKind.doodle =>
        StoreCatalog.chessSet(
              profile?['equipped_chess_pieces'] as String? ?? 'classic',
            )?.name ??
            'Classic',
    };
    final stats = ref.watch(_statsProvider(widget.userId)).valueOrNull;
    // Their coins, if they show them.
    final coins = ref.watch(publicCoinsProvider(widget.userId)).valueOrNull;
    // Only this game's record: a Ludo table doesn't care about chess.
    final prefix = widget.game.name;
    final won = stats?['${prefix}_won'];
    final played = stats?['${prefix}_played'];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Material(
          type: MaterialType.transparency,
          child: PopCard(
            borderRadius: 30,
            glow: seat,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header in the player's color, the avatar floating over it.
                Container(
                  height: 86,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(27),
                    ),
                    gradient: LinearGradient(
                      colors: [Color.lerp(seat, Colors.white, 0.25)!, seat],
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: 8,
                        top: 4,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -44,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                              border: Border.all(color: seat, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: seat.withValues(alpha: 0.6),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: UserAvatar.fromProfile(
                              profile,
                              fallbackInitial: name,
                              radius: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 52),
                Text(name, style: AppTextStyles.display(fontSize: 22)),
                Text(
                  [
                    if (username != null) '@$username',
                    if (stats?['member_since'] != null)
                      'Joined ${_joined(stats!['member_since'] as String?)}',
                  ].join(' · '),
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  children: [
                    _Chip(
                      icon: Icons.circle,
                      iconColor: seat,
                      label: widget.side,
                    ),
                    _Chip(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppColors.accentSecondary,
                      label: pieces,
                    ),
                    if (coins != null)
                      _Chip(
                        icon: Icons.monetization_on_rounded,
                        iconColor: AppColors.coinGold,
                        label: '${formatCoinsShort(coins)} coins',
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      _Stat(
                        label: switch (widget.game) {
                          GameKind.ludo => 'Ludo wins',
                          GameKind.chess => 'Chess wins',
                          GameKind.checkers => 'Checkers wins',
                          GameKind.doodle => 'Doodle wins',
                        },
                        value: won == null ? '–' : '$won',
                      ),
                      _Stat(
                        label: 'Played',
                        value: played == null ? '–' : '$played',
                      ),
                      _Stat(
                        label: 'Win rate',
                        value: won == null || played == null || played == 0
                            ? '–'
                            : '${((won as num) / (played as num) * 100).round()}%',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        _friendButton(isGuest),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: _muted
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                label: _muted ? 'Unmute chat' : 'Mute chat',
                                onTap: () {
                                  widget.onToggleMute();
                                  setState(() => _muted = !_muted);
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.flag_rounded,
                                label: 'Report',
                                danger: true,
                                onTap: () => _report(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _joined(String? iso) {
    if (iso == null) return '–';
    final d = DateTime.tryParse(iso);
    if (d == null) return '–';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${months[d.month - 1]} '${d.year % 100}";
  }

  Widget _friendButton(bool isGuest) {
    if (isGuest) {
      return const _ActionButton(
        icon: Icons.person_add_disabled_rounded,
        label: 'Save your account to add friends',
        onTap: null,
      );
    }
    final status = ref.watch(_friendshipProvider(widget.userId));
    return status.when(
      loading: () => const _ActionButton(
        icon: Icons.person_add_rounded,
        label: 'Add friend',
        onTap: null,
      ),
      error: (_, _) => const _ActionButton(
        icon: Icons.person_add_rounded,
        label: 'Add friend',
        onTap: null,
      ),
      data: (s) => switch (s) {
        FriendshipStatus.friends => const _ActionButton(
          icon: Icons.favorite_rounded,
          label: 'Friends',
          onTap: null,
          highlight: true,
        ),
        FriendshipStatus.requested => const _ActionButton(
          icon: Icons.hourglass_top_rounded,
          label: 'Request sent',
          onTap: null,
        ),
        FriendshipStatus.incoming => _ActionButton(
          icon: Icons.how_to_reg_rounded,
          label: 'Accept friend request',
          highlight: true,
          onTap: _sending ? null : _addFriend,
        ),
        _ => _ActionButton(
          icon: Icons.person_add_rounded,
          label: 'Add friend',
          highlight: true,
          onTap: _sending ? null : _addFriend,
        ),
      },
    );
  }

  Future<void> _addFriend() async {
    setState(() => _sending = true);
    try {
      // Sending to someone who already asked us accepts their request.
      await ref.read(friendRepositoryProvider).sendFriendRequest(widget.userId);
      ref.read(gameAudioProvider).play(Sfx.reaction);
      ref.invalidate(_friendshipProvider(widget.userId));
    } catch (_) {
      if (mounted) {
        showUtopiaToast(
          context,
          "Couldn't send the request. Try again.",
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.zero,
          child: PopCard(
            borderRadius: 26,
            sheet: true,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Report this player',
                  style: AppTextStyles.display(fontSize: 20),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final (id, label, icon) in const [
                  (
                    'offensive_chat',
                    'Offensive chat',
                    Icons.chat_bubble_outline_rounded,
                  ),
                  ('cheating', 'Cheating', Icons.gpp_bad_outlined),
                  (
                    'quitting',
                    'Leaving games on purpose',
                    Icons.directions_run_rounded,
                  ),
                  (
                    'name_or_avatar',
                    'Inappropriate name or picture',
                    Icons.badge_outlined,
                  ),
                  ('other', 'Something else', Icons.more_horiz_rounded),
                ])
                  ListTile(
                    leading: Icon(icon, color: AppColors.accentSecondary),
                    title: Text(label),
                    onTap: () => Navigator.of(context).pop(id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(ludoRepositoryProvider)
          .reportPlayer(
            userId: widget.userId,
            reason: reason,
            matchId: widget.matchId,
          );
      if (mounted) {
        showUtopiaToast(
          this.context,
          'Thanks. Our team will take a look.',
          kind: ToastKind.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showUtopiaToast(
          this.context,
          "Couldn't send the report. Try again.",
          kind: ToastKind.error,
        );
      }
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.glowRing.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.display(fontSize: 18)),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.error
        : (highlight ? AppColors.accent : AppColors.surfaceElevated);
    return Material(
      color: color.withValues(alpha: highlight || danger ? 0.85 : 1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.goldBorder.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
