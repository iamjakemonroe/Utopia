import 'dart:js_interop';

@JS('utopiaRender')
external _Render? get _render;

extension type _Render._(JSObject _) implements JSObject {
  external double cap();
  external double real();
  external void set(double value);
}

bool available() {
  try {
    return _render != null;
  } catch (_) {
    return false;
  }
}

double cap() => _render?.cap() ?? 1;

double screen() => _render?.real() ?? 1;

void setCap(double value) => _render?.set(value);
