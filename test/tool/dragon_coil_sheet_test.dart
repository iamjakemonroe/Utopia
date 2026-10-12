// The Dragon Coil aura as the side menu shows it: a 30pt avatar, drawn at a
// phone's 3x pixel density, at six moments through its cycle (idle, the
// wingbeat, the fire). Renders test/tool/goldens/dragon_coil.png.
// Run: flutter test --update-goldens --run-skipped test/tool/dragon_coil_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/auras/presentation/aura_frame.dart';

const _times = [0.5, 1.6, 3.3, 3.9, 6.0, 7.5];
const _cell = Size(420, 460);
const _density = 3.0;
const _avatar = 30.0;

class _Sheet extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF17112A),
    );
    for (final (i, t) in _times.indexed) {
      final origin = Offset((i % 3) * _cell.width, (i ~/ 3) * _cell.height);
      final centre = origin + Offset(_cell.width / 2, _cell.height * 0.68);
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.scale(_density);
      // The painters see the avatar's own box, as AuraFrame gives them.
      canvas.translate(-_avatar, -_avatar);
      const box = Size.square(_avatar * 2);
      const mid = Offset(_avatar, _avatar);
      final clock = ValueNotifier<double>(t);
      // Same order as the side menu: its gold ring (the Container round the
      // avatar) is painted first, then the aura's back layer, the picture
      // with its thin rim, and the aura's front layer.
      canvas.drawCircle(
        mid,
        _avatar + 4.25,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFE8B84A),
      );
      AuraPainter('dragon', clock, front: false).paint(canvas, box);
      canvas.drawCircle(mid, _avatar, Paint()..color = const Color(0xFF4DA3FF));
      canvas.drawCircle(
        mid,
        _avatar - 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFB27BFF),
      );
      AuraPainter('dragon', clock, front: true).paint(canvas, box);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

void main() {
  testWidgets('dragon coil sheet', (tester) async {
    final size = Size(_cell.width * 3, _cell.height * 2);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: CustomPaint(size: size, painter: _Sheet()),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/dragon_coil.png'),
    );
  });
}
