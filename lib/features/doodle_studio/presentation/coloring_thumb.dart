import 'package:flutter/material.dart';

import '../domain/art_doc.dart';
import '../domain/coloring_pages.dart';
import '../domain/line_art.dart';
import 'art_render.dart';

/// A coloring page drawn small, outlines on paper.
class ColoringThumb extends StatelessWidget {
  const ColoringThumb(this.page, {super.key});

  final ColoringPage page;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kPageSize.width / kPageSize.height,
      child: CustomPaint(painter: _Thumb(page)),
    );
  }
}

class _Thumb extends CustomPainter {
  _Thumb(this.page) : super(repaint: LineArt.ready);

  final ColoringPage page;
  static final _paths = <String, List<Path>>{};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kPaper);
    canvas.scale(size.width / kPageSize.width);
    paintPageLines(canvas, page, _paths);
  }

  @override
  bool shouldRepaint(_Thumb old) => old.page.id != page.id;
}
