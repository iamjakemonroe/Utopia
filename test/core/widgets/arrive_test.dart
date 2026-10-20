import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/arrive.dart';
import 'package:utopia/features/auth/presentation/widgets/auth_world.dart';

/// How RiseIn used to do it: built again every frame.
class _OldRiseIn extends StatelessWidget {
  const _OldRiseIn({required this.child, this.delay = 0});

  final Widget child;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final total = 700 + (delay * 1000).round();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, v, child) {
        final start = delay * 1000 / total;
        final p = ((v - start) / (1 - start)).clamp(0.0, 1.0);
        final e = Curves.easeOutBack.transform(p);
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - e)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// How a notification's row used to arrive.
class _OldRow extends StatelessWidget {
  const _OldRow({required this.child, required this.index});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 350 + index.clamp(0, 8) * 70),
    curve: Curves.easeOutCubic,
    builder: (context, v, child) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
    ),
    child: child,
  );
}

void main() {
  const box = SizedBox(width: 40, height: 40);

  Widget pair(Widget old, Widget now) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, height: 100, child: old),
        SizedBox(width: 100, height: 100, child: now),
      ],
    ),
  );

  double opacityOf(WidgetTester tester, Key key) {
    final box = tester.renderObject(find.byKey(key));
    var o = 1.0;
    for (RenderObject? r = box; r != null; r = r.parent) {
      if (r is RenderOpacity) o *= r.opacity;
      if (r is RenderAnimatedOpacity) o *= r.opacity.value;
    }
    return o;
  }

  Future<void> sameAllTheWay(WidgetTester tester, int ms) async {
    for (var t = 0; t <= ms + 100; t += 25) {
      final a = tester.getTopLeft(find.byKey(const Key('old')));
      final b = tester.getTopLeft(find.byKey(const Key('new')));
      expect(b.dy, closeTo(a.dy, 1e-6), reason: 'rise at $t ms');
      expect(
        opacityOf(tester, const Key('new')),
        closeTo(opacityOf(tester, const Key('old')), 1e-6),
        reason: 'fade at $t ms',
      );
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  testWidgets('RiseIn arrives just as it did', (tester) async {
    for (final delay in [0.0, 0.3]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        pair(
          _OldRiseIn(
            delay: delay,
            child: const KeyedSubtree(key: Key('old'), child: box),
          ),
          RiseIn(
            delay: delay,
            child: const KeyedSubtree(key: Key('new'), child: box),
          ),
        ),
      );
      await sameAllTheWay(tester, 700 + (delay * 1000).round());
    }
  });

  testWidgets('a notification row arrives just as it did', (tester) async {
    for (final index in [0, 3, 12]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        pair(
          _OldRow(
            index: index,
            child: const KeyedSubtree(key: Key('old'), child: box),
          ),
          Arrive(
            duration: Duration(milliseconds: 350 + index.clamp(0, 8) * 70),
            fade: Curves.easeOutCubic,
            child: const KeyedSubtree(key: Key('new'), child: box),
          ),
        ),
      );
      await sameAllTheWay(tester, 350 + index.clamp(0, 8) * 70);
    }
  });
}
