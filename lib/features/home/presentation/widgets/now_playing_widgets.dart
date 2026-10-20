import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/now_playing/now_playing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../chip/presentation/chip_chat_sheet.dart';
import '../../../../core/widgets/frosted.dart';
import '../../../../l10n/strings.dart';

/// Little bars bouncing to the music.
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    required this.playing,
    this.color,
    this.height = 14,
  });

  final bool playing;
  final Color? color;
  final double height;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant EqualizerBars old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) _c.repeat();
    if (!widget.playing && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.coinGold;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 3,
              height:
                  widget.height *
                  (widget.playing
                      ? 0.3 +
                            0.7 *
                                (0.5 +
                                        0.5 *
                                            math.sin(
                                              _c.value *
                                                      2 *
                                                      math.pi *
                                                      (1 + i * 0.3) +
                                                  i * 1.7,
                                            ))
                                    .abs()
                      : 0.3),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

/// A little sign of what's on: bouncing bars for music and radio, a play
/// button for video, a mic for podcasts, a book for stories.
class MediaKindBadge extends StatelessWidget {
  const MediaKindBadge({super.key, required this.kind, required this.playing});

  final MediaKind kind;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      MediaKind.music || MediaKind.radio => null,
      MediaKind.video => Icons.smart_display_rounded,
      MediaKind.podcast => Icons.mic_rounded,
      MediaKind.sermon => Icons.auto_awesome_rounded,
      MediaKind.audiobook => Icons.menu_book_rounded,
      MediaKind.unknown => Icons.headphones_rounded,
    };
    if (icon == null) return EqualizerBars(playing: playing, height: 12);
    return Icon(icon, size: 15, color: AppColors.coinGold);
  }
}

/// The cover art, or a glowing note when there's none.
class TrackArt extends StatelessWidget {
  const TrackArt({super.key, required this.track, required this.size});

  final NowPlayingTrack? track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final art = track?.art;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox.square(
        dimension: size,
        child: art != null
            ? Image.memory(art, fit: BoxFit.cover, gaplessPlayback: true)
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accent, AppColors.glowRing],
                  ),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: size * 0.5,
                ),
              ),
      ),
    );
  }
}

/// Chip with the full picture of what's playing: the cover with a record
/// spinning out from behind it, the song, and floating cloud buttons to
/// skip, pause and go back. Tap outside to let it go.
void showNowPlaying(BuildContext context, WidgetRef ref) {
  HapticFeedback.lightImpact();
  ref.read(gameAudioProvider).play(Sfx.reaction);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.nowPlayingClose,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 650),
    pageBuilder: (context, animation, _) =>
        _NowPlayingPopup(animation: animation),
  );
}

class _NowPlayingPopup extends ConsumerStatefulWidget {
  const _NowPlayingPopup({required this.animation});

  final Animation<double> animation;

  @override
  ConsumerState<_NowPlayingPopup> createState() => _NowPlayingPopupState();
}

class _NowPlayingPopupState extends ConsumerState<_NowPlayingPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final music = ref.watch(nowPlayingProvider);
    final controller = ref.read(nowPlayingProvider.notifier);
    final track = music.track;
    final playing = track?.playing ?? music.otherAudio;
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final t = widget.animation.value;
        final closing = widget.animation.status == AnimationStatus.reverse;
        final fade = Curves.easeOut.transform(t);
        final pop = closing
            ? Curves.easeIn.transform(t)
            : Curves.elasticOut.transform(((t - 0.12) / 0.88).clamp(0, 1));
        return Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Frosted(
                  sigma: 16 * fade,
                  child: ColoredBox(
                    color: AppColors.background.withValues(alpha: 0.5 * fade),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: Opacity(
                      opacity: pop.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.5 + 0.5 * pop,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CoinBuddy(
                                mood: music.chipLine.mood,
                                flavor: music.chipLine.flavor,
                                size: 110,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                music.chipLine.headline,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.display(
                                  fontSize: 20,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (music.chipLine.comment != null) ...[
                                const SizedBox(height: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 320,
                                  ),
                                  child: Text(
                                    music.chipLine.comment!,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.body(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              // Swallows taps so pressing the card doesn't
                              // close it.
                              GestureDetector(
                                onTap: () {},
                                child: _PlayerCard(
                                  music: music,
                                  spin: _spin,
                                  playing: playing,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (track != null && track.controls)
                                GestureDetector(
                                  onTap: () {},
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CloudButton(
                                        icon: Icons.skip_previous_rounded,
                                        label: strings.nowPlayingPrevious,
                                        phase: 0,
                                        onTap: controller.previous,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      CloudButton(
                                        icon: playing
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        label: playing
                                            ? strings.nowPlayingPause
                                            : strings.nowPlayingPlay,
                                        big: true,
                                        phase: 1.4,
                                        onTap: controller.playPause,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      CloudButton(
                                        icon: Icons.skip_next_rounded,
                                        label: strings.nowPlayingNext,
                                        phase: 2.8,
                                        onTap: controller.next,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: () {},
                                  child: _AccessHint(music: music),
                                ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                strings.nowPlayingTapAnywhereToClose,
                                style: AppTextStyles.body(
                                  fontSize: 12,
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.music,
    required this.spin,
    required this.playing,
  });

  final NowPlayingState music;
  final Animation<double> spin;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final track = music.track;
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AppColors.surfaceElevated, AppColors.glowRing, 0.2)!,
            AppColors.surface,
          ],
        ),
        border: Border.all(color: AppColors.goldBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.glowRing.withValues(alpha: 0.35),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 170,
            width: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The record slides out from behind the cover while it
                // plays, turning.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  left: playing ? 95 : 45,
                  child: AnimatedBuilder(
                    animation: spin,
                    builder: (context, _) => Transform.rotate(
                      angle: playing ? spin.value * 2 * math.pi : 0,
                      child: CustomPaint(
                        size: const Size.square(150),
                        painter: _RecordPainter(label: AppColors.accent),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TrackArt(track: track, size: 160),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EqualizerBars(playing: playing, height: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  track?.title ?? music.chipLine.detail,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.display(fontSize: 22),
                ),
              ),
            ],
          ),
          if ((track?.artist ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              track!.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (track?.source != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.headphones_rounded,
                    size: 14,
                    color: AppColors.coinGold,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'on ${track!.source}',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A vinyl record: grooves, a shine, and a label in the theme's color.
class _RecordPainter extends CustomPainter {
  _RecordPainter({required this.label});

  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF111018));
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.08);
    for (var k = 0.42; k < 0.97; k += 0.05) {
      canvas.drawCircle(c, r * k, groove);
    }
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.8),
      -2.4,
      0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.3
        ..color = Colors.white.withValues(alpha: 0.06),
    );
    canvas.drawCircle(
      c,
      r * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(label, Colors.white, 0.3)!, label],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.34)),
    );
    canvas.drawCircle(c, r * 0.05, Paint()..color = const Color(0xFF111018));
  }

  @override
  bool shouldRepaint(covariant _RecordPainter old) => old.label != label;
}

/// A soft cloud with a button's icon on it, bobbing on the air. Squishes
/// when pressed.
class CloudButton extends StatefulWidget {
  const CloudButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.big = false,
    this.phase = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big;
  final double phase;

  @override
  State<CloudButton> createState() => _CloudButtonState();
}

class _CloudButtonState extends State<CloudButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  bool _down = false;

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.big ? 96.0 : 76.0;
    final h = w * 0.66;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _float,
          builder: (context, child) {
            final bob = math.sin(_float.value * 2 * math.pi + widget.phase);
            return Transform.translate(
              offset: Offset(0, bob * 5),
              child: AnimatedScale(
                scale: _down ? 0.88 : 1,
                duration: const Duration(milliseconds: 120),
                child: child,
              ),
            );
          },
          child: SizedBox(
            width: w,
            height: h,
            child: CustomPaint(
              painter: _CloudPainter(),
              child: Padding(
                padding: EdgeInsets.only(top: h * 0.14),
                child: Icon(
                  widget.icon,
                  size: widget.big ? 40 : 30,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cloud = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.3, h * 0.6), radius: h * 0.32),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.52, h * 0.42), radius: h * 0.4),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.74, h * 0.6), radius: h * 0.3),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.12, h * 0.55, w * 0.9, h * 0.92),
          Radius.circular(h * 0.2),
        ),
      );
    canvas.drawPath(
      cloud.shift(Offset(0, h * 0.06)),
      Paint()
        ..color = AppColors.glowRing.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      cloud,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE6DCFF)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.42, h * 0.3),
        width: w * 0.3,
        height: h * 0.14,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) => false;
}

/// When Chip can hear something but the phone won't say what: he wants to
/// know. Let him see it, or just tell him in his chat.
class _AccessHint extends ConsumerWidget {
  const _AccessHint({required this.music});

  final NowPlayingState music;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ios = !kIsWeb && Platform.isIOS;
    final text = ios
        ? (music.access == MusicAccess.granted
              ? strings.nowPlayingOohWhatSPlayingI
              : strings.nowPlayingOohWhatSPlayingLet)
        : strings.nowPlayingOohWhatSPlayingLet2;
    final canAsk = !ios || music.access == MusicAccess.unknown;
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.scrim(0.3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 13, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              if (canAsk)
                CloudButton(
                  icon: Icons.music_note_rounded,
                  label: ios
                      ? strings.nowPlayingShowMyAppleMusic
                      : strings.nowPlayingAllow,
                  big: true,
                  onTap: () =>
                      ref.read(nowPlayingProvider.notifier).requestAccess(),
                ),
              CloudButton(
                icon: Icons.chat_bubble_rounded,
                label: strings.nowPlayingTellChip,
                big: !canAsk,
                phase: 1.4,
                onTap: () {
                  // Off this card and into his chat.
                  Navigator.of(context).pop();
                  showChipChat(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
