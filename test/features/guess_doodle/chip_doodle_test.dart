import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/guess_doodle/domain/chip_doodle.dart';
import 'package:utopia/features/guess_doodle/presentation/chip_doodle_game.dart';

const _door = ChipDoodleRound(
  word: 'door',
  strokes: ['M 300 900 L 300 100 L 700 100 L 700 900', 'M 620 500 L 640 500'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('guesses', () {
    test('the word, however it is typed, is right', () {
      for (final g in ['door', 'Door!', '  DOOR ', "it's a door"]) {
        expect(judgeGuess(g, 'door'), GuessVerdict.right, reason: g);
      }
      expect(judgeGuess('icecream', 'ice cream'), GuessVerdict.right);
      expect(judgeGuess('ice-cream', 'ice cream'), GuessVerdict.right);
    });

    test('a letter off is close; more is wrong', () {
      expect(judgeGuess('dor', 'door'), GuessVerdict.close);
      expect(judgeGuess('doors', 'door'), GuessVerdict.close);
      expect(judgeGuess('elefant', 'elephant'), GuessVerdict.close);
      expect(judgeGuess('window', 'door'), GuessVerdict.wrong);
      // Short words are all-or-nothing.
      expect(judgeGuess('cap', 'cat'), GuessVerdict.wrong);
      expect(judgeGuess('', 'door'), GuessVerdict.wrong);
    });

    test('faster guesses score more, as online', () {
      expect(guessPoints(60, 60), 500);
      expect(guessPoints(0, 60), 50);
      expect(guessPoints(30, 60), 275);
    });
  });

  group('hints', () {
    test('the mask hides letters, not spaces or hyphens', () {
      expect(maskedWord('ice cream', {}), '___ _____');
      expect(maskedWord('t-shirt', {0}), 't-_____');
    });

    test('hints never give the word away', () {
      final rng = math.Random(4);
      final shown = <int>{};
      for (var i = 0; i < 10; i++) {
        final at = nextHint('cat', shown, rng);
        if (at != null) shown.add(at);
      }
      expect(shown.length, 1);
      expect(hintsFor('cat'), 1);
      expect(hintsFor('elephant'), 2);
    });
  });

  group("Chip's pen", () {
    test('paths become pen lines, a piece each', () {
      final lines = penLines([
        'M 100 100 L 400 100',
        'M 0 0 L 0 60 M 50 0 L 50 60',
      ]);
      expect(lines, hasLength(3));
      expect(lines.first.first, const Offset(100, 100));
      expect(lines.first.last, const Offset(400, 100));
      expect(lines.first.length, greaterThan(40));
    });

    test('draws in order, at a hand pace, then everything is down', () {
      final pen = ChipPen(penLines(['M 0 0 L 750 0', 'M 0 100 L 750 100']));
      final got = <int, int>{};
      final done = <int>[];
      void tick(double s) => pen.advance(
        s,
        onPoints: (line, from, pts) {
          expect(from, got[line] ?? 0);
          got[line] = from + pts.length;
        },
        onLine: (line, _) => done.add(line),
      );
      tick(0.5); // the breath before the first line
      expect(got, isEmpty);
      tick(0.5);
      expect(done, isEmpty);
      tick(0.6); // a second a line, at 750 a second
      expect(done, [0]);
      for (var i = 0; i < 20; i++) {
        tick(0.1);
      }
      expect(done, [0, 1]);
      expect(pen.done, isTrue);
    });
  });

  group('a game', () {
    late List<ChipDoodleRound> deck;
    late int dealt;
    ChipDoodleGame game({int rounds = 2}) {
      dealt = 0;
      return ChipDoodleGame(
        () async {
          if (dealt >= deck.length) throw const FormatException('empty');
          return deck[dealt++];
        },
        rounds: rounds,
        random: math.Random(1),
      );
    }

    setUp(
      () => deck = [
        _door,
        const ChipDoodleRound(word: 'elephant', strokes: ['M 0 0 L 9 9']),
      ],
    );

    test('a right guess ends the round with points for speed', () async {
      final g = game();
      await g.start();
      expect(g.phase, ChipDoodlePhase.drawing);
      expect(g.mask, '____');
      g.tick(12);
      expect(g.guess('window'), GuessVerdict.wrong);
      expect(g.guess('dor'), GuessVerdict.close);
      expect(g.phase, ChipDoodlePhase.drawing);
      expect(g.guess('a door'), GuessVerdict.right);
      expect(g.phase, ChipDoodlePhase.reveal);
      expect(g.lastPoints, guessPoints(48, 60));
      expect(g.score, g.lastPoints);
      expect(g.guess('door'), isNull);
      g.dispose();
    });

    test(
      'time runs out with hints along the way; then the next doodle',
      () async {
        final g = game();
        await g.start();
        await g.next(); // not before the round's over
        expect(g.round, 1);
        g.skip();
        await g.next();
        expect(g.round, 2);
        expect(g.current!.word, 'elephant');
        expect(dealt, 2, reason: 'fetched ahead');
        g.tick(31);
        expect(g.hints, hasLength(1));
        g.tick(15);
        expect(g.hints, hasLength(2));
        g.tick(15);
        expect(g.phase, ChipDoodlePhase.reveal);
        expect(g.guessed, isFalse);
        expect(g.score, 0);
        await g.next();
        expect(g.phase, ChipDoodlePhase.over);
        g.dispose();
      },
    );

    test("when Chip can't deal, it says so, and can try again", () async {
      deck = [];
      final g = game();
      await g.start();
      expect(g.phase, ChipDoodlePhase.error);
      deck = [_door];
      await g.retry();
      expect(g.phase, ChipDoodlePhase.drawing);
      g.dispose();
    });
  });
}
