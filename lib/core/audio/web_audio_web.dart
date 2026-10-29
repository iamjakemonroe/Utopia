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
///
/// The audio context is made at that first touch, not before. Making one
/// holds the page up while the browser starts its sound: Chrome took 1 to
/// 3.6 seconds the first time, freezing the welcome screen as it opened.
/// Until then, sounds are decoded on an offline context (no speakers, made
/// at once), and Chrome's sound is started in the background ([_warm]), so
/// by the first touch making the context takes a moment.
class WebAudio {
  WebAudio._();

  static final instance = WebAudio._();

  late final music = WebMusic(this);

  web.AudioContext? _context;
  final _buffers = <String, Future<web.AudioBuffer?>>{};
  Iterable<String> _preload = const [];
  bool _unlocked = false;
  final _firstTouch = Completer<void>();
  final _touched = <void Function()>[];
  bool _listening = false;

  /// Decodes sounds before there's an audio context (and after: one
  /// decoder for all). Buffers play in any context.
  late final web.OfflineAudioContext _decoder = web.OfflineAudioContext(
    2.toJS,
    1,
    48000,
  );

  /// The audio context: made at the first touch (see the class), and only
  /// used from then on.
  web.AudioContext get context => _context ??= web.AudioContext();

  /// Waits for the page's first touch, from then on sound can play.
  Future<void> get touched => _firstTouch.future;

  /// Listens for the first touch or key (and every one after, for
  /// [onTouch]), and starts warming Chrome's sound meanwhile.
  void _listen() {
    if (_listening) return;
    _listening = true;
    void unlock(web.Event _) {
      final context = this.context;
      if (context.state != 'running') context.resume();
      for (final action in List.of(_touched)) {
        action();
      }
      if (!_unlocked) {
        _unlocked = true;
        _firstTouch.complete();
        unawaited(_trickle());
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
    _warm();
  }

  /// Starts Chrome's (and Edge's) sound without holding the page up: asking
  /// for the list of audio devices (with no permission: no names, and no
  /// prompt) starts what making an audio context would otherwise wait for,
  /// in the background. A muted clip can't: before a touch it's refused.
  /// Only there: Safari makes a context at once.
  void _warm() {
    if (web.window.navigator.vendor != 'Google Inc.') return;
    try {
      unawaited(
        web.window.navigator.mediaDevices.enumerateDevices().toDart.then(
          (_) {},
          onError: (_) {},
        ),
      );
    } catch (_) {
      // No warming: the context is made at the first touch all the same.
    }
  }

  bool get _running => _context?.state == 'running';

  /// After the first touch, sound the browser has put to sleep since (Safari
  /// after a call or another app's sound, a long pause) is woken as soon as
  /// something plays, not only at the next touch: the Halloween world's
  /// thunder and screams come with no touch at all.
  Future<void> _wake() async {
    if (!_unlocked || _running) return;
    try {
      await context.resume().toDart;
    } catch (_) {
      // Not allowed yet: the next touch wakes it.
    }
  }

  /// [asset] decoded (once), or null if it can't be.
  Future<web.AudioBuffer?> buffer(String asset) =>
      _buffers.putIfAbsent(asset, () async {
        try {
          final data = await rootBundle.load(asset);
          // Decoding takes the bytes over: it gets its own copy.
          final bytes = Uint8List.fromList(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          return await _decoder.decodeAudioData(bytes.buffer.toJS).toDart;
        } catch (_) {
          unawaited(_buffers.remove(asset));
          return null;
        }
      });

  /// Fetches and decodes [asset] now, so it plays the moment it's asked
  /// for (one that isn't preloaded for everyone).
  void warm(String asset) => unawaited(buffer(asset));

  /// Runs [action] on every touch or key (from the browser's own event,
  /// where it may turn sound on), until [offTouch].
  void onTouch(void Function() action) {
    _listen();
    if (!_touched.contains(action)) _touched.add(action);
  }

  void offTouch(void Function() action) => _touched.remove(action);

  /// Decodes [assets] once the page is first touched, so each effect plays
  /// the moment it's asked for.
  void preloadOnUnlock(Iterable<String> assets) {
    _preload = assets;
    _listen();
    if (_unlocked) unawaited(_trickle());
  }

  bool _trickling = false;

  /// The effects, fetched and decoded one at a time, starting a moment
  /// after the first touch. All at once (60 files, 8 MB) they held up
  /// whatever that touch was for (signing in, typing a room code) while
  /// the page took them all in. One asked for before its turn is fetched
  /// then ([buffer]).
  Future<void> _trickle() async {
    if (_trickling) return;
    _trickling = true;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    for (final asset in _preload.toList()) {
      await buffer(asset);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  /// Loops [asset] at [volume], fading in, until the loop is stopped.
  WebLoop loop(String asset, double volume) {
    final loop = WebLoop._();
    if (!_running) return loop;
    buffer(asset).then((buffer) {
      if (buffer == null || !_running || loop._stopped) return;
      final ctx = context;
      final now = ctx.currentTime;
      final gain = ctx.createGain();
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(volume, now + 0.7);
      final source = ctx.createBufferSource()
        ..buffer = buffer
        ..loop = true;
      source.connect(gain);
      gain.connect(ctx.destination);
      source.start();
      loop
        .._context = ctx
        .._source = source
        .._gain = gain;
    });
    return loop;
  }

  /// Plays [asset] once at [volume]. Not before the first touch: they'd
  /// all play at once when sound comes on.
  void effect(String asset, double volume) {
    if (!_unlocked) return;
    final awake = _wake();
    buffer(asset).then((buffer) async {
      await awake;
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

/// A sound looping until [stop] (a hologram's aura), faded in and out.
class WebLoop {
  WebLoop._();

  bool _stopped = false;
  web.AudioContext? _context;
  web.AudioBufferSourceNode? _source;
  web.GainNode? _gain;

  /// Fades it out and ends it (before it's begun: it never does).
  void stop() {
    if (_stopped) return;
    _stopped = true;
    final ctx = _context;
    final gain = _gain;
    final source = _source;
    if (ctx == null || gain == null || source == null) return;
    final now = ctx.currentTime;
    gain.gain.cancelScheduledValues(now);
    gain.gain.setValueAtTime(gain.gain.value, now);
    gain.gain.linearRampToValueAtTime(0, now + 0.3);
    source.stop(now + 0.35);
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
    final awake = _audio._wake();
    final buffer = await _audio.buffer(asset);
    await awake;
    // Before the first touch it waits for it: there's no context yet.
    await _audio.touched;
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
