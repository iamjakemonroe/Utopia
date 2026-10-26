import 'dart:async';
import 'dart:math';

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

  /// The row as the server has it (set by [push]).
  Map<String, dynamic>? current;

  /// The server's die: these numbers next, then random ones.
  final dice = <int>[];

  /// Every roll and move the server made, in order, with the state after.
  final sent = <(String, Map<String, dynamic>)>[];

  /// The server's row changes: everyone hears.
  void push(Map<String, dynamic> row) {
    current = row;
    match.add(row);
  }

  @override
  Stream<Map<String, dynamic>?> watchMatch(String matchId) => match.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchChat(String matchId) => chat.stream;

  /// Rolls like the server: a roll nothing can use passes (sixes always stand).
  @override
  Future<Map<String, dynamic>> rollDice(String matchId) async {
    final row = current!;
    final game = LudoState.fromJson(row['state'] as Map<String, dynamic>);
    final value = dice.isNotEmpty ? dice.removeAt(0) : Random().nextInt(6) + 1;
    final outcome = const LudoEngine().registerRoll(game, value);
    var turns = row['turn_count'] as int;
    var next = outcome.state;
    if (outcome.movableTokens.isEmpty) {
      next = const LudoEngine().passTurnNoMove(next);
      turns++;
    }
    sent.add(('roll', next.toJson()));
    return current = {...row, 'state': next.toJson(), 'turn_count': turns};
  }

  /// Moves like the server.
  @override
  Future<Map<String, dynamic>> moveToken({
    required String matchId,
    required int token,
  }) async {
    final row = current!;
    final game = LudoState.fromJson(row['state'] as Map<String, dynamic>);
    final next = const LudoEngine()
        .applyMove(game, token, game.diceValue!)
        .state;
    sent.add(('move', next.toJson()));
    return current = {
      ...row,
      'state': next.toJson(),
      'turn_count': (row['turn_count'] as int) + 1,
    };
  }

  /// Chat messages sent: (kind, body).
  final chats = <(String, String)>[];

  @override
  Future<Map<String, dynamic>> sendChat({
    required String matchId,
    required String kind,
    required String body,
  }) async {
    chats.add((kind, body));
    return {};
  }
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
      repo.push(_row(_base()));
      await _settle();
      expect(controller.state.pendingReaction, isNull);

      repo.push(_row(_captured(_base(), 1), turnCount: 1));
      await _settle();
      expect(controller.state.pendingReaction?.capture.seq, 1);
      expect(controller.state.pendingReaction?.capture.by, LudoColor.yellow);
      // Not my capture, so I only watch.
      expect(controller.state.choosingReaction, isFalse);
    },
  );

  test('the one who captured can roll on, which passes on reacting', () async {
    repo.push(_row(_base()));
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
    repo.push(_row(mine, turnCount: 1));
    await _settle();
    expect(controller.state.choosingReaction, isTrue);
    // The die doesn't wait for a reaction no one has asked to make.
    expect(controller.state.canRoll, isTrue);

    await controller.rollDice();
    await _settle();
    expect(controller.state.choosingReaction, isFalse);
    // Yellow, sent home, can still react.
    expect(
      controller.state.pendingReaction?.waitingOn(LudoColor.yellow),
      isTrue,
    );
    expect(repo.sent.map((s) => s.$1), contains('roll'));
  });

  test('a capture from before the match was opened is not replayed', () async {
    repo.push(_row(_captured(_base(), 3), turnCount: 5));
    await _settle();
    expect(controller.state.pendingReaction, isNull);
  });

  test("the capturer's reaction plays for everyone", () async {
    repo.push(_row(_base()));
    repo.chat.add([]); // the (empty) history on opening
    await _settle();
    repo.push(_row(_captured(_base(), 1), turnCount: 1));
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
    expect(controller.state.reactions.last.kind, TokenReaction.war);
    expect(controller.state.reactions.last.color, LudoColor.yellow);
    // Still waiting on me: my piece was the one sent home.
    expect(
      controller.state.pendingReaction?.waitingOn(LudoColor.yellow),
      isFalse,
    );
    expect(controller.state.sentHomeChoosing, [LudoColor.red]);
  });

  test('a piece sent home reacts sad or again, on that piece', () async {
    repo.push(_row(_base()));
    repo.chat.add([]);
    await _settle();
    repo.push(_row(_captured(_base(), 1), turnCount: 1));
    await _settle();
    expect(controller.state.sentHomeChoosing, [LudoColor.red]);
    // Not the capturer: war isn't mine to pick.
    await controller.chooseReaction(TokenReaction.war);
    expect(controller.state.reactions, isEmpty);

    await controller.chooseReaction(TokenReaction.again);
    expect(controller.state.reactions.single.kind, TokenReaction.again);
    expect(controller.state.reactions.single.color, LudoColor.red);
    expect(controller.state.reactions.single.token, 0);
    expect(repo.chats, [('reaction', 'again')]);
    expect(controller.state.sentHomeChoosing, isEmpty);

    // The capturer's war comes in after: everyone's reacted, nothing waits.
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
    expect(controller.state.reactions.map((r) => r.kind), [
      TokenReaction.again,
      TokenReaction.war,
    ]);
    expect(controller.state.pendingReaction, isNull);
  });

  test(
    "a sent-home reaction from someone who wasn't sent home is ignored",
    () async {
      repo.push(_row(_base()));
      repo.chat.add([]);
      await _settle();
      repo.push(_row(_captured(_base(), 1), turnCount: 1));
      await _settle();
      repo.chat.add([
        {
          'id': 1,
          'sender_id': _them,
          'kind': 'reaction',
          'body': 'sad',
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);
      await _settle();
      expect(controller.state.reactions, isEmpty);
    },
  );

  test('a late, older row never rolls the game back', () async {
    final rolled = _base().copyWith(
      rollSeq: 4,
      lastRoll: const LudoRoll(LudoColor.red, 5),
    );
    repo.push(_row(rolled, turnCount: 3));
    await _settle();
    repo.push(_row(_base().copyWith(rollSeq: 2), turnCount: 3));
    await _settle();
    expect(controller.state.game.rollSeq, 4);
    repo.push(_row(_base().copyWith(rollSeq: 1), turnCount: 2));
    await _settle();
    expect(controller.state.game.rollSeq, 4);
    // A genuinely newer move is taken.
    repo.push(_row(_base().copyWith(rollSeq: 5), turnCount: 4));
    await _settle();
    expect(controller.state.game.rollSeq, 5);
  });

  test('pieces only light up once the die shows its number', () async {
    // One piece already out, so whatever comes up, something can move.
    final base = _base();
    repo.push(
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
      repo.push(_row(before, turnCount: 3));
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
      repo.push(_row(after, turnCount: 4));
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

  test('a roll no piece can use is shown, then the turn passes', () async {
    // All in the yard: a 3 can't be used. The server passes the turn.
    repo.push(_row(_base()));
    await _settle();
    repo.dice.add(3);
    await controller.rollDice();
    await _settle();
    expect(repo.sent.single.$1, 'roll');
    // Everyone sees the 3 land first, still on red's turn...
    expect(controller.state.game.lastRoll, const LudoRoll(LudoColor.red, 3));
    expect(controller.state.game.turn, LudoColor.red);
    // ...and then the turn moves on.
    await Future<void>.delayed(
      kDiceReveal + kNoMoveHold + const Duration(milliseconds: 80),
    );
    expect(controller.state.game.turn, LudoColor.yellow);
    expect(controller.state.game.hasRolled, isFalse);
  });

  test(
    'the server rolls, and the move it works out is the one that counts',
    () async {
      final base = _base();
      repo.push(
        _row(
          base.copyWith(
            tokens: {
              ...base.tokens,
              LudoColor.red: const [5, 20, -1, -1],
            },
          ),
        ),
      );
      await _settle();
      repo.dice.add(4);
      await controller.rollDice();
      await _settle();
      expect(controller.state.game.diceValue, 4);
      await Future<void>.delayed(kDiceReveal);
      await controller.selectToken(0);
      await _settle();
      expect(repo.sent.map((e) => e.$1), ['roll', 'move']);
      expect(controller.state.game.tokens[LudoColor.red], [9, 20, -1, -1]);
      expect(controller.state.game.turn, LudoColor.yellow);
      expect(controller.state.busy, isFalse);
    },
  );

  test(
    'chat history on opening is not unread and old reactions stay put',
    () async {
      repo.push(_row(_base()));
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
      expect(controller.state.reactions, isEmpty);

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

  test('offline, I finish first and the bots play on for second', () async {
    const id = 'local-podium';
    final start = LudoState.initial(const [
      LudoColor.red,
      LudoColor.green,
      LudoColor.yellow,
    ]);
    restoreLocalLudo('/ludo/$id', {
      'players': [_me, 'bot:pip', 'bot:dot'],
      'colors': ['red', 'green', 'yellow'],
      'human': _me,
      'game': start
          .copyWith(
            tokens: {
              ...start.tokens,
              LudoColor.red: [56, 56, 56, 55],
            },
            diceValue: 1,
            hasRolled: true,
            rollSeq: 1,
          )
          .toJson(),
      'turn': 9,
    });
    final local = LudoMatchController.local(repo, id, _me, localLudoSetup(id)!);
    addTearDown(local.dispose);

    // The die has long landed: move the last piece home.
    await Future<void>.delayed(kDiceReveal);
    await local.selectToken(3);
    await _settle();

    final s = local.state;
    expect(s.iFinished, isTrue);
    expect(s.myPlace, 1);
    expect(s.winnerId, _me);
    // Not over: two bots are still racing, and it's their go.
    expect(s.isActive, isTrue);
    expect(s.playingOn, isTrue);
    expect(s.game.turn, LudoColor.green);
    expect(s.isMyTurn, isFalse);
    expect(s.canRoll, isFalse);
    // Leaving now is free (and doesn't end the game for them).
    await local.leave();
  });
}
