import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The picture for each coin pack, growing with its size: a velvet pouch,
/// a bulging sack, an open treasure chest, gold bars, a mountain of coins,
/// a dragon's hoard, a floating treasure island, and that island crowned
/// with a gold castle. [t] is seconds, for glints, sparkles, flags and
/// falling coins.
class CoinPackArtPainter extends CustomPainter {
  CoinPackArtPainter({required this.tier, required this.t});

  final int tier;
  final double t;

  static const _gold = [
    Color(0xFFFFF4C2),
    Color(0xFFFFD45E),
    Color(0xFFE5A834),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Everything bobs a little.
    canvas.save();
    canvas.translate(0, math.sin(t * 2 + tier) * h * 0.015);
    _glow(canvas, Offset(w / 2, h * 0.58), w * (0.36 + tier * 0.03));
    switch (tier) {
      case 0:
        _pouch(canvas, w, h);
      case 1:
        _sack(canvas, w, h);
      case 2:
        _chest(canvas, w, h);
      case 3:
        _bars(canvas, w, h);
      case 4:
        _mountain(canvas, w, h, crown: false);
      case 5:
        _mountain(canvas, w, h, crown: true);
      case 6:
        _island(canvas, w, h);
      default:
        _island(canvas, w, h, castle: true);
    }
    canvas.restore();
    _sparkles(canvas, w, h);
  }

  // ── pieces ──────────────────────────────────────────────────────────────

  void _glow(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD45E).withValues(alpha: 0.32 + tier * 0.04),
            const Color(0x00FFD45E),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  /// A coin lying flat, seen from above at an angle.
  void _coin(Canvas canvas, Offset c, double w) {
    final h = w * 0.42;
    final thick = w * 0.13;
    final top = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawOval(
      top.translate(0, thick),
      Paint()..color = const Color(0xFF9A6410),
    );
    canvas.drawRect(
      Rect.fromLTRB(top.left, c.dy, top.right, c.dy + thick),
      Paint()..color = const Color(0xFFC88A1E),
    );
    canvas.drawOval(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gold,
        ).createShader(top),
    );
    canvas.drawOval(
      top.deflate(w * 0.12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = const Color(0x66A86E14),
    );
  }

  /// A coin standing up, slowly turning.
  void _standingCoin(Canvas canvas, Offset c, double r, double spin) {
    final sx = math.max(0.15, math.cos(spin).abs());
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(sx, 1);
    canvas.drawCircle(
      const Offset(0, 2),
      r,
      Paint()..color = const Color(0xFFA86E14),
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: _gold,
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = const Color(0x66A86E14),
    );
    _star(canvas, Offset.zero, r * 0.42, const Color(0xFFFFF6CF));
    canvas.restore();
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  void _bag(
    Canvas canvas,
    double w,
    double h, {
    required double width,
    required List<Color> cloth,
    required Color rope,
  }) {
    final cx = w / 2;
    final neckY = h * 0.38;
    final body = Path()
      ..moveTo(cx - w * 0.11, neckY)
      ..cubicTo(
        cx - w * width,
        h * 0.5,
        cx - w * (width + 0.04),
        h * 0.86,
        cx - w * width * 0.7,
        h * 0.9,
      )
      ..lineTo(cx + w * width * 0.7, h * 0.9)
      ..cubicTo(
        cx + w * (width + 0.04),
        h * 0.86,
        cx + w * width,
        h * 0.5,
        cx + w * 0.11,
        neckY,
      )
      ..close();
    final rect = Rect.fromLTRB(cx - w * width, neckY, cx + w * width, h * 0.9);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cloth,
        ).createShader(rect),
    );
    // Folds and a soft sheen.
    canvas.drawOval(
      Rect.fromLTWH(cx - w * width * 0.75, h * 0.5, w * width * 0.45, h * 0.22),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    // Ruffled top above the tie.
    final ruffle = Path()
      ..moveTo(cx - w * 0.11, neckY)
      ..quadraticBezierTo(cx - w * 0.2, h * 0.3, cx - w * 0.16, h * 0.25)
      ..quadraticBezierTo(cx - w * 0.06, h * 0.3, cx, h * 0.24)
      ..quadraticBezierTo(cx + w * 0.06, h * 0.3, cx + w * 0.16, h * 0.25)
      ..quadraticBezierTo(cx + w * 0.2, h * 0.3, cx + w * 0.11, neckY)
      ..close();
    canvas.drawPath(ruffle, Paint()..color = cloth[1]);
    // The rope tie with a little tassel.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, neckY),
          width: w * 0.26,
          height: h * 0.06,
        ),
        Radius.circular(h * 0.03),
      ),
      Paint()..color = rope,
    );
    canvas.drawLine(
      Offset(cx + w * 0.08, neckY),
      Offset(cx + w * 0.12, neckY + h * 0.14),
      Paint()
        ..color = rope
        ..strokeWidth = w * 0.022
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(cx + w * 0.12, neckY + h * 0.16),
      w * 0.025,
      Paint()..color = rope,
    );
  }

  void _pouch(Canvas canvas, double w, double h) {
    // Coins peeking out of the top.
    _coin(canvas, Offset(w * 0.45, h * 0.26), w * 0.2);
    _coin(canvas, Offset(w * 0.57, h * 0.23), w * 0.2);
    _bag(
      canvas,
      w,
      h,
      width: 0.27,
      cloth: const [Color(0xFFC9B3FF), Color(0xFF7B4DFF), Color(0xFF3D1F8A)],
      rope: const Color(0xFFFFC94D),
    );
    _star(canvas, Offset(w * 0.5, h * 0.66), w * 0.07, const Color(0xFFFFD45E));
  }

  void _sack(Canvas canvas, double w, double h) {
    _coin(canvas, Offset(w * 0.42, h * 0.25), w * 0.22);
    _coin(canvas, Offset(w * 0.58, h * 0.22), w * 0.22);
    _bag(
      canvas,
      w,
      h,
      width: 0.34,
      cloth: const [Color(0xFFF7DCAA), Color(0xFFD9A066), Color(0xFF8A5A2E)],
      rope: const Color(0xFF7A4A22),
    );
    // A gold coin badge stitched on the front.
    _standingCoin(canvas, Offset(w * 0.5, h * 0.66), w * 0.1, 0);
    // Coins spilling out at the front.
    _coin(canvas, Offset(w * 0.2, h * 0.88), w * 0.2);
    _coin(canvas, Offset(w * 0.8, h * 0.9), w * 0.18);
    _standingCoin(canvas, Offset(w * 0.82, h * 0.76), w * 0.08, t * 2);
  }

  void _chest(Canvas canvas, double w, double h) {
    final l = w * 0.16, r = w * 0.84, top = h * 0.52, bottom = h * 0.9;
    // Light pouring out of the open chest.
    final beam = Path()
      ..moveTo(l + w * 0.06, top)
      ..lineTo(w * 0.04, h * 0.02)
      ..lineTo(w * 0.96, h * 0.02)
      ..lineTo(r - w * 0.06, top)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(
              0xFFFFE29A,
            ).withValues(alpha: 0.55 + 0.2 * math.sin(t * 3)),
            const Color(0x00FFE29A),
          ],
        ).createShader(Rect.fromLTRB(0, 0, w, top)),
    );
    // Lid, tipped back.
    final lid = Path()
      ..moveTo(l + w * 0.03, top - h * 0.02)
      ..lineTo(l + w * 0.08, h * 0.24)
      ..quadraticBezierTo(w / 2, h * 0.14, r - w * 0.08, h * 0.24)
      ..lineTo(r - w * 0.03, top - h * 0.02)
      ..close();
    canvas.drawPath(lid, Paint()..color = const Color(0xFF6B3412));
    canvas.drawPath(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..color = const Color(0xFFE5A834),
    );
    // Heap of coins inside.
    for (var i = 0; i < 6; i++) {
      _coin(
        canvas,
        Offset(
          l + w * (0.12 + i * 0.1),
          top - h * 0.02 - (i.isEven ? 0 : h * 0.04),
        ),
        w * 0.17,
      );
    }
    _coin(canvas, Offset(w * 0.5, top - h * 0.09), w * 0.18);
    // Box.
    final box = RRect.fromLTRBR(l, top, r, bottom, Radius.circular(w * 0.04));
    canvas.drawRRect(
      box,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC0723A), Color(0xFF7A3E16)],
        ).createShader(box.outerRect),
    );
    final band = Paint()..color = const Color(0xFFE5A834);
    for (final x in [l + w * 0.12, r - w * 0.16]) {
      canvas.drawRect(Rect.fromLTRB(x, top, x + w * 0.04, bottom), band);
    }
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..color = const Color(0xFFFFD45E),
    );
    // Lock.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, top + h * 0.1),
          width: w * 0.12,
          height: h * 0.14,
        ),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = const Color(0xFFFFD45E),
    );
    canvas.drawCircle(
      Offset(w / 2, top + h * 0.09),
      w * 0.018,
      Paint()..color = const Color(0xFF6B3412),
    );
  }

  void _bars(Canvas canvas, double w, double h) {
    final bw = w * 0.27, bh = h * 0.12;
    void bar(Offset c) {
      final topFace = Path()
        ..moveTo(c.dx - bw * 0.38, c.dy - bh)
        ..lineTo(c.dx + bw * 0.38, c.dy - bh)
        ..lineTo(c.dx + bw / 2, c.dy - bh * 0.55)
        ..lineTo(c.dx - bw / 2, c.dy - bh * 0.55)
        ..close();
      final front = Rect.fromLTRB(
        c.dx - bw / 2,
        c.dy - bh * 0.55,
        c.dx + bw / 2,
        c.dy,
      );
      canvas.drawRect(
        front,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD45E), Color(0xFFC98A1E)],
          ).createShader(front),
      );
      canvas.drawPath(topFace, Paint()..color = const Color(0xFFFFF0B8));
      canvas.drawRect(
        front.deflate(bw * 0.12),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x55A86E14),
      );
    }

    final base = h * 0.9;
    for (var i = 0; i < 3; i++) {
      bar(Offset(w * 0.5 + (i - 1) * bw * 1.02, base));
    }
    for (var i = 0; i < 2; i++) {
      bar(Offset(w * 0.5 + (i - 0.5) * bw * 1.02, base - bh * 0.92));
    }
    bar(Offset(w * 0.5, base - bh * 1.84));
    // A glint sweeping across the stack.
    final x = ((t * 0.5) % 1.4 - 0.2) * w;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(w * 0.08, base - bh * 3, w * 0.92, base));
    canvas.drawRect(
      Rect.fromLTWH(x, 0, w * 0.08, h),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x, 0, w * 0.08, h)),
    );
    canvas.restore();
    _standingCoin(canvas, Offset(w * 0.12, h * 0.78), w * 0.08, t * 1.6);
    _standingCoin(canvas, Offset(w * 0.88, h * 0.8), w * 0.07, t * 1.3 + 1);
  }

  void _mountain(Canvas canvas, double w, double h, {required bool crown}) {
    final rows = crown ? 7 : 6;
    final cw = w * (crown ? 0.15 : 0.16);
    for (var row = 0; row < rows; row++) {
      final count = rows - row;
      final y = h * 0.9 - row * cw * 0.32;
      for (var i = 0; i < count; i++) {
        final x = w / 2 + (i - (count - 1) / 2) * cw * 0.78;
        _coin(canvas, Offset(x, y), cw);
      }
    }
    final peak = Offset(w / 2, h * 0.9 - (rows - 1) * cw * 0.32);
    if (crown) {
      // Gems glinting in the pile.
      const gems = [
        (0.3, 0.8, Color(0xFFFF5C6C)),
        (0.62, 0.74, Color(0xFF4DA3FF)),
        (0.45, 0.62, Color(0xFF2FD98E)),
        (0.7, 0.86, Color(0xFFB27BFF)),
      ];
      for (final (gx, gy, color) in gems) {
        final c = Offset(w * gx, h * gy);
        final s = w * 0.05;
        final gem = Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx + s * 0.8, c.dy)
          ..lineTo(c.dx, c.dy + s)
          ..lineTo(c.dx - s * 0.8, c.dy)
          ..close();
        canvas.drawPath(gem, Paint()..color = color);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - s)
            ..lineTo(c.dx + s * 0.8, c.dy)
            ..lineTo(c.dx, c.dy)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: 0.4),
        );
      }
      // A crown sitting on top.
      final cs = w * 0.2;
      final top = peak.translate(0, -cw * 0.3);
      final crownPath = Path()
        ..moveTo(top.dx - cs / 2, top.dy)
        ..lineTo(top.dx - cs / 2, top.dy - cs * 0.45)
        ..lineTo(top.dx - cs / 4, top.dy - cs * 0.2)
        ..lineTo(top.dx, top.dy - cs * 0.6)
        ..lineTo(top.dx + cs / 4, top.dy - cs * 0.2)
        ..lineTo(top.dx + cs / 2, top.dy - cs * 0.45)
        ..lineTo(top.dx + cs / 2, top.dy)
        ..close();
      canvas.drawPath(
        crownPath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF0B8), Color(0xFFE5A834)],
          ).createShader(crownPath.getBounds()),
      );
      canvas.drawCircle(
        top.translate(0, -cs * 0.15),
        cs * 0.07,
        Paint()..color = const Color(0xFFFF5C9C),
      );
    } else {
      // A little flag planted at the top.
      final base = peak.translate(0, -cw * 0.1);
      canvas.drawLine(
        base,
        base.translate(0, -h * 0.26),
        Paint()
          ..color = const Color(0xFF7A4A22)
          ..strokeWidth = w * 0.02,
      );
      final wave = math.sin(t * 5) * w * 0.02;
      final flag = Path()
        ..moveTo(base.dx, base.dy - h * 0.26)
        ..quadraticBezierTo(
          base.dx + w * 0.1,
          base.dy - h * 0.24 + wave,
          base.dx + w * 0.18,
          base.dy - h * 0.22,
        )
        ..lineTo(base.dx, base.dy - h * 0.15)
        ..close();
      canvas.drawPath(flag, Paint()..color = const Color(0xFFFF5C9C));
    }
  }

  void _island(Canvas canvas, double w, double h, {bool castle = false}) {
    // Rainbow behind.
    const bands = [
      Color(0xFFFF5C6C),
      Color(0xFFFFC93D),
      Color(0xFF2FD98E),
      Color(0xFF4DA3FF),
      Color(0xFFB27BFF),
    ];
    for (final (i, color) in bands.indexed) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(w / 2, h * 0.62),
          radius: w * (0.46 - i * 0.035),
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035
          ..color = color.withValues(alpha: 0.5),
      );
    }
    final c = Offset(w / 2, h * 0.62);
    // Rocky underside.
    final rock = Path()
      ..moveTo(c.dx - w * 0.36, c.dy)
      ..quadraticBezierTo(
        c.dx - w * 0.2,
        c.dy + h * 0.28,
        c.dx,
        c.dy + h * 0.36,
      )
      ..quadraticBezierTo(
        c.dx + w * 0.2,
        c.dy + h * 0.28,
        c.dx + w * 0.36,
        c.dy,
      )
      ..close();
    canvas.drawPath(
      rock,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A55B0), Color(0xFF1E0F45)],
        ).createShader(rock.getBounds()),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w * 0.74, height: h * 0.14),
      Paint()..color = const Color(0xFF3FD9AE),
    );
    // Coins pouring off the edge.
    for (var i = 0; i < 5; i++) {
      final p = (t * 0.8 + i / 5) % 1;
      _standingCoin(
        canvas,
        Offset(c.dx + w * 0.3 + p * w * 0.06, c.dy + p * h * 0.4),
        w * 0.035,
        t * 5 + i,
      );
    }
    // The castle stands on the grass, with gold piled round its feet.
    if (castle) _castle(canvas, Offset(c.dx, c.dy + h * 0.01), w);
    // Heap of gold on top.
    for (var row = 0; row < (castle ? 2 : 4); row++) {
      final count = 5 - row;
      for (var i = 0; i < count; i++) {
        _coin(
          canvas,
          Offset(c.dx + (i - (count - 1) / 2) * w * 0.1, c.dy - row * h * 0.05),
          w * 0.13,
        );
      }
    }
    if (!castle) {
      _standingCoin(canvas, Offset(c.dx, c.dy - h * 0.25), w * 0.07, t * 2);
    }
  }

  /// A little gold castle: three pink-roofed towers with waving flags
  /// behind a keep whose gate glows.
  void _castle(Canvas canvas, Offset base, double w) {
    final bounds = Rect.fromLTRB(
      base.dx - w * 0.22,
      base.dy - w * 0.32,
      base.dx + w * 0.22,
      base.dy,
    );
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _gold,
      ).createShader(bounds);
    final shade = Paint()..color = const Color(0x55A0660C);

    void block(Rect r) {
      canvas.drawRect(r, gold);
      // Shadow down the right side, for a bit of depth.
      canvas.drawRect(
        Rect.fromLTRB(r.right - r.width * 0.28, r.top, r.right, r.bottom),
        shade,
      );
    }

    void tower(double dx, double width, double height, double phase) {
      final r = Rect.fromLTWH(
        base.dx + dx - width / 2,
        base.dy - height,
        width,
        height,
      );
      block(r);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(r.center.dx, r.top + height * 0.3),
            width: width * 0.34,
            height: height * 0.18,
          ),
          Radius.circular(width * 0.17),
        ),
        Paint()..color = const Color(0xFF6A3A0C),
      );
      final peak = Offset(r.center.dx, r.top - width * 1.05);
      canvas.drawPath(
        Path()
          ..moveTo(r.left - width * 0.18, r.top)
          ..lineTo(peak.dx, peak.dy)
          ..lineTo(r.right + width * 0.18, r.top)
          ..close(),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFF8ABE), Color(0xFFD9327A)],
          ).createShader(Rect.fromLTRB(r.left, peak.dy, r.right, r.top)),
      );
      // A flag on top, waving.
      final pole = peak.translate(0, -width * 0.55);
      canvas.drawLine(
        peak,
        pole,
        Paint()
          ..color = const Color(0xFFFFF4C2)
          ..strokeWidth = 1.2,
      );
      final wave = math.sin(t * 6 + phase) * width * 0.1;
      canvas.drawPath(
        Path()
          ..moveTo(pole.dx, pole.dy)
          ..quadraticBezierTo(
            pole.dx + width * 0.3,
            pole.dy + wave,
            pole.dx + width * 0.6,
            pole.dy + width * 0.08 + wave,
          )
          ..lineTo(pole.dx, pole.dy + width * 0.3)
          ..close(),
        Paint()..color = const Color(0xFF4DA3FF),
      );
    }

    tower(-w * 0.15, w * 0.1, w * 0.25, 0);
    tower(w * 0.15, w * 0.1, w * 0.25, 2);
    tower(0, w * 0.12, w * 0.32, 4);

    // The keep, with battlements.
    final keepW = w * 0.26;
    final keepH = w * 0.16;
    final keep = Rect.fromLTWH(
      base.dx - keepW / 2,
      base.dy - keepH,
      keepW,
      keepH,
    );
    block(keep);
    final merlon = keepW / 7;
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          keep.left + i * 2 * merlon,
          keep.top - merlon * 0.9,
          merlon,
          merlon * 0.9,
        ),
        gold,
      );
    }
    // An arched gate with warm light inside.
    final half = keepW * 0.17;
    final gate = Path()
      ..moveTo(base.dx - half, base.dy)
      ..lineTo(base.dx - half, base.dy - keepH * 0.5)
      ..arcToPoint(
        Offset(base.dx + half, base.dy - keepH * 0.5),
        radius: Radius.circular(half),
      )
      ..lineTo(base.dx + half, base.dy)
      ..close();
    final glow = 0.5 + 0.5 * math.sin(t * 2.5);
    canvas.drawPath(
      gate,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF8A4A0A),
          const Color(0xFFFFF4C2),
          glow,
        )!,
    );
  }

  void _sparkles(Canvas canvas, double w, double h) {
    final count = 2 + tier;
    for (var i = 0; i < count; i++) {
      final phase = (t * 0.7 + i * 0.37) % 1.6;
      if (phase > 1) continue;
      final s = math.sin(phase * math.pi) * w * 0.05;
      final x = w * (0.15 + ((i * 0.618) % 1) * 0.7);
      final y = h * (0.1 + ((i * 0.37) % 1) * 0.6);
      final p = Offset(x, y);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - s)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CoinPackArtPainter old) =>
      old.t != t || old.tier != tier;
}
