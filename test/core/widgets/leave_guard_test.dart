import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utopia/core/widgets/leave_guard.dart';

/// A game screen with the guard: [playing] says whether leaving costs
/// anything; asking counts in [asked] and, when [sayYes], leaves.
class _Game extends StatefulWidget {
  const _Game({
    required this.playing,
    required this.sayYes,
    required this.asked,
  });

  final bool playing;
  final bool sayYes;
  final List<int> asked;

  @override
  State<_Game> createState() => _GameState();
}

class _GameState extends State<_Game> {
  Future<void> _ask() async {
    widget.asked.add(1);
    if (!widget.sayYes) return;
    LeaveGuard.release();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) => LeaveGuard(
    canLeave: !widget.playing,
    onAsk: _ask,
    child: const Text('game'),
  );
}

Future<GoRouter> _open(
  WidgetTester tester, {
  required bool playing,
  required bool sayYes,
  required List<int> asked,
}) async {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      GoRoute(path: '/elsewhere', builder: (_, _) => const Text('elsewhere')),
      GoRoute(
        path: '/game',
        onExit: LeaveGuard.onExit,
        builder: (_, _) =>
            _Game(playing: playing, sayYes: sayYes, asked: asked),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  router.push('/game');
  await tester.pumpAndSettle();
  expect(find.text('game'), findsOneWidget);
  return router;
}

void main() {
  testWidgets("the browser's Back in a game asks, and stays", (tester) async {
    final asked = <int>[];
    final router = await _open(
      tester,
      playing: true,
      sayYes: false,
      asked: asked,
    );
    // What the browser's Back does: the address changes underneath.
    router.go('/elsewhere');
    await tester.pumpAndSettle();
    expect(asked, [1]);
    expect(find.text('game'), findsOneWidget);
  });

  testWidgets("the app's back (a swipe, Android's button) asks too", (
    tester,
  ) async {
    final asked = <int>[];
    await _open(tester, playing: true, sayYes: false, asked: asked);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(asked, [1]);
    expect(find.text('game'), findsOneWidget);
  });

  testWidgets('saying yes leaves', (tester) async {
    final asked = <int>[];
    final router = await _open(
      tester,
      playing: true,
      sayYes: true,
      asked: asked,
    );
    router.go('/elsewhere');
    await tester.pumpAndSettle();
    expect(asked, [1]);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a game that is over just goes', (tester) async {
    final asked = <int>[];
    final router = await _open(
      tester,
      playing: false,
      sayYes: false,
      asked: asked,
    );
    router.go('/elsewhere');
    await tester.pumpAndSettle();
    expect(asked, isEmpty);
    expect(find.text('elsewhere'), findsOneWidget);
  });
}
