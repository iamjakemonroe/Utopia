import 'dart:typed_data';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/chat/domain/voice_note.dart';
import 'package:utopia/features/chat/presentation/voice_notes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/profiles/profile_providers.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/guess_doodle/data/doodle_game_repository.dart';
import 'package:utopia/features/guess_doodle/domain/doodle_game.dart';
import 'package:utopia/features/guess_doodle/presentation/doodle_game_controller.dart';
import 'package:utopia/features/guess_doodle/presentation/guess_doodle_screen.dart';

final _me = User(
  id: 'me',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime(2026).toIso8601String(),
);

class _FakeLink implements DoodleInkLink {
  void Function(String, Map<String, dynamic>)? onEvent;
  final sent = <(String, Map<String, dynamic>)>[];
  bool closed = false;

  @override
  void listen(void Function(String, Map<String, dynamic>) onEvent) =>
      this.onEvent = onEvent;

  @override
  void send(String event, Map<String, dynamic> data) => sent.add((event, data));

  @override
  Future<void> close() async => closed = true;
}

class _FakeRepo implements DoodleGameRepository {
  final voices = <String>[];

  @override
  Future<void> uploadVoice(String path, Uint8List bytes) async {}

  @override
  Future<void> sendVoice(String gameId, VoiceNote note) async =>
      voices.add(note.encode());
  final game = StreamController<DoodleGame?>.broadcast();
  final players = StreamController<List<DoodlePlayer>>.broadcast();
  final messages = StreamController<List<DoodleMessage>>.broadcast();
  final link = _FakeLink();

  final calls = <String>[];
  final guesses = <String>[];
  final saved = <Map<String, Object?>>[];
  ({GuessResult result, int points}) nextGuess = (
    result: GuessResult.chat,
    points: 0,
  );
  ({int turn, List<String> choices, String? word}) secretValue = (
    turn: -1,
    choices: const [],
    word: null,
  );

  @override
  Stream<DoodleGame?> watchGame(String gameId) => game.stream;

  @override
  Stream<List<DoodlePlayer>> watchPlayers(String gameId) => players.stream;

  @override
  Stream<List<DoodleMessage>> watchMessages(String gameId) => messages.stream;

  @override
  DoodleInkLink inkLink(String gameId) => link;

  // A reload finds the players the test last sent.
  List<DoodlePlayer> _lastPlayers = const [];
  late final _keepLast = players.stream.listen((p) => _lastPlayers = p);

  @override
  Future<List<DoodlePlayer>> fetchPlayers(String gameId) async {
    _keepLast;
    return List.of(_lastPlayers);
  }

  @override
  Future<DateTime?> tick(String gameId) async => DateTime.now();

  @override
  Future<({int turn, List<String> choices, String? word})> secret(
    String gameId,
  ) async => secretValue;

  @override
  Future<void> start(String gameId) async => calls.add('start');

  @override
  Future<void> choose(String gameId, int index) async =>
      calls.add('choose $index');

  @override
  Future<({GuessResult result, int points})> guess(
    String gameId,
    String text,
  ) async {
    guesses.add(text);
    return nextGuess;
  }

  @override
  Future<void> leave(String gameId) async => calls.add('leave');

  @override
  Future<int> addStroke({
    required String gameId,
    required int turn,
    required int epoch,
    required Map<String, Object?> op,
  }) async {
    saved.add(op);
    return saved.length;
  }

  @override
  Future<int> undo(String gameId) async {
    calls.add('undo');
    return 0;
  }

  @override
  Future<int> clear(String gameId) async {
    calls.add('clear');
    return 0;
  }

  /// The canvas as saved, and (when set) a load held back until the test
  /// lets it through: it returns the canvas as it was when it was asked.
  List<Map<String, Object?>> savedStrokes = const [];
  Completer<void>? holdStrokes;

  @override
  Future<List<Map<String, Object?>>> strokes({
    required String gameId,
    required int turn,
    required int epoch,
  }) async {
    final rows = List.of(savedStrokes);
    calls.add('strokes');
    await holdStrokes?.future;
    return rows;
  }

  @override
  Future<String> quickPlay() async => 'g1';

  @override
  Future<(String, String)> create({
    required int rounds,
    required int drawSeconds,
  }) async => ('g1', 'ABC234');

  @override
  Future<String> join(String code) async => 'g1';

  @override
  Future<String?> myGame() async => null;
}

DoodleGame _game({
  DoodlePhase phase = DoodlePhase.lobby,
  String host = 'me',
  String? drawer,
  int turn = 1,
  String? mask,
  String? revealed,
  bool public = false,
  int rev = 0,
}) => DoodleGame(
  id: 'g1',
  code: 'ABC234',
  isPublic: public,
  hostId: host,
  phase: phase,
  rounds: 3,
  drawSeconds: 80,
  maxPlayers: 8,
  round: 1,
  turn: turn,
  drawerId: drawer,
  phaseEndsAt: phase == DoodlePhase.lobby
      ? null
      : DateTime.now().add(const Duration(seconds: 60)),
  wordMask: mask,
  revealedWord: revealed,
  canvasEpoch: 0,
  canvasRev: rev,
  winnerIds: const [],
);

DoodlePlayer _player(
  String id, {
  int score = 0,
  int points = 0,
  int guessed = 0,
  int seq = 1,
}) => DoodlePlayer(
  userId: id,
  score: score,
  turnPoints: points,
  guessedTurn: guessed,
  joinSeq: seq,
  left: false,
);

/// Voice notes that never play (tests have no audio, nor a server to
/// fetch them from).
class _QuietPlayback extends StateNotifier<VoicePlaybackState>
    implements VoicePlayback {
  _QuietPlayback() : super(const VoicePlaybackState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<_FakeRepo> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        doodleGameRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(_me),
        profileByIdProvider.overrideWith(
          (ref, id) async => {
            'id': id,
            'display_name': id == 'me' ? 'Jake' : 'Mia',
          },
        ),
        publicCoinsProvider.overrideWith((ref, id) async => null),
        voicePlaybackProvider.overrideWith((ref) => _QuietPlayback()),
      ],
      child: const MaterialApp(home: GuessDoodleScreen(gameId: 'g1')),
    ),
  );
  await tester.pump();
  return repo;
}

/// Lets streams deliver and animations move on (the screen has timers and
/// a ticking clock, so it never fully settles).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('the host starts a private game once a friend is in', (
    tester,
  ) async {
    final repo = await _pump(tester);
    repo.game.add(_game());
    repo.players.add([_player('me')]);
    await _settle(tester);
    expect(find.text('Invite friends'), findsOneWidget);
    expect(find.text('Waiting for friends'), findsOneWidget);
    expect(find.text('1 of 8 players'), findsOneWidget);

    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    await _settle(tester);
    expect(find.text('2 of 8 players'), findsOneWidget);
    await tester.tap(find.text('Start game'));
    await _settle(tester);
    expect(repo.calls, contains('start'));
    await _finish(tester);
  });

  testWidgets('the drawer picks one of three words', (tester) async {
    final repo = await _pump(tester);
    repo.secretValue = (
      turn: 1,
      choices: const ['cat', 'rocket', 'jollof'],
      word: null,
    );
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(_game(phase: DoodlePhase.choosing, drawer: 'me'));
    await _settle(tester);
    expect(find.text('Pick a word to draw'), findsOneWidget);
    await tester.tap(find.text('ROCKET'));
    await _settle(tester);
    expect(repo.calls, contains('choose 1'));
    await _finish(tester);
  });

  testWidgets('others wait while the drawer picks', (tester) async {
    final repo = await _pump(tester);
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(_game(phase: DoodlePhase.choosing, drawer: 'mia'));
    await _settle(tester);
    expect(find.text('Mia is picking a word'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('a guess goes to the server; a right one celebrates', (
    tester,
  ) async {
    final repo = await _pump(tester);
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(
      _game(phase: DoodlePhase.drawing, drawer: 'mia', mask: '______'),
    );
    await _settle(tester);
    expect(find.text('6'), findsOneWidget, reason: 'the letter count');
    expect(find.text('Type your guess'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'banana');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await _settle(tester);
    expect(repo.guesses, ['banana']);

    repo.nextGuess = (result: GuessResult.correct, points: 340);
    repo.secretValue = (turn: 1, choices: const [], word: 'rocket');
    await tester.enterText(find.byType(TextField), 'rocket');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await _settle(tester);
    expect(find.text('You got it!'), findsOneWidget);
    expect(find.text('+340'), findsOneWidget);

    // Once you've guessed, the word shows and chat is for those who got it.
    repo.players.add([_player('me', guessed: 1), _player('mia', seq: 2)]);
    repo.game.add(
      _game(phase: DoodlePhase.drawing, drawer: 'mia', mask: '______', rev: 0),
    );
    await _settle(tester);
    expect(find.text('ROCKET'), findsOneWidget);
    expect(find.text('Chat with players who got it'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets("the drawer's strokes go out live and are saved", (tester) async {
    final repo = await _pump(tester);
    repo.secretValue = (turn: 1, choices: const [], word: 'cat');
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(_game(phase: DoodlePhase.drawing, drawer: 'me', mask: '___'));
    await _settle(tester);
    expect(find.text('CAT'), findsOneWidget);
    // Every tool, named under it.
    for (final tool in ['Brush', 'Fill', 'Line', 'Box', 'Circle', 'Eraser']) {
      expect(find.text(tool), findsOneWidget, reason: tool);
    }

    final canvas = find.byType(Listener).first;
    final center = tester.getCenter(canvas);
    final gesture = await tester.startGesture(center);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveBy(const Offset(6, 4));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await _settle(tester);

    final events = [for (final (e, _) in repo.link.sent) e];
    expect(events, contains('ink'));
    expect(events.last, 'end');
    expect(repo.saved, hasLength(1));
    expect((repo.saved.single['p'] as List).length, greaterThan(9));

    await tester.tap(find.byTooltip('Undo'));
    await _settle(tester);
    expect(repo.calls, contains('undo'));
    expect(repo.link.sent.last.$1, 'undo');
    await _finish(tester);
  });

  testWidgets('voice notes: between turns, and once you know the word', (
    tester,
  ) async {
    final repo = await _pump(tester);
    final mic = find.byIcon(Icons.mic_rounded);
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(_game());
    await _settle(tester);
    expect(mic, findsOneWidget, reason: 'the lobby: anyone talks');

    // Mia draws; still guessing, I can't talk (I might say the word).
    repo.game.add(
      _game(phase: DoodlePhase.drawing, drawer: 'mia', mask: '______'),
    );
    await _settle(tester);
    expect(mic, findsNothing);

    // Guessed it: now I can, with Mia and the others who know it.
    repo.players.add([_player('me', guessed: 1), _player('mia', seq: 2)]);
    await _settle(tester);
    expect(mic, findsOneWidget);

    // A note arrives in the chat as a voice bubble.
    repo.messages.add([
      DoodleMessage(
        id: 1,
        senderId: 'mia',
        turn: 1,
        kind: DoodleMessageKind.voice,
        body: 'voice:g1/0b5c3a5e-6a77-4d1c-9a0e-2f1d7e3c9b11.m4a|3200|1234567',
        guessedOnly: true,
      ),
    ]);
    await _settle(tester);
    expect(find.text('0:03'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('the drawer pours paint and drags out a box', (tester) async {
    final repo = await _pump(tester);
    repo.secretValue = (turn: 1, choices: const [], word: 'cat');
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(_game(phase: DoodlePhase.drawing, drawer: 'me', mask: '___'));
    await _settle(tester);

    final canvas = find.byType(Listener).first;
    final center = tester.getCenter(canvas);

    // The box: dragged out, then sent whole (nothing streamed meanwhile).
    await tester.tap(find.text('Box'));
    await tester.pump();
    final gesture = await tester.startGesture(center - const Offset(40, 40));
    for (var i = 1; i <= 8; i++) {
      await gesture.moveBy(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await _settle(tester);
    expect([for (final (e, _) in repo.link.sent) e], ['end']);
    expect((repo.saved.single['p'] as List).length, 9 * 3);

    // Fill: one tap pours, and it's sent and saved like a stroke.
    await tester.tap(find.text('Fill'));
    await tester.pump();
    await tester.tapAt(center);
    await _settle(tester);
    expect(repo.link.sent.last.$1, 'spill');
    expect(repo.saved.last['t'], 'b');
    await _finish(tester);
  });

  testWidgets("guessers see the drawer's strokes arrive", (tester) async {
    final repo = await _pump(tester);
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(
      _game(phase: DoodlePhase.drawing, drawer: 'mia', mask: '___'),
    );
    await _settle(tester);
    repo.link.onEvent!('end', {
      'by': 'mia',
      'turn': 1,
      'epoch': 0,
      'sid': 1,
      'op': {
        't': 's',
        'tool': 'marker',
        'c': 0xFF1F1E1B,
        'w': 12,
        'p': [100, 100, 12, 300, 300, 12],
      },
    });
    // From someone who isn't drawing: ignored.
    repo.link.onEvent!('end', {
      'by': 'me',
      'turn': 1,
      'epoch': 0,
      'sid': 2,
      'op': {
        't': 's',
        'tool': 'marker',
        'c': 0xFF1F1E1B,
        'w': 12,
        'p': [1, 1, 12],
      },
    });
    await _settle(tester);
    final ink = ProviderScope.containerOf(
      tester.element(find.byType(GuessDoodleScreen)),
    ).read(doodleGameControllerProvider('g1').notifier).ink;
    expect(ink.canUndo, isTrue);
    ink.undo();
    expect(ink.canUndo, isFalse, reason: "only the drawer's stroke landed");
    await _finish(tester);
  });

  testWidgets('a canvas loaded while the drawer undoes never brings it back', (
    tester,
  ) async {
    final repo = await _pump(tester);
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(
      _game(phase: DoodlePhase.drawing, drawer: 'mia', mask: '___'),
    );
    await _settle(tester);
    final ink = ProviderScope.containerOf(
      tester.element(find.byType(GuessDoodleScreen)),
    ).read(doodleGameControllerProvider('g1').notifier).ink;

    // Mia pours red over the empty page and draws a white line...
    const spill = {'t': 'b', 'x': 50, 'y': 50, 'c': 0xFFD9493E};
    const line = {
      't': 's',
      'tool': 'marker',
      'c': 0xFFFFFFFF,
      'w': 12,
      'p': [100, 100, 12, 300, 300, 12],
    };
    repo.link.onEvent!('spill', {
      'by': 'mia',
      'turn': 1,
      'epoch': 0,
      'op': spill,
    });
    repo.link.onEvent!('end', {
      'by': 'mia',
      'turn': 1,
      'epoch': 0,
      'sid': 1,
      'op': line,
    });
    await _settle(tester);
    // ...the game says more happened than came through, so this phone
    // loads the canvas from the server...
    repo.savedStrokes = [spill, line];
    repo.holdStrokes = Completer();
    repo.game.add(
      _game(phase: DoodlePhase.drawing, drawer: 'mia', mask: '___', rev: 3),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    expect(repo.calls, contains('strokes'));
    // ...and while it loads, she undoes both.
    repo.link.onEvent!('undo', {'by': 'mia', 'turn': 1, 'epoch': 0});
    repo.link.onEvent!('undo', {'by': 'mia', 'turn': 1, 'epoch': 0});
    repo.holdStrokes!.complete();
    repo.holdStrokes = null;
    await _settle(tester);
    expect(ink.isEmpty, isTrue, reason: 'what she undid stays gone');

    // A load with nothing happening meanwhile still puts the canvas right.
    repo.savedStrokes = [line];
    repo.game.add(
      _game(phase: DoodlePhase.drawing, drawer: 'mia', mask: '___', rev: 9),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    await _settle(tester);
    expect(ink.canUndo, isTrue);
    ink.undo();
    expect(ink.canUndo, isFalse, reason: 'exactly the saved canvas');
    expect(ink.rev, 9);
    await _finish(tester);
  });

  testWidgets('the reveal shows the word and the points', (tester) async {
    final repo = await _pump(tester);
    repo.players.add([
      _player('me', score: 390, points: 390, guessed: 1),
      _player('mia', seq: 2, score: 50, points: 50),
    ]);
    repo.game.add(
      _game(phase: DoodlePhase.reveal, drawer: 'mia', revealed: 'rocket'),
    );
    await _settle(tester);
    expect(find.text('The word was'), findsOneWidget);
    expect(find.text('+390'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('sending keeps the keyboard up; tapping outside puts it away', (
    tester,
  ) async {
    final repo = await _pump(tester);
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(
      _game(phase: DoodlePhase.drawing, drawer: 'mia', mask: '______'),
    );
    await _settle(tester);
    bool typing() => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;

    await tester.tap(find.byType(TextField));
    await _settle(tester);
    expect(typing(), isTrue);

    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _settle(tester);
    expect(repo.guesses, ['banana']);
    expect(typing(), isTrue, reason: 'ready for the next guess');

    // A tap on the drawing.
    await tester.tapAt(tester.getCenter(find.byType(Listener).first));
    await _settle(tester);
    expect(typing(), isFalse);
    await _finish(tester);
  });

  testWidgets('leaving mid-game asks first, then leaves', (tester) async {
    final repo = await _pump(tester);
    repo.players.add([_player('me'), _player('mia', seq: 2)]);
    repo.game.add(
      _game(phase: DoodlePhase.drawing, drawer: 'mia', mask: '___'),
    );
    await _settle(tester);
    await tester.tap(find.byTooltip('Leave'));
    await _settle(tester);
    expect(find.text('Leave the game?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await _settle(tester);
    expect(repo.calls, isNot(contains('leave')));

    await tester.tap(find.byTooltip('Leave'));
    await _settle(tester);
    await tester.tap(find.text('Leave'));
    await _settle(tester);
    expect(repo.calls, contains('leave'));
    await _finish(tester);
  });
}
