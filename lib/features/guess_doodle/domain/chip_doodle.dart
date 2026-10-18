import 'dart:math' as math;
import 'dart:ui';

import '../../doodle_studio/domain/svg_path.dart';

/// "Chip draws, you guess": Guess My Doodle on your own. Chip draws a word
/// stroke by stroke, as if by hand, and the player races to guess it.

/// Doodles in a game.
const kChipRounds = 5;

/// Seconds to guess each one.
const kChipRoundSeconds = 60;

/// One of Chip's doodles: the word, and its pen lines as SVG path data on
/// the 1000 x 1000 page, in the order he draws them.
class ChipDoodleRound {
  const ChipDoodleRound({required this.word, required this.strokes});

  static ChipDoodleRound? fromJson(Object? json) {
    if (json is! Map) return null;
    final word = json['word'];
    final strokes = json['strokes'];
    if (word is! String || word.isEmpty || strokes is! List) return null;
    return ChipDoodleRound(
      word: word,
      strokes: [for (final s in strokes) ?(s is String ? s : null)],
    );
  }

  final String word;
  final List<String> strokes;
}

/// The pen lines in [paths] as points along them, every [step] page units,
/// in drawing order. A path in several pieces is several lines.
List<List<Offset>> penLines(List<String> paths, {double step = 6}) {
  final lines = <List<Offset>>[];
  for (final d in paths) {
    final path = parseSvgPath(d);
    if (path == null) continue;
    for (final metric in path.computeMetrics()) {
      if (metric.length < 1) continue;
      final points = <Offset>[
        for (var at = 0.0; at < metric.length; at += step)
          metric.getTangentForOffset(at)!.position,
        metric.getTangentForOffset(metric.length)!.position,
      ];
      lines.add(points);
    }
  }
  return lines;
}

/// Chip's pen, drawing [lines] by hand: [advance] moves it on, at [speed]
/// page units a second, with a short pause between lines (and a breath
/// before the first).
class ChipPen {
  ChipPen(this.lines, {this.speed = 750, this.step = 6, this.pause = 0.28});

  final List<List<Offset>> lines;
  final double speed;

  /// The spacing of the points in [lines].
  final double step;
  final double pause;

  int _line = 0;
  double _progress = 0;
  int _sent = 0;
  double _wait = 0.5;

  bool get done => _line >= lines.length;

  /// Moves the pen on by [dt] seconds. [onPoints] gets each line's new
  /// points (from index [from]); [onLine] each line as it's finished.
  void advance(
    double dt, {
    required void Function(int line, int from, List<Offset> points) onPoints,
    required void Function(int line, List<Offset> points) onLine,
  }) {
    final perSecond = speed / step;
    var budget = dt;
    while (budget > 1e-9 && !done) {
      if (_wait > 0) {
        final w = math.min(_wait, budget);
        _wait -= w;
        budget -= w;
        continue;
      }
      final points = lines[_line];
      final take = math.min(points.length - _progress, budget * perSecond);
      _progress += take;
      budget -= take / perSecond;
      final upTo = _progress >= points.length - 1e-6
          ? points.length
          : _progress.floor();
      if (upTo > _sent) {
        onPoints(_line, _sent, points.sublist(_sent, upTo));
        _sent = upTo;
      }
      if (_sent >= points.length) _nextLine(onLine);
    }
  }

  /// Puts down everything left at once (the round's over).
  void finish({required void Function(int line, List<Offset> points) onLine}) {
    while (!done) {
      _nextLine(onLine);
    }
  }

  void _nextLine(void Function(int line, List<Offset> points) onLine) {
    onLine(_line, lines[_line]);
    _line++;
    _progress = 0;
    _sent = 0;
    _wait = pause;
  }
}

/// What a guess was.
enum GuessVerdict { right, close, wrong }

/// Lowercase letters and digits, single spaces between words (as the
/// online game reads guesses).
String normalizeGuess(String text) =>
    text.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();

/// Right when it's the word (spaced or not, or said in a sentence: "it's a
/// door"); close when it's a letter off (two, for words of 8 or more).
/// The same rules as online.
GuessVerdict judgeGuess(String guess, String word) {
  final g = normalizeGuess(guess);
  final w = normalizeGuess(word);
  if (g.isEmpty || w.isEmpty) return GuessVerdict.wrong;
  final gs = g.replaceAll(' ', '');
  final ws = w.replaceAll(' ', '');
  if (g == w || gs == ws || ' $g '.contains(' $w ')) return GuessVerdict.right;
  final distance = math.min(editDistance(g, w), editDistance(gs, ws));
  if (w.length >= 4 && distance <= (w.length >= 8 ? 2 : 1)) {
    return GuessVerdict.close;
  }
  return GuessVerdict.wrong;
}

/// Letters to add, remove or change to turn [a] into [b].
int editDistance(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = <int>[i];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur.add(
        math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Points for a right guess with [left] of [total] seconds to go: 50, and
/// up to 450 more for speed, in fives (as online).
int guessPoints(double left, double total) =>
    50 + ((450 * (left / total).clamp(0.0, 1.0)) / 5).round() * 5;

bool _isLetter(String ch) => RegExp('[a-z0-9]').hasMatch(ch);

/// [word] with its letters hidden as '_', except those at [shown] (the
/// online game's word mask).
String maskedWord(String word, Set<int> shown) => [
  for (var i = 0; i < word.length; i++)
    _isLetter(word[i]) && !shown.contains(i) ? '_' : word[i],
].join();

/// How many letters a word gives away as hints: two for a long word, one
/// otherwise.
int hintsFor(String word) =>
    word.split('').where(_isLetter).length >= 6 ? 2 : 1;

/// A hidden letter of [word] to show as a hint, or null when that would
/// leave fewer than two hidden.
int? nextHint(String word, Set<int> shown, math.Random random) {
  final hidden = [
    for (var i = 0; i < word.length; i++)
      if (_isLetter(word[i]) && !shown.contains(i)) i,
  ];
  if (hidden.length <= 2) return null;
  return hidden[random.nextInt(hidden.length)];
}
