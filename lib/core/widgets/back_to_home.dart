import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back to the previous screen, or home when this screen was opened on its
/// own (like a lobby reached from "Play again"), so nobody gets stuck.
void goBackOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

/// An app bar back button that never leads nowhere.
class BackOrHomeButton extends StatelessWidget {
  const BackOrHomeButton({super.key});

  @override
  Widget build(BuildContext context) =>
      BackButton(onPressed: () => goBackOrHome(context));
}

/// Makes the system back gesture behave like [BackOrHomeButton].
class BackToHomeScope extends StatelessWidget {
  const BackToHomeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: child,
    );
  }
}
