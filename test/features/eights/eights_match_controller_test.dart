import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/widgets/game_card_art.dart';
import 'package:utopia/features/eights/data/eights_repository.dart';
import 'package:utopia/features/eights/domain/eights_engine.dart';
import 'package:utopia/features/eights/presentation/controllers/eights_match_controller.dart';
import 'package:utopia/features/home/data/offline_game.dart';

PlayingCard c(String code) => PlayingCard.fromCode(code);

/// The server swapped for streams and answers the test drives.
class _FakeRepo extends EightsRepository {
  _FakeRepo() : super(SupabaseClient('http://localhost', 'test-key'));

  final match = StreamController<Map<String, dynamic>?>.broadcast();
  final chat = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<PlayingCard> hand = [];
  final calls = <String>[];

  @override
  Stream<Map<String, dynamic>?> watchMatch(String matchId) => match.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchChat(String matchId) => chat.stream;

  @override
  Future<List<PlayingCard>> fetchHand(String matchId, String userId) async {
    calls.add('hand');
    return hand;
  }

  @override
  Future<List<PlayingCard>> play(
    String matchId,
    PlayingCard card, {
    CardSuit? suit,
  }) async {
    calls.add('play ${card.code}${suit == null ? '' : ' ${suit.code}'}');
    hand = [...hand]..remove(card);
    return hand;
  }

  @override
  Future<List<PlayingCard>> draw(String matchId) async {
    calls.add('draw');
    hand = [...hand, c('JC')];
    return hand;
  }

  @override
  Future<void> pass(String matchId) async => calls.add('pass');
}

const _me = 'user-me';
const _them = 'user-them';

Map<String, dynamic> _row(EightsTable t, {String status = 'active'}) => {
  'id': 'm1',
  'status': status,
  'mode': 'public',
  'stake': 50,
  'players': [_me, _them],
  'missed_turns': <String, int>{},
  'state': t.toJson(),
};

EightsTable _table({
  int turn = 0,
  String top = '5S',
  List<int> counts = const [3, 3],
  int seq = 4,
}) => EightsTable(
  counts: counts,
  turn: turn,
  top: c(top),
  suit: c(top).suit,
  drawCount: 30,
  seq: seq,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeRepo repo;
  late EightsMatchController controller;

  setUp(() {
    repo = _FakeRepo()..hand = [c('KS'), c('2H'), c('8C')];
    controller = EightsMatchController(repo, 'm1', _me);
  });

  tearDown(() => controller.dispose());

  test('opening the game fetches my cards and shows what goes', () async {
    repo.match.add(_row(_table()));
    await _settle();
    await _settle();
    expect(controller.state.hand, [c('KS'), c('2H'), c('8C')]);
    expect(controller.state.isMyTurn, isTrue);
    expect(controller.state.playable, {c('KS'), c('8C')});
    expect(controller.state.canDraw, isTrue);
  });

  test('a card played shows at once, and the server confirms it', () async {
    repo.match.add(_row(_table()));
    await _settle();
    await _settle();
    final playing = controller.play(c('KS'));
    final t = controller.state.table!;
    expect(t.top, c('KS'));
    expect(t.turn, 1);
    expect(t.seq, 5);
    expect(controller.state.hand, [c('2H'), c('8C')]);
    await playing;
    expect(repo.calls, contains('play KS'));
    expect(controller.state.busy, isFalse);
  });

  test("a card that doesn't go isn't sent", () async {
    repo.match.add(_row(_table()));
    await _settle();
    await _settle();
    await controller.play(c('2H'));
    expect(repo.calls.where((x) => x.startsWith('play')), isEmpty);
  });

  test('an eight needs its suit, and sends it', () async {
    repo.match.add(_row(_table()));
    await _settle();
    await _settle();
    await controller.play(c('8C'));
    expect(repo.calls.where((x) => x.startsWith('play')), isEmpty);
    await controller.play(c('8C'), suit: CardSuit.hearts);
    expect(repo.calls, contains('play 8C H'));
    expect(controller.state.table!.suit, CardSuit.hearts);
  });

  test('an older row never takes the table back', () async {
    repo.match.add(_row(_table(seq: 4)));
    await _settle();
    await _settle();
    await controller.play(c('KS'));
    repo.match.add(_row(_table(seq: 4)));
    await _settle();
    expect(controller.state.table!.top, c('KS'));
    expect(controller.state.table!.seq, 5);
  });

  test(
    'drawing adds the card; nothing goes, so it passes on its own',
    () async {
      repo.hand = [c('2H')];
      repo.match.add(_row(_table(counts: const [1, 3])));
      await _settle();
      await _settle();
      expect(controller.state.playable, isEmpty);
      await controller.draw();
      expect(controller.state.hand, [c('2H'), c('JC')]);
      expect(controller.state.canPass, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(repo.calls.last, 'pass');
      expect(controller.state.table!.turn, 1);
    },
  );

  test('not my turn: nothing to play or draw', () async {
    repo.match.add(_row(_table(turn: 1)));
    await _settle();
    await _settle();
    expect(controller.state.isMyTurn, isFalse);
    expect(controller.state.playable, isEmpty);
    expect(controller.state.canDraw, isFalse);
  });

  test('my count changing under me (a timeout) fetches my cards', () async {
    repo.match.add(_row(_table()));
    await _settle();
    await _settle();
    final before = repo.calls.where((x) => x == 'hand').length;
    repo.hand = [...repo.hand, c('4D')];
    repo.match.add(_row(_table(turn: 1, counts: const [4, 3], seq: 5)));
    await _settle();
    await _settle();
    expect(repo.calls.where((x) => x == 'hand').length, before + 1);
    expect(controller.state.hand.length, 4);
  });

  test('offline: saved as it goes, and back as it was after the app '
      'closes', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OfflineGameStore(await SharedPreferences.getInstance());
    final repo = _FakeRepo();
    final id = startLocalEights(
      const LocalEightsSetup(playerIds: [_me, 'bot:pip'], humanId: _me),
    );
    final first = EightsMatchController.local(
      repo,
      id,
      _me,
      localEightsSetup(id)!,
      random: Random(5),
      store: store,
    );
    final saved = store.load()!;
    expect(saved.kind, GameKind.eights);
    expect(saved.resumeRoute, '/eights/$id');
    final hand = [for (final card in first.state.hand) card.code];
    final top = first.state.table!.top.code;
    first.dispose();
    expect(store.load(), isNull, reason: 'leaving on purpose ends it');

    // Had the app closed instead, the save sets the same table back up.
    restoreLocalEights(saved.route, saved.data);
    final again = EightsMatchController.local(
      repo,
      id,
      _me,
      localEightsSetup(id)!,
      store: store,
    );
    addTearDown(again.dispose);
    expect([for (final card in again.state.hand) card.code], hand);
    expect(again.state.table!.top.code, top);
  });

  test('offline: the game is dealt and the bots play', () async {
    final id = startLocalEights(
      const LocalEightsSetup(
        playerIds: [_me, 'bot:pip', 'bot:momo'],
        humanId: _me,
      ),
    );
    final local = EightsMatchController.local(
      repo,
      id,
      _me,
      localEightsSetup(id)!,
      random: Random(3),
    );
    addTearDown(local.dispose);
    expect(local.state.table!.counts, [5, 5, 5]);
    expect(local.state.hand.length, 5);
    expect(local.state.isLocal, isTrue);
    // Play until it's my turn, then play (or draw): the game moves on.
    final seq = local.state.table!.seq;
    if (local.state.isMyTurn) {
      final card = local.state.playable.firstOrNull;
      if (card != null) {
        await local.play(card, suit: card.isEight ? CardSuit.hearts : null);
      } else {
        await local.draw();
      }
      expect(local.state.table!.seq, greaterThan(seq));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 3600));
      expect(local.state.table!.seq, greaterThan(seq));
    }
  });
}
