import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/bots/bots.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/quiet_lobby_offer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/back_to_home.dart';
import '../../../../core/widgets/candy_mode_button.dart';
import '../../../../core/widgets/coin_balance_pill.dart';
import '../../../../core/widgets/entry_selector.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../coins/presentation/providers/coin_balance_provider.dart';
import '../../../friends/presentation/widgets/friends_popup.dart';
import '../../../checkers/domain/checkers_engine.dart';
import '../../../checkers/presentation/widgets/checkers_disc.dart';
import '../../../friends/presentation/widgets/invite_stake_sheet.dart';
import '../../../store/presentation/coin_shop.dart';
import '../../domain/chess_bot.dart';
import '../../domain/chess_types.dart';
import '../../domain/time_control.dart';
import '../controllers/chess_match_controller.dart';
import '../widgets/chess_piece_art.dart';
import '../widgets/chess_piece_styles.dart';
import '../widgets/time_control_style.dart';
import '../../../../core/layout/responsive.dart';

/// Pick a clock and an entry, then play someone new, challenge a friend,
/// or play offline. Chess and checkers share it ([game]).
class ChessLobbyScreen extends ConsumerStatefulWidget {
  const ChessLobbyScreen({super.key, this.game = GameKind.chess});

  /// [GameKind.chess] or [GameKind.checkers].
  final GameKind game;

  @override
  ConsumerState<ChessLobbyScreen> createState() => _ChessLobbyScreenState();
}

class _ChessLobbyScreenState extends ConsumerState<ChessLobbyScreen> {
  TimeControl _time = TimeControl.standard;
  int _entry = 0;
  bool _searching = false;
  DateTime? _queuedAt;
  StreamSubscription<List<Map<String, dynamic>>>? _matchesSub;

  bool get _checkers => widget.game == GameKind.checkers;
  String get _name => _checkers ? 'checkers' : 'chess';

  @override
  void initState() {
    super.initState();
    inviteGameHint.value = _name;
  }

  @override
  void dispose() {
    _matchesSub?.cancel();
    if (_searching) {
      ref.read(chessRepositoryProvider).leaveMatchmakingQueue();
    }
    super.dispose();
  }

  bool _canAfford() {
    final balance = ref.read(coinBalanceProvider).valueOrNull ?? 0;
    if (_entry <= balance) return true;
    showCoinShop(context, needed: _entry);
    return false;
  }

  Future<void> _playOnline() async {
    final myId = ref.read(currentUserProvider)?.id;
    if (myId == null || !_canAfford()) return;
    ref.read(gameAudioProvider).play(Sfx.tap);

    setState(() {
      _searching = true;
      _queuedAt = DateTime.now();
    });

    final repository = ref.read(chessRepositoryProvider);
    String? matchId;
    try {
      matchId = await repository.joinMatchmakingQueue(
        _entry,
        minutes: _time.minutes,
        increment: _time.increment,
        game: _name,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      showUtopiaToast(context, friendlyError(e), kind: ToastKind.error);
      return;
    }
    if (!mounted) return;
    if (matchId != null) {
      _goToMatch(matchId);
      return;
    }

    _matchesSub = repository.watchMyMatches(myId).listen((matches) {
      final queuedAt = _queuedAt;
      if (queuedAt == null) return;
      for (final match in matches) {
        if (match['status'] != 'active') continue;
        if ((match['game'] as String? ?? 'chess') != _name) continue;
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

  /// Nobody to play online right now: a free game against Chip on the same
  /// clock instead.
  Future<void> _playChipInstead() async {
    await _cancelSearch();
    if (!mounted) return;
    context.push(
      '/$_name/bot?opponent=${kChessChip.key}&level=${BotLevel.normal.name}'
      '&color=random&clock=${_time.minutes}&inc=${_time.increment}',
    );
  }

  void _playFriend() {
    if (ref.read(isAnonymousProvider)) {
      showUtopiaToast(
        context,
        'Save your account so friends can find you.',
        icon: Icons.person_add_alt_1_rounded,
      );
      context.push('/auth/link');
      return;
    }
    showFriendsPopup(context);
  }

  /// Offline against Chip or Robo (or, in checkers, someone next to you):
  /// pick who, how hard, and your side.
  Future<void> _openBot() async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final choice =
        await showModalBottomSheet<(String, BotLevel, String, TimeControl?)>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _BotSheet(checkers: _checkers),
        );
    if (choice == null || !mounted) return;
    final (opponent, level, color, clock) = choice;
    context.push(
      '/$_name/bot?opponent=$opponent&level=${level.name}&color=$color'
      '&clock=${clock?.minutes ?? 0}&inc=${clock?.increment ?? 0}',
    );
  }

  void _goToMatch(String matchId) {
    _matchesSub?.cancel();
    _matchesSub = null;
    setState(() => _searching = false);
    if (mounted) context.push('/$_name/$matchId');
  }

  Future<void> _cancelSearch() async {
    await ref.read(chessRepositoryProvider).leaveMatchmakingQueue();
    _matchesSub?.cancel();
    _matchesSub = null;
    if (mounted) setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const BackOrHomeButton(),
          title: Text(_checkers ? 'Checkers' : 'Chess'),
          actions: const [
            Padding(
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
                      time: _time,
                      entry: _entry,
                      checkers: _checkers,
                      onCancel: _cancelSearch,
                      onPlayChip: _playChipInstead,
                    )
                  : ListView(
                      key: const ValueKey('setup'),
                      padding: context.readablePadding(
                        top: AppSpacing.xs,
                        bottom: AppSpacing.xl,
                      ),
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: GameSceneArt(game: widget.game, height: 150),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionLabel(
                          icon: Icons.timer_rounded,
                          text: 'Clock',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TimeControlPicker(
                          value: _time,
                          onChanged: (t) {
                            ref.read(gameAudioProvider).play(Sfx.tap);
                            setState(() => _time = t);
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionLabel(
                          icon: Icons.toll_rounded,
                          text: 'Entry',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        EntrySelector(
                          options: kChessEntries,
                          value: _entry,
                          players: 2,
                          onChanged: (v) {
                            ref.read(gameAudioProvider).play(Sfx.tap);
                            setState(() => _entry = v);
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        CandyModeButton(
                          icon: Icons.public_rounded,
                          label: 'Play online',
                          primary: true,
                          subtitle: 'Get matched with a player now',
                          colors: const [Color(0xFF6BF0B0), Color(0xFF1FB877)],
                          onTap: _playOnline,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CandyModeButton(
                          icon: Icons.group_rounded,
                          label: 'Play a friend',
                          subtitle: 'Send a challenge to someone you know',
                          colors: const [Color(0xFFB79BFF), Color(0xFF7B5CFF)],
                          onTap: _playFriend,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CandyModeButton(
                          icon: Icons.smart_toy_rounded,
                          label: 'Play offline',
                          subtitle: 'Chip, Robo or a friend on this phone',
                          colors: const [Color(0xFF8FD8FF), Color(0xFF2E8FE0)],
                          onTap: _openBot,
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

/// Who to play, how hard, and which side.
class _BotSheet extends StatefulWidget {
  const _BotSheet({required this.checkers});

  /// Checkers: sides are dark and light, and two people can share a phone.
  final bool checkers;

  @override
  State<_BotSheet> createState() => _BotSheetState();
}

class _BotSheetState extends State<_BotSheet> {
  String _opponent = kChessChip.key;
  BotLevel _level = BotLevel.normal;
  String _color = 'random';

  /// The clock, or null for none.
  TimeControl? _clock = const TimeControl(5, 0);
  TimeControl _lastClock = const TimeControl(5, 0);

  @override
  Widget build(BuildContext context) {
    Widget choice<T>(
      T value,
      T current,
      String label,
      ValueChanged<T> pick, {
      Widget? icon,
    }) {
      final on = value == current;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => pick(value)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: on
                    ? [
                        Color.lerp(AppColors.accent, Colors.white, 0.25)!,
                        AppColors.accent,
                      ]
                    : [AppColors.surfaceElevated, AppColors.surface],
              ),
              border: Border.all(
                color: on
                    ? AppColors.goldBorderBright
                    : AppColors.glowRing.withValues(alpha: 0.35),
                width: on ? 2 : 1.2,
              ),
            ),
            child: Column(
              children: [
                ?icon,
                if (icon != null) const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w800,
                    color: on ? AppColors.onAccent : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: sheetRadius(30),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.background],
        ),
        border: sheetBorder(AppColors.goldBorder),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
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
                Text(
                  'Play offline',
                  style: AppTextStyles.display(fontSize: 22),
                ),
                const SizedBox(height: AppSpacing.md),
                const _SectionLabel(
                  icon: Icons.smart_toy_rounded,
                  text: 'Opponent',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    choice(
                      kChessChip.key,
                      _opponent,
                      'Chip',
                      (v) => _opponent = v,
                      icon: const CoinBuddy(mood: BuddyMood.happy, size: 54),
                    ),
                    const SizedBox(width: 8),
                    choice(
                      kChessRobot.key,
                      _opponent,
                      'Robo',
                      (v) => _opponent = v,
                      icon: const SizedBox(
                        height: 54,
                        child: Icon(
                          Icons.smart_toy_rounded,
                          size: 40,
                          color: Color(0xFF7DE8FF),
                        ),
                      ),
                    ),
                    ...[
                      const SizedBox(width: 8),
                      choice(
                        'local',
                        _opponent,
                        'A friend',
                        (v) => _opponent = v,
                        icon: SizedBox(
                          height: 54,
                          child: Icon(
                            Icons.people_alt_rounded,
                            size: 40,
                            color: AppColors.coinGold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_opponent == 'local') ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Two players on this phone, taking turns.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                ],
                if (_opponent != 'local') ...[
                  const SizedBox(height: AppSpacing.md),
                  const _SectionLabel(icon: Icons.speed_rounded, text: 'Level'),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      choice(BotLevel.easy, _level, 'Easy', (v) => _level = v),
                      const SizedBox(width: 8),
                      choice(
                        BotLevel.normal,
                        _level,
                        'Normal',
                        (v) => _level = v,
                      ),
                      const SizedBox(width: 8),
                      choice(BotLevel.hard, _level, 'Hard', (v) => _level = v),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SectionLabel(
                    icon: Icons.contrast_rounded,
                    text: 'You play',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      choice(
                        'white',
                        _color,
                        widget.checkers ? 'Dark' : 'White',
                        (v) => _color = v,
                      ),
                      const SizedBox(width: 8),
                      choice('random', _color, 'Random', (v) => _color = v),
                      const SizedBox(width: 8),
                      choice(
                        'black',
                        _color,
                        widget.checkers ? 'Light' : 'Black',
                        (v) => _color = v,
                      ),
                    ],
                  ),
                  if (widget.checkers) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Dark moves first.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.md),
                const _SectionLabel(icon: Icons.timer_rounded, text: 'Clock'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    choice(false, _clock != null, 'No clock', (_) {
                      _clock = null;
                    }),
                    const SizedBox(width: 8),
                    choice(true, _clock != null, 'Clock', (_) {
                      _clock = _lastClock;
                    }),
                  ],
                ),
                if (_clock != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TimeControlPicker(
                    value: _clock!,
                    onChanged: (t) => setState(() {
                      _clock = t;
                      _lastClock = t;
                    }),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Start game',
                  color: const Color(0xFF2E8FE0),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((_opponent, _level, _color, _clock)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accentSecondary),
        const SizedBox(width: 8),
        Text(text, style: AppTextStyles.display(fontSize: 18)),
      ],
    );
  }
}

/// Looking for an opponent: chess pieces orbit a spinning board while the
/// seconds tick by.
class _SearchingView extends StatefulWidget {
  const _SearchingView({
    super.key,
    required this.time,
    required this.entry,
    required this.checkers,
    required this.onCancel,
    required this.onPlayChip,
  });

  final TimeControl time;
  final int entry;
  final bool checkers;
  final VoidCallback onCancel;
  final VoidCallback onPlayChip;

  @override
  State<_SearchingView> createState() => _SearchingViewState();
}

class _SearchingViewState extends State<_SearchingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  final _started = DateTime.now();

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speed = widget.time.speed;
    const pieces = [
      (PieceType.knight, PieceColor.white),
      (PieceType.queen, PieceColor.black),
      (PieceType.rook, PieceColor.white),
      (PieceType.bishop, PieceColor.black),
      (PieceType.king, PieceColor.white),
      (PieceType.pawn, PieceColor.black),
    ];
    final style = ChessPieceStyle.byId('classic');

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 240,
              child: AnimatedBuilder(
                animation: _orbit,
                builder: (context, _) {
                  final t = _orbit.value * 2 * math.pi;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      const UtopiaLoader(size: 96),
                      for (final (i, (type, color)) in pieces.indexed)
                        Transform.translate(
                          offset: Offset(
                            math.cos(t + i * math.pi / 3) * 96,
                            math.sin(t + i * math.pi / 3) * 96 * 0.55,
                          ),
                          child: Transform.scale(
                            scale:
                                0.75 +
                                0.25 * (math.sin(t + i * math.pi / 3) + 1) / 2,
                            child: widget.checkers
                                ? CustomPaint(
                                    size: const Size.square(40),
                                    painter: _OrbitDisc(
                                      side: i.isEven
                                          ? CheckersSide.dark
                                          : CheckersSide.light,
                                      king: i % 3 == 0,
                                    ),
                                  )
                                : ChessPieceArt(
                                    type: type,
                                    finish: style.of(color),
                                    size: 40,
                                  ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Finding an opponent',
              style: AppTextStyles.display(fontSize: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(speedIcon(speed), size: 18, color: speedColor(speed)),
                const SizedBox(width: 4),
                Text(
                  widget.time.label,
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
            StreamBuilder<int>(
              stream: Stream.periodic(
                const Duration(seconds: 1),
                (_) => DateTime.now().difference(_started).inSeconds,
              ),
              builder: (context, snap) {
                final s = snap.data ?? 0;
                return Text(
                  '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                );
              },
            ),
            QuietLobbyOffer(label: 'Play Chip', onPlay: widget.onPlayChip),
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

class _OrbitDisc extends CustomPainter {
  _OrbitDisc({required this.side, required this.king});

  final CheckersSide side;
  final bool king;

  @override
  void paint(Canvas canvas, Size size) {
    paintCheckersDisc(
      canvas,
      size.center(Offset.zero),
      size.width * 0.36,
      finish: checkersFinish('classic', side),
      king: king,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitDisc old) => false;
}
