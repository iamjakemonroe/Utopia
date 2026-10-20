import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/ludo/data/ludo_repository.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/controllers/ludo_match_controller.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_dice.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_pieces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A LudoRepository with the network swapped for streams the test drives.
class _FakeRepo extends LudoRepository {
  _FakeRepo() : super(SupabaseClient('http://localhost', 'test-key'));

  final match = StreamController<Map<String, dynamic>?>.broadcast();
  final chat = StreamController<List<Map<String, dynamic>>>.broadcast();
  final moves = <Map<String, dynamic>>[];

  /// Everything sent, in order: ('roll', state) or ('move', state).
  final sent = <(String, Map<String, dynamic>)>[];

  @override
  Stream<Map<String, dynamic>?> watchMatch(String matchId) => match.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchChat(String matchId) => chat.stream;

  @override
  Future<void> recordRoll({
    required String matchId,
    required Map<String, dynamic> state,
  }) async {
    sent.add(('roll', state));
  }

  @override
  Future<void> recordMove({
    required String matchId,
    required int turnNumber,
    required int diceValue,
    int? tokenIndex,
    required bool captured,
    required bool reachedHome,
    required Map<String, dynamic> stateAfter,
  }) async {
    moves.add(stateAfter);
    sent.add(('move', stateAfter));
  }

  @override
  Future<void> reportMatchResult({
    required String matchId,
    String? winnerId,
    required String result,
  }) async {}

  @override
  Future<Map<String, dynamic>> sendChat({
    required String matchId,
    required String kind,
    required String body,
  }) async => {};
}

const _me = 'user-red';
const _them = 'user-yellow';

Map<String, dynamic> _row(LudoState game, {int turnCount = 0}) => {
  'id': 'm1',
  'status': 'active',
  'stake': 50,
  'mode': 'public',
  'turn_count': turnCount,
  'players': [_me, _them],
  'colors': ['red', 'yellow'],
  'state': game.toJson(),
};

LudoState _base() => LudoState.initial(const [LudoColor.red, LudoColor.yellow]);

LudoState _captured(LudoState from, int seq) => from.copyWith(
  turn: LudoColor.yellow,
  capture: LudoCapture(
    seq: seq,
    by: LudoColor.yellow,
    token: 0,
    victims: const [(LudoColor.red, 0)],
  ),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeRepo repo;
  late LudoMatchController controller;

  setUp(() {
    repo = _FakeRepo();
    controller = LudoMatchController(repo, 'm1', _me);
  });

  tearDown(() => controller.dispose());

  test(
    'the first capture after opening the match asks for a reaction',
    () async {
      repo.match.add(_row(_base()));
      await _settle();
      expect(controller.state.pendingReaction, isNull);

      repo.match.add(_row(_captured(_base(), 1), turnCount: 1));
      await _settle();
      expect(controller.state.pendingReaction?.capture.seq, 1);
      expect(controller.state.pendingReaction?.capture.by, LudoColor.yellow);
      // Not my capture, so I only watch.
      expect(controller.state.choosingReaction, isFalse);
    },
  );

  test('the one who captured can roll on, which passes on reacting', () async {
    repo.match.add(_row(_base()));
    await _settle();
    final mine = _base().copyWith(
      turn: LudoColor.red,
      capture: const LudoCapture(
        seq: 1,
        by: LudoColor.red,
        token: 0,
        victims: [(LudoColor.yellow, 0)],
      ),
    );
    repo.match.add(_row(mine, turnCount: 1));
    await _settle();
    expect(controller.state.choosingReaction, isTrue);
    // The die doesn't wait for a reaction no one has asked to make.
    expect(controller.state.canRoll, isTrue);

    await controller.rollDice();
    await _settle();
    expect(controller.state.pendingReaction, isNull);
    expect(repo.sent.map((s) => s.$1), contains('roll'));
  });

  test('a capture from before the match was opened is not replayed', () async {
    repo.match.add(_row(_captured(_base(), 3), turnCount: 5));
    await _settle();
    expect(controller.state.pendingReaction, isNull);
  });

  test("the capturer's reaction plays for everyone", () async {
    repo.match.add(_row(_base()));
    repo.chat.add([]); // the (empty) history on opening
    await _settle();
    repo.match.add(_row(_captured(_base(), 1), turnCount: 1));
    await _settle();
    repo.chat.add([
      {
        'id': 1,
        'sender_id': _them,
        'kind': 'reaction',
        'body': 'war',
        'created_at': DateTime.now().toIso8601String(),
      },
    ]);
    await _settle();
    expect(controller.state.pendingReaction, isNull);
    expect(controller.state.reaction?.kind, TokenReaction.war);
    expect(controller.state.reaction?.color, LudoColor.yellow);
  });

  test('a late, older row never rolls the game back', () async {
    final rolled = _base().copyWith(
      rollSeq: 4,
      lastRoll: const LudoRoll(LudoColor.red, 5),
    );
    repo.match.add(_row(rolled, turnCount: 3));
    await _settle();
    repo.match.add(_row(_base().copyWith(rollSeq: 2), turnCount: 3));
    await _settle();
    expect(controller.state.game.rollSeq, 4);
    repo.match.add(_row(_base().copyWith(rollSeq: 1), turnCount: 2));
    await _settle();
    expect(controller.state.game.rollSeq, 4);
    // A genuinely newer move is taken.
    repo.match.add(_row(_base().copyWith(rollSeq: 5), turnCount: 4));
    await _settle();
    expect(controller.state.game.rollSeq, 5);
  });

  test('pieces only light up once the die shows its number', () async {
    // One piece already out, so whatever comes up, something can move.
    final base = _base();
    repo.match.add(
      _row(
        base.copyWith(
          tokens: {
            ...base.tokens,
            LudoColor.red: const [5, -1, -1, -1],
          },
        ),
      ),
    );
    await _settle();
    await controller.rollDice();
    await _settle();
    expect(controller.state.game.hasRolled, isTrue);
    // Rolled, but the die is still tumbling: nothing glows, taps do nothing.
    expect(controller.state.movableTokens, isEmpty);
    await Future<void>.delayed(kDiceReveal);
    expect(controller.state.movableTokens, isNotEmpty);
  });

  test(
    'a roll that arrives with its move shows before the piece moves',
    () async {
      final base = _base();
      final before = base.copyWith(
        turn: LudoColor.yellow,
        tokens: {
          ...base.tokens,
          LudoColor.yellow: const [10, -1, -1, -1],
        },
      );
      repo.match.add(_row(before, turnCount: 3));
      await _settle();
      // Yellow rolled a 4 and moved; this phone never saw the roll alone.
      final after = before.copyWith(
        turn: LudoColor.red,
        rollSeq: before.rollSeq + 1,
        lastRoll: const LudoRoll(LudoColor.yellow, 4),
        tokens: {
          ...before.tokens,
          LudoColor.yellow: const [14, -1, -1, -1],
        },
      );
      repo.match.add(_row(after, turnCount: 4));
      await _settle();
      // The die rolls first, on the board as it was.
      expect(controller.state.game.rollSeq, after.rollSeq);
      expect(
        controller.state.game.lastRoll,
        const LudoRoll(LudoColor.yellow, 4),
      );
      expect(controller.state.game.tokens[LudoColor.yellow]![0], 10);
      // Then, once its number has been seen, the piece moves.
      await Future<void>.delayed(
        kDiceReveal + kDiceReadTime + const Duration(milliseconds: 50),
      );
      expect(controller.state.game.tokens[LudoColor.yellow]![0], 14);
      expect(controller.state.game.turn, LudoColor.red);
    },
  );

  test('a roll with no legal move is shown and passes the turn', () async {
    // All tokens in base: anything but a 6 has no legal move.
    repo.match.add(_row(_base()));
    await _settle();
    var tries = 0;
    // A 6 lets a piece out instead (and the same player rolls again), so
    // keep going until a roll passes the turn.
    bool passedTurn() =>
        repo.moves.any((m) => LudoState.fromJson(m).turn == LudoColor.yellow);
    while (!passedTurn() && tries++ < 15) {
      // A 6 lets a piece out instead; reset the board and retry. The count
      // jumps well past anything this phone played, so the reset always
      // counts as newer.
      repo.match.add(
        _row(
          _base().copyWith(rollSeq: controller.state.game.rollSeq + 1),
          turnCount: tries * 10,
        ),
      );
      await _settle();
      // The roll that came in has to land before the next one.
      await Future<void>.delayed(kDiceReveal + kDiceReadTime);
      await _settle();
      await controller.rollDice();
      // Let whatever that roll set going (a pass, or a piece leaving base
      // on a 6) finish before the board is reset.
      await Future<void>.delayed(
        kDiceReadTime + const Duration(milliseconds: 300),
      );
      await _settle();
    }
    expect(passedTurn(), isTrue);
    // Everyone saw the roll before the turn passed: it went out on its own
    // first, still the roller's turn, and the pass came after it.
    final passIndex = repo.sent.indexWhere(
      (e) =>
          e.$1 == 'move' && LudoState.fromJson(e.$2).turn == LudoColor.yellow,
    );
    final (kind, rolled) = repo.sent[passIndex - 1];
    expect(kind, 'roll');
    expect(LudoState.fromJson(rolled).turn, LudoColor.red);
    expect(LudoState.fromJson(rolled).hasRolled, isTrue);
    final passed = LudoState.fromJson(repo.sent[passIndex].$2);
    expect(passed.turn, LudoColor.yellow);
    expect(passed.lastRoll?.color, LudoColor.red);
    expect(passed.lastRoll?.value, isNot(6));
    expect(passed.hasRolled, isFalse);
  });

  test(
    'chat history on opening is not unread and old reactions stay put',
    () async {
      repo.match.add(_row(_base()));
      await _settle();
      Map<String, dynamic> msg(int id, String kind, String body) => {
        'id': id,
        'sender_id': _them,
        'kind': kind,
        'body': body,
        'created_at': DateTime.now().toIso8601String(),
      };
      repo.chat.add([msg(1, 'text', 'hi'), msg(2, 'reaction', 'war')]);
      await _settle();
      expect(controller.state.chat.length, 2);
      expect(controller.state.unread, 0);
      expect(controller.state.chatBaseline, 2);
      expect(controller.state.reaction, isNull);

      repo.chat.add([
        msg(1, 'text', 'hi'),
        msg(2, 'reaction', 'war'),
        msg(3, 'text', 'gg'),
      ]);
      await _settle();
      expect(controller.state.unread, 1);
    },
  );

  test('pass and play: a friend on this phone rolls on their turn', () async {
    const id = 'local-pass';
    restoreLocalLudo('/ludo/$id', {
      'players': [_me, 'friend:2'],
      'colors': ['red', 'yellow'],
      'human': _me,
      'game': _base().copyWith(turn: LudoColor.yellow).toJson(),
      'turn': 3,
    });
    final local = LudoMatchController.local(repo, id, _me, localLudoSetup(id)!);
    addTearDown(local.dispose);

    expect(local.state.friendColors, {LudoColor.yellow});
    // Yellow is a friend holding this phone: the die is theirs to tap.
    expect(local.state.isMyTurn, isTrue);
    expect(local.state.canRoll, isTrue);
    await local.rollDice();
    await _settle();
    expect(local.state.game.lastRoll?.color, LudoColor.yellow);
  });

  test('an offline game waits while the app is in the background', () async {
    const id = 'local-away';
    restoreLocalLudo('/ludo/$id', {
      'players': [_me, 'bot:pip'],
      'colors': ['red', 'yellow'],
      'human': _me,
      'game': _base().copyWith(turn: LudoColor.yellow).toJson(),
      'turn': 1,
    });
    final local = LudoMatchController.local(repo, id, _me, localLudoSetup(id)!);
    addTearDown(local.dispose);
    final seq = local.state.game.rollSeq;

    local.appHidden();
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    // The bot didn't play on while nobody was watching.
    expect(local.state.game.rollSeq, seq);
    final left = local.state.turnMsLeft!;

    local.appShown();
    // The time away was given back...
    expect(local.state.turnMsLeft, greaterThan(left + 1500));
    // ...and the bot carries on.
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    expect(local.state.game.rollSeq, greaterThan(seq));
  });
}
