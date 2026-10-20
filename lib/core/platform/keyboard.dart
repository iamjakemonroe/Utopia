import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether a field may take focus on its own (as it opens, as a round
/// starts) rather than from a tap. Not in a browser: a phone's browser only
/// opens its keyboard for a tap, and a field focused without one keeps the
/// keyboard shut to every tap after (Flutter's web engine opens it only
/// when the field newly takes focus).
const bool canFocusWithoutTap = !kIsWeb;

/// Focuses [node]'s field on its own, where that brings the keyboard up
/// (in the apps: see [canFocusWithoutTap]).
void focusIfAllowed(FocusNode node) {
  if (canFocusWithoutTap) node.requestFocus();
}

/// Brings the keyboard up for [node]'s field, from a tap: focuses it, or,
/// if it's focused already with the keyboard put away (Android's back key,
/// a swipe down), shows the keyboard again (asking a focused field for
/// focus does nothing).
void openKeyboard(FocusNode node) {
  if (node.hasFocus) {
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  } else {
    node.requestFocus();
  }
}
