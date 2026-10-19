import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// The browser's sound: one audio context for the whole app (a browser
/// allows only a few, and audioplayers made one per player), the effects
/// decoded once and played from memory with no delay, and the music a
/// looping buffer through its own volume. A browser keeps sound off until
/// the page is touched: the first touch or key turns it on (from the
/// browser's own event, the only place Safari allows it).
class WebAudio {
  WebAudio._();

  static final instance = WebAudio._();

  late final music = WebMusic(this);

  web.AudioContext? _context;
  final _buffers = <String, Future<web.AudioBuffer?>>{};
  Iterable<String> _preload = const [];
  bool _unlocked = false;

  web.AudioContext get context {
    final existing = _context;
    if (existing != null) return existing;
    final context = _context = web.AudioContext();
    void unlock(web.Event _) {
      if (context.state != 'running') context.resume();
      if (!_unlocked) {
        _unlocked = true;
        _preload.forEach(buffer);
      }
    }

    final listener = unlock.toJS;
    for (final type in ['pointerdown', 'pointerup', 'touchend', 'keydown']) {
      web.document.addEventListener(
        type,
        listener,
        web.AddEventListenerOptions(capture: true, passive: true),
      );
    }
    return context;
  }

  bool get _running => context.state == 'running';

  /// [asset] decoded (once), or null if it can't be.
  Future<web.AudioBuffer?> buffer(String asset) =>
      _buffers.putIfAbsent(asset, () async {
        try {
          final data = await rootBundle.load(asset);
          // Decoding takes the bytes over: it gets its own copy.
          final bytes = Uint8List.fromList(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          return await context.decodeAudioData(bytes.buffer.toJS).toDart;
        } catch (_) {
          unawaited(_buffers.remove(asset));
          return null;
        }
      });

  /// Decodes [assets] once the page is first touched, so each effect plays
  /// the moment it's asked for.
  void preloadOnUnlock(Iterable<String> assets) {
    _preload = assets;
    context;
    if (_unlocked) assets.forEach(buffer);
  }

  /// Plays [asset] once at [volume]. Not before the first touch: they'd
  /// all play at once when sound comes on.
  void effect(String asset, double volume) {
    if (!_running) return;
    buffer(asset).then((buffer) {
      if (buffer == null || !_running) return;
      final ctx = context;
      final gain = ctx.createGain()..gain.value = volume;
      final source = ctx.createBufferSource()..buffer = buffer;
      source.connect(gain);
      gain.connect(ctx.destination);
      source.start();
    });
  }
}

/// The music: one track at a time, looping, keeping its place when paused.
class WebMusic {
  WebMusic(this._audio);

  final WebAudio _audio;
  web.AudioBufferSourceNode? _source;
  web.GainNode? _gain;
  String? _asset;
  double _volume = 1;

  /// Where in the track it was paused, and the context time it started at
  /// (as if from the beginning) while playing.
  double _offset = 0;
  double _startedAt = 0;
  double _length = 0;

  /// Bumped by every play, resume and pause, so a slow load can't start an
  /// old track over a newer one.
  int _turn = 0;

  String? get asset => _asset;

  double get volume => _volume;

  void setVolume(double volume) {
    _volume = volume;
    _gain?.gain.value = volume;
  }

  /// [asset] from the start.
  Future<void> play(String asset) {
    _asset = asset;
    _offset = 0;
    return resume();
  }

  /// The track from where it was paused.
  Future<void> resume() async {
    final asset = _asset;
    if (asset == null) return;
    final turn = ++_turn;
    final buffer = await _audio.buffer(asset);
    if (buffer == null || turn != _turn) return;
    _stop();
    final ctx = _audio.context;
    final gain = _gain ??= ctx.createGain()..connect(ctx.destination);
    gain.gain.value = _volume;
    _length = buffer.duration;
    final offset = _length > 0 ? _offset % _length : 0.0;
    final source = ctx.createBufferSource()
      ..buffer = buffer
      ..loop = true;
    source.connect(gain);
    source.start(0, offset);
    _startedAt = ctx.currentTime - offset;
    _source = source;
  }

  void pause() {
    _turn++;
    if (_source == null) return;
    final played = _audio.context.currentTime - _startedAt;
    _offset = _length > 0 ? played % _length : 0;
    _stop();
  }

  void _stop() {
    final source = _source;
    _source = null;
    if (source == null) return;
    try {
      source.stop();
      source.disconnect();
    } catch (_) {}
  }
}
