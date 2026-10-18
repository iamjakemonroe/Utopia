import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/back_to_home.dart';
import '../../../core/widgets/candy_mode_button.dart';
import '../../../core/widgets/coin_balance_pill.dart';
import '../../../core/widgets/game_card_art.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../ludo/presentation/screens/ludo_lobby_screen.dart' show CodeTiles;
import '../data/doodle_game_repository.dart';

/// Server errors in words a player can use.
String doodleErrorText(Object e) {
  final text = e.toString();
  if (text.contains('no game with that code')) {
    return "We couldn't find that game. Check the code.";
  }
  if (text.contains('game is full')) return 'That game is full.';
  if (text.contains('has ended')) return 'That game has ended.';
  return friendlyError(e);
}

/// Guess My Doodle's front door: jump into a public game, or make a
/// private one for friends (or join theirs with a code).
class GuessDoodleLobbyScreen extends ConsumerWidget {
  const GuessDoodleLobbyScreen({super.key});

  Future<void> _playOnline(BuildContext context, WidgetRef ref) async {
    ref.read(gameAudioProvider).play(Sfx.tap);
    try {
      final id = await runWithUtopiaLoader(
        context,
        () => ref.read(doodleGameRepositoryProvider).quickPlay(),
        label: 'Finding a game',
      );
      ref.read(gameAudioProvider).play(Sfx.reaction);
      if (context.mounted) context.push('/doodle-game/$id');
    } catch (e) {
      if (context.mounted) {
        showUtopiaToast(context, doodleErrorText(e), kind: ToastKind.error);
      }
    }
  }

  Future<void> _openFriends(BuildContext context, WidgetRef ref) async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final action = await showModalBottomSheet<_FriendsAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FriendsSheet(),
    );
    if (action == null || !context.mounted) return;
    final repo = ref.read(doodleGameRepositoryProvider);
    try {
      final id = await runWithUtopiaLoader(context, () async {
        switch (action) {
          case _Create(:final rounds, :final seconds):
            return (await repo.create(rounds: rounds, drawSeconds: seconds)).$1;
          case _Join(:final code):
            return repo.join(code);
        }
      });
      ref.read(gameAudioProvider).play(Sfx.reaction);
      if (context.mounted) context.push('/doodle-game/$id');
    } catch (e) {
      if (context.mounted) {
        showUtopiaToast(context, doodleErrorText(e), kind: ToastKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const BackOrHomeButton(),
          title: const Text('Guess My Doodle'),
          actions: [
            IconButton(
              tooltip: 'How to play',
              icon: const Icon(Icons.menu_book_rounded),
              onPressed: () => showDoodleRules(context),
            ),
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: CoinBalancePill(),
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
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(26)),
                  child: GameSceneArt(game: GameKind.doodle, height: 190),
                ),
                const SizedBox(height: AppSpacing.lg),
                CandyModeButton(
                  icon: Icons.public_rounded,
                  label: 'Play online',
                  primary: true,
                  subtitle: 'Jump into a game with players anywhere',
                  colors: const [Color(0xFF6BF0B0), Color(0xFF1FB877)],
                  onTap: () => _playOnline(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                CandyModeButton(
                  icon: Icons.group_rounded,
                  label: 'Play with friends',
                  subtitle: 'Make a game or join one with a code',
                  colors: const [Color(0xFFB79BFF), Color(0xFF7B5CFF)],
                  onTap: () => _openFriends(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                CandyModeButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Chip draws, you guess',
                  subtitle: 'Guess his doodles on your own',
                  colors: const [Color(0xFFFFE082), Color(0xFFFFA726)],
                  onTap: () {
                    ref.read(gameAudioProvider).play(Sfx.tap);
                    context.push('/guess-my-doodle/chip');
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                const _FactsRow(),
              ],
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
        fact(Icons.groups_rounded, AppColors.sky, '1 to 8\nplayers'),
        fact(Icons.brush_rounded, const Color(0xFFFF5C9C), 'Draw &\nguess'),
        fact(
          Icons.bolt_rounded,
          AppColors.coinGold,
          'Faster guess,\nmore points',
        ),
        fact(Icons.vpn_key_rounded, AppColors.mint, 'Private\ngames'),
      ],
    );
  }
}

sealed class _FriendsAction {
  const _FriendsAction();
}

class _Create extends _FriendsAction {
  const _Create(this.rounds, this.seconds);

  final int rounds;
  final int seconds;
}

class _Join extends _FriendsAction {
  const _Join(this.code);

  final String code;
}

class _FriendsSheet extends StatefulWidget {
  const _FriendsSheet();

  @override
  State<_FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<_FriendsSheet> {
  bool _joining = false;
  int _rounds = 3;
  int _seconds = 80;
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
      child: Container(
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
                    const GlossyBadge(
                      icon: Icons.group_rounded,
                      color: Color(0xFF7B5CFF),
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Play with friends',
                      style: AppTextStyles.display(fontSize: 22),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Tabs(
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
                                          (_, v) => v.copyWith(
                                            text: v.text.toUpperCase(),
                                          ),
                                        ),
                                      ],
                                      onChanged: (_) => setState(() {}),
                                      onSubmitted: (v) {
                                        if (v.length == 6) {
                                          Navigator.of(context).pop(_Join(v));
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
                              label: 'Join game',
                              onPressed: code.length == 6
                                  ? () => Navigator.of(context).pop(_Join(code))
                                  : null,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Choice(
                              label: 'Rounds',
                              options: const [2, 3, 4, 5],
                              value: _rounds,
                              text: (n) => '$n',
                              onChanged: (n) => setState(() => _rounds = n),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _Choice(
                              label: 'Time to draw',
                              options: const [60, 80, 100, 120],
                              value: _seconds,
                              text: (n) => '${n}s',
                              onChanged: (n) => setState(() => _seconds = n),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PrimaryButton(
                              label: 'Create game',
                              onPressed: () => Navigator.of(
                                context,
                              ).pop(_Create(_rounds, _seconds)),
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

class _Tabs extends StatelessWidget {
  const _Tabs({required this.joining, required this.onChanged});

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

/// A row of options to pick one from.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.options,
    required this.value,
    required this.text,
    required this.onChanged,
  });

  final String label;
  final List<int> options;
  final int value;
  final String Function(int) text;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final o in options)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(o);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: o == value
                            ? AppColors.accent
                            : Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: o == value
                              ? AppColors.goldBorderBright
                              : Colors.white.withValues(alpha: 0.12),
                          width: o == value ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        text(o),
                        style: AppTextStyles.display(
                          fontSize: 17,
                          color: o == value
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// How Guess My Doodle works, in a few steps.
Future<void> showDoodleRules(BuildContext context) {
  Widget step(IconData icon, Color color, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlossyBadge(icon: icon, color: color, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.display(fontSize: 17)),
              const SizedBox(height: 2),
              Text(
                text,
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
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
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('How to play', style: AppTextStyles.display(fontSize: 24)),
              const SizedBox(height: AppSpacing.lg),
              step(
                Icons.brush_rounded,
                const Color(0xFFFF5C9C),
                'Take turns drawing',
                'One player picks a word from three and draws it. No letters '
                    'or numbers in the drawing.',
              ),
              step(
                Icons.chat_bubble_rounded,
                AppColors.mint,
                'Guess in the chat',
                'Everyone else types guesses. A right guess is never shown to '
                    'the others, and "so close" tells only you when you nearly '
                    'have it.',
              ),
              step(
                Icons.bolt_rounded,
                AppColors.coinGold,
                'Be quick',
                'The sooner you guess, the more points you get, with a bonus '
                    'for the first. The drawer scores for everyone who gets it.',
              ),
              step(
                Icons.lightbulb_rounded,
                AppColors.sky,
                'Hints',
                'Letters of the word appear as the clock runs down.',
              ),
              step(
                Icons.emoji_events_rounded,
                const Color(0xFFFFC94D),
                'Win',
                'Everyone draws once each round. The most points after the '
                    'last round wins.',
              ),
              PrimaryButton(
                label: 'Got it',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
