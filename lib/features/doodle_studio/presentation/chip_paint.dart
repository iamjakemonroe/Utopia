import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/chip/chip_brain.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../domain/art_doc.dart';
import '../domain/regions.dart';
import 'art_render.dart';
import 'studio_toolbar.dart';

/// The ways Chip can color a picture at a tap (players can also describe
/// their own).
const kChipPaintStyles = [
  'Your pick',
  'Black and white shading',
  'Pastel',
  'Sunset',
  'Neon',
  'Ocean',
  'Autumn',
  'Royal gold',
];

/// Asks Chip to color [page] in [style]: its shapes go to him numbered on
/// a picture of the page, and his color for each one comes back.
Future<ChipPaint> askChipToPaint(
  ChipBrain brain,
  PageArt page,
  String style,
) async {
  final shapes = await page.regions.shapesInBackground();
  if (shapes.isEmpty) return const ChipPaint('error');
  final image = await numberedPage(page, shapes);
  return brain.paint(
    style: style,
    image: image,
    title: page.page.name,
    shapes: [
      for (final s in shapes)
        {
          'i': s.id,
          'x': s.labelX.round(),
          'y': s.labelY.round(),
          'w': s.width.round(),
          'h': s.height.round(),
          'a': s.area.round(),
        },
    ],
  );
}

/// The page's outlines on white paper, every shape's number written at its
/// label point (a PNG [scale] times the page's size). [fontFamily] is the
/// phone's own font unless given (tests load a real one).
Future<Uint8List> numberedPage(
  PageArt page,
  List<RegionInfo> shapes, {
  double scale = 0.75,
  String? fontFamily,
}) async {
  final size = kPageSize * scale;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  canvas.save();
  canvas.scale(scale);
  canvas.drawPicture(page.lines);
  canvas.restore();
  final halo = Paint()..color = const Color(0xD9FFFFFF);
  for (final s in shapes) {
    final fontSize = (math.sqrt(s.area) * scale * 0.16).clamp(9.0, 15.0);
    final text = TextPainter(
      text: TextSpan(
        text: '${s.id}',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFD7002A),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = Offset(
      s.labelX * scale - text.width / 2,
      s.labelY * scale - text.height / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (at & text.size).inflate(1.5),
        const Radius.circular(3),
      ),
      halo,
    );
    text.paint(canvas, at);
    text.dispose();
  }
  final picture = rec.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Asks how Chip should color the picture: one of [kChipPaintStyles], or
/// the player's own words. Null if they close it.
Future<String?> showChipPaintSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChipPaintSheet(),
  );
}

class _ChipPaintSheet extends StatefulWidget {
  const _ChipPaintSheet();

  @override
  State<_ChipPaintSheet> createState() => _ChipPaintSheetState();
}

class _ChipPaintSheetState extends State<_ChipPaintSheet> {
  final _own = TextEditingController();

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  void _pick(String style) {
    final s = style.trim();
    if (s.isNotEmpty) Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: const BoxDecoration(
          color: kStudioPaper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: kStudioInk, width: 2.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CoinBuddy(mood: BuddyMood.excited, size: 58),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'How should I color it?',
                      style: AppTextStyles.display(
                        fontSize: 21,
                        color: kStudioInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final style in kChipPaintStyles)
                    _StyleChip(label: style, onTap: () => _pick(style)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _own,
                      maxLength: 100,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _pick,
                      style: AppTextStyles.body(color: kStudioInk),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Or describe it, like "only blues"',
                        hintStyle: AppTextStyles.body(
                          color: kStudioInk.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: kStudioDesk,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StudioButton(
                    tooltip: 'Color it',
                    icon: Icons.palette_rounded,
                    onTap: () => _pick(_own.text),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kStudioDesk,
      shape: const StadiumBorder(side: BorderSide(color: kStudioInk, width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: AppTextStyles.body(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: kStudioInk,
            ),
          ),
        ),
      ),
    );
  }
}
