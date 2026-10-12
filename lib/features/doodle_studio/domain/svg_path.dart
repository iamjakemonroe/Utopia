import 'dart:ui';

/// Reads SVG path data ("M 10 20 C 30 40 ...") into a [Path]. Every
/// command is understood, absolute and relative. Reading stops at anything
/// it can't make sense of, keeping what came before; null when nothing
/// could be read at all.
Path? parseSvgPath(String d) {
  final s = _Scanner(d);
  final path = Path();
  var cur = Offset.zero;
  var start = Offset.zero;
  // The last control point, for the smooth commands (S and T) to mirror.
  Offset? lastCubic;
  Offset? lastQuad;
  String? cmd;
  var drawn = false;
  var steps = 0;

  while (steps++ < 20000) {
    final next = s.command();
    if (next != null) {
      cmd = next;
    } else if (cmd == null || !s.atNumber) {
      break;
    }
    final c = cmd;
    final rel = c.toLowerCase() == c;
    Offset point(double x, double y) => rel ? cur + Offset(x, y) : Offset(x, y);

    switch (c.toUpperCase()) {
      case 'Z':
        path.close();
        cur = start;
        lastCubic = lastQuad = null;
        // Z takes nothing, so numbers straight after it make no sense.
        cmd = null;
        continue;
      case 'M':
        final p = s.pair();
        if (p == null) return drawn ? path : null;
        cur = start = point(p.dx, p.dy);
        path.moveTo(cur.dx, cur.dy);
        // More pairs after a move are lines.
        cmd = rel ? 'l' : 'L';
      case 'L':
        final p = s.pair();
        if (p == null) return drawn ? path : null;
        cur = point(p.dx, p.dy);
        path.lineTo(cur.dx, cur.dy);
      case 'H':
        final x = s.number();
        if (x == null) return drawn ? path : null;
        cur = Offset(rel ? cur.dx + x : x, cur.dy);
        path.lineTo(cur.dx, cur.dy);
      case 'V':
        final y = s.number();
        if (y == null) return drawn ? path : null;
        cur = Offset(cur.dx, rel ? cur.dy + y : y);
        path.lineTo(cur.dx, cur.dy);
      case 'C':
        final a = s.pair(), b = s.pair(), p = s.pair();
        if (a == null || b == null || p == null) return drawn ? path : null;
        final c1 = point(a.dx, a.dy), c2 = point(b.dx, b.dy);
        cur = point(p.dx, p.dy);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, cur.dx, cur.dy);
        lastCubic = c2;
        lastQuad = null;
        drawn = true;
        continue;
      case 'S':
        final b = s.pair(), p = s.pair();
        if (b == null || p == null) return drawn ? path : null;
        final c1 = lastCubic == null ? cur : cur * 2 - lastCubic;
        final c2 = point(b.dx, b.dy);
        cur = point(p.dx, p.dy);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, cur.dx, cur.dy);
        lastCubic = c2;
        lastQuad = null;
        drawn = true;
        continue;
      case 'Q':
        final a = s.pair(), p = s.pair();
        if (a == null || p == null) return drawn ? path : null;
        final q = point(a.dx, a.dy);
        cur = point(p.dx, p.dy);
        path.quadraticBezierTo(q.dx, q.dy, cur.dx, cur.dy);
        lastQuad = q;
        lastCubic = null;
        drawn = true;
        continue;
      case 'T':
        final p = s.pair();
        if (p == null) return drawn ? path : null;
        final q = lastQuad == null ? cur : cur * 2 - lastQuad;
        cur = point(p.dx, p.dy);
        path.quadraticBezierTo(q.dx, q.dy, cur.dx, cur.dy);
        lastQuad = q;
        lastCubic = null;
        drawn = true;
        continue;
      case 'A':
        final rx = s.number(), ry = s.number(), turn = s.number();
        final large = s.flag(), sweep = s.flag();
        final p = s.pair();
        if (rx == null ||
            ry == null ||
            turn == null ||
            large == null ||
            sweep == null ||
            p == null) {
          return drawn ? path : null;
        }
        cur = point(p.dx, p.dy);
        if (rx == 0 || ry == 0) {
          path.lineTo(cur.dx, cur.dy);
        } else {
          // y points down on both, so SVG's sweep flag is clockwise here.
          path.arcToPoint(
            cur,
            radius: Radius.elliptical(rx.abs(), ry.abs()),
            rotation: turn,
            largeArc: large,
            clockwise: sweep,
          );
        }
      default:
        return drawn ? path : null;
    }
    lastCubic = lastQuad = null;
    drawn = true;
  }
  return drawn ? path : null;
}

class _Scanner {
  _Scanner(this.s);

  final String s;
  int i = 0;

  static const _commands = 'MmLlHhVvCcSsQqTtAaZz';

  /// Numbers this big can only be a mistake on a 1000-wide page.
  static const _limit = 1e5;

  void _gap() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      // space, comma, tab, newline, carriage return
      if (c == 0x20 || c == 0x2C || c == 0x09 || c == 0x0A || c == 0x0D) {
        i++;
      } else {
        break;
      }
    }
  }

  String? command() {
    _gap();
    if (i >= s.length || !_commands.contains(s[i])) return null;
    return s[i++];
  }

  bool get atNumber {
    _gap();
    if (i >= s.length) return false;
    final c = s.codeUnitAt(i);
    return _digit(c) || c == 0x2D || c == 0x2B || c == 0x2E;
  }

  static bool _digit(int c) => c >= 0x30 && c <= 0x39;

  double? number() {
    _gap();
    final from = i;
    if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
    var digits = false;
    var dot = false;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (_digit(c)) {
        digits = true;
        i++;
      } else if (c == 0x2E && !dot) {
        dot = true;
        i++;
      } else {
        break;
      }
    }
    if (!digits) {
      i = from;
      return null;
    }
    if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
      final mark = i++;
      if (i < s.length && (s[i] == '-' || s[i] == '+')) i++;
      var exp = false;
      while (i < s.length && _digit(s.codeUnitAt(i))) {
        i++;
        exp = true;
      }
      if (!exp) i = mark;
    }
    final v = double.tryParse(s.substring(from, i));
    if (v == null || !v.isFinite || v.abs() > _limit) return null;
    return v;
  }

  Offset? pair() {
    final x = number();
    if (x == null) return null;
    final y = number();
    if (y == null) return null;
    return Offset(x, y);
  }

  /// An arc's flag: a single 0 or 1, which may run straight into the next
  /// number ("a5 5 0 0110 10").
  bool? flag() {
    _gap();
    if (i >= s.length) return null;
    final c = s[i];
    if (c != '0' && c != '1') return null;
    i++;
    return c == '1';
  }
}
