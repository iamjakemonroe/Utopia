import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../events/presentation/events_controller.dart';
import '../data/chip_doodle_repository.dart';
import '../domain/chip_doodle.dart';
import 'chip_doodle_game.dart';
import 'widgets/doodle_canvas_view.dart';
import 'widgets/doodle_header.dart';

/// "Chip draws, you guess": Chip doodles a word stroke by stroke and the
/// player races to guess it, five times. Faster guesses score more; letters
/// show up as hints as time runs down.
class ChipDoodleScreen extends ConsumerStatefulWidget {
  const ChipDoodleScreen({super.key});

  @override
  ConsumerState<ChipDoodleScreen> createState() => _ChipDoodleScreenState();
}

class _ChipDoodleScreenState extends ConsumerState<ChipDoodleScreen>
    with SingleTickerProviderStateMixin {
  static const _bestKey = 'chip_doodle.best';

  late final ChipDoodleGame _game = ChipDoodleGame(
    ref.read(chipDoodleRepositoryProvider).round,
  );
  late final Ticker _ticker = createTicker(_onFrame);
  final _input = TextEditingController();
  final _focus = FocusNode();
  Duration _last = Duration.zero;
  DateTime? _endsAt;
  ChipDoodlePhase _phase = ChipDoodlePhase.loading;
  int _best = 0;
  bool _newBest = false;

  @override
  void initState() {
    super.initState();
    _best = ref.read(sharedPreferencesProvider).getInt(_bestKey) ?? 0;
    _game.addListener(_changed);
    _game.start();
  }

  @override
  void dispose() {
    _game.removeListener(_changed);
    _ticker.dispose();
    _game.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  GameAudio get _audio => ref.read(gameAudioProvider);

  void _changed() {
    final phase = _game.phase;
    if (phase != _phase) {
      _phase = phase;
      switch (phase) {
        case ChipDoodlePhase.drawing:
          _endsAt = DateTime.now().add(Duration(seconds: _game.seconds));
          _last = Duration.zero;
          if (!_ticker.isActive) _ticker.start();
          _audio.play(Sfx.drawer);
          _focus.requestFocus();
        case ChipDoodlePhase.reveal:
          _ticker.stop();
          _endsAt = null;
          _input.clear();
          if (!_game.guessed) _audio.play(Sfx.drop);
        case ChipDoodlePhase.over:
          _finished();
        case ChipDoodlePhase.loading || ChipDoodlePhase.error:
          _ticker.stop();
          _endsAt = null;
      }
    }
    if (mounted) setState(() {});
  }

  void _onFrame(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _game.tick(dt.clamp(0.0, 0.1));
  }

  void _send() {
    final text = _input.text;
    final verdict = _game.guess(text);
    if (verdict == null) return;
    switch (verdict) {
      case GuessVerdict.right:
        HapticFeedback.mediumImpact();
        _audio.play(Sfx.win);
      case GuessVerdict.close:
        HapticFeedback.selectionClick();
        _audio.play(Sfx.reaction);
        _input.clear();
      case GuessVerdict.wrong:
        _audio.play(Sfx.tap);
        _input.clear();
    }
    _focus.requestFocus();
  }

  void _finished() {
    ref.read(eventsProvider.notifier).gameFinished('doodle');
    _newBest = _game.score > _best;
    if (_newBest) {
      _best = _game.score;
      ref.read(sharedPreferencesProvider).setInt(_bestKey, _best);
      _audio.play(Sfx.purchase);
    }
  }

  /// What Chip says over the canvas.
  (String, BuddyMood) get _chip {
    final g = _game;
    switch (g.phase) {
      case ChipDoodlePhase.loading:
        return ('Hmm, what shall I draw?', BuddyMood.thinking);
      case ChipDoodlePhase.error:
        return ('Oops, my pencil broke!', BuddyMood.sad);
      case ChipDoodlePhase.reveal:
        return g.guessed
            ? ('You got it! +${g.lastPoints}', BuddyMood.excited)
            : ('It was ${_article(g.current!.word)}!', BuddyMood.happy);
      case ChipDoodlePhase.over:
        return ('What a game!', BuddyMood.excited);
      case ChipDoodlePhase.drawing:
        final last = g.guesses.firstOrNull;
        if (last?.verdict == GuessVerdict.close) {
          return ('So close! Keep going.', BuddyMood.excited);
        }
        if (g.left <= 10) {
          return ('Quick, time is nearly up!', BuddyMood.thinking);
        }
        if (g.hints.isNotEmpty) {
          return ("Here's a little hint!", BuddyMood.happy);
        }
        if (last != null) return ('Nope! Look again.', BuddyMood.happy);
        return g.elapsed < 6
            ? ('Watch closely...', BuddyMood.happy)
            : ('What do you think it is?', BuddyMood.thinking);
    }
  }

  static String _article(String word) => RegExp('^[aeiou]').hasMatch(word)
      ? 'an ${word.toUpperCase()}'
      : 'a ${word.toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final (line, mood) = _chip;
    final drawing = g.phase == ChipDoodlePhase.drawing;
    final reveal = g.phase == ChipDoodlePhase.reveal;

    return MusicTrackScope(
      track: MusicTrack.game,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Chip draws'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: _ScorePill(score: g.score),
                ),
              ],
            ),
            body: AppBackground(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CoinBuddy(mood: mood, size: 54),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _Says(line)),
                          const SizedBox(width: AppSpacing.sm),
                          DoodleTimer(
                            endsAt: _endsAt,
                            total: g.seconds,
                            offset: Duration.zero,
                            onSecond: (s) {
                              if (s <= 5) _audio.play(Sfx.tick);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _RoundDots(round: g.round, rounds: g.rounds),
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        height: 44,
                        child: Center(
                          child: DoodleWordBar(
                            mask: g.mask,
                            word: g.guessed ? g.current?.word : null,
                            revealed: reveal && !g.guessed
                                ? g.current?.word
                                : null,
                            guessed: g.guessed,
                            drawing: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Square, under the word, however tall the screen.
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: DoodleCanvasView(
                              ink: g.ink,
                              canDraw: false,
                              onStart: (_) {},
                              onMove: (_) {},
                              onEnd: () {},
                              overlay: _overlay(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _Guesses(guesses: g.guesses),
                      const SizedBox(height: AppSpacing.xs),
                      _GuessField(
                        controller: _input,
                        focus: _focus,
                        enabled: drawing,
                        onSend: _send,
                        onSkip: g.skip,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (reveal && g.guessed)
            const Positioned.fill(
              child: IgnorePointer(child: ConfettiBurst(pieces: 60)),
            ),
        ],
      ),
    );
  }

  Widget? _overlay() {
    final g = _game;
    switch (g.phase) {
      case ChipDoodlePhase.drawing:
        return null;
      case ChipDoodlePhase.loading:
        return const _Veil(child: UtopiaLoader(size: 56));
      case ChipDoodlePhase.error:
        return _Veil(
          child: _Card(
            children: [
              Text(
                g.error ?? "Chip couldn't draw just now.",
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(label: 'Try again', onPressed: g.retry),
            ],
          ),
        );
      case ChipDoodlePhase.reveal:
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: PrimaryButton(
              label: g.lastRound ? 'See your score' : 'Next doodle',
              color: AppColors.success,
              onPressed: () {
                _audio.play(Sfx.tap);
                g.next();
              },
            ),
          ),
        );
      case ChipDoodlePhase.over:
        return _Veil(
          child: _Card(
            children: [
              Text(
                _newBest ? 'New best score!' : 'Great guessing!',
                style: AppTextStyles.display(fontSize: 24),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${g.score}',
                style: AppTextStyles.display(
                  fontSize: 46,
                  color: AppColors.coinGoldBright,
                ),
              ),
              Text(
                'You guessed ${g.guessedCount} of ${g.rounds}',
                style: AppTextStyles.body(fontWeight: FontWeight.w700),
              ),
              if (!_newBest && _best > 0)
                Text(
                  'Your best: $_best',
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Play again',
                color: AppColors.success,
                onPressed: () {
                  _audio.play(Sfx.tap);
                  _newBest = false;
                  g.again();
                },
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
    }
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 18, color: AppColors.coinGold),
          const SizedBox(width: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(end: score.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              '${v.round()}',
              style: AppTextStyles.body(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip's line, in a small bubble.
class _Says extends StatelessWidget {
  const _Says(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: AppColors.glowRing.withValues(alpha: 0.3)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          text,
          key: ValueKey(text),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Which doodle of the game this is.
class _RoundDots extends StatelessWidget {
  const _RoundDots({required this.round, required this.rounds});

  final int round;
  final int rounds;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= rounds; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == round ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i <= round
                  ? AppColors.coinGold
                  : Colors.white.withValues(alpha: 0.25),
            ),
          ),
      ],
    );
  }
}

/// The last few guesses: wrong ones crossed out, close ones flagged.
class _Guesses extends StatelessWidget {
  const _Guesses({required this.guesses});

  final List<ChipGuess> guesses;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final guess in guesses.take(6))
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: switch (guess.verdict) {
                  GuessVerdict.right => const Color(0xFF1E7A4C),
                  GuessVerdict.close => const Color(0xFF8A5A00),
                  GuessVerdict.wrong => Colors.black.withValues(alpha: 0.4),
                },
                border: Border.all(
                  color: switch (guess.verdict) {
                    GuessVerdict.right => AppColors.success,
                    GuessVerdict.close => AppColors.coinGold,
                    GuessVerdict.wrong => Colors.white24,
                  },
                ),
              ),
              child: Text(
                guess.verdict == GuessVerdict.close
                    ? '${guess.text} \u00b7 so close!'
                    : guess.text,
                style:
                    AppTextStyles.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: guess.verdict == GuessVerdict.wrong
                          ? Colors.white70
                          : Colors.white,
                    ).copyWith(
                      decoration: guess.verdict == GuessVerdict.wrong
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: Colors.white70,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuessField extends StatelessWidget {
  const _GuessField({
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.onSend,
    required this.onSkip,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            enabled: enabled,
            textInputAction: TextInputAction.send,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            maxLength: 40,
            onSubmitted: (_) => onSend(),
            style: AppTextStyles.body(fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: enabled ? 'Type your guess' : 'Get ready...',
              counterText: '',
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.28),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          tooltip: 'Guess',
          onPressed: enabled ? onSend : null,
          icon: const Icon(Icons.send_rounded),
        ),
        IconButton(
          tooltip: 'Skip this one',
          onPressed: enabled ? onSkip : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}

/// A soft cover over the canvas.
class _Veil extends StatelessWidget {
  const _Veil({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(child: child),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: PopCard(
        borderRadius: 26,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
