import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_controller.dart';
import '../widgets/utopia_world.dart' show worldSeconds;
import 'web_audio.dart';

/// What the room sounds like, for the Music world: how loud it is, its
/// spectrum and waveform, the hits (a drum, a clap) and, once it's found
/// one, the room's tempo. Read by the world's painter every frame, written
/// by [RoomListener] while it listens. Nothing of the sound itself is
/// kept: only these few numbers, for a second or so.
abstract final class RoomSound {
  /// Bars in the spectrum (the Music world's equalizer has as many).
  static const bandCount = 24;

  /// Points in the waveform (the stage's screen).
  static const waveLength = 48;

  /// Listening now.
  static bool listening = false;

  /// How loud, 0 (quiet) to 1 (a party), as [show]n.
  static double level = 0;

  /// The spectrum as [show]n, bass to treble, each 0 to 1. Each band is
  /// scaled to what it's been lately, so quiet music fills it as loud does.
  static final bands = Float64List(bandCount);

  /// The waveform as [show]n, -1 to 1.
  static final wave = Float64List(waveLength);

  /// When the room last made a sound above its quiet ([worldSeconds]).
  static double heardAt = -100;

  /// When the last hit landed, and hits heard so far.
  static double beatAt = -100;
  static int beats = 0;

  /// The room's tempo once it has a steady beat: seconds a beat, and a
  /// beat on the grid ([anchor], numbered [anchorCount]). 0 when there's
  /// none. The grid runs ahead of the microphone, so the show hits on the
  /// beat, not a moment after hearing it.
  static double period = 0;
  static double anchor = 0;
  static int anchorCount = 0;

  /// While something else needs the microphone (a voice note being
  /// recorded), the room isn't listened to.
  static final hold = ValueNotifier<int>(0);

  /// When the Music world was last drawn ([worldSeconds]). It's only drawn
  /// while it's on screen (covered, its clock stops), and the microphone's
  /// only on while it is.
  static double drawnAt = -100;

  static bool get onScreen => worldSeconds - drawnAt < 3;

  /// How much the room is driving the show at [t], 0 to 1: all of it
  /// while there's sound, fading out over a second once it's gone quiet.
  static double presenceAt(double t) =>
      listening ? (2.0 - (t - heardAt)).clamp(0.0, 1.0) : 0.0;

  static double get presence => presenceAt(worldSeconds);

  /// Whether the room is driving the show.
  static bool get hearing => presence > 0;

  static final _frames = _Frames();
  static double _shownAt = double.nan;

  /// Brings [level], [bands] and [wave] to how the room sounded just
  /// before [t]. The microphone delivers in bursts (a tenth of a second
  /// on an iPhone), so what's shown runs that far behind, smoothly.
  static void show(double t) {
    if (t == _shownAt) return;
    _shownAt = t;
    _frames.show(t - _frames.lag);
  }

  /// Back to a silent room.
  static void reset() {
    level = 0;
    bands.fillRange(0, bandCount, 0);
    wave.fillRange(0, waveLength, 0);
    heardAt = -100;
    beatAt = -100;
    beats = 0;
    period = 0;
    anchor = 0;
    anchorCount = 0;
    _frames.clear();
    _shownAt = double.nan;
  }
}

/// The last second and a half of what was heard, frame by frame (each
/// [RoomListener._hopSeconds]), for [RoomSound.show].
class _Frames {
  static const size = 96;

  final times = Float64List(size);
  final levels = Float64List(size);
  final bands = Float64List(size * RoomSound.bandCount);
  final waves = Float64List(size * RoomSound.waveLength);

  /// Frames written so far.
  int count = 0;

  /// How far behind the shown sound runs: the gap between the
  /// microphone's bursts, and a little.
  double lag = 0.15;

  void clear() => count = 0;

  void add(double time, double level, Float64List band, Float64List wave) {
    final i = count % size;
    times[i] = time;
    levels[i] = level;
    bands.setRange(
      i * RoomSound.bandCount,
      (i + 1) * RoomSound.bandCount,
      band,
    );
    waves.setRange(
      i * RoomSound.waveLength,
      (i + 1) * RoomSound.waveLength,
      wave,
    );
    count++;
  }

  void show(double t) {
    if (count == 0) {
      RoomSound.level = 0;
      RoomSound.bands.fillRange(0, RoomSound.bandCount, 0);
      RoomSound.wave.fillRange(0, RoomSound.waveLength, 0);
      return;
    }
    // The newest frame at or before t, and the one after it.
    final newest = count - 1;
    final oldest = math.max(0, count - size);
    var at = newest;
    while (at > oldest && times[at % size] > t) {
      at--;
    }
    final a = at % size;
    double mix;
    int b;
    double fade;
    if (at == newest) {
      // Nothing newer yet (the microphone's late): hold, dying away.
      mix = 0;
      b = a;
      fade = math.exp(-math.max(0.0, t - times[a]) * 4);
    } else {
      b = (at + 1) % size;
      final span = times[b] - times[a];
      mix = span > 0 ? ((t - times[a]) / span).clamp(0.0, 1.0) : 0;
      fade = 1;
    }
    double lerp(double x, double y) => (x + (y - x) * mix) * fade;
    RoomSound.level = lerp(levels[a], levels[b]);
    for (var k = 0; k < RoomSound.bandCount; k++) {
      RoomSound.bands[k] = lerp(
        bands[a * RoomSound.bandCount + k],
        bands[b * RoomSound.bandCount + k],
      );
    }
    for (var k = 0; k < RoomSound.waveLength; k++) {
      RoomSound.wave[k] = lerp(
        waves[a * RoomSound.waveLength + k],
        waves[b * RoomSound.waveLength + k],
      );
    }
  }
}

/// Listens to the room through the microphone, for [RoomSound]. The sound
/// is read as it comes in and let go at once; it's never recorded, kept
/// or sent anywhere.
///
/// Every 16 ms it looks at the last 32 ms: how loud, the spectrum (an
/// FFT, in 24 bands from the bass up), and how much it changed (spectral
/// flux, where hits stand out). The hits are peaks in that change, and
/// the tempo is where it repeats (autocorrelation over the last six
/// seconds), the grid set where the hits fall.
class RoomListener {
  RoomListener({@visibleForTesting double Function()? clock})
    : _now = clock ?? (() => worldSeconds);

  /// The world's clock (everything's timed on it, as the painter draws).
  final double Function() _now;

  static const _rate = 16000;
  static const _window = 512;
  static const _hop = 256;
  static const _hopSeconds = _hop / _rate;

  /// Six seconds of change, for the tempo.
  static const _history = 384;

  /// Tempos looked for: a beat every 0.3 to 1 second (60 to 200 a minute).
  static const _shortest = 18;
  static const _longest = 63;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _sub;
  bool _starting = false;
  bool _wanted = false;
  Timer? _watch;
  double _lastChunk = 0;

  // The sound coming in, and where it is in the world's time.
  final _ring = Float64List(_window);
  int _ringAt = 0;
  int _sinceHop = 0;
  int _samples = 0;
  double _hopSquares = 0;
  double? _offset;
  double? _lastArrival;
  double _gap = 0.1;

  // One frame's working.
  final _re = Float64List(_window);
  final _im = Float64List(_window);
  final _waveOut = Float64List(RoomSound.waveLength);

  // The room lately: its quiet, each band's quiet and peak, the
  // waveform's peak.
  double? _floor;
  final _bandFloor = Float64List(RoomSound.bandCount);
  final _bandPeak = Float64List(RoomSound.bandCount);
  final _bandShown = Float64List(RoomSound.bandCount);
  final _bandWas = Float64List(RoomSound.bandCount);
  final _bandDb = Float64List(RoomSound.bandCount);
  bool _bandsSet = false;
  double _wavePeak = 0.02;
  double _level = 0;

  // The change, frame by frame, and when each frame was.
  final _flux = Float64List(_history);
  final _fluxTime = Float64List(_history);
  final _fluxHeard = List<bool>.filled(_history, false);
  int _frames = 0;
  double _lastHit = -100;
  double _quietSince = 0;

  // The tempo's working, kept from one look to the next.
  final _rises = Float64List(_history);
  final _repeats = Float64List(_longest * 2 + 4);

  // The tempo being found, and how sure it was last time.
  @visibleForTesting
  double confidence = 0;
  double _candidate = 0;
  int _agreed = 0;
  int _doubted = 0;

  /// Starts listening; false if the microphone isn't allowed (or the
  /// platform can't).
  Future<bool> start() {
    _wanted = true;
    return _open();
  }

  Future<void> stop() async {
    _wanted = false;
    await _close();
  }

  Future<bool> _open() async {
    if (_recorder != null || _starting) return true;
    _starting = true;
    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) {
        await recorder.dispose();
        return false;
      }
      final stream = await recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _rate,
          numChannels: 1,
          // The room as it is: nothing evened out or cleaned up.
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
          // A browser's sound in fiftieths of a second (an iPhone's
          // comes in tenths whatever's asked; Android's own size is safe).
          streamBufferSize: kIsWeb ? 1024 : null,
          // Utopia's own sound, and the player's music, keep playing out
          // of the speaker alongside.
          iosConfig: const IosRecordConfig(
            categoryOptions: [
              IosAudioCategoryOption.mixWithOthers,
              IosAudioCategoryOption.defaultToSpeaker,
              IosAudioCategoryOption.allowBluetoothA2DP,
            ],
          ),
        ),
      );
      _recorder = recorder;
      _sub = stream.listen(_hear, onError: (_) => _restart());
      RoomSound.listening = true;
      _lastChunk = _now();
      _watch?.cancel();
      _watch = Timer.periodic(const Duration(seconds: 1), (_) => _check());
      if (kIsWeb) WebAudio.instance.onTouch(_wake);
      // Stopped while it was starting.
      if (!_wanted) await _close();
      return true;
    } catch (_) {
      await recorder.dispose();
      return false;
    } finally {
      _starting = false;
    }
  }

  Future<void> _close() async {
    final recorder = _recorder;
    _recorder = null;
    _watch?.cancel();
    _watch = null;
    if (kIsWeb) WebAudio.instance.offTouch(_wake);
    await _sub?.cancel();
    _sub = null;
    RoomSound.listening = false;
    RoomSound.reset();
    _forget();
    if (recorder == null) return;
    try {
      await recorder.stop();
    } catch (_) {}
    await recorder.dispose();
  }

  /// Nothing's come for a while: on a phone, the microphone was taken
  /// away (the audio switched over, a call), so it starts again. A
  /// browser keeps sound off until the page is touched ([_wake]).
  void _check() {
    if (_recorder == null || _starting || kIsWeb) return;
    if (_now() - _lastChunk < 2) return;
    unawaited(_restart());
  }

  Future<void> _restart() async {
    await _close();
    if (_wanted && RoomSound.hold.value == 0) await _open();
  }

  /// The page was touched: if the browser was holding the microphone's
  /// sound back, it lets it through now.
  void _wake() {
    final recorder = _recorder;
    if (recorder == null || _now() - _lastChunk < 0.5) return;
    unawaited(recorder.resume().catchError((Object _) {}));
  }

  void _forget() {
    _ring.fillRange(0, _window, 0);
    _ringAt = 0;
    _sinceHop = 0;
    _samples = 0;
    _hopSquares = 0;
    _offset = null;
    _lastArrival = null;
    _floor = null;
    _bandsSet = false;
    _bandShown.fillRange(0, RoomSound.bandCount, 0);
    _wavePeak = 0.02;
    _level = 0;
    _frames = 0;
    _lastHit = -100;
    _candidate = 0;
    _agreed = 0;
    _doubted = 0;
  }

  /// What's just been heard, as 16-bit samples (for tests too).
  @visibleForTesting
  void hear(Uint8List chunk) => _hear(chunk);

  void _hear(Uint8List chunk) {
    final count = chunk.length ~/ 2;
    if (count == 0) return;
    final now = _now();
    _lastChunk = now;
    // Where these samples sit in the world's time: the last one is now
    // (or a little before: a late delivery only ever makes it look later,
    // so the earliest estimate stands, creeping on slowly).
    final end = _samples + count;
    final offset = now - end / _rate;
    final previous = _offset;
    _offset = previous == null
        ? offset
        : math.min(offset, previous + 0.01 * count / _rate);
    final last = _lastArrival;
    if (last != null) {
      _gap = _gap * 0.9 + (now - last).clamp(0.0, 0.5) * 0.1;
    }
    _lastArrival = now;
    RoomSound._frames.lag = _gap + 0.035;

    final data = ByteData.sublistView(chunk);
    for (var i = 0; i < count; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768;
      _ring[_ringAt] = v;
      _ringAt = (_ringAt + 1) % _window;
      _hopSquares += v * v;
      _samples++;
      if (++_sinceHop == _hop) {
        _sinceHop = 0;
        _frame();
      }
    }
  }

  /// When sample [index] was, on the world's clock.
  double _timeOf(num index) => _offset! + index / _rate;

  void _frame() {
    // The frame stands for the middle of what it looked at.
    final time = _timeOf(_samples - _window / 2);
    final db = 10 * math.log(math.max(_hopSquares / _hop, 1e-12)) / math.ln10;
    _hopSquares = 0;

    // The room's quiet: drops at once, rises slowly; never above -50 dB
    // (anything louder is a sound, not the room).
    final floor = _floor;
    _floor = floor == null
        ? db
        : db < floor
        ? floor + (db - floor) * 0.3
        : floor + 0.3 * _hopSeconds;
    final quiet = _floor!.clamp(-90.0, -50.0);
    final heard = db > quiet + 8;
    if (heard) RoomSound.heardAt = time;
    final loud = ((db - quiet - 6) / 30).clamp(0.0, 1.0);
    _level += (loud - _level) * (loud > _level ? 0.5 : 0.1);

    // The spectrum.
    for (var i = 0; i < _window; i++) {
      _re[i] = _ring[(_ringAt + i) % _window] * _hann[i];
      _im[i] = 0;
    }
    _fft(_re, _im);
    for (var k = 1; k < _window ~/ 2; k++) {
      _re[k] = math.sqrt(_re[k] * _re[k] + _im[k] * _im[k]) * (4 / _window);
    }
    final flux = _bandsFrom(_re, heard);

    // The waveform: the newest stretch, scaled to the loudest lately.
    var peak = 0.0;
    for (var k = 0; k < RoomSound.waveLength; k++) {
      final v =
          _ring[(_ringAt + _window - 5 * (RoomSound.waveLength - k)) % _window];
      _waveOut[k] = v;
      peak = math.max(peak, v.abs());
    }
    _wavePeak = math.max(math.max(_wavePeak * 0.97, peak), 0.02);
    for (var k = 0; k < RoomSound.waveLength; k++) {
      _waveOut[k] = (_waveOut[k] / _wavePeak).clamp(-1.0, 1.0);
    }

    RoomSound._frames.add(time, _level, _bandShown, _waveOut);
    _change(flux, time, heard);
  }

  /// Each band's loudness against its own quiet and peak lately; and how
  /// much they rose since the frame before (in bels, above each band's
  /// quiet, so a hiss flickering under it doesn't count), where hits
  /// stand out.
  double _bandsFrom(Float64List magnitudes, bool heard) {
    const release = 0.9; // about a tenth of a second to fall
    var loudest = -140.0;
    for (var b = 0; b < RoomSound.bandCount; b++) {
      final from = _edges[b];
      final to = _edges[b + 1];
      var energy = 0.0;
      for (var k = from; k < to; k++) {
        energy += magnitudes[k] * magnitudes[k];
      }
      final db = _bandDb[b] =
          10 * math.log(math.max(energy / (to - from), 1e-14)) / math.ln10;
      loudest = math.max(loudest, db);
    }
    var flux = 0.0;
    for (var b = 0; b < RoomSound.bandCount; b++) {
      final db = _bandDb[b];
      if (!_bandsSet) {
        _bandFloor[b] = db;
        _bandPeak[b] = db + 24;
        _bandWas[b] = db;
      }
      // The rise, counted from just above the band's quiet, and from 40 dB
      // under the loudest band (below that it's only the loud one's
      // spill, which wavers as its phase turns).
      final above = math.max(db, math.max(_bandFloor[b] + 3, loudest - 40));
      if (above > _bandWas[b]) flux += (above - _bandWas[b]) / 10;
      _bandWas[b] = above;
      // Its quiet: the hiss's level, followed while it's near it (and
      // falling to a new quiet within half a second); under a sound, it
      // only creeps up.
      final floor = _bandFloor[b];
      _bandFloor[b] = db < floor + 6
          ? floor + (db - floor) * 0.03
          : floor + 0.3 * _hopSeconds;
      _bandPeak[b] = math.max(
        math.max(db, _bandPeak[b] - 3 * _hopSeconds),
        _bandFloor[b] + 24,
      );
      final span = _bandPeak[b] - _bandFloor[b] - 9;
      var v = ((db - _bandFloor[b] - 9) / span).clamp(0.0, 1.0);
      if (!heard) v *= 0.3;
      _bandShown[b] = math.max(v, _bandShown[b] * release);
    }
    _bandsSet = true;
    return flux;
  }

  /// Takes in this frame's change: a hit where it peaks, and every so
  /// often, the tempo.
  void _change(double flux, double time, bool heard) {
    final i = _frames % _history;
    _flux[i] = flux;
    _fluxTime[i] = time;
    _fluxHeard[i] = heard;
    _frames++;
    if (heard) _quietSince = time;

    // Quiet a while: the beat's gone, and what's next starts fresh.
    if (time - _quietSince > 1.5) {
      if (RoomSound.period > 0 || _frames > 1) {
        RoomSound.period = 0;
        _frames = 0;
        _candidate = 0;
        _agreed = 0;
      }
      return;
    }

    // A hit: the frame before peaked well above the change lately.
    if (_frames >= 3) {
      final a = _flux[(_frames - 3) % _history];
      final b = _flux[(_frames - 2) % _history];
      final at = _fluxTime[(_frames - 2) % _history];
      var mean = 0.0;
      final n = math.min(_frames, 24);
      for (var k = 1; k <= n; k++) {
        mean += _flux[(_frames - k) % _history];
      }
      mean /= n;
      if (b > a &&
          b >= flux &&
          b > math.max(mean * 1.5, _hitFloor) &&
          _fluxHeard[(_frames - 2) % _history] &&
          at - _lastHit > 0.18) {
        _lastHit = at;
        RoomSound.beatAt = at + _hitLead;
        RoomSound.beats++;
      }
    }

    // Three seconds in, and every eighth frame after: the tempo.
    if (_frames >= 188 && _frames % 8 == 0) _tempo();
  }

  void _tempo() {
    final n = math.min(_frames, _history);
    final first = _frames - n;
    // The change less its running mean, the rises only: where hits are.
    final e = _rises;
    var run = 0.0;
    for (var k = 0; k < n; k++) {
      final v = _flux[(first + k) % _history];
      run = k == 0 ? v : run * 0.9 + v * 0.1;
      e[k] = math.max(0, v - run);
    }
    var r0 = 0.0;
    for (var k = 0; k < n; k++) {
      r0 += e[k] * e[k];
    }
    r0 /= n;
    if (r0 <= 0) return _doubt();
    final r = _repeats;
    for (var lag = _shortest ~/ 2; lag < r.length; lag++) {
      var sum = 0.0;
      for (var k = lag; k < n; k++) {
        sum += e[k] * e[k - lag];
      }
      r[lag] = n - lag > 0 ? sum / (n - lag) : 0;
    }
    // Each tempo scored by how well the change repeats at its beat (and
    // at two beats), leaning to around 120 a minute.
    double score(int lag) {
      final octaves = math.log(lag * _hopSeconds / 0.5) / math.ln2;
      return (r[lag] + 0.5 * r[lag * 2]) * math.exp(-0.5 * octaves * octaves);
    }

    var best = _shortest;
    for (var lag = _shortest + 1; lag <= _longest; lag++) {
      if (score(lag) > score(best)) best = lag;
    }
    final confidence = this.confidence = r[best] / r0;
    if (confidence < _sure) return _doubt();
    // Between frames: the peak of a parabola through its neighbours.
    final s0 = score(best - 1);
    final s1 = score(best);
    final s2 = score(best + 1);
    final bend = s0 - 2 * s1 + s2;
    final frames = best + (bend < 0 ? 0.5 * (s0 - s2) / bend : 0);

    // Where the beats fall: the phase whose beats line up with the most
    // change, the latest counting most.
    var phase = 0;
    var top = -1.0;
    for (var p = 0; p < frames.ceil(); p++) {
      var sum = 0.0;
      var weight = 1.0;
      for (var x = n - 1 - p.toDouble(); x >= 1; x -= frames) {
        final k = x.round();
        sum += weight * (e[k] + 0.5 * (e[k - 1] + (k + 1 < n ? e[k + 1] : 0)));
        weight *= 0.92;
      }
      if (sum > top) {
        top = sum;
        phase = p;
      }
    }
    final beat = _fluxTime[(first + n - 1 - phase) % _history] + _hitLead;
    _doubted = 0;
    _settle(frames * _hopSeconds, beat);
  }

  /// How sure (the share of the change that repeats at the beat) before
  /// the show takes the room's tempo: music comes out above 0.55, talk
  /// below 0.35.
  static const _sure = 0.4;

  /// The least change that's a hit (bels, over all the bands): a drum
  /// lifts several bands by 5 dB or more; a hiss flickering doesn't.
  static const _hitFloor = 1.5;

  /// A hit peaks in the change as it enters the newest 16 ms, this long
  /// before the middle of the frame it's in (measured against kicks at
  /// known times).
  static const _hitLead = 0.015;

  void _doubt() {
    // A second and a half unsure: no tempo.
    if (++_doubted >= 12) {
      RoomSound.period = 0;
      _candidate = 0;
      _agreed = 0;
    }
  }

  /// Moves the grid towards [period] and a beat at [beat]: nudged when
  /// it's the tempo already, taken when a new one's found a few times
  /// running.
  void _settle(double period, double beat) {
    final current = RoomSound.period;
    if (current > 0 && (period / current - 1).abs() < 0.08) {
      final k = ((beat - RoomSound.anchor) / current).round();
      final predicted = RoomSound.anchor + k * current;
      RoomSound.anchorCount += k;
      RoomSound.anchor = predicted + (beat - predicted) * 0.3;
      RoomSound.period = current + (period - current) * 0.3;
      _agreed = 0;
      return;
    }
    if (_candidate > 0 && (period / _candidate - 1).abs() < 0.06) {
      if (++_agreed >= 3) {
        RoomSound.anchorCount = current > 0
            ? RoomSound.anchorCount +
                  ((beat - RoomSound.anchor) / current).round()
            : RoomSound.beats;
        RoomSound.period = period;
        RoomSound.anchor = beat;
        _candidate = 0;
        _agreed = 0;
      }
    } else {
      _candidate = period;
      _agreed = 1;
    }
  }

  static final _hann = Float64List.fromList([
    for (var i = 0; i < _window; i++)
      0.5 - 0.5 * math.cos(2 * math.pi * i / (_window - 1)),
  ]);

  /// The bands' edges in FFT bins (31.25 Hz each): from 62 Hz to 7.5 kHz,
  /// evenly spaced in pitch, at least a bin each.
  static final _edges = () {
    final edges = <int>[2];
    for (var b = 1; b <= RoomSound.bandCount; b++) {
      final ideal = (2 * math.pow(120, b / RoomSound.bandCount)).round();
      edges.add(math.max(ideal, edges.last + 1));
    }
    return edges;
  }();

  static final _cos = Float64List.fromList([
    for (var k = 0; k < _window ~/ 2; k++) math.cos(2 * math.pi * k / _window),
  ]);
  static final _sin = Float64List.fromList([
    for (var k = 0; k < _window ~/ 2; k++) -math.sin(2 * math.pi * k / _window),
  ]);

  /// A fast Fourier transform of [re] and [im] (in place, [_window] long).
  static void _fft(Float64List re, Float64List im) {
    const n = _window;
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final half = len >> 1;
      final step = n ~/ len;
      for (var i = 0; i < n; i += len) {
        for (var k = 0; k < half; k++) {
          final wr = _cos[k * step];
          final wi = _sin[k * step];
          final a = i + k;
          final b = a + half;
          final tr = re[b] * wr - im[b] * wi;
          final ti = re[b] * wi + im[b] * wr;
          re[b] = re[a] - tr;
          im[b] = im[a] - ti;
          re[a] += tr;
          im[a] += ti;
        }
      }
    }
  }
}

/// Whether the Music world listens to the room (Settings > Sound), off
/// until the player turns it on; and whether they've been asked.
class MusicWorldListens extends StateNotifier<bool> {
  MusicWorldListens(this._prefs) : super(_prefs?.getBool(_key) ?? false);

  final SharedPreferences? _prefs;

  static const _key = 'music_world.listens';
  static const _askedKey = 'music_world.asked';

  bool get asked => _prefs?.getBool(_askedKey) ?? false;

  void set(bool on) {
    state = on;
    _prefs?.setBool(_key, on);
    _prefs?.setBool(_askedKey, true);
  }

  void markAsked() => _prefs?.setBool(_askedKey, true);
}

final musicWorldListensProvider =
    StateNotifierProvider<MusicWorldListens, bool>((ref) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {}
      return MusicWorldListens(prefs);
    });
