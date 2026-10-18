import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bots/bots.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/quiet_lobby_offer.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/back_to_home.dart';
import '../../../../core/widgets/candy_mode_button.dart';
import '../../../../core/widgets/coin_balance_pill.dart';
import '../../../../core/widgets/entry_selector.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../coins/presentation/providers/coin_balance_provider.dart';
import '../../../store/presentation/coin_shop.dart';
import '../../data/ludo_repository.dart';
import '../../domain/ludo_engine.dart';
import '../controllers/ludo_match_controller.dart';
import '../widgets/ludo_pieces.dart';
import '../widgets/ludo_rules_sheet.dart';
import '../widgets/ludo_setup_widgets.dart';
import '../../../../core/widgets/ambient_tick.dart';

/// Turns backend errors into something a player can act on.
String _friendly(Object e) {
  final text = e.toString();
  if (text.contains('insufficient balance:')) {
    return 'Someone in the room needs more coins for this game.';
  }
  if (text.contains('no room with that code')) {
    return "We couldn't find that room. Check the code.";
  }
  if (text.contains('need at least 2')) {
    return 'You need at least 2 players to start.';
  }
  return friendlyError(e);
}

/// Ludo's front door: play online with 1 or 3 others, or a private room
/// friends join with a code.
class LudoLobbyScreen extends ConsumerStatefulWidget {
  const LudoLobbyScreen({super.key});

  @override
  ConsumerState<LudoLobbyScreen> createState() => _LudoLobbyScreenState();
}

class _LudoLobbyScreenState extends ConsumerState<LudoLobbyScreen> {
  bool _searching = false;
  int _entry = 0;
  int _size = 2;
  DateTime? _queuedAt;
  StreamSubscription<List<Map<String, dynamic>>>? _matchesSub;
  late final LudoRepository _repo;

  @override
  void initState() {
    super.initState();
    // Held onto here because providers can't be read during dispose.
    _repo = ref.read(ludoRepositoryProvider);
  }

  @override
  void dispose() {
    _matchesSub?.cancel();
    if (_searching) _repo.leaveMatchmakingQueue().ignore();
    super.dispose();
  }

  bool _canAfford(int entry) {
    final balance = ref.read(coinBalanceProvider).valueOrNull ?? 0;
    if (entry <= balance) return true;
    showCoinShop(context, needed: entry);
    return false;
  }

  Future<void> _openOnline() async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final choice = await showModalBottomSheet<(int, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OnlineSheet(size: _size, entry: _entry),
    );
    if (choice == null || !mounted) return;
    _size = choice.$1;
    _entry = choice.$2;
    if (!_canAfford(_entry)) return;
    await _playOnline();
  }

  Future<void> _playOnline() async {
    setState(() {
      _searching = true;
      _queuedAt = DateTime.now();
    });

    try {
      final immediate = await _repo.joinMatchmakingQueue(_entry, size: _size);
      if (!mounted) return;
      if (immediate != null) {
        _goToMatch(immediate);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      showUtopiaToast(context, _friendly(e), kind: ToastKind.error);
      return;
    }

    // Someone else's join may complete our table: watch for the match.
    _matchesSub = _repo.watchMyMatches().listen((matches) {
      final queuedAt = _queuedAt;
      if (queuedAt == null) return;
      for (final match in matches) {
        if (match['status'] != 'active' || match['mode'] != 'public') continue;
        final createdAt = DateTime.tryParse(
          match['created_at'] as String? ?? '',
        );
        if (createdAt == null ||
            createdAt.isBefore(queuedAt.subtract(const Duration(seconds: 2)))) {
          continue;
        }
        _goToMatch(match['id'] as String);
        return;
      }
    });
  }

  void _goToMatch(String matchId) {
    _matchesSub?.cancel();
    _matchesSub = null;
    setState(() => _searching = false);
    if (mounted) context.push('/ludo/$matchId');
  }

  Future<void> _cancelSearch() async {
    await _repo.leaveMatchmakingQueue();
    _matchesSub?.cancel();
    _matchesSub = null;
    if (mounted) setState(() => _searching = false);
  }

  /// Nobody to play online right now: the same size table offline, with
  /// bots in the other seats.
  Future<void> _playBotsInstead() async {
    await _cancelSearch();
    if (!mounted) return;
    final me = ref.read(currentUserProvider)?.id ?? 'me';
    final id = startLocalLudo(
      LocalLudoSetup(
        playerIds: _offlineSeats(_size, 0, 0, me),
        colors: ludoSeatColors(_size),
        humanId: me,
      ),
    );
    ref.read(gameAudioProvider).play(Sfx.reaction);
    context.push('/ludo/$id');
  }

  /// An offline table with computer players: pick how many play and which
  /// color is yours, and the bots fill the other seats.
  Future<void> _openBots() async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final choice = await showModalBottomSheet<(int, int, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _BotsSheet(),
    );
    if (choice == null || !mounted) return;
    final (players, mySeat, friends) = choice;
    final me = ref.read(currentUserProvider)?.id ?? 'me';
    final colors = ludoSeatColors(players);
    final ids = _offlineSeats(players, mySeat, friends, me);
    final id = startLocalLudo(
      LocalLudoSetup(playerIds: ids, colors: colors, humanId: me),
    );
    ref.read(gameAudioProvider).play(Sfx.reaction);
    context.push('/ludo/$id');
  }

  Future<void> _openFriends() async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final action = await showModalBottomSheet<_FriendsAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FriendsSheet(),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _CreateRoom(:final players, :final entry):
        if (!_canAfford(entry)) return;
        try {
          final room = await runWithUtopiaLoader(
            context,
            () => _repo.createRoom(maxPlayers: players, stake: entry),
          );
          if (mounted) context.push('/ludo/room/${room.id}');
        } catch (e) {
          if (mounted) {
            showUtopiaToast(context, _friendly(e), kind: ToastKind.error);
          }
        }
      case _JoinRoom(:final code):
        try {
          final roomId = await runWithUtopiaLoader(
            context,
            () => _repo.joinRoom(code),
          );
          ref.read(gameAudioProvider).play(Sfx.reaction);
          if (mounted) context.push('/ludo/room/$roomId');
        } catch (e) {
          if (mounted) {
            showUtopiaToast(context, _friendly(e), kind: ToastKind.error);
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const BackOrHomeButton(),
          title: const Text('Ludo'),
          actions: [
            IconButton(
              tooltip: 'How to play',
              icon: const Icon(Icons.menu_book_rounded),
              onPressed: () => showLudoRules(context),
            ),
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: CoinBalancePill(),
            ),
          ],
        ),
        body: AppBackground(
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _searching
                  ? _SearchingView(
                      key: const ValueKey('search'),
                      entry: _entry,
                      size: _size,
                      onCancel: _cancelSearch,
                      onPlayBots: _playBotsInstead,
                    )
                  : ListView(
                      key: const ValueKey('home'),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      children: [
                        const ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(26)),
                          child: GameSceneArt(game: GameKind.ludo, height: 190),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        CandyModeButton(
                          icon: Icons.public_rounded,
                          label: 'Play online',
                          primary: true,
                          subtitle: 'Join a table of 2 or 4 players',
                          colors: const [Color(0xFF6BF0B0), Color(0xFF1FB877)],
                          onTap: _openOnline,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CandyModeButton(
                          icon: Icons.group_rounded,
                          label: 'Play with friends',
                          subtitle: 'Make a room or join one with a code',
                          colors: const [Color(0xFFB79BFF), Color(0xFF7B5CFF)],
                          onTap: _openFriends,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CandyModeButton(
                          icon: Icons.smart_toy_rounded,
                          label: 'Play offline',
                          subtitle:
                              'Bots, or friends taking turns on this phone',
                          colors: const [Color(0xFF8FD8FF), Color(0xFF2E8FE0)],
                          onTap: _openBots,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const _FactsRow(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who sits where offline: me at [mySeat], then [friends] taking turns on
/// this phone (Player 2, 3, ...), then bots in the rest.
List<String> _offlineSeats(int players, int mySeat, int friends, String me) {
  var friend = 0;
  var bot = 0;
  return [
    for (var seat = 0; seat < players; seat++)
      if (seat == mySeat)
        me
      else if (friend < friends)
        '$kFriendSeatPrefix${2 + friend++}'
      else
        kLudoBots[bot++].id,
  ];
}

/// A few facts as icons, in place of a paragraph.
class _FactsRow extends StatelessWidget {
  const _FactsRow();

  @override
  Widget build(BuildContext context) {
    Widget fact(IconData icon, Color color, String text) => Expanded(
      child: Column(
        children: [
          GlossyBadge(icon: icon, color: color, size: 40),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        fact(Icons.groups_rounded, AppColors.sky, '2 to 6\nplayers'),
        fact(Icons.timer_rounded, const Color(0xFFFF5C9C), 'Timed\nturns'),
        fact(Icons.chat_bubble_rounded, AppColors.mint, 'Chat &\nreactions'),
        fact(Icons.vpn_key_rounded, AppColors.coinGold, 'Private\nrooms'),
      ],
    );
  }
}

/// The offline setup: how many at the table and which seat is yours. The
/// table shows who you'll be playing.
class _BotsSheet extends StatefulWidget {
  const _BotsSheet();

  @override
  State<_BotsSheet> createState() => _BotsSheetState();
}

class _BotsSheetState extends State<_BotsSheet> {
  int _players = 4;
  int _mySeat = 0;

  /// Friends playing on this phone with me; bots fill the other seats.
  int _friends = 0;

  @override
  Widget build(BuildContext context) {
    final colors = ludoSeatColors(_players);
    final seats = _offlineSeats(_players, _mySeat, _friends, '');
    return _SheetShell(
      icon: Icons.smart_toy_rounded,
      color: const Color(0xFF2E8FE0),
      title: 'Play offline',
      children: [
        PlayerCountPicker(
          options: const [2, 3, 4, 5, 6],
          value: _players,
          onChanged: (n) => setState(() {
            _players = n;
            if (_mySeat >= n) _mySeat = 0;
            if (_friends >= n) _friends = n - 1;
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Friends on this phone',
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var n = 0; n < _players; n++) ...[
              if (n > 0) const SizedBox(width: 8),
              Expanded(
                child: _FriendCountPill(
                  label: n == 0 ? 'None' : '$n',
                  selected: n == _friends,
                  onTap: () => setState(() => _friends = n),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Tap a seat to sit there',
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var seat = 0; seat < _players; seat++)
              Builder(
                builder: (context) {
                  final mine = seat == _mySeat;
                  final bot = botById(seats[seat]);
                  final friend = isFriendSeatId(seats[seat])
                      ? friendSeatName(seats[seat])
                      : null;
                  final color = ludoColorPalette[colors[seat]]!;
                  return GestureDetector(
                    onTap: () => setState(() => _mySeat = seat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: color.withValues(alpha: mine ? 0.35 : 0.14),
                        border: Border.all(
                          color: mine
                              ? Colors.white
                              : color.withValues(alpha: 0.6),
                          width: mine ? 2 : 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mine)
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: color,
                              child: const Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            )
                          else if (bot == null)
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: color.withValues(alpha: 0.5),
                              child: const Icon(
                                Icons.people_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            )
                          else
                            UserAvatar.fromProfile(
                              botProfile(bot.id),
                              fallbackInitial: bot.name,
                              radius: 14,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            mine ? 'You' : bot?.name ?? friend ?? '',
                            style: AppTextStyles.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Start game',
          color: const Color(0xFF2E8FE0),
          onPressed: () =>
              Navigator.of(context).pop((_players, _mySeat, _friends)),
        ),
      ],
    );
  }
}

/// The online setup: how many at the table and the entry.
class _OnlineSheet extends StatefulWidget {
  const _OnlineSheet({required this.size, required this.entry});

  final int size;
  final int entry;

  @override
  State<_OnlineSheet> createState() => _OnlineSheetState();
}

class _OnlineSheetState extends State<_OnlineSheet> {
  late int _size = widget.size;
  late int _entry = widget.entry;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.public_rounded,
      color: const Color(0xFF1FB877),
      title: 'Play online',
      children: [
        PlayerCountPicker(
          options: const [2, 4],
          value: _size,
          onChanged: (n) => setState(() => _size = n),
        ),
        const SizedBox(height: AppSpacing.lg),
        EntrySelector(
          options: kLudoEntries,
          value: _entry,
          players: _size,
          onChanged: (v) => setState(() => _entry = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Play',
          color: const Color(0xFF1FB877),
          onPressed: () => Navigator.of(context).pop((_size, _entry)),
        ),
      ],
    );
  }
}

sealed class _FriendsAction {
  const _FriendsAction();
}

class _CreateRoom extends _FriendsAction {
  const _CreateRoom(this.players, this.entry);

  final int players;
  final int entry;
}

class _JoinRoom extends _FriendsAction {
  const _JoinRoom(this.code);

  final String code;
}

/// Create a room (players, entry) or join one with a code.
class _FriendsSheet extends StatefulWidget {
  const _FriendsSheet();

  @override
  State<_FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<_FriendsSheet> {
  bool _joining = false;
  int _players = 4;
  int _entry = 0;
  final _code = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _code.text;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _SheetShell(
        icon: Icons.group_rounded,
        color: const Color(0xFF7B5CFF),
        title: 'Play with friends',
        children: [
          _TabSwitch(
            joining: _joining,
            onChanged: (j) {
              setState(() => _joining = j);
              if (j) {
                _focus.requestFocus();
              } else {
                _focus.unfocus();
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: _joining
                ? Column(
                    children: [
                      GestureDetector(
                        onTap: () => _focus.requestFocus(),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: 0,
                              child: TextField(
                                controller: _code,
                                focusNode: _focus,
                                maxLength: 6,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp('[A-Za-z0-9]'),
                                  ),
                                  TextInputFormatter.withFunction(
                                    (_, v) =>
                                        v.copyWith(text: v.text.toUpperCase()),
                                  ),
                                ],
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (v) {
                                  if (v.length == 6) {
                                    Navigator.of(context).pop(_JoinRoom(v));
                                  }
                                },
                              ),
                            ),
                            IgnorePointer(
                              child: FittedBox(
                                child: CodeTiles(
                                  code: code,
                                  length: 6,
                                  focused: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Join room',
                        onPressed: code.length == 6
                            ? () => Navigator.of(context).pop(_JoinRoom(code))
                            : null,
                      ),
                    ],
                  )
                : Column(
                    children: [
                      PlayerCountPicker(
                        options: const [2, 3, 4, 5, 6],
                        value: _players,
                        onChanged: (n) => setState(() => _players = n),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _players <= 4
                                ? Icons.add_box_rounded
                                : Icons.star_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _players <= 4 ? 'Classic board' : 'Star board',
                            style: AppTextStyles.body(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      EntrySelector(
                        options: kLudoEntries,
                        value: _entry,
                        players: _players,
                        onChanged: (v) => setState(() => _entry = v),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Create room',
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_CreateRoom(_players, _entry)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.joining, required this.onChanged});

  final bool joining;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(bool join, IconData icon, String label) {
      final on = join == joining;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(join),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: on ? AppColors.accent : Colors.transparent,
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: on ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.25),
      ),
      child: Row(
        children: [
          tab(false, Icons.add_circle_rounded, 'Create'),
          tab(true, Icons.vpn_key_rounded, 'Join'),
        ],
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.background],
        ),
        border: sheetBorder(AppColors.goldBorder),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  GlossyBadge(icon: icon, color: color, size: 38),
                  const SizedBox(width: 10),
                  Text(title, style: AppTextStyles.display(fontSize: 22)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A room code as a row of glossy letter tiles.
class CodeTiles extends StatelessWidget {
  const CodeTiles({
    super.key,
    required this.code,
    this.length = 6,
    this.focused = false,
    this.size = 44,
  });

  final String code;
  final int length;
  final bool focused;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < length; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.07),
            child: AnimatedScale(
              scale: i < code.length ? 1 : 0.92,
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              child: Container(
                width: size,
                height: size * 1.2,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, const Color(0xFFE9E2FF)],
                  ),
                  border: Border.all(
                    color: focused && i == code.length
                        ? AppColors.goldBorderBright
                        : Colors.white.withValues(
                            alpha: i < code.length ? 1 : 0.5,
                          ),
                    width: focused && i == code.length ? 3 : 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.depthShade(AppColors.accent),
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  i < code.length ? code[i] : '',
                  style: AppTextStyles.display(
                    fontSize: size * 0.55,
                    color: AppColors.faceInk,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Looking for players: tokens hop around the loader while the seconds
/// tick by.
class _SearchingView extends StatefulWidget {
  const _SearchingView({
    super.key,
    required this.entry,
    required this.size,
    required this.onCancel,
    required this.onPlayBots,
  });

  final int entry;
  final int size;
  final VoidCallback onCancel;
  final VoidCallback onPlayBots;

  @override
  State<_SearchingView> createState() => _SearchingViewState();
}

class _SearchingViewState extends State<_SearchingView>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Started here: a lazy field would only be created (and started)
    // on first use, which for a ticker is never.
    _ticker = createTicker(
      ambientTick((e) => _t.value = e.inMicroseconds / 1e6),
    )..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ludoSeatColors(4);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 240,
              child: ValueListenableBuilder<double>(
                valueListenable: _t,
                builder: (context, t, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    const UtopiaLoader(size: 96),
                    for (var i = 0; i < 4; i++)
                      Transform.translate(
                        offset: Offset(
                          math.cos(t * 0.9 + i * math.pi / 2) * 92,
                          math.sin(t * 0.9 + i * math.pi / 2) * 92 * 0.55 -
                              10 *
                                  math
                                      .sin(t * 6 + i)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                        ),
                        child: SizedBox(
                          width: 30,
                          height: 30 * LudoTokenPainter.aspect,
                          child: CustomPaint(
                            painter: LudoTokenPainter(
                              setId: 'classic',
                              color: colors[i],
                              t: t + i,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.size == 2 ? 'Finding an opponent' : 'Gathering players',
              style: AppTextStyles.display(fontSize: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_rounded, size: 18, color: AppColors.sky),
                const SizedBox(width: 4),
                Text(
                  '${widget.size}',
                  style: AppTextStyles.body(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 14),
                if (widget.entry == 0) ...[
                  Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: AppColors.coral,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Free',
                    style: AppTextStyles.body(fontWeight: FontWeight.w800),
                  ),
                ] else
                  CoinAmount(widget.entry, size: 15),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ValueListenableBuilder<double>(
              valueListenable: _t,
              builder: (context, t, _) {
                final s = t.floor();
                return Text(
                  '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                );
              },
            ),
            QuietLobbyOffer(label: 'Play with bots', onPlay: widget.onPlayBots),
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every seat color, for anything that needs one per seat.
List<Color> seatPalette(int players) => [
  for (final c in ludoSeatColors(players)) ludoColorPalette[c]!,
];

/// Seat [i]'s color at a table of [players].
LudoColor seatColor(int players, int i) => ludoSeatColors(players)[i];

/// One choice of how many friends play on this phone.
class _FriendCountPill extends StatelessWidget {
  const _FriendCountPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? AppColors.accent : AppColors.surfaceElevated,
          border: Border.all(
            color: selected
                ? AppColors.goldBorderBright
                : AppColors.glowRing.withValues(alpha: 0.35),
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.onAccent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
