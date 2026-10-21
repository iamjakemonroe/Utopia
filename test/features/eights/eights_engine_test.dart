import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/eights/domain/eights_engine.dart';

const engine = EightsEngine();

PlayingCard c(String code) => PlayingCard.fromCode(code);

/// A game set up by hand: [hands] per seat, [top] on the pile.
EightsGame rigged(
  List<List<String>> hands, {
  String top = '5S',
  String? suit,
  int turn = 0,
  List<String> draw = const ['2C', '3C', '4C'],
}) => EightsGame(
  table: EightsTable(
    counts: [for (final h in hands) h.length],
    turn: turn,
    top: c(top),
    suit: suit == null ? c(top).suit : CardSuit.fromCode(suit),
    drawCount: draw.length,
  ),
  hands: [
    for (final h in hands) [for (final x in h) c(x)],
  ],
  drawPile: [for (final x in draw) c(x)],
  discard: const [],
);

void main() {
  group('cards', () {
    test('codes go both ways, tens are T', () {
      for (final card in kFullDeck) {
        expect(PlayingCard.fromCode(card.code), card);
      }
      expect(c('TD').label, '10');
      expect(c('TD').rank, 10);
      expect(c('AS').label, 'A');
      expect(kFullDeck.toSet().length, 52);
    });
  });

  group('the deal', () {
    test('two players get seven, more get five; nothing is lost', () {
      for (final n in [2, 3, 4, 6]) {
        final g = engine.deal(n, random: Random(n));
        final size = n == 2 ? 7 : 5;
        expect(g.table.counts, List.filled(n, size));
        final all = [...g.hands.expand((h) => h), ...g.drawPile, g.table.top];
        expect(all.toSet().length, 52);
        expect(g.table.drawCount, g.drawPile.length);
        expect(g.table.top.isEight, isFalse);
        expect(g.table.suit, g.table.top.suit);
      }
    });
  });

  group('what goes', () {
    final t = rigged([
      ['KS'],
    ], top: '5H').table;
    test('the same suit, the same rank, or an eight', () {
      expect(t.canPlay(c('KH')), isTrue);
      expect(t.canPlay(c('5C')), isTrue);
      expect(t.canPlay(c('8D')), isTrue);
      expect(t.canPlay(c('KS')), isFalse);
    });

    test("after an eight, only the suit it named (or another eight)", () {
      final named = rigged(
        [
          ['KS'],
        ],
        top: '8H',
        suit: 'C',
      ).table;
      expect(named.canPlay(c('2C')), isTrue);
      expect(named.canPlay(c('2H')), isFalse);
      expect(named.canPlay(c('8S')), isTrue);
    });
  });

  group('playing', () {
    test('a card goes on the pile and the turn moves on', () {
      final g = engine.play(
        rigged([
          ['5H', 'KS'],
          ['2D'],
        ]),
        0,
        c('5H'),
      );
      expect(g.table.top, c('5H'));
      expect(g.table.suit, CardSuit.hearts);
      expect(g.table.turn, 1);
      expect(g.table.counts, [1, 1]);
      expect(g.discard, [c('5S')]);
      expect(g.table.last!.kind, EightsActionKind.play);
    });

    test('an eight names the suit', () {
      final g = engine.play(
        rigged([
          ['8D', 'KS'],
          ['2D'],
        ]),
        0,
        c('8D'),
        suit: CardSuit.spades,
      );
      expect(g.table.suit, CardSuit.spades);
      expect(g.table.last!.suit, CardSuit.spades);
    });

    test('the rules hold', () {
      final g = rigged([
        ['KH', '8C'],
        ['2D'],
      ]);
      expect(() => engine.play(g, 1, c('2D')), throwsA(isA<EightsRuleError>()));
      expect(() => engine.play(g, 0, c('AS')), throwsA(isA<EightsRuleError>()));
      expect(() => engine.play(g, 0, c('KH')), throwsA(isA<EightsRuleError>()));
      expect(() => engine.play(g, 0, c('8C')), throwsA(isA<EightsRuleError>()));
    });

    test('the last card wins', () {
      final g = engine.play(
        rigged([
          ['KS'],
          ['2D'],
        ]),
        0,
        c('KS'),
      );
      expect(g.table.winner, 0);
      expect(g.table.isOver, isTrue);
      expect(() => engine.draw(g, 0), throwsA(isA<EightsRuleError>()));
    });
  });

  group('drawing and passing', () {
    test('draw one, then play or pass', () {
      var g = rigged([
        ['KH'],
        ['2D'],
      ]);
      expect(() => engine.pass(g, 0), throwsA(isA<EightsRuleError>()));
      g = engine.draw(g, 0);
      expect(g.hands[0], [c('KH'), c('4C')]);
      expect(g.table.drawn, isTrue);
      expect(g.table.turn, 0);
      expect(g.table.drawCount, 2);
      expect(() => engine.draw(g, 0), throwsA(isA<EightsRuleError>()));
      g = engine.pass(g, 0);
      expect(g.table.turn, 1);
      expect(g.table.drawn, isFalse);
    });

    test('an empty pile is refilled from the played cards', () {
      var g = rigged([
        ['KH'],
        ['2D'],
      ], draw: const []).copyWith(discard: [c('3H'), c('9C')]);
      g = engine.draw(g, 0, random: Random(1));
      expect(g.hands[0].length, 2);
      expect(g.discard, isEmpty);
      expect(g.drawPile.length, 1);
    });

    test('nothing at all to draw: the turn just passes', () {
      final g = engine.draw(
        rigged([
          ['KH'],
          ['2D'],
        ], draw: const []),
        0,
      );
      expect(g.table.turn, 1);
      expect(g.hands[0], [c('KH')]);
    });

    test('running out of time draws and passes', () {
      final g = engine.timeOut(
        rigged([
          ['KH'],
          ['2D'],
        ]),
        0,
      );
      expect(g.hands[0].length, 2);
      expect(g.table.turn, 1);
      expect(g.table.last!.kind, EightsActionKind.timeout);
    });
  });

  group('leaving', () {
    test('cards go back, turns skip them, the last one left wins', () {
      var g = rigged([
        ['KH'],
        ['2D', '3D'],
        ['4S'],
      ]);
      g = engine.leave(g, 1);
      expect(g.table.left, [1]);
      expect(g.table.counts[1], 0);
      expect(g.drawPile.length, 5);
      expect(g.table.nextSeat(0), 2);
      expect(g.table.isOver, isFalse);
      g = engine.leave(g, 0);
      expect(g.table.winner, 2);
      expect(g.table.turn, 2);
    });
  });

  group('bots', () {
    test('play a matching card from their biggest suit, keep eights', () {
      final t = rigged([[]], top: '5H').table;
      final move = chooseEightsPlay([
        c('8S'),
        c('2H'),
        c('5C'),
        c('9C'),
        c('JC'),
      ], t);
      expect(move!.$1, c('5C'));
      expect(move.$2, isNull);
    });

    test('an eight when nothing else goes, naming their best suit', () {
      final t = rigged([[]], top: '5H').table;
      final move = chooseEightsPlay([c('8S'), c('2C'), c('9C'), c('3D')], t);
      expect(move!.$1, c('8S'));
      expect(move.$2, CardSuit.clubs);
    });

    test('nothing goes: draw', () {
      final t = rigged([[]], top: '5H').table;
      expect(chooseEightsPlay([c('2C'), c('9D')], t), isNull);
    });

    test('a whole game of bots ends with a winner', () {
      for (var seed = 0; seed < 20; seed++) {
        final rng = Random(seed);
        var g = engine.deal(2 + seed % 5, random: rng);
        var moves = 0;
        while (!g.table.isOver && moves++ < 2000) {
          final seat = g.table.turn;
          final move = chooseEightsPlay(g.hands[seat], g.table, random: rng);
          if (move != null) {
            g = engine.play(g, seat, move.$1, suit: move.$2);
          } else if (!g.table.drawn) {
            g = engine.draw(g, seat, random: rng);
          } else {
            g = engine.pass(g, seat);
          }
          final total =
              g.hands.expand((h) => h).length +
              g.drawPile.length +
              g.discard.length +
              1;
          expect(total, 52);
        }
        expect(g.table.isOver, isTrue, reason: 'seed $seed');
        expect(g.hands[g.table.winner!], isEmpty);
      }
    });
  });

  test('the table survives a JSON round trip', () {
    final g = engine.play(
      rigged([
        ['8D', 'KS'],
        ['2D'],
      ]),
      0,
      c('8D'),
      suit: CardSuit.spades,
    );
    final back = EightsTable.fromJson(g.table.toJson());
    expect(back.top, g.table.top);
    expect(back.suit, CardSuit.spades);
    expect(back.counts, g.table.counts);
    expect(back.last!.card, c('8D'));
    final whole = EightsGame.fromJson(g.toJson());
    expect(whole.hands[0], [c('KS')]);
  });
}
