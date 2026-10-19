import 'dart:ui' as ui;

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
class SpriteCache {
  SpriteCache({this.maxBytes = 48 << 20});

  final int maxBytes;
  final _sprites = <Object, _Sprite>{};
  int _bytes = 0;

  static final _clock = Stopwatch()..start();
  static const _stale = Duration(seconds: 2);

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
      final bytes = _Sprite.bytesFor(bounds, dpr);
      _makeRoom(bytes);
      if (_bytes + bytes > maxBytes) {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        if (angle != 0) canvas.rotate(angle);
        if (absolute) canvas.translate(-at.dx, -at.dy);
        paint(canvas);
        canvas.restore();
        return;
      }
      sprite = _Sprite.draw(bounds, dpr, (c) {
        if (absolute) c.translate(-at.dx, -at.dy);
        paint(c);
      });
      _bytes += sprite.bytes;
    }
    sprite.shown = _clock.elapsed;
    _sprites[fullKey] = sprite;

    canvas.save();
    // Whole pixels apart, so the pixels land on pixels.
    canvas.translate(
      (at.dx * dpr).roundToDouble() / dpr,
      (at.dy * dpr).roundToDouble() / dpr,
    );
    if (angle != 0) canvas.rotate(angle);
    canvas.drawImageRect(sprite.image, sprite.source, sprite.dest, _paint);
    canvas.restore();
  }

  /// Lets go of drawings not shown lately, oldest first, until [bytes]
  /// more fit.
  void _makeRoom(int bytes) {
    final now = _clock.elapsed;
    while (_bytes + bytes > maxBytes && _sprites.isNotEmpty) {
      final oldest = _sprites.keys.first;
      if (now - _sprites[oldest]!.shown < _stale) return;
      _let(_sprites.remove(oldest)!);
    }
  }

  void _let(_Sprite sprite) {
    _bytes -= sprite.bytes;
    sprite.image.dispose();
  }

  /// Lets every drawing go.
  void clear() {
    for (final sprite in _sprites.values) {
      _let(sprite);
    }
    _sprites.clear();
  }

  static final _paint = Paint()..filterQuality = FilterQuality.low;
}

/// The worlds' drawings kept as pixels: one budget, whichever world is
/// showing.
final worldSprites = SpriteCache();

class _Sprite {
  _Sprite(this.image, this.source, this.dest);

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

  final ui.Image image;
  final Rect source;
  final Rect dest;

  /// When it was last shown (on [SpriteCache._clock]).
  Duration shown = Duration.zero;

  int get bytes => image.width * image.height * 4;

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
