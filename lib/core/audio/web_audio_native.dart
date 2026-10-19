/// The browser's sound (see web_audio_web.dart). Phones play through
/// audioplayers instead, so this is never used there.
class WebAudio {
  WebAudio._();

  static final instance = WebAudio._();

  final music = WebMusic();

  void effect(String asset, double volume) {}

  void preloadOnUnlock(Iterable<String> assets) {}
}

class WebMusic {
  String? get asset => null;

  double get volume => 0;

  void setVolume(double volume) {}

  Future<void> play(String asset) async {}

  Future<void> resume() async {}

  void pause() {}
}
