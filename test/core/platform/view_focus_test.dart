import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/platform/view_focus.dart';

class _Watch with WidgetsBindingObserver {
  final seen = <ViewFocusEvent>[];

  @override
  void didChangeViewFocus(ViewFocusEvent event) => seen.add(event);
}

void main() {
  testWidgets('focus that comes before the first frame waits for it', (
    tester,
  ) async {
    final dispatcher = tester.binding.platformDispatcher;
    final original = dispatcher.onViewFocusChange;
    addTearDown(() => dispatcher.onViewFocusChange = original);
    final watch = _Watch();
    tester.binding.addObserver(watch);
    addTearDown(() => tester.binding.removeObserver(watch));

    holdViewFocusUntilFirstFrame();
    final event = ViewFocusEvent(
      viewId: tester.view.viewId,
      state: ViewFocusState.focused,
      direction: ViewFocusDirection.forward,
    );
    dispatcher.onViewFocusChange!(event);
    expect(watch.seen, isEmpty);

    await tester.pumpWidget(const SizedBox());
    expect(watch.seen, [event]);

    // After that, straight through.
    dispatcher.onViewFocusChange!(event);
    expect(watch.seen, [event, event]);
  });
}
