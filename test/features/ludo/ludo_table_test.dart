import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_board_geometry.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_seat_panel.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_table.dart';

/// Phones and tablets either way up, a small phone, a computer's window.
const _screens = {
  'iPhone SE': Size(375, 667),
  'iPhone': Size(390, 844),
  'iPhone on its side': Size(844, 390),
  'iPad mini': Size(744, 1133),
  'iPad': Size(820, 1180),
  'iPad on its side': Size(1180, 820),
  'iPad Pro on its side': Size(1366, 1024),
  'laptop': Size(1440, 900),
};

const _boardKey = Key('board');

Future<void> _pumpTable(
  WidgetTester tester,
  Size screen,
  List<LudoColor> colors, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final game = LudoState.initial(colors);
  final g = LudoGeometry.of(game.board);
  final rotation = g.viewRotation(colors.first);
  final half = g.halfExtent(rotation);
  final seats = <LudoSeat>[];
  for (final color in colors) {
    final a = g.yardAngle(g.rules.seatOf(color)) + rotation;
    seats.add((color: color, x: math.cos(a), y: math.sin(a)));
  }
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: screen,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: LudoTable(
              seats: seats,
              boardAspect: (half.width + 0.45) / (half.height + 0.45),
              board: const ColoredBox(key: _boardKey, color: Colors.green),
              panel: (color, {required mirrored}) => LudoSeatPanel(
                key: ValueKey(color),
                color: color,
                userId: null,
                isMe: false,
                isTurn: false,
                left: false,
                home: 0,
                mirrored: mirrored,
                onAvatarTap: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Rect _rect(WidgetTester tester, Finder f) {
  final box = tester.renderObject<RenderBox>(f);
  final topLeft = box.localToGlobal(Offset.zero);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
  return Rect.fromPoints(topLeft, bottomRight);
}

void main() {
  for (final players in [
    [LudoColor.red, LudoColor.green, LudoColor.yellow, LudoColor.blue],
    [LudoColor.red, LudoColor.yellow],
    LudoColor.values,
  ]) {
    for (final MapEntry(key: name, value: screen) in _screens.entries) {
      testWidgets(
        '${players.length} players, $name: every seat on screen, '
        'by its own corner, none over the board',
        (tester) async {
          await _pumpTable(tester, screen, players);
          expect(tester.takeException(), isNull);
          final whole = Offset.zero & screen;
          final board = _rect(tester, find.byKey(_boardKey));
          expect(whole.contains(board.topLeft), isTrue);
          expect(
            whole.contains(board.bottomRight - const Offset(1, 1)),
            isTrue,
          );
          // The board gets most of the room it could have.
          expect(
            board.shortestSide,
            greaterThan(math.min(screen.width, screen.height) * 0.55),
          );
          for (final color in players) {
            final seat = _rect(tester, find.byKey(ValueKey(color)));
            expect(
              whole.contains(seat.topLeft) &&
                  whole.contains(seat.bottomRight - const Offset(1, 1)),
              isTrue,
              reason: '$color off the screen: $seat',
            );
            expect(
              seat.overlaps(board.deflate(1)),
              isFalse,
              reason: '$color over the board: $seat / $board',
            );
          }
          // Near its yard: a seat on the board's left half sits left of
          // its middle, and one on its top half above it (or level).
          final mid = board.center;
          final game = LudoState.initial(players);
          final g = LudoGeometry.of(game.board);
          final rotation = g.viewRotation(players.first);
          for (final color in players) {
            final a = g.yardAngle(g.rules.seatOf(color)) + rotation;
            final seat = _rect(tester, find.byKey(ValueKey(color))).center;
            if (math.cos(a) < -0.3) expect(seat.dx, lessThan(mid.dx));
            if (math.cos(a) > 0.3) expect(seat.dx, greaterThan(mid.dx));
            if (math.sin(a) < -0.3) expect(seat.dy, lessThan(mid.dy));
            if (math.sin(a) > 0.3) expect(seat.dy, greaterThan(mid.dy));
          }
        },
      );
    }
  }

  testWidgets('big text on a small phone: shrunk to fit, nothing cut off', (
    tester,
  ) async {
    const screen = Size(375, 667);
    await _pumpTable(tester, screen, [
      LudoColor.red,
      LudoColor.green,
      LudoColor.yellow,
      LudoColor.blue,
    ], textScale: 1.6);
    expect(tester.takeException(), isNull);
    final whole = Offset.zero & screen;
    for (final color in [
      LudoColor.red,
      LudoColor.green,
      LudoColor.yellow,
      LudoColor.blue,
    ]) {
      final seat = _rect(tester, find.byKey(ValueKey(color)));
      expect(whole.inflate(0.5).contains(seat.bottomRight), isTrue);
      expect(whole.inflate(0.5).contains(seat.topLeft), isTrue);
    }
  });
}
