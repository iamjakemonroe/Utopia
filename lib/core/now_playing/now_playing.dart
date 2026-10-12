import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/game_audio.dart';
import '../chip/chip_brain.dart';
import '../settings/gameplay_settings.dart';
import '../widgets/coin_buddy.dart';
import 'media_kind.dart';

export 'media_kind.dart';

/// A song playing in another app.
@immutable
class NowPlayingTrack {
  const NowPlayingTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.playing,
    required this.controls,
    this.kind = MediaKind.unknown,
    this.flavor = ChipFlavor.none,
    this.clues = const MediaClues(),
    this.album,
    this.source,
    this.show,
    this.art,
  });

  final String id;
  final String title;
  final String artist;
  final String? album;

  /// The app it's playing in ("Spotify"), when known.
  final String? source;

  /// Cover art (JPEG), when the app shares it.
  final Uint8List? art;
  final bool playing;

  /// Whether play, pause, next and previous reach the music app.
  final bool controls;

  /// Song, video, podcast, sermon...
  final MediaKind kind;

  /// The podcast or show it belongs to, when known.
  final String? show;

  /// A first guess at its feel from its words, before Chip's brain answers.
  final ChipFlavor flavor;

  /// Everything the phone told us, for Chip's brain.
  final MediaClues clues;

  NowPlayingTrack withArt(Uint8List? art) => NowPlayingTrack(
    id: id,
    title: title,
    artist: artist,
    album: album,
    source: source,
    show: show,
    kind: kind,
    flavor: flavor,
    clues: clues,
    art: art,
    playing: playing,
    controls: controls,
  );
}

/// Whether the phone will tell us what's playing.
enum MusicAccess { granted, unknown, denied, unsupported }

@immutable
class NowPlayingState {
  const NowPlayingState({
    this.track,
    this.otherAudio = false,
    this.access = MusicAccess.unsupported,
    this.vibe,
  });

  final NowPlayingTrack? track;

  /// What Chip's brain made of [track], once it has answered.
  final ChipVibe? vibe;

  /// Something is playing in another app, even if we can't see what.
  final bool otherAudio;
  final MusicAccess access;

  /// The player is listening to (or watching) something right now.
  bool get listening => (track?.playing ?? false) || otherAudio;

  /// What Chip says about it and how he looks.
  ChipMediaLine get chipLine {
    final t = track;
    final v = vibe;
    // Chip's brain knows best what it is and how it feels; the phone's
    // clues and a word-based guess fill in until it answers.
    final brainKind = v == null
        ? null
        : MediaKind.values.where((k) => k.name == v.kind).firstOrNull;
    final kind = brainKind == null || brainKind == MediaKind.unknown
        ? (t?.kind ?? MediaKind.unknown)
        : brainKind;
    final flavor = v == null
        ? (t?.flavor ?? ChipFlavor.none)
        : ChipFlavor.fromVibe(v.vibe);
    final line = chipMediaLine(
      kind: kind,
      title: t?.title,
      artist: t?.artist ?? '',
      source: t?.source,
      show: t?.show,
      seed: (t?.id ?? 'something').hashCode,
      flavor: flavor,
    );
    if (v == null) return line;
    return ChipMediaLine(
      headline: v.headline,
      detail: line.detail,
      mood: line.mood,
      flavor: flavor,
      comment: v.detail.isEmpty ? null : v.detail,
    );
  }
}

/// Keeps an eye on the music the player has on, for Chip on the home
/// screen. Polls gently, and only while something wants to know (home is
/// on screen, the app is open and the setting is on), so it costs nothing
/// the rest of the time.
class NowPlayingController extends StateNotifier<NowPlayingState>
    with WidgetsBindingObserver {
  NowPlayingController(this._ref) : super(const NowPlayingState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;
  static const _channel = MethodChannel('utopia/now_playing');
  Timer? _poll;
  final Set<String> _watchers = {};
  bool _foreground = true;

  /// What Chip's brain said about each track this session, by track id.
  final Map<String, ChipVibe> _vibes = {};
  final Set<String> _asked = {};

  bool get _wanted => _watchers.isNotEmpty;

  static bool get supported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Home and the floating Chip call this as they come and go ([who] tells
  /// them apart); it runs while either wants it. It's called from widget
  /// life-cycles, where providers can't change yet, so the work waits a
  /// beat (and always uses the latest answer).
  void setWatching(bool on, {String who = 'home'}) {
    final changed = on ? _watchers.add(who) : _watchers.remove(who);
    if (!changed) return;
    scheduleMicrotask(() {
      if (mounted) _update();
    });
  }

  bool get _enabled => _ref.read(gameplaySettingsProvider).showNowPlaying;

  void _update() {
    final run = supported && _wanted && _foreground && _enabled;
    if (run && _poll == null) {
      refresh();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    } else if (!run && _poll != null) {
      _poll?.cancel();
      _poll = null;
    }
    if (!run && (state.listening || state.track != null)) {
      state = NowPlayingState(access: state.access);
      _ref.read(gameAudioProvider).yieldToOtherMusic(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  Future<void> refresh() async {
    if (!supported) return;
    try {
      final previous = state.track;
      var raw = await _channel.invokeMapMethod<String, Object?>('read', {
        'art': false,
      });
      if (!mounted || raw == null) return;
      // Cover art only when the song changes: it's the heavy part.
      final id = raw['id'] as String?;
      if (id != null && (id != previous?.id || previous?.art == null)) {
        raw =
            await _channel.invokeMapMethod<String, Object?>('read', {
              'art': true,
            }) ??
            raw;
        if (!mounted) return;
      }
      final access = switch (raw['access']) {
        'granted' => MusicAccess.granted,
        'denied' => MusicAccess.denied,
        _ => MusicAccess.unknown,
      };
      final title = raw['title'] as String?;
      NowPlayingTrack? track;
      if (title != null && title.isNotEmpty) {
        final id = raw['id'] as String? ?? title;
        final art = raw['art'] as Uint8List?;
        final artist = raw['artist'] as String? ?? '';
        final album = raw['album'] as String?;
        final source = raw['source'] as String?;
        final show = raw['show'] as String?;
        final clues = MediaClues(
          kind: raw['kind'] as String?,
          package: raw['package'] as String?,
          source: source,
          title: title,
          artist: artist,
          album: album ?? '',
          genre: raw['genre'] as String? ?? '',
          show: show,
          mediaId: raw['mediaId'] as String? ?? '',
          durationMs: (raw['durationMs'] as num?)?.toInt(),
        );
        final kind = classifyMedia(clues);
        track = NowPlayingTrack(
          id: id,
          title: title,
          artist: artist,
          album: album,
          source: source,
          show: show,
          kind: kind,
          flavor: guessFlavor(kind, clues),
          clues: clues,
          art: art ?? (previous?.id == id ? previous?.art : null),
          playing: raw['playing'] as bool? ?? false,
          controls: raw['controls'] as bool? ?? false,
        );
      }
      final otherAudio = raw['otherAudio'] as bool? ?? false;
      // A paused song while something else plays (Apple Music paused,
      // another app playing) isn't what they're listening to.
      if (track != null && !track.playing && otherAudio) track = null;
      state = NowPlayingState(
        track: track,
        otherAudio: otherAudio,
        access: access,
        vibe: track == null ? null : _vibes[track.id],
      );
      // Utopia's own music steps aside while theirs plays.
      _ref.read(gameAudioProvider).yieldToOtherMusic(state.listening);
      if (track != null && track.playing) _askBrain(track);
    } catch (_) {
      // The phone said no, or doesn't support it: just no music info.
    }
  }

  /// Asks Chip's brain about a new track, once per track per session. The
  /// answer is shown when it arrives, if the track is still on.
  Future<void> _askBrain(NowPlayingTrack track) async {
    if (!_asked.add(track.id)) return;
    final c = track.clues;
    final vibe = await _ref.read(chipBrainProvider).vibe({
      'title': c.title,
      'artist': c.artist,
      'album': c.album,
      'genre': c.genre,
      'source': c.source,
      'package': c.package,
      'kind': c.kind,
      'durationMs': c.durationMs,
    });
    if (vibe == null || !mounted) return;
    _vibes[track.id] = vibe;
    if (state.track?.id == track.id) {
      state = NowPlayingState(
        track: state.track,
        otherAudio: state.otherAudio,
        access: state.access,
        vibe: vibe,
      );
    }
  }

  /// Asks to see what's playing (Apple Music on iPhone; on Android it opens
  /// the notification access settings).
  Future<void> requestAccess() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<Object?>('requestAccess');
    } catch (_) {}
    await refresh();
  }

  Future<void> _command(String method) async {
    try {
      await _channel.invokeMethod<Object?>(method);
    } catch (_) {}
    // The music app takes a moment to change track.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await refresh();
  }

  Future<void> playPause() =>
      _command(state.track?.playing ?? false ? 'pause' : 'play');
  Future<void> next() => _command('next');
  Future<void> previous() => _command('previous');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }
}

final nowPlayingProvider =
    StateNotifierProvider<NowPlayingController, NowPlayingState>((ref) {
      final controller = NowPlayingController(ref);
      ref.listen(
        gameplaySettingsProvider.select((s) => s.showNowPlaying),
        (_, _) => controller._update(),
      );
      return controller;
    });
