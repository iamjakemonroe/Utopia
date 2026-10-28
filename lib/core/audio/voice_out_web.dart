import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_audio.dart';

/// Plays voice notes in the browser, through one audio element kept for
/// the whole visit.
///
/// Safari only lets a page start sound by itself from an element a touch
/// has already started, and audioplayers made a new element (through an
/// audio context of its own, which Safari keeps asleep) for every note: a
/// note that arrived mid-game played to no one on an iPhone or iPad. So
/// the page's first touches start this element on a moment of silence,
/// and every note after plays on it, tapped or not. An element also plays
/// with an iPhone's silent switch on, as a message's sound does (the
/// effects' audio context doesn't).
class VoiceOut {
  VoiceOut() {
    final element = _element;
    _subs = [
      element.onTimeUpdate.listen((_) {
        if (_mine) {
          _position.add(
            Duration(milliseconds: (element.currentTime * 1000).round()),
          );
        }
      }),
      element.onEnded.listen((_) => _end()),
      element.onError.listen((_) => _end()),
    ];
  }

  static web.HTMLAudioElement? _shared;
  static bool _unlocked = false;

  /// Whose note is on the element (none: the silence, or nothing).
  static VoiceOut? _owner;

  static web.HTMLAudioElement get _element => _shared ??= _make();

  /// Makes the element and has the page's touches start it, until one
  /// does (from the browser's own event, the only place Safari allows it).
  /// Called at startup, so the touches that lead into a game count.
  static void prime() => _element;

  static web.HTMLAudioElement _make() {
    // Asked for with CORS: the game's page is cross-origin isolated, which
    // turns away a plain cross-site load (storage answers CORS).
    final element = web.HTMLAudioElement()
      ..preload = 'auto'
      ..crossOrigin = 'anonymous';
    void unlock() {
      if (_unlocked) return WebAudio.instance.offTouch(unlock);
      // A note's on it: never cut off for the silence.
      if (_owner != null) return;
      element.src = _silence;
      element.play().toDart.then(
        (_) {
          _unlocked = true;
          if (element.src == _silence) element.pause();
        },
        // Not a touch Safari counts (a press, not a tap): the next one.
        onError: (Object _) {},
      );
    }

    WebAudio.instance.onTouch(unlock);
    return element;
  }

  /// A tenth of a second of silence (8 kHz, 8-bit).
  static final String _silence = () {
    const samples = 800;
    final wav = ByteData(44 + samples);
    void tag(int at, String s) {
      for (var i = 0; i < 4; i++) {
        wav.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    wav.setUint32(4, 36 + samples, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    wav
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, 8000, Endian.little)
      ..setUint32(28, 8000, Endian.little)
      ..setUint16(32, 1, Endian.little)
      ..setUint16(34, 8, Endian.little);
    tag(36, 'data');
    wav.setUint32(40, samples, Endian.little);
    for (var i = 0; i < samples; i++) {
      wav.setUint8(44 + i, 128);
    }
    return 'data:audio/wav;base64,${base64Encode(wav.buffer.asUint8List())}';
  }();

  final _position = StreamController<Duration>.broadcast();
  final _completed = StreamController<void>.broadcast();
  late final List<StreamSubscription<web.Event>> _subs;

  bool get _mine => identical(_owner, this);

  Stream<Duration> get position => _position.stream;

  Stream<void> get completed => _completed.stream;

  void _end() {
    if (!_mine) return;
    _owner = null;
    _completed.add(null);
  }

  Future<void> play(String url) async {
    final element = _element;
    _owner = this;
    element.src = url;
    try {
      await element.play().toDart;
      _unlocked = true;
    } catch (_) {
      if (_mine) _owner = null;
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_mine) return;
    _owner = null;
    _element.pause();
  }

  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    if (_mine) {
      _owner = null;
      _element.pause();
    }
    unawaited(_position.close());
    unawaited(_completed.close());
  }
}
