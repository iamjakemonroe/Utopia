import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../doodle_studio/domain/art_doc.dart';
import '../domain/chip_doodle.dart';
import 'doodle_ink.dart';

enum ChipDoodlePhase {
  /// Waiting for Chip's next doodle.
  loading,

  /// Chip's drawing; the player's guessing.
  drawing,

  /// The round's over: guessed, or time ran out.
  reveal,

  /// All the rounds are done.
  over,

  /// Chip couldn't deal a round ([ChipDoodleGame.error] says why).
  error,
}

/// A guess the player typed, and what it was.
class ChipGuess {
  const ChipGuess(this.text, this.verdict);

  final String text;
  final GuessVerdict verdict;
}

/// A game of "Chip draws, you guess": [rounds] doodles, [seconds] each.
/// Chip's pen draws onto [ink] as [tick] moves time on; the next doodle is
/// fetched while the player guesses this one.
class ChipDoodleGame extends ChangeNotifier {
  ChipDoodleGame(
    this._fetch, {
    this.rounds = kChipRounds,
    this.seconds = kChipRoundSeconds,
    math.Random? random,
  }) : _random = random ?? math.Random();

  final Future<ChipDoodleRound> Function() _fetch;
  final int rounds;
  final int seconds;
  final math.Random _random;

  final ink = DoodleInk();

  /// Chip's pen: black ink, a medium nib.
  static const penColor = 0xFF1F1E1B;
  static const penSize = 12.0;

  ChipDoodlePhase phase = ChipDoodlePhase.loading;
  String? error;

  /// 1 to [rounds].
  int round = 1;
  int score = 0;
  int guessedCount = 0;

  ChipDoodleRound? current;
  ChipPen? _pen;

  /// Seconds into this round.
  double elapsed = 0;
  final Set<int> hints = {};

  /// Newest first.
  final List<ChipGuess> guesses = [];

  /// The player got this round's word.
  bool guessed = false;

  /// Points from this round's guess.
  int lastPoints = 0;

  Future<ChipDoodleRound>? _next;
  bool _disposed = false;

  double get left => math.max(0, seconds - elapsed);
  bool get lastRound => round >= rounds;

  /// The word's blanks, with any hints.
  String? get mask {
    final word = current?.word;
    return word == null ? null : maskedWord(word, hints);
  }

  Future<void> start() => _load();

  Future<void> retry() => _load();

  Future<void> _load() async {
    phase = ChipDoodlePhase.loading;
    error = null;
    _notify();
    try {
      final pending = _next ?? _fetch();
      _next = null;
      final doodle = await pending;
      if (_disposed) return;
      _begin(doodle);
    } catch (e) {
      if (_disposed) return;
      phase = ChipDoodlePhase.error;
      error = e.toString();
      _notify();
    }
  }

  void _begin(ChipDoodleRound doodle) {
    current = doodle;
    _pen = ChipPen(penLines(doodle.strokes));
    elapsed = 0;
    hints.clear();
    guesses.clear();
    guessed = false;
    lastPoints = 0;
    ink.reset(turn: round, epoch: 0);
    phase = ChipDoodlePhase.drawing;
    _notify();
    if (!lastRound) {
      // Fetched now, so the next round's ready the moment this one ends.
      // (Its error, if any, surfaces when it's awaited.)
      _next = _fetch()..ignore();
    }
  }

  /// Moves the round on by [dt] seconds: Chip's pen, hints, the clock.
  void tick(double dt) {
    if (phase != ChipDoodlePhase.drawing) return;
    elapsed += dt;
    _pen?.advance(dt, onPoints: _points, onLine: _line);
    final word = current!.word;
    final due = hintsFor(word) == 2
        ? (elapsed >= seconds * 0.75
              ? 2
              : elapsed >= seconds * 0.5
              ? 1
              : 0)
        : (elapsed >= seconds * 0.6 ? 1 : 0);
    if (hints.length < due) {
      final at = nextHint(word, hints, _random);
      if (at != null) hints.add(at);
    }
    if (elapsed >= seconds) {
      _reveal();
      return;
    }
    _notify();
  }

  /// The player's guess. Right ends the round with points for speed.
  GuessVerdict? guess(String text) {
    if (phase != ChipDoodlePhase.drawing || text.trim().isEmpty) return null;
    final verdict = judgeGuess(text, current!.word);
    guesses.insert(0, ChipGuess(text.trim(), verdict));
    if (verdict == GuessVerdict.right) {
      guessed = true;
      lastPoints = guessPoints(left, seconds.toDouble());
      score += lastPoints;
      guessedCount++;
      _reveal();
    } else {
      _notify();
    }
    return verdict;
  }

  /// The player gives up on this one.
  void skip() {
    if (phase == ChipDoodlePhase.drawing) _reveal();
  }

  void _reveal() {
    // The whole doodle, so they see what it was.
    _pen?.finish(onLine: _line);
    phase = ChipDoodlePhase.reveal;
    _notify();
  }

  /// On to the next doodle, or the end of the game.
  Future<void> next() async {
    if (phase != ChipDoodlePhase.reveal) return;
    if (lastRound) {
      phase = ChipDoodlePhase.over;
      _notify();
      return;
    }
    round++;
    await _load();
  }

  /// A fresh game, from round one.
  Future<void> again() {
    round = 1;
    score = 0;
    guessedCount = 0;
    return _load();
  }

  static List<double> _flat(List<Offset> points) => [
    for (final p in points) ...[p.dx, p.dy, penSize],
  ];

  void _points(int line, int from, List<Offset> points) => ink.receivePoints(
    sid: line,
    tool: ArtTool.pen,
    color: penColor,
    size: penSize,
    from: from,
    values: _flat(points),
  );

  void _line(int line, List<Offset> points) => ink.receiveDone(
    line,
    StrokeOp(
      tool: ArtTool.pen,
      color: penColor,
      size: penSize,
      points: _flat(points),
    ),
  );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ink.dispose();
    super.dispose();
  }
}
