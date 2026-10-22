import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Drawings kept as pictures of pixels, for a browser.
///
/// A browser draws every shape of every layer again each frame (the apps
/// keep what hasn't changed as pixels by themselves), and building a
/// shape there costs far more. A world's crosshatched islands and
/// branching trees are hundreds of shapes that only move as a whole (bob,
/// drift, sway): drawn once into pixels at the screen's full sharpness,
/// they're placed whole pixels apart from then on, so they look exactly
/// as drawn, at a sliver of the work.
///
/// Past [maxBytes], drawings not shown for a couple of seconds are let
/// go; when they're all still showing (a huge window), what doesn't fit
/// is drawn as it is each frame instead.
///
/// Where making pixels reads them back off the GPU ([readsBack]: Safari
/// and every iPhone, which draw with CanvasKit), each one stalls the GPU
/// and leaves a copy in CanvasKit's own small memory, which too many big
/// drawings run out (the browser's drawing then crashes), and a readback
/// can fail. There, pixels are kept only within half of [maxBytes] and
/// let go only when unseen for longer; the rest, and any whose pixels
/// couldn't be made, are kept as recorded pictures: the shapes are still
/// built only once, and they draw exactly as they would directly.
class SpriteCache {
  SpriteCache({
    this.maxBytes = 48 << 20,
    this.frameBudget = const Duration(milliseconds: 6),
  });

  final int maxBytes;

  /// How long a frame may spend making new drawings into pixels (one is
  /// always made, however slow the phone, so they all get made). Past it,
  /// the rest are drawn as they are this frame and made on the frames
  /// after: a world coming into view (the app opening, a trip to another
  /// world) makes its drawings over a few frames instead of stalling on
  /// them all at once. It looks the same either way.
  final Duration frameBudget;

  /// The frame making is in (a 60th of a second on [_clock]), and how
  /// long making has taken in it.
  int _frame = -1;
  Duration _spent = Duration.zero;
  final _sprites = <Object, _Sprite>{};
  int _bytes = 0;

  /// Pixels kept, and drawings, for tests.
  @visibleForTesting
  int get bytes => _bytes;
  @visibleForTesting
  int get length => _sprites.length;

  /// Drawings whose pixels couldn't be made: kept as pictures for good.
  final _noPixels = <Object>{};

  static final _clock = Stopwatch()..start();
  static const _stale = Duration(seconds: 2);
  static const _staleReadingBack = Duration(seconds: 10);

  /// Whether making pixels reads them back off the GPU: in a browser
  /// drawing with CanvasKit (a JavaScript build; the WebAssembly one draws
  /// with Skwasm, which makes images on the GPU).
  static bool get readsBack =>
      debugReadsBack ??
      (kIsWeb && !const bool.fromEnvironment('dart.tool.dart2wasm'));

  /// Forces [readsBack] (tests and the perf harness), or null for the
  /// browser's own.
  static bool? debugReadsBack;

  /// Makes making pixels fail (tests).
  @visibleForTesting
  static bool debugFailPixels = false;

  /// Draws what [paint] draws within [bounds] (around the origin), with
  /// its origin at [at], turned [angle] about it. The first time for
  /// [key] (which must name everything that changes the drawing, besides
  /// where it is), it's drawn into pixels at [dpr].
  ///
  /// With [absolute], [paint] draws where the thing is now (around [at])
  /// instead of around the origin.
  void draw(
    Canvas canvas,
    Object key, {
    required Rect bounds,
    required double dpr,
    required void Function(Canvas canvas) paint,
    Offset at = Offset.zero,
    double angle = 0,
    bool absolute = false,
  }) {
    final fullKey = (key, dpr);
    var sprite = _sprites.remove(fullKey);
    if (sprite == null) {
      final frame = _clock.elapsedMilliseconds ~/ 16;
      if (frame != _frame) {
        _frame = frame;
        _spent = Duration.zero;
      }
      final readingBack = readsBack;
      final bytes = _Sprite.bytesFor(bounds, dpr);
      final room = readingBack ? maxBytes ~/ 2 : maxBytes;
      _makeRoom(bytes, room, readingBack ? _staleReadingBack : _stale);
      final pixels =
          _bytes + bytes <= room &&
          _spent <= frameBudget &&
          !_noPixels.contains(fullKey);
      if (!pixels && !readingBack) {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        if (angle != 0) canvas.rotate(angle);
        if (absolute) canvas.translate(-at.dx, -at.dy);
        paint(canvas);
        canvas.restore();
        return;
      }
      final making = Stopwatch()..start();
      void record(Canvas c) {
        if (absolute) c.translate(-at.dx, -at.dy);
        paint(c);
      }

      if (pixels) {
        try {
          if (debugFailPixels) throw StateError('no pixels (test)');
          sprite = _Sprite.draw(bounds, dpr, record);
        } catch (_) {
          // Never asked again (it failed the same way each frame before).
          _noPixels.add(fullKey);
          sprite = _Sprite.record(record);
        }
      } else {
        sprite = _Sprite.record(record);
      }
      _spent += making.elapsed;
      _bytes += sprite.bytes;
    }
    sprite.shown = _clock.elapsed;
    _sprites[fullKey] = sprite;

    final picture = sprite.picture;
    if (picture != null) {
      // As it would be drawn directly.
      canvas.save();
      canvas.translate(at.dx, at.dy);
      if (angle != 0) canvas.rotate(angle);
      canvas.drawPicture(picture);
      canvas.restore();
      return;
    }
    canvas.save();
    // Whole pixels apart, so the pixels land on pixels.
    canvas.translate(
      (at.dx * dpr).roundToDouble() / dpr,
      (at.dy * dpr).roundToDouble() / dpr,
    );
    if (angle != 0) canvas.rotate(angle);
    canvas.drawImageRect(sprite.image!, sprite.source, sprite.dest, _paint);
    canvas.restore();
  }

  /// Lets go of drawings not shown for [stale], oldest first, until
  /// [bytes] more fit in [room].
  void _makeRoom(int bytes, int room, Duration stale) {
    final now = _clock.elapsed;
    while (_bytes + bytes > room && _sprites.isNotEmpty) {
      final oldest = _sprites.keys.first;
      if (now - _sprites[oldest]!.shown < stale) return;
      _let(_sprites.remove(oldest)!);
    }
  }

  void _let(_Sprite sprite) {
    _bytes -= sprite.bytes;
    sprite.image?.dispose();
    sprite.picture?.dispose();
  }

  /// Lets every drawing go.
  void clear() {
    for (final sprite in _sprites.values) {
      _let(sprite);
    }
    _sprites.clear();
    _noPixels.clear();
  }

  static final _paint = Paint()..filterQuality = FilterQuality.low;
}

/// The worlds' drawings kept as pixels: one budget, whichever world is
/// showing.
final worldSprites = SpriteCache();

class _Sprite {
  _Sprite(this.image, this.source, this.dest) : picture = null;

  /// [paint]'s drawing kept as it was recorded (see
  /// [SpriteCache.keepsPictures]).
  _Sprite.record(void Function(Canvas) paint)
    : image = null,
      picture = _recorded(paint),
      source = Rect.zero,
      dest = Rect.zero;

  static ui.Picture _recorded(void Function(Canvas) paint) {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    return recorder.endRecording();
  }

  /// [paint]'s drawing within [bounds], at [dpr] pixels a point. Its edges
  /// are on whole pixels, so its pixels land on the screen's.
  factory _Sprite.draw(Rect bounds, double dpr, void Function(Canvas) paint) {
    final (left, top, width, height) = _pixels(bounds, dpr);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(-left.toDouble(), -top.toDouble())
      ..scale(dpr);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return _Sprite(
      image,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Rect.fromLTWH(left / dpr, top / dpr, width / dpr, height / dpr),
    );
  }

  final ui.Image? image;
  final ui.Picture? picture;
  final Rect source;
  final Rect dest;

  /// When it was last shown (on [SpriteCache._clock]).
  Duration shown = Duration.zero;

  /// What it holds: an image's pixels, or a nominal size for a picture
  /// (a list of shapes), so endless keys still meet the budget.
  int get bytes {
    final i = image;
    return i == null ? pictureBytes : i.width * i.height * 4;
  }

  static const pictureBytes = 4096;

  static int bytesFor(Rect bounds, double dpr) {
    final (_, _, width, height) = _pixels(bounds, dpr);
    return width * height * 4;
  }

  /// [bounds] in whole pixels: left, top, width, height.
  static (int, int, int, int) _pixels(Rect bounds, double dpr) {
    final left = (bounds.left * dpr).floor();
    final top = (bounds.top * dpr).floor();
    return (
      left,
      top,
      ((bounds.right * dpr).ceil() - left).clamp(1, 8192),
      ((bounds.bottom * dpr).ceil() - top).clamp(1, 8192),
    );
  }
}
