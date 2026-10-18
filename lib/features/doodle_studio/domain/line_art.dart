import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'art_doc.dart';
import 'coloring_pages.dart';

/// Line-art pages (real portraits): each page's image, made ready once per
/// session as ink on clear paper, so it can be drawn over the colors.
class LineArt {
  LineArt._();

  /// Where the images come from: the picture library sets this.
  static Future<Uint8List> Function(String path)? source;

  /// Bumped whenever an image becomes ready, so anything drawing a page
  /// that was still loading draws it again.
  static final ready = ValueNotifier<int>(0);

  static final _images = <String, ui.Image>{};
  static final _loading = <String, Future<ui.Image>>{};

  /// [page]'s ink if it's ready (and starts getting it if not).
  static ui.Image? of(ColoringPage page) {
    final path = page.artPath;
    if (path == null) return null;
    final image = _images[path];
    if (image == null) unawaited(load(page).then((_) {}, onError: (_) {}));
    return image;
  }

  /// [page]'s ink, once it's fetched and made ready.
  static Future<ui.Image> load(ColoringPage page) {
    final path = page.artPath!;
    return _loading[path] ??= _make(path).then(
      (image) {
        _images[path] = image;
        ready.value++;
        return image;
      },
      onError: (Object e) {
        _loading.remove(path);
        throw e;
      },
    );
  }

  static Future<ui.Image> _make(String path) async {
    final get = source;
    if (get == null) throw StateError('nowhere to get line art from');
    final bytes = await get(path);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final art = frame.image;
    final data = await art.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = art.width, h = art.height;
    art.dispose();
    final pixels = data!.buffer.asUint8List();
    final ink = await Isolate.run(() => inkOf(pixels));
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(ink, w, h, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  /// The ink in a drawing (RGBA): dark pixels become the page's line color,
  /// as solid as they're dark; light ones (the paper) become clear.
  static Uint8List inkOf(Uint8List rgba) {
    final out = Uint8List(rgba.length);
    for (var i = 0; i < rgba.length; i += 4) {
      final lum =
          (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
      final dark = ((215 - lum) * 255 ~/ 155).clamp(0, 255);
      out[i] = 0x1F;
      out[i + 1] = 0x1E;
      out[i + 2] = 0x1B;
      out[i + 3] = dark * rgba[i + 3] ~/ 255;
    }
    return out;
  }

  /// Where [image] sits on the page: as big as fits, in the middle.
  static ui.Rect fit(ui.Image image) {
    final s = math.min(
      kPageSize.width / image.width,
      kPageSize.height / image.height,
    );
    final w = image.width * s, h = image.height * s;
    return ui.Rect.fromLTWH(
      (kPageSize.width - w) / 2,
      (kPageSize.height - h) / 2,
      w,
      h,
    );
  }
}
