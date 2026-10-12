import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/app_text_styles.dart';

const _red = Color(0xFFFF1F3D);

/// "Mythic" in hot red with lightning crackling across it, for the tier
/// that sits above legendary. [chip] wraps it in a glowing red pill.
class MythicLightning extends StatefulWidget {
  const MythicLightning({
    super.key,
    this.fontSize = 18,
    this.label = 'Mythic',
    this.chip = false,
  });

  final double fontSize;
  final String label;
  final bool chip;

  @override
  State<MythicLightning> createState() => _MythicLightningState();
}

class _MythicLightningState extends State<MythicLightning>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Started here, not lazily: a lazy ticker would never start.
    _ticker = createTicker((e) => _t.value = e.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.fontSize;
    return ValueListenableBuilder<double>(
      valueListenable: _t,
      builder: (context, t, _) {
        // A flash a few times a second, like a live wire.
        final flash = _flash(t);
        final text = ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(const Color(0xFFFF8A96), Colors.white, flash)!,
              _red,
              const Color(0xFFB30020),
            ],
          ).createShader(rect),
          child: Text(
            widget.label,
            style: AppTextStyles.display(fontSize: size, color: Colors.white)
                .copyWith(
                  shadows: [
                    Shadow(
                      color: _red.withValues(alpha: 0.6 + 0.4 * flash),
                      blurRadius: size * (0.5 + 0.6 * flash),
                    ),
                  ],
                ),
          ),
        );
        final bolt = Opacity(
          opacity: 0.55 + 0.45 * flash,
          child: Icon(
            Icons.bolt_rounded,
            size: size * 1.05,
            color: Color.lerp(_red, Colors.white, flash * 0.7),
            shadows: [Shadow(color: _red, blurRadius: size * 0.6)],
          ),
        );
        final body = CustomPaint(
          foregroundPainter: _CracklePainter(t: t, scale: size),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              bolt,
              SizedBox(width: size * 0.12),
              text,
            ],
          ),
        );
        if (!widget.chip) return body;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: size * 0.45,
            vertical: size * 0.12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.8),
            color: _red.withValues(alpha: 0.18 + 0.1 * flash),
            border: Border.all(color: _red.withValues(alpha: 0.9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: 0.35 + 0.35 * flash),
                blurRadius: size * 0.7,
              ),
            ],
          ),
          child: body,
        );
      },
    );
  }

  static double _flash(double t) {
    final beat = (t * 3.3) % 1;
    final second = (t * 3.3 + 0.37) % 1;
    return math.max(
      beat < 0.08 ? 1 - beat / 0.08 : 0.0,
      second < 0.05 ? 0.6 * (1 - second / 0.05) : 0.0,
    );
  }
}

double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// Little bolts jumping between points around the label, a new set every
/// tenth of a second.
class _CracklePainter extends CustomPainter {
  _CracklePainter({required this.t, required this.scale});

  final double t;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = (t * 10).floor();
    for (var b = 0; b < 2; b++) {
      final seed = frame * 13 + b * 7;
      if (_rand(seed, 1) < 0.45) continue;
      final from = Offset(
        _rand(seed, 2) * size.width,
        _rand(seed, 3) < 0.5 ? -scale * 0.15 : size.height + scale * 0.15,
      );
      final to = Offset(
        _rand(seed, 4) * size.width,
        size.height * _rand(seed, 5),
      );
      final path = Path()..moveTo(from.dx, from.dy);
      const steps = 5;
      for (var s = 1; s <= steps; s++) {
        final p = Offset.lerp(from, to, s / steps)!;
        final jitter = s == steps
            ? 0.0
            : (_rand(seed + s, 6) - 0.5) * scale * 0.5;
        path.lineTo(p.dx + jitter, p.dy + jitter * 0.4);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * 0.14
          ..strokeJoin = StrokeJoin.round
          ..color = _red.withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.12),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, scale * 0.04)
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CracklePainter old) =>
      (old.t * 10).floor() != (t * 10).floor() || old.scale != scale;
}

/// Wraps a Mythic aura's buy button in power that's trying to come alive:
/// a low red glow most of the time, then the edge sputters (flickers and
/// tiny sparks, dimming as if it lost the charge), surges once with arcs
/// jumping off the button, and dies back down to wait again. Something
/// about to be born, not a constant light show.
class MythicCharge extends StatefulWidget {
  const MythicCharge({
    super.key,
    required this.child,
    this.enabled = true,
    this.radius = 26,
    this.bottomInset = 5,
  });

  final Widget child;

  /// Off while a purchase is going through.
  final bool enabled;

  /// Corner radius of the button underneath.
  final double radius;

  /// Space under the button that isn't the button (its drop shadow).
  final double bottomInset;

  @override
  State<MythicCharge> createState() => _MythicChargeState();
}

class _MythicChargeState extends State<MythicCharge>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _t.value = e.inMicroseconds / 1e6);
    if (widget.enabled) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant MythicCharge old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_ticker.isActive) _ticker.start();
    if (!widget.enabled && _ticker.isActive) {
      _ticker.stop();
      _t.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChargePainter(
        t: _t,
        radius: widget.radius,
        bottomInset: widget.bottomInset,
        glowOnly: true,
      ),
      foregroundPainter: _ChargePainter(
        t: _t,
        radius: widget.radius,
        bottomInset: widget.bottomInset,
        glowOnly: false,
      ),
      child: widget.child,
    );
  }
}

/// How the charge rises and falls over one cycle.
enum _Phase { idle, sputter, surge, fade }

const _cycle = 3.6;

(_Phase, double) _phaseAt(double t) {
  final c = t % _cycle;
  if (c < 1.7) return (_Phase.idle, c / 1.7);
  if (c < 2.55) return (_Phase.sputter, (c - 1.7) / 0.85);
  if (c < 2.8) return (_Phase.surge, (c - 2.55) / 0.25);
  return (_Phase.fade, (c - 2.8) / 0.8);
}

/// 0 (no power) to 1 (full surge).
double _power(double t) {
  final base = 0.16 + 0.05 * math.sin(t * 2.2);
  final round = (t / _cycle).floor();
  final (phase, k) = _phaseAt(t);
  switch (phase) {
    case _Phase.idle:
      return base;
    case _Phase.sputter:
      // Catching and losing it: on/off flickers that dip below idle.
      final frame = (t * 20).floor();
      final on = _rand(frame, round + 3) > 0.5 + 0.2 * (1 - k);
      return on ? 0.3 + 0.4 * _rand(frame, 9) : base * 0.4;
    case _Phase.surge:
      return 0.45 + 0.55 * Curves.easeOut.transform(k);
    case _Phase.fade:
      final f = Curves.easeIn.transform(k);
      return 1.0 * (1 - f) + base * f;
  }
}

class _ChargePainter extends CustomPainter {
  _ChargePainter({
    required this.t,
    required this.radius,
    required this.bottomInset,
    required this.glowOnly,
  }) : super(repaint: t);

  final ValueNotifier<double> t;
  final double radius;
  final double bottomInset;
  final bool glowOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final now = t.value;
    if (now == 0) return;
    final rect = Offset.zero & Size(size.width, size.height - bottomInset);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final p = _power(now);

    if (glowOnly) {
      canvas.drawRRect(
        rrect.inflate(2 + 6 * p),
        Paint()
          ..color = _red.withValues(alpha: 0.25 + 0.5 * p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 14 * p),
      );
      return;
    }

    // A live edge, brighter as the charge builds.
    canvas.drawRRect(
      rrect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + 1.4 * p
        ..color = Color.lerp(
          _red,
          Colors.white,
          p,
        )!.withValues(alpha: 0.2 + 0.7 * p),
    );

    final (phase, _) = _phaseAt(now);
    final round = (now / _cycle).floor();
    final frame = (now * 20).floor();
    final int arcs;
    final double reach;
    switch (phase) {
      case _Phase.sputter:
        arcs = p > 0.3 ? 1 + (_rand(frame, 5) * 2).floor() : 0;
        reach = 7;
      case _Phase.surge:
        arcs = 4;
        reach = 16;
      case _Phase.fade:
        arcs = _rand(frame, 4) > 0.75 ? 1 : 0;
        reach = 8;
      case _Phase.idle:
        arcs = 0;
        reach = 0;
    }
    for (var a = 0; a < arcs; a++) {
      final seed = frame * 31 + a * 17 + round;
      final (from, normal) = _edgePoint(rect, _rand(seed, 1));
      final tangent = Offset(-normal.dy, normal.dx);
      final len = reach * (0.6 + 0.6 * _rand(seed, 2));
      final to =
          from + normal * len + tangent * ((_rand(seed, 3) - 0.5) * len * 1.2);
      final path = Path()..moveTo(from.dx, from.dy);
      const steps = 4;
      for (var s = 1; s <= steps; s++) {
        final q = Offset.lerp(from, to, s / steps)!;
        final j = s == steps ? 0.0 : (_rand(seed + s, 6) - 0.5) * reach * 0.5;
        path.lineTo(q.dx + tangent.dx * j, q.dy + tangent.dy * j);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeJoin = StrokeJoin.round
          ..color = _red.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }
  }

  /// A point on the edge of a pill-shaped button at [u] (0..1 around it),
  /// with the direction pointing outward.
  (Offset, Offset) _edgePoint(Rect r, double u) {
    final rad = r.height / 2;
    final straight = r.width - 2 * rad;
    final arc = math.pi * rad;
    final total = 2 * straight + 2 * arc;
    var d = u * total;
    if (d < straight) {
      return (Offset(r.left + rad + d, r.top), const Offset(0, -1));
    }
    d -= straight;
    if (d < arc) {
      final a = -math.pi / 2 + d / rad;
      final n = Offset(math.cos(a), math.sin(a));
      return (Offset(r.right - rad, r.center.dy) + n * rad, n);
    }
    d -= arc;
    if (d < straight) {
      return (Offset(r.right - rad - d, r.bottom), const Offset(0, 1));
    }
    d -= straight;
    final a = math.pi / 2 + d / rad;
    final n = Offset(math.cos(a), math.sin(a));
    return (Offset(r.left + rad, r.center.dy) + n * rad, n);
  }

  @override
  bool shouldRepaint(covariant _ChargePainter old) =>
      old.radius != radius ||
      old.bottomInset != bottomInset ||
      old.glowOnly != glowOnly;
}
