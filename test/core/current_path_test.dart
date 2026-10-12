import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:utopia/core/router/app_router.dart';

void main() {
  testWidgets('currentPath follows pushed screens, not just the base', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(path: '/settings', builder: (_, _) => const Text('settings')),
        GoRoute(path: '/chess/:id', builder: (_, _) => const Text('game')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(currentPath(router), '/home');

    router.push('/settings');
    await tester.pumpAndSettle();
    expect(currentPath(router), '/settings');
    // The raw uri is what used to fool the checks.
    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');

    router.push('/chess/abc');
    await tester.pumpAndSettle();
    expect(currentPath(router), '/chess/abc');

    router.pop();
    router.pop();
    await tester.pumpAndSettle();
    expect(currentPath(router), '/home');
  });
}
