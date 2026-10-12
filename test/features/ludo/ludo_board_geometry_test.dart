import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_board_geometry.dart';

/// The original hand-written 15x15 classic ring, (row, col), in travel
/// order from red's start. The arm-based geometry must reproduce it.
const _classicGrid = [
  [6, 1],
  [6, 2],
  [6, 3],
  [6, 4],
  [6, 5],
  [5, 6],
  [4, 6],
  [3, 6],
  [2, 6],
  [1, 6],
  [0, 6],
  [0, 7],
  [0, 8],
  [1, 8],
  [2, 8],
  [3, 8],
  [4, 8],
  [5, 8],
  [6, 9],
  [6, 10],
  [6, 11],
  [6, 12],
  [6, 13],
  [6, 14],
  [7, 14],
  [8, 14],
  [8, 13],
  [8, 12],
  [8, 11],
  [8, 10],
  [8, 9],
  [9, 8],
  [10, 8],
  [11, 8],
  [12, 8],
  [13, 8],
  [14, 8],
  [14, 7],
  [14, 6],
  [13, 6],
  [12, 6],
  [11, 6],
  [10, 6],
  [9, 6],
  [8, 5],
  [8, 4],
  [8, 3],
  [8, 2],
  [8, 1],
  [8, 0],
  [7, 0],
  [6, 0],
];

Offset _gridCell(List<int> rc) => Offset(rc[1] - 7.0, rc[0] - 7.0);

void _expectNear(Offset actual, Offset expected) {
  expect(
    (actual - expected).distance,
    lessThan(1e-9),
    reason: '$actual vs $expected',
  );
}

void main() {
  group('classic board', () {
    final g = LudoGeometry.of(LudoBoardKind.classic);

    test('reproduces the original 15x15 ring exactly', () {
      expect(g.ring.length, 52);
      for (var i = 0; i < 52; i++) {
        _expectNear(g.ring[i], _gridCell(_classicGrid[i]));
      }
    });

    test('home stretches run up the middle of each arm into the center', () {
      _expectNear(g.stretch[LudoColor.red]!.first, _gridCell([7, 1]));
      _expectNear(g.stretch[LudoColor.red]![4], _gridCell([7, 5]));
      expect(g.stretch[LudoColor.red]!.length, 5);
      _expectNear(g.stretch[LudoColor.yellow]!.first, _gridCell([7, 13]));
      _expectNear(g.stretch[LudoColor.green]!.first, _gridCell([1, 7]));
      _expectNear(g.stretch[LudoColor.blue]!.first, _gridCell([13, 7]));
    });

    test('yards sit in the right corners', () {
      expect(g.yardCenter[LudoColor.red]!.dx, lessThan(0));
      expect(g.yardCenter[LudoColor.red]!.dy, lessThan(0));
      expect(g.yardCenter[LudoColor.yellow]!.dx, greaterThan(0));
      expect(g.yardCenter[LudoColor.yellow]!.dy, greaterThan(0));
    });

    test('my yard is rotated to the bottom-left for every seat', () {
      for (final color in LudoBoardRules.classic.seats) {
        final r = LudoGeometry.rotate(
          g.yardCenter[color]!,
          g.viewRotation(color),
        );
        expect(r.dx, lessThan(0), reason: '$color');
        expect(r.dy, greaterThan(0), reason: '$color');
      }
    });
  });

  group('both boards', () {
    for (final kind in LudoBoardKind.values) {
      final g = LudoGeometry.of(kind);
      final rules = g.rules;

      test('$kind: ring squares are unique and spaced a cell apart', () {
        expect(g.ring.length, rules.ringSize);
        for (var i = 0; i < g.ring.length; i++) {
          for (var j = i + 1; j < g.ring.length; j++) {
            expect((g.ring[i] - g.ring[j]).distance, greaterThan(0.95));
          }
          // Consecutive squares are neighbors.
          final next = g.ring[(i + 1) % g.ring.length];
          expect((g.ring[i] - next).distance, lessThan(1.5));
        }
      });

      test('$kind: each seat starts on its own arm, next to its yard', () {
        for (final color in rules.seats) {
          final start = g.positionOf(color, 0, 0);
          _expectNear(start, g.ring[rules.startSquare(color)]);
          expect((start - g.yardCenter[color]!).distance, lessThan(5.5));
        }
      });

      test('$kind: the path runs ring -> home stretch -> home', () {
        for (final color in rules.seats) {
          final last = g.positionOf(color, 0, rules.ringLast);
          final firstStretch = g.positionOf(color, 0, rules.ringLast + 1);
          expect((last - firstStretch).distance, lessThan(1.1));
          final path = g.path(color, 0, 0, rules.finish);
          expect(path.length, rules.finish);
          _expectNear(path.last, g.homeSlot(color, 0));
        }
      });

      test('$kind: yard slots clear the track and stay on the board', () {
        final track = [...g.ring, for (final s in g.stretch.values) ...s];
        for (final slots in g.yardSlots.values) {
          for (final slot in slots) {
            for (final cell in track) {
              expect((slot - cell).distance, greaterThan(1.0));
            }
            expect(slot.distance, lessThan(g.outline.first.distance));
          }
          for (var a = 0; a < 4; a++) {
            for (var b = a + 1; b < 4; b++) {
              expect((slots[a] - slots[b]).distance, greaterThan(1.3));
            }
          }
        }
      });

      test('$kind: leaving base enters on the start square', () {
        for (final color in rules.seats) {
          final hop = g.path(color, 2, kLudoBase, 0);
          expect(hop.length, 1);
          _expectNear(hop.single, g.positionOf(color, 2, 0));
        }
      });
    }
  });

  test('the six-arm board is a star with a 78-square ring', () {
    final g = LudoGeometry.of(LudoBoardKind.hex);
    expect(g.ring.length, 78);
    expect(g.innerRadius, closeTo(3 * math.sqrt(3) / 2, 1e-9));
  });
}
