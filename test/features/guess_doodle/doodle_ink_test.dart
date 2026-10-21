import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';
import 'package:utopia/features/guess_doodle/domain/doodle_game.dart';
import 'package:utopia/features/guess_doodle/presentation/doodle_ink.dart';

StrokeOp _stroke(double x) => StrokeOp(
  tool: ArtTool.marker,
  color: 0xFF1F1E1B,
  size: 12,
  points: [x, 10, 12, x + 10, 20, 12],
);

void main() {
  group('DoodleInk', () {
    test('plays incoming points back, then keeps the finished stroke', () {
      final ink = DoodleInk()..reset(turn: 1, epoch: 0);
      ink.receivePoints(
        sid: 1,
        tool: ArtTool.marker,
        color: 0xFF000000,
        size: 12,
        from: 0,
        values: [0, 0, 12, 5, 5, 12, 10, 10, 12],
      );
      expect(ink.animating, isTrue);
      expect(ink.liveStrokes, isEmpty, reason: 'nothing shown before a frame');
      ink.advance(1 / 60);
      expect(ink.liveStrokes, hasLength(1));
      ink.receiveDone(1, _stroke(0));
      expect(ink.rev, 1);
      for (var i = 0; i < 30; i++) {
        ink.advance(1 / 60);
      }
      expect(ink.animating, isFalse);
      expect(ink.canUndo, isTrue);
      expect(ink.liveStrokes, isEmpty);
    });

    test('ignores points that arrive out of order', () {
      final ink = DoodleInk()..reset(turn: 1, epoch: 0);
      ink.receivePoints(
        sid: 1,
        tool: ArtTool.marker,
        color: 0,
        size: 12,
        from: 2,
        values: [5, 5, 12],
      );
      expect(ink.incoming[1]!.length, 0);
    });

    test('finished strokes go down in order', () {
      final ink = DoodleInk()..reset(turn: 1, epoch: 0);
      ink.receiveDone(2, _stroke(200));
      ink.receiveDone(1, _stroke(100));
      for (var i = 0; i < 30; i++) {
        ink.advance(1 / 60);
      }
      // Undo takes the last one off: stroke 2.
      final undone = ink.undo();
      expect((undone as StrokeOp?)?.points.first, 200);
    });

    test('undo puts strokes still arriving down first', () {
      final ink = DoodleInk()..reset(turn: 1, epoch: 0);
      ink.receiveDone(1, _stroke(100));
      ink.receiveDone(2, _stroke(200));
      // No frames yet: both are pending. Undo removes the newest.
      final undone = ink.undo();
      expect((undone as StrokeOp?)?.points.first, 200);
      expect(ink.canUndo, isTrue);
      expect(ink.incoming, isEmpty);
    });

    test('clear and reset empty the paper', () {
      final ink = DoodleInk()..reset(turn: 1, epoch: 0);
      ink.add(_stroke(0));
      ink.clear(epoch: 1);
      expect(ink.isEmpty, isTrue);
      expect(ink.epoch, 1);
      ink.add(_stroke(0));
      ink.reset(turn: 2, epoch: 0);
      expect(ink.isEmpty, isTrue);
      expect(ink.turn, 2);
      expect(ink.rev, 0);
    });

    test('replaceAll matches the saved canvas', () {
      final ink = DoodleInk()..reset(turn: 3, epoch: 0);
      ink.replaceAll([_stroke(1), _stroke(2)], rev: 5);
      expect(ink.rev, 5);
      expect((ink.undo() as StrokeOp?)?.points.first, 2);
    });
  });

  group('maskWords', () {
    test('splits words and shows hinted letters', () {
      expect(maskWords('___ _r___'), [
        [null, null, null],
        [null, 'r', null, null, null],
      ]);
    });

    test('keeps hyphens', () {
      expect(maskWords('____-____')[0][4], '-');
    });
  });

  test('DoodleGame reads a server row', () {
    final game = DoodleGame.fromRow({
      'id': 'g1',
      'code': 'ABC234',
      'is_public': true,
      'host_id': 'u1',
      'status': 'drawing',
      'rounds': 3,
      'draw_seconds': 80,
      'max_players': 8,
      'round': 2,
      'turn': 5,
      'drawer_id': 'u2',
      'phase_ends_at': '2026-10-12T10:00:00+00:00',
      'word_mask': '_____',
      'revealed_word': null,
      'canvas_epoch': 1,
      'canvas_rev': 7,
      'winner_ids': ['u1'],
    });
    expect(game.phase, DoodlePhase.drawing);
    expect(game.playing, isTrue);
    expect(game.phaseEndsAt, DateTime.utc(2026, 10, 12, 10));
    expect(game.winnerIds, ['u1']);
    expect(DoodlePhase.parse('nonsense'), DoodlePhase.closed);
  });
}
