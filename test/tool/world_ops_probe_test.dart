import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/game_card_art.dart';
import 'package:utopia/core/widgets/utopia_world.dart';

/// What a world draws in a frame, biggest first: each path's area on a
/// phone's screen (at 3x), whether it's blurred, and which part drew it.
/// In a browser, a big path that isn't convex is filled pixel by pixel on
/// the CPU each frame (Skia's software path renderer), blurred ones too.
///   WORLDS=utopia_adventure,utopia_dark flutter test --run-skipped \
///     test/tool/world_ops_probe_test.dart
class _Log implements Canvas {
  final rows = <(String, double, bool, String)>[];
  final _stack = <Matrix4>[Matrix4.identity()..scaleByDouble(3, 3, 1, 1)];
  Matrix4 get _m => _stack.last;

  String _caller() {
    for (final line in StackTrace.current.toString().split('\n').skip(2)) {
      final m = RegExp(r'#\d+\s+(\S+)').firstMatch(line);
      if (m == null) continue;
      final f = m.group(1)!;
      if (f.startsWith('_Log') || f.contains('<anonymous')) continue;
      return f;
    }
    return '?';
  }

  void _add(String kind, Rect r, Paint p) {
    final box = MatrixUtils.transformRect(_m, r);
    rows.add((kind, box.width * box.height, p.maskFilter != null, _caller()));
  }

  @override
  void drawPath(Path path, Paint paint) =>
      _add('path', path.getBounds(), paint);
  @override
  void drawRect(Rect rect, Paint paint) => _add('rect', rect, paint);
  @override
  void drawOval(Rect rect, Paint paint) => _add('oval', rect, paint);
  @override
  void drawCircle(Offset c, double r, Paint paint) =>
      _add('circle', Rect.fromCircle(center: c, radius: r), paint);
  @override
  void drawRRect(RRect rrect, Paint paint) =>
      _add('rrect', rrect.outerRect, paint);
  @override
  void save() => _stack.add(_m.clone());
  @override
  void saveLayer(Rect? bounds, Paint paint) {
    rows.add(('LAYER', 0, false, _caller()));
    _stack.add(_m.clone());
  }

  @override
  void restore() => _stack.removeLast();
  @override
  int getSaveCount() => _stack.length;
  @override
  void restoreToCount(int count) {
    while (_stack.length > count) {
      _stack.removeLast();
    }
  }

  @override
  void translate(double dx, double dy) => _m.translateByDouble(dx, dy, 0, 1);
  @override
  void scale(double sx, [double? sy]) => _m.scaleByDouble(sx, sy ?? sx, 1, 1);
  @override
  void rotate(double radians) => _m.rotateZ(radians);
  @override
  void transform(Float64List matrix4) =>
      _m.multiply(Matrix4.fromFloat64List(matrix4));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const worlds = String.fromEnvironment('WORLDS', defaultValue: '');
  final ids =
      (worlds.isEmpty
              ? const ['utopia_adventure', 'utopia_dark', 'utopia_calm']
              : worlds.split(','))
          .toList();
  testWidgets('ops in the game cards', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    for (final game in GameKind.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 170,
              child: GameSceneArt(game: game, height: 150),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      final scene = tester
          .renderObjectList<RenderCustomPaint>(find.byType(CustomPaint))
          .map((r) => r.painter)
          .whereType<CustomPainter>()
          .firstWhere((p) => p.runtimeType.toString().contains('Diorama'));
      final log = _Log();
      scene.paint(log, const Size(170, 150));
      final byPart = <String, (int, double)>{};
      var blurs = 0;
      for (final (kind, area, blur, at) in log.rows) {
        if (blur) blurs++;
        final key = '$kind ${blur ? 'BLUR ' : ''}$at';
        final (n, a) = byPart[key] ?? (0, 0.0);
        byPart[key] = (n + 1, a + area);
      }
      final rows = byPart.entries.toList()
        ..sort((a, b) => b.value.$2.compareTo(a.value.$2));
      // ignore: avoid_print
      print('== ${game.name}: ${log.rows.length} ops, $blurs blurred');
      for (final r in rows.take(14)) {
        // ignore: avoid_print
        print(
          '  ${(r.value.$2 / 1000).toStringAsFixed(0).padLeft(6)}k px'
          '  x${r.value.$1.toString().padRight(4)} ${r.key}',
        );
      }
    }
    await tester.pumpWidget(const SizedBox());
  }, tags: ['probe']);

  for (final id in ids) {
    testWidgets('ops in $id', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      SharedPreferences.setMockInitialValues({'utopia.theme': id});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: UtopiaWorld(style: UtopiaThemes.byId(id).world),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      final scene = tester
          .renderObjectList<RenderCustomPaint>(find.byType(CustomPaint))
          .map((r) => r.painter)
          .whereType<CustomPainter>()
          .firstWhere((p) => p.runtimeType.toString().contains('Scene'));
      final log = _Log();
      scene.paint(log, const Size(390, 844));
      final screen = 1170.0 * 2532;
      final byPart = <String, (int, double, int)>{};
      for (final (kind, area, blur, at) in log.rows) {
        final key = '$kind ${blur ? 'BLUR ' : ''}$at';
        final (n, a, _) = byPart[key] ?? (0, 0.0, 0);
        byPart[key] = (n + 1, a + area, 0);
      }
      final rows = byPart.entries.toList()
        ..sort((a, b) => b.value.$2.compareTo(a.value.$2));
      // ignore: avoid_print
      print('== $id: ${log.rows.length} ops');
      for (final r in rows.take(22)) {
        // ignore: avoid_print
        print(
          '  ${(r.value.$2 / screen).toStringAsFixed(2).padLeft(6)} screens'
          '  x${r.value.$1.toString().padRight(4)} ${r.key}',
        );
      }
      await tester.pumpWidget(const SizedBox());
    }, tags: ['probe']);
  }
}
