import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/platform/recording_bytes.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../data/chat_repository.dart';
import '../domain/voice_note.dart';

// ── playback ──────────────────────────────────────────────────────────────

@immutable
class VoicePlaybackState {
  const VoicePlaybackState({this.playing, this.position = Duration.zero});

  /// Storage path of the note playing, if any.
  final String? playing;
  final Duration position;
}

/// Plays voice notes, one at a time, and turns the music down meanwhile.
class VoicePlayback extends StateNotifier<VoicePlaybackState> {
  VoicePlayback(this._repo, this._audio) : super(const VoicePlaybackState()) {
    _subs = [
      _player.onPositionChanged.listen((p) {
        if (mounted && state.playing != null) {
          state = VoicePlaybackState(playing: state.playing, position: p);
        }
      }),
      _player.onPlayerComplete.listen((_) => _finished()),
    ];
  }

  final ChatRepository _repo;
  final GameAudio _audio;
  final AudioPlayer _player = AudioPlayer(playerId: 'utopia-voice');
  final Map<String, String> _urls = {};
  late final List<StreamSubscription<Object?>> _subs;

  bool isPlaying(String path) => state.playing == path;

  /// Plays [note], or stops it if it's the one playing.
  Future<void> toggle(VoiceNote note) async {
    if (state.playing == note.path) return stop();
    await play(note);
  }

  Future<void> play(VoiceNote note) async {
    await _player.stop();
    state = VoicePlaybackState(playing: note.path);
    _audio.duck(true);
    try {
      final url = _urls[note.path] ??= await _repo.voiceUrl(note.path);
      if (!mounted || state.playing != note.path) return;
      await _player.play(UrlSource(url));
    } catch (_) {
      _finished();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _finished();
  }

  void _finished() {
    _audio.duck(false);
    if (mounted) state = const VoicePlaybackState();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _audio.duck(false);
    _player.dispose();
    super.dispose();
  }
}

final voicePlaybackProvider =
    StateNotifierProvider.autoDispose<VoicePlayback, VoicePlaybackState>(
      (ref) => VoicePlayback(
        ref.watch(chatRepositoryProvider),
        ref.read(gameAudioProvider),
      ),
    );

// ── waveform ──────────────────────────────────────────────────────────────

/// Rounded bars for a voice note; the played part is filled in.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.wave,
    required this.progress,
    required this.color,
    this.height = 26,
  });

  final List<int> wave;

  /// 0-1, how much has played.
  final double progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _WavePainter(wave, progress, color),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.wave, this.progress, this.color);

  final List<int> wave;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (wave.isEmpty) return;
    final n = wave.length;
    final slot = size.width / n;
    final barW = math.max(2.0, slot * 0.55);
    for (var i = 0; i < n; i++) {
      final h = size.height * (0.18 + 0.82 * (wave[i] / 9));
      final x = i * slot + (slot - barW) / 2;
      final played = (i + 0.5) / n <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, barW, h),
          Radius.circular(barW / 2),
        ),
        Paint()..color = played ? color : color.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress || old.wave != wave || old.color != color;
}

// ── chat bubble ───────────────────────────────────────────────────────────

/// A voice note in the chat: play button, waveform and length.
class VoiceNoteBubble extends ConsumerWidget {
  const VoiceNoteBubble({super.key, required this.note, required this.mine});

  final VoiceNote note;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(voicePlaybackProvider);
    final playing = playback.playing == note.path;
    final progress = playing && note.ms > 0
        ? (playback.position.inMilliseconds / note.ms).clamp(0.0, 1.0)
        : 0.0;
    final ink = mine ? Colors.white : AppColors.accentSecondary;

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(voicePlaybackProvider.notifier).toggle(note),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mine
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.accent,
              ),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VoiceWaveform(
              wave: note.wave,
              progress: progress,
              color: ink,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatVoiceLength(
              playing ? playback.position.inMilliseconds : note.ms,
            ),
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// The speech bubble over a seat while that player's voice note plays:
/// a mic and bars that dance while it's audible.
class VoiceSpeechChip extends ConsumerStatefulWidget {
  const VoiceSpeechChip({super.key, required this.note});

  final VoiceNote note;

  @override
  ConsumerState<VoiceSpeechChip> createState() => _VoiceSpeechChipState();
}

class _VoiceSpeechChipState extends ConsumerState<VoiceSpeechChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dance;

  @override
  void initState() {
    super.initState();
    _dance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _dance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing =
        ref.watch(voicePlaybackProvider).playing == widget.note.path;
    return GestureDetector(
      onTap: () => ref.read(voicePlaybackProvider.notifier).toggle(widget.note),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playing ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            AnimatedBuilder(
              animation: _dance,
              builder: (context, _) => Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Container(
                      width: 3,
                      height: playing
                          ? 5 +
                                11 *
                                    (0.5 +
                                        0.5 *
                                            math.sin(
                                              _dance.value * 2 * math.pi +
                                                  i * 1.3,
                                            ))
                          : 6.0 + (i.isEven ? 4 : 0),
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              formatVoiceLength(widget.note.ms),
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.faceInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── recording ─────────────────────────────────────────────────────────────

/// Uploads a finished recording and posts it to the chat. Returns an error
/// message to show, or null.
typedef VoiceSender =
    Future<String?> Function(
      Uint8List bytes, {
      required int ms,
      required List<int> wave,
    });

/// Tap the mic to record; the bar shows a live waveform and the time, with
/// a bin to throw it away and a send button. Stops by itself at 30 seconds.
class VoiceRecorderButton extends ConsumerStatefulWidget {
  const VoiceRecorderButton({
    super.key,
    required this.onSend,
    required this.onRecordingChanged,
  });

  final VoiceSender onSend;

  /// Lets the chat hide its text field while recording.
  final ValueChanged<bool> onRecordingChanged;

  @override
  ConsumerState<VoiceRecorderButton> createState() =>
      _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends ConsumerState<VoiceRecorderButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  late final GameAudio _audio;
  StreamSubscription<Amplitude>? _amps;
  final List<double> _levels = [];
  DateTime? _startedAt;
  Timer? _limit;
  bool _sending = false;
  late final Ticker _clock;
  Duration _elapsed = Duration.zero;

  bool get _recording => _startedAt != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = ref.read(gameAudioProvider);
    _clock = createTicker((_) {
      final s = _startedAt;
      if (s != null) setState(() => _elapsed = DateTime.now().difference(s));
    });
  }

  /// Leaving the app mid-recording throws the recording away and lets go of
  /// the microphone at once: it's never kept listening in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) _cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _limit?.cancel();
    _amps?.cancel();
    _clock.dispose();
    if (_recording) {
      _recorder.cancel();
      _audio.reclaimSession();
    }
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final audio = ref.read(gameAudioProvider);
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        showUtopiaToast(
          context,
          'Allow microphone access in Settings to send voice notes.',
          icon: Icons.mic_off_rounded,
          kind: ToastKind.warning,
        );
      }
      return;
    }
    await ref.read(voicePlaybackProvider.notifier).stop();
    // The apps record AAC to a file. A browser records WAV (what every
    // phone and browser plays: Chrome's own WebM won't play on an iPhone),
    // at 16 kHz so 30 seconds stays under 1 MB, and hands back a link.
    final path = kIsWeb
        ? ''
        : '${(await getTemporaryDirectory()).path}'
              '/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        kIsWeb
            ? const RecordConfig(
                encoder: AudioEncoder.wav,
                sampleRate: 16000,
                numChannels: 1,
              )
            : const RecordConfig(
                encoder: AudioEncoder.aacLc,
                bitRate: 48000,
                sampleRate: 22050,
                numChannels: 1,
              ),
        path: path,
      );
    } catch (_) {
      audio.reclaimSession();
      if (mounted) {
        showUtopiaToast(
          context,
          "Couldn't start recording.",
          kind: ToastKind.error,
        );
      }
      return;
    }
    HapticFeedback.mediumImpact();
    _levels.clear();
    _amps = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 90))
        .listen((a) => _levels.add(a.current));
    setState(() {
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
    });
    _clock.start();
    _limit = Timer(VoiceNote.maxLength, _send);
    widget.onRecordingChanged(true);
  }

  void _reset() {
    _limit?.cancel();
    _amps?.cancel();
    _clock.stop();
    ref.read(gameAudioProvider).reclaimSession();
    if (mounted) setState(() => _startedAt = null);
    widget.onRecordingChanged(false);
  }

  Future<void> _cancel() async {
    await _recorder.cancel();
    HapticFeedback.lightImpact();
    _reset();
  }

  Future<void> _send() async {
    if (!_recording || _sending) return;
    final started = _startedAt!;
    final path = await _recorder.stop();
    final ms = DateTime.now().difference(started).inMilliseconds;
    final wave = VoiceNote.waveFrom(List.of(_levels));
    _reset();
    if (path == null || ms < VoiceNote.minLength.inMilliseconds) return;

    setState(() => _sending = true);
    final Uint8List bytes;
    try {
      bytes = await takeRecording(path);
    } catch (_) {
      if (mounted) setState(() => _sending = false);
      return;
    }
    final error = await widget.onSend(bytes, ms: ms, wave: wave);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      showUtopiaToast(context, error, kind: ToastKind.error);
    } else {
      ref.read(gameAudioProvider).play(Sfx.chat);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_recording) {
      return IconButton.filled(
        tooltip: 'Record a voice note',
        style: IconButton.styleFrom(backgroundColor: AppColors.surfaceElevated),
        icon: _sending
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Icon(Icons.mic_rounded, color: AppColors.accentSecondary),
        onPressed: _sending ? null : _start,
      );
    }

    final left = VoiceNote.maxLength - _elapsed;
    final beat = 0.5 + 0.5 * math.sin(_elapsed.inMilliseconds / 160);
    final recent = _levels.length > 34
        ? _levels.sublist(_levels.length - 34)
        : _levels;
    // One line, always: the time never wraps under the dot (Android's
    // wider digits used to push it onto a second line), and the waveform
    // takes whatever room is left.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.textSecondary,
          onPressed: _cancel,
        ),
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.black.withValues(alpha: 0.25),
              border: Border.all(
                color: const Color(
                  0xFFFF4D5E,
                ).withValues(alpha: 0.35 + 0.3 * beat),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      const Color(0xFFFF4D5E),
                      const Color(0xFFFF9AA4),
                      beat,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFFFF4D5E,
                        ).withValues(alpha: 0.6 * beat),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatVoiceLength(_elapsed.inMilliseconds),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style:
                      AppTextStyles.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 26,
                    child: VoiceWaveform(
                      wave: [
                        for (final db in recent)
                          (((db + 50) / 50).clamp(0.0, 1.0) * 9).round(),
                      ],
                      progress: 1,
                      color: left.inSeconds < 5
                          ? const Color(0xFFFF4D5E)
                          : AppColors.accentSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          tooltip: 'Send',
          style: IconButton.styleFrom(backgroundColor: AppColors.success),
          icon: const Icon(Icons.send_rounded, color: Colors.white),
          onPressed: _send,
        ),
      ],
    );
  }
}
