import 'package:flutter/foundation.dart';

bool available() => false;

bool touch() => false;

ValueNotifier<bool> watch() => ValueNotifier(false);

void enter() {}

void exit() {}

void onNextTouch(void Function() action) {}
