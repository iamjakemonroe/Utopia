import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/audio/room_sound.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/music_world.dart';

const _rate = 16000;

final _random = math.Random(7);

void _add(Float64List x, double at, Float64List sound, double gain) {
  final from = (at * _rate).round();
  for (var i = 0; i < sound.length && from + i < x.length; i++) {
    x[from + i] += sound[i] * gain;
  }
}

Float64List _sound(double seconds, double Function(double t) f) =>
    Float64List.fromList([
      for (var i = 0; i < seconds * _rate; i++) f(i / _rate),
    ]);

/// A kick: a thump sweeping down from 160 Hz, with a click.
Float64List _kick() => _sound(0.35, (t) {
  final phase = 2 * math.pi * (50 * t + 110 * (1 - math.exp(-t * 25)) / 25);
  final click = t < 0.0025 ? (_random.nextDouble() - 0.5) * 0.6 : 0.0;
  return math.sin(phase) * math.exp(-t * 9) + click;
});

Float64List _snare() => _sound(
  0.2,
  (t) =>
      (_random.nextDouble() - 0.5) * 1.2 * math.exp(-t * 22) +
      0.5 * math.sin(2 * math.pi * 190 * t) * math.exp(-t * 30),
);

Float64List _hat() =>
    _sound(0.05, (t) => (_random.nextDouble() - 0.5) * math.exp(-t * 80));

Float64List _saw(double f, double seconds, double decay) => _sound(
  seconds,
  (t) =>
      (2 * ((f * t) % 1) - 1) *
      0.5 *
      math.exp(-t * decay) *
      math.min(1, t * _rate / 80),
);

/// A track at [bpm]: kicks, a snare on 2 and 4, hats, a bass line and a
/// three-note arpeggio in sixteenths (which repeats off the beat, the
/// hard part). Hip-hop: a syncopated kick and sixteenth hats. Returns it
/// and when its beats land.
(Float64List, List<double>) _track(
  double bpm,
  double seconds, {
  bool hipHop = false,
}) {
  final x = Float64List((seconds * _rate).round());
  final beat = 60 / bpm;
  final kick = _kick();
  final snare = _snare();
  final hat = _hat();
  const roots = [110.0, 87.3, 130.8, 98.0];
  final beats = <double>[];
  for (var b = 0; b * beat < seconds - 0.4; b++) {
    final t = b * beat + 0.13;
    beats.add(t);
    final inBar = b % 4;
    if (hipHop) {
      if (inBar.isEven) _add(x, t, kick, 0.8);
      if (inBar == 1) _add(x, t + beat / 2, kick, 0.6);
    } else if (inBar.isEven) {
      _add(x, t, kick, 0.8);
    }
    if (inBar.isOdd) _add(x, t, snare, 0.45);
    final hats = hipHop ? 4 : 2;
    for (var q = 0; q < hats; q++) {
      _add(x, t + q * beat / hats, hat, 0.25);
    }
    final root = roots[(b ~/ 4) % 4];
    _add(x, t, _saw(root, beat * 0.9, 2), 0.35);
    for (var q = 0; q < 4; q++) {
      final f = root * 4 * const [1.0, 1.26, 1.5][(b * 4 + q) % 3];
      _add(x, t + q * beat / 4, _saw(f, beat / 4, 12), 0.12);
    }
  }
  return (x, beats);
}

/// Through a phone's speaker or microphone: no deep bass.
Float64List _phone(Float64List x) {
  final a = 1 / (1 + 2 * math.pi * 300 / _rate);
  final y = Float64List(x.length);
  for (var i = 1; i < x.length; i++) {
    y[i] = a * (y[i - 1] + x[i] - x[i - 1]);
  }
  return y;
}

/// Someone talking: syllables at an uneven pace.
Float64List _talk(double seconds) {
  final x = Float64List((seconds * _rate).round());
  var t = 0.2;
  while (t < seconds - 0.5) {
    final length = 0.1 + _random.nextDouble() * 0.3;
    final f = 120 + _random.nextDouble() * 100;
    _add(
      x,
      t,
      _sound(
        length,
        (u) =>
            math.sin(2 * math.pi * f * u) *
                math.sin(math.pi * u / length) *
                (0.5 + 0.5 * math.sin(2 * math.pi * 4 * u)) +
            (_random.nextDouble() - 0.5) * 0.1,
      ),
      0.4,
    );
    t += length + 0.05 + _random.nextDouble() * 0.5;
  }
  return x;
}

/// One of the app's own tracks (16-bit mono WAV), at 16 kHz.
Float64List _wav(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var at = 12;
  var rate = 0;
  while (at < bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(at, at + 4));
    final size = data.getUint32(at + 4, Endian.little);
    if (id == 'fmt ') rate = data.getUint32(at + 12, Endian.little);
    if (id == 'data') {
      final n = size ~/ 2;
      final out = Float64List((n * _rate / rate).floor());
      for (var i = 0; i < out.length; i++) {
        final x = i * rate / _rate;
        final k = x.floor();
        final f = x - k;
        double v(int j) =>
            data.getInt16(at + 8 + math.min(j, n - 1) * 2, Endian.little) /
            32768;
        out[i] = v(k) * (1 - f) + v(k + 1) * f;
      }
      return out;
    }
    at += 8 + size;
  }
  throw StateError('no sound in $path');
}

void main() {
  late double now;
  late RoomListener ears;

  setUp(() {
    now = 0;
    ears = RoomListener(clock: () => now);
    RoomSound.reset();
    RoomSound.listening = true;
  });

  tearDown(() {
    RoomSound.listening = false;
    RoomSound.reset();
  });

  /// [sound] at [gain] over a quiet room's hiss, as an iPhone delivers it
  /// (a tenth of a second at a time); [each] after every delivery.
  void play(Float64List sound, double gain, [void Function()? each]) {
    for (var at = 0; at + 1600 <= sound.length; at += 1600) {
      final chunk = ByteData(3200);
      for (var i = 0; i < 1600; i++) {
        final v = sound[at + i] * gain + (_random.nextDouble() - 0.5) * 0.002;
        chunk.setInt16(
          i * 2,
          (v * 32767).round().clamp(-32768, 32767),
          Endian.little,
        );
      }
      now += 0.1;
      ears.hear(chunk.buffer.asUint8List());
      each?.call();
    }
  }

  void expectBeat(double period, double of, {List<double>? beats}) {
    final related = [of, of / 2, of * 2];
    expect(
      related.any((p) => (period / p - 1).abs() < 0.03),
      isTrue,
      reason: 'a beat every $period s, for one every $of s',
    );
    if (beats != null && (period / of - 1).abs() < 0.03) {
      // The grid lands on the beats.
      var off = (RoomSound.anchor - beats.first) % of;
      if (off > of / 2) off -= of;
      expect(off.abs(), lessThan(0.03), reason: 'off the beat by $off s');
    }
  }

  test('a quiet room: no hits, no tempo, nothing shown', () {
    play(Float64List(4 * _rate), 1);
    expect(RoomSound.beats, 0);
    expect(RoomSound.period, 0);
    expect(RoomSound.presenceAt(now), 0);
    RoomSound.show(now);
    expect(RoomSound.level, lessThan(0.1));
  });

  test('music through a phone: its tempo, on the beat, and loud', () {
    final (music, beats) = _track(124, 30);
    play(_phone(music), 0.4);
    expectBeat(RoomSound.period, 60 / 124, beats: beats);
    expect(RoomSound.presenceAt(now), 1);
    RoomSound.show(now);
    expect(RoomSound.level, greaterThan(0.3));
    expect(RoomSound.bands.reduce(math.max), greaterThan(0.3));
  });

  test('played quietly, the same', () {
    final (music, beats) = _track(124, 30);
    play(music, 0.03);
    expectBeat(RoomSound.period, 60 / 124, beats: beats);
  });

  test('hip-hop, its kick off the beat: still its tempo', () {
    final (music, beats) = _track(90, 30, hipHop: true);
    play(_phone(music), 0.4);
    expectBeat(RoomSound.period, 60 / 90, beats: beats);
  });

  test("the app's own menu music: its beat", () {
    final music = _wav('assets/music/menu.wav');
    play(Float64List.fromList([...music, ...music]), 0.3);
    expectBeat(RoomSound.period, 60 / 84);
  });

  test('the tempo is held from early on', () {
    final (music, _) = _track(124, 30);
    var held = 0;
    var after = 0;
    play(music, 0.3, () {
      if (now < 6) return;
      after++;
      if (RoomSound.period > 0) held++;
    });
    expect(held / after, greaterThan(0.95));
  });

  test('talking: heard, but no tempo', () {
    var tempo = 0;
    play(_talk(30), 0.3, () {
      if (RoomSound.period > 0) tempo++;
    });
    expect(tempo, 0);
    expect(RoomSound.presenceAt(now), greaterThan(0));
  });

  test('each hit is heard', () {
    play(Float64List(_rate), 1);
    final drums = Float64List(6 * _rate);
    for (var k = 0; k < 12; k++) {
      _add(drums, 0.1 + k * 0.5, k.isEven ? _kick() : _snare(), 0.6);
    }
    play(_phone(drums), 0.5);
    expect(RoomSound.beats, inInclusiveRange(11, 13), reason: '12 hits');
  });

  test('one steady sound is not a stream of hits', () {
    play(Float64List(_rate), 1);
    play(_sound(5, (t) => math.sin(2 * math.pi * 220 * t)), 0.3);
    expect(RoomSound.beats, lessThanOrEqualTo(1), reason: 'where it began');
    expect(RoomSound.period, 0);
  });

  test('a tone lights its own band of the spectrum', () {
    play(Float64List(_rate), 1);
    play(_sound(3, (t) => math.sin(2 * math.pi * 1000 * t)), 0.3);
    RoomSound.show(now);
    final bands = RoomSound.bands;
    var loudest = 0;
    for (var b = 1; b < bands.length; b++) {
      if (bands[b] > bands[loudest]) loudest = b;
    }
    // 62 Hz to 7.5 kHz in 24 steps: 1 kHz is in the 14th band or so.
    expect(loudest, inInclusiveRange(12, 16));
    expect(bands[0], lessThan(0.2));
  });

  test('quiet again: the show lets go, and the tempo with it', () {
    final (music, _) = _track(124, 15);
    play(music, 0.3);
    expect(RoomSound.period, greaterThan(0));
    play(Float64List(3 * _rate), 1);
    expect(RoomSound.presenceAt(now), 0);
    expect(RoomSound.period, 0);
  });

  test('the Music world draws to the room, on a beat and between', () {
    final (music, _) = _track(124, 8);
    play(music, 0.3);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(390, 844);
    for (final (listening, at) in [
      (false, now),
      (true, now),
      (true, now + 0.2),
      (true, now + 1.5),
      (true, now + 5),
    ]) {
      RoomSound.listening = listening;
      paintMusicScene(
        canvas,
        size,
        at,
        UtopiaThemes.utopiaMusic.world,
        moon: const Offset(290, 130),
      );
    }
    recorder.endRecording().dispose();
  });
}
