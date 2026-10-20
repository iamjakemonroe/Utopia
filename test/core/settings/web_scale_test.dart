import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/settings/web_scale.dart';

/// How WebScale used to scale: a FittedBox.
class _Fitted extends StatelessWidget {
  const _Fitted({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size / scale;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: MediaQuery(
            data: media.copyWith(
              size: size,
              devicePixelRatio: media.devicePixelRatio * scale,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

void main() {
  const scale = 0.85;
  final shot = GlobalKey();
  var taps = 0;

  Widget page(Widget Function(Widget child) scaled) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: shot,
      child: scaled(
        Scaffold(
          body: Stack(
            children: [
              const Positioned(
                left: 31,
                top: 47,
                width: 120,
                height: 64,
                child: ColoredBox(color: Color(0xFF2FD98E)),
              ),
              Positioned(
                left: 200,
                top: 300,
                width: 100,
                height: 100,
                child: GestureDetector(
                  key: const Key('target'),
                  onTap: () => taps++,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFFF5C6C),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 12,
                bottom: 20,
                child: Text('Utopia', style: TextStyle(fontSize: 30)),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<Uint8List> pixels(WidgetTester tester) async {
    final boundary =
        shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late Uint8List bytes;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
    });
    return bytes;
  }

  setUp(() => taps = 0);

  testWidgets('draws and lays out just as the fitted box did', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      page((child) => _Fitted(scale: scale, child: child)),
    );
    final before = await pixels(tester);
    final beforeRect = tester.getRect(find.byKey(const Key('target')));

    await tester.pumpWidget(
      page((child) => WebScale(scale: scale, child: child)),
    );
    final after = await pixels(tester);
    final afterRect = tester.getRect(find.byKey(const Key('target')));

    expect(afterRect, beforeRect);
    expect(afterRect.left, closeTo(200 * scale, 1e-9));
    expect(after, before);

    // A touch lands where the circle is drawn.
    await tester.tapAt(afterRect.center);
    expect(taps, 1);
    await tester.tapAt(const Offset(260, 360)); // where it would be unscaled
    expect(taps, 1);
  });

  testWidgets('where things are can be asked before the first layout', (
    tester,
  ) async {
    // The focus system sorts what can take focus by where it is on screen,
    // and may ask before the first layout: the fitted box threw then.
    Future<void> ask(Widget Function(Widget child) scaled) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: scaled(
            const SizedBox.square(key: Key('field'), dimension: 40),
          ),
        ),
        phase: EnginePhase.build,
      );
      tester.renderObject(find.byKey(const Key('field'))).getTransformTo(null);
    }

    Object? fitted;
    try {
      await ask((child) => _Fitted(scale: scale, child: child));
    } catch (e) {
      fitted = e;
    }
    expect(fitted, isNotNull, reason: 'the fitted box needed its size');
    await ask((child) => WebScale(scale: scale, child: child));
  });
}
