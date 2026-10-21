import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/bots/bots.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/platform/keyboard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ambient_tick.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/back_to_home.dart';
import '../../../../core/widgets/candy_mode_button.dart';
import '../../../../core/widgets/coin_balance_pill.dart';
import '../../../../core/widgets/entry_selector.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/quiet_lobby_offer.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../../l10n/strings.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../coins/presentation/providers/coin_balance_provider.dart';
import '../../../ludo/presentation/screens/ludo_lobby_screen.dart';
import '../../../ludo/presentation/widgets/ludo_setup_widgets.dart';
import '../../../store/presentation/coin_shop.dart';
import '../../data/eights_repository.dart';
import '../../domain/eights_engine.dart';
import '../controllers/eights_match_controller.dart';
import '../widgets/card_art.dart';
import '../widgets/eights_rules_sheet.dart';

/// The card table's front door: online with 1 to 3 others, a private room
/// friends join with a code, or offline against bots.
class EightsLobbyScreen extends ConsumerStatefulWidget {
  const EightsLobbyScreen({super.key});

  @override
  ConsumerState<EightsLobbyScreen> createState() => _EightsLobbyScreenState();
}

class _EightsLobbyScreenState extends ConsumerState<EightsLobbyScreen> {
  bool _searching = false;
  int _entry = 0;
  int _size = 2;
  DateTime? _queuedAt;
  StreamSubscription<List<Map<String, dynamic>>>? _matchesSub;
  late final EightsRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(eightsRepositoryProvider);
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
    setState(() {
      _searching = true;
      _queuedAt = DateTime.now();
    });
    try {
      final matchId = await _repo.joinMatchmakingQueue(_entry, size: _size);
      if (!mounted) return;
      if (matchId != null) {
        _goToMatch(matchId);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      showUtopiaToast(context, ludoErrorText(e), kind: ToastKind.error);
      return;
    }
    // Someone else's join may fill our table: watch for the game.
    _matchesSub = _repo.watchMyMatches().listen((matches) {
      final queuedAt = _queuedAt;
      if (queuedAt == null) return;
      for (final m in matches) {
        if (m['status'] != 'active' || m['mode'] != 'public') continue;
        final created = DateTime.tryParse(m['created_at'] as String? ?? '');
        if (created == null ||
            created.isBefore(queuedAt.subtract(const Duration(seconds: 2)))) {
          continue;
        }
        _goToMatch(m['id'] as String);
        return;
      }
    });
  }

  void _goToMatch(String matchId) {
    _matchesSub?.cancel();
    _matchesSub = null;
    setState(() => _searching = false);
    if (mounted) context.push('/eights/$matchId');
  }

  Future<void> _cancelSearch() async {
    await _repo.leaveMatchmakingQueue();
    _matchesSub?.cancel();
    _matchesSub = null;
    if (mounted) setState(() => _searching = false);
  }

  /// A table on this phone: me and [players] - 1 bots.
  void _startOffline(int players) {
    final me = ref.read(currentUserProvider)?.id ?? 'me';
    final id = startLocalEights(
      LocalEightsSetup(
        playerIds: [me, for (var i = 0; i < players - 1; i++) kLudoBots[i].id],
        humanId: me,
      ),
    );
    ref.read(gameAudioProvider).play(Sfx.reaction);
    context.push('/eights/$id');
  }

  Future<void> _playBotsInstead() async {
    await _cancelSearch();
    if (mounted) _startOffline(_size);
  }

  Future<void> _openOffline() async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final players = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _OfflineSheet(),
    );
    if (players != null && mounted) _startOffline(players);
  }

  Future<void> _openFriends() async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final action = await showModalBottomSheet<(int, int)?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FriendsSheet(onJoin: _join),
    );
    if (action == null || !mounted) return;
    final (players, entry) = action;
    if (!_canAfford(entry)) return;
    try {
      final room = await runWithUtopiaLoader(
        context,
        () => _repo.createRoom(maxPlayers: players, stake: entry),
      );
      if (mounted) context.push('/eights/room/${room.id}');
    } catch (e) {
      if (mounted) {
        showUtopiaToast(context, ludoErrorText(e), kind: ToastKind.error);
      }
    }
  }

  Future<void> _join(String code) async {
    try {
      final roomId = await runWithUtopiaLoader(
        context,
        () => _repo.joinRoom(code),
      );
      ref.read(gameAudioProvider).play(Sfx.reaction);
      if (mounted) context.push('/eights/room/$roomId');
    } catch (e) {
      if (mounted) {
        showUtopiaToast(context, ludoErrorText(e), kind: ToastKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const BackOrHomeButton(),
          title: Text(strings.homeCrazyEights),
          actions: [
            IconButton(
              tooltip: strings.ludoLobbyHowToPlay,
              icon: const Icon(Icons.menu_book_rounded),
              onPressed: () => showEightsRules(context),
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
                      padding: context.readablePadding(
                        top: AppSpacing.xs,
                        bottom: AppSpacing.xl,
                      ),
                      children: [
                        const ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(26)),
                          child: GameSceneArt(
                            game: GameKind.eights,
                            height: 190,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        CandyModeButton(
                          icon: Icons.public_rounded,
                          label: strings.ludoLobbyPlayOnline,
                          primary: true,
                          subtitle: strings.eightsLobbyOnlineSubtitle,
                          colors: const [Color(0xFF6BF0B0), Color(0xFF1FB877)],
                          onTap: _openOnline,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CandyModeButton(
                          icon: Icons.group_rounded,
                          label: strings.ludoLobbyPlayWithFriends,
                          subtitle: strings.ludoLobbyMakeARoomOrJoin,
                          colors: const [Color(0xFFB79BFF), Color(0xFF7B5CFF)],
                          onTap: _openFriends,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CandyModeButton(
                          icon: Icons.smart_toy_rounded,
                          label: strings.ludoLobbyPlayOffline,
                          subtitle: strings.eightsLobbyOfflineSubtitle,
                          colors: const [Color(0xFF8FD8FF), Color(0xFF2E8FE0)],
                          onTap: _openOffline,
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
        fact(Icons.groups_rounded, AppColors.sky, strings.ludoLobby2To6Players),
        fact(
          Icons.auto_awesome_rounded,
          const Color(0xFFB27BFF),
          strings.homeEightsAreWild,
        ),
        fact(
          Icons.chat_bubble_rounded,
          AppColors.mint,
          strings.eightsLobbyChatVoice,
        ),
        fact(
          Icons.vpn_key_rounded,
          AppColors.coinGold,
          strings.ludoLobbyPrivateRooms,
        ),
      ],
    );
  }
}

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
    return LobbySheetShell(
      icon: Icons.public_rounded,
      color: const Color(0xFF1FB877),
      title: strings.ludoLobbyPlayOnline,
      children: [
        PlayerCountPicker(
          options: const [2, 3, 4],
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
          label: strings.ludoLobbyPlay,
          color: const Color(0xFF1FB877),
          onPressed: () => Navigator.of(context).pop((_size, _entry)),
        ),
      ],
    );
  }
}

class _OfflineSheet extends StatefulWidget {
  const _OfflineSheet();

  @override
  State<_OfflineSheet> createState() => _OfflineSheetState();
}

class _OfflineSheetState extends State<_OfflineSheet> {
  int _players = 3;

  @override
  Widget build(BuildContext context) {
    return LobbySheetShell(
      icon: Icons.smart_toy_rounded,
      color: const Color(0xFF2E8FE0),
      title: strings.ludoLobbyPlayOffline,
      children: [
        PlayerCountPicker(
          options: const [2, 3, 4, 5, 6],
          value: _players,
          onChanged: (n) => setState(() => _players = n),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.eightsLobbyBotsFill(_players - 1),
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: strings.ludoLobbyStartGame,
          color: const Color(0xFF2E8FE0),
          onPressed: () => Navigator.of(context).pop(_players),
        ),
      ],
    );
  }
}

/// Make a room (players, entry), or join one with a code.
class _FriendsSheet extends StatefulWidget {
  const _FriendsSheet({required this.onJoin});

  final Future<void> Function(String code) onJoin;

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

  void _submit(String code) {
    Navigator.of(context).pop();
    widget.onJoin(code);
  }

  @override
  Widget build(BuildContext context) {
    final code = _code.text;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LobbySheetShell(
        icon: Icons.group_rounded,
        color: const Color(0xFF7B5CFF),
        title: strings.ludoLobbyPlayWithFriends,
        children: [
          LobbyTabSwitch(
            joining: _joining,
            onChanged: (j) {
              setState(() => _joining = j);
              if (j) {
                focusIfAllowed(_focus);
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
                        onTap: () => openKeyboard(_focus),
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
                                  if (v.length == 6) _submit(v);
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
                        label: strings.ludoLobbyJoinRoom,
                        onPressed: code.length == 6
                            ? () => _submit(code)
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
                      const SizedBox(height: AppSpacing.lg),
                      EntrySelector(
                        options: kLudoEntries,
                        value: _entry,
                        players: _players,
                        onChanged: (v) => setState(() => _entry = v),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: strings.ludoLobbyCreateRoom,
                        onPressed: () =>
                            Navigator.of(context).pop((_players, _entry)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Looking for players: cards circling the loader while the seconds tick.
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

  static const _cards = [
    PlayingCard(8, CardSuit.hearts),
    PlayingCard(1, CardSuit.spades),
    PlayingCard(13, CardSuit.diamonds),
    PlayingCard(7, CardSuit.clubs),
  ];

  @override
  void initState() {
    super.initState();
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
                    for (var i = 0; i < _cards.length; i++)
                      Transform.translate(
                        offset: Offset(
                          math.cos(t * 0.9 + i * math.pi / 2) * 92,
                          math.sin(t * 0.9 + i * math.pi / 2) * 92 * 0.55,
                        ),
                        child: Transform.rotate(
                          angle: math.sin(t * 2 + i) * 0.3,
                          child: PlayingCardView(card: _cards[i], width: 34),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.size == 2
                  ? strings.ludoLobbyFindingAnOpponent
                  : strings.ludoLobbyGatheringPlayers,
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
                    strings.ludoLobbyFree,
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
            QuietLobbyOffer(
              label: strings.ludoLobbyPlayWithBots,
              onPlay: widget.onPlayBots,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close_rounded),
              label: Text(strings.ludoLobbyCancel),
            ),
          ],
        ),
      ),
    );
  }
}
