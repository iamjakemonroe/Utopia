import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tests set this to have world cards behave as in a browser.
@visibleForTesting
bool? debugLiveWorldCardsAsWeb;

bool get _web => debugLiveWorldCardsAsWeb ?? kIsWeb;

/// In a browser, only the world card nearest the middle of the screen
/// moves; the rest hold still. Every live world is a whole scene to draw
/// each frame, and a browser can't keep up with a screenful of them. The
/// apps animate them all.
class LiveWorldArea extends StatefulWidget {
  const LiveWorldArea({super.key, required this.child});

  final Widget child;

  @override
  State<LiveWorldArea> createState() => _LiveWorldAreaState();
}

class _LiveWorldAreaState extends State<LiveWorldArea> {
  final _live = _LiveWorld();

  @override
  void initState() {
    super.initState();
    if (_web) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _live.pick());
    }
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _LiveWorldScope(live: _live, child: widget.child);
    if (!_web) return scope;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
          _live.pick();
        }
        return false;
      },
      child: scope,
    );
  }
}

/// The world cards on screen, and which one is live.
class _LiveWorld extends ChangeNotifier {
  final _cards = <Object, BuildContext>{};
  Object? live;

  void add(Object id, BuildContext context) => _cards[id] = context;

  void remove(Object id) => _cards.remove(id);

  /// The card nearest the middle of the screen goes live.
  void pick() {
    Object? best;
    var nearest = double.infinity;
    for (final MapEntry(key: id, value: context) in _cards.entries) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final middle = MediaQuery.sizeOf(context).height / 2;
      final centre = box.localToGlobal(box.size.center(Offset.zero)).dy;
      final away = (centre - middle).abs();
      if (away < nearest) {
        nearest = away;
        best = id;
      }
    }
    if (best != live) {
      live = best;
      notifyListeners();
    }
  }
}

class _LiveWorldScope extends InheritedNotifier<_LiveWorld> {
  const _LiveWorldScope({required _LiveWorld live, required super.child})
    : super(notifier: live);

  static _LiveWorld? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LiveWorldScope>()?.notifier;
}

/// A world card's moving world: in a browser it moves only while it's the
/// live one. The rest hold still, and a browser would still draw all of
/// each again every frame: so each is drawn once into a picture of itself
/// (the same pixels), kept between visits ([_Stills]), and only the live
/// one is a world at all.
class LiveWorldCard extends StatefulWidget {
  const LiveWorldCard({super.key, required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  State<LiveWorldCard> createState() => _LiveWorldCardState();
}

class _LiveWorldCardState extends State<LiveWorldCard> {
  _LiveWorld? _live;
  final _world = GlobalKey();
  bool _wasMoving = false;

  /// It just stopped: its picture is taken as it is now, not an older one.
  bool _stopped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final live = _LiveWorldScope.of(context);
    if (live != _live) {
      _live?.remove(widget.id);
      _live = live?..add(widget.id, context);
    }
  }

  @override
  void dispose() {
    _live?.remove(widget.id);
    _Pictures.forget(this);
    super.dispose();
  }

  /// Takes the picture of the world as it's drawn now (after a frame).
  bool _take(_StillKey key) {
    if (!mounted || _live?.live == widget.id) return false;
    final box = _world.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || !box.hasSize) return false;
    _Stills.put(key, box.toImageSync(pixelRatio: key.$3));
    setState(() {});
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final live = _LiveWorldScope.of(context);
    if (!_web || live == null) return widget.child;
    final moving = live.live == widget.id;
    if (_wasMoving && !moving) _stopped = true;
    _wasMoving = moving;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final key = (widget.id, constraints.biggest, dpr);
        if (!moving) {
          if (_stopped) {
            _stopped = false;
            _Stills.drop(key);
          }
          final still = _Stills.get(key);
          if (still != null) {
            return CustomPaint(
              size: constraints.biggest,
              painter: _StillPainter(still, dpr),
            );
          }
          _Pictures.ask(this, key);
        }
        return TickerMode(
          enabled: moving,
          child: RepaintBoundary(key: _world, child: widget.child),
        );
      },
    );
  }
}

typedef _StillKey = (Object, Size, double);

/// The still world cards' pictures in a browser, kept between visits.
abstract final class _Stills {
  static const _maxBytes = 32 << 20;

  /// Most recently shown last.
  static final _images = <_StillKey, ui.Image>{};
  static int _bytes = 0;

  static int _sizeOf(ui.Image image) => image.width * image.height * 4;

  static ui.Image? get(_StillKey key) {
    final image = _images.remove(key);
    if (image != null) _images[key] = image;
    return image;
  }

  static void drop(_StillKey key) {
    final image = _images.remove(key);
    if (image == null) return;
    _bytes -= _sizeOf(image);
    image.dispose();
  }

  static void put(_StillKey key, ui.Image image) {
    drop(key);
    // What's on screen keeps its pixels in the pictures already drawn.
    while (_images.isNotEmpty && _bytes + _sizeOf(image) > _maxBytes) {
      drop(_images.keys.first);
    }
    _images[key] = image;
    _bytes += _sizeOf(image);
  }
}

/// Pictures waiting to be taken: one a frame, so a screenful of cards
/// coming into view doesn't make one long frame of them all.
abstract final class _Pictures {
  static final _waiting = <_LiveWorldCardState, _StillKey>{};
  static bool _soon = false;

  static void ask(_LiveWorldCardState card, _StillKey key) {
    _waiting[card] = key;
    if (_soon) return;
    _soon = true;
    SchedulerBinding.instance.addPostFrameCallback(_takeOne);
    SchedulerBinding.instance.scheduleFrame();
  }

  static void forget(_LiveWorldCardState card) => _waiting.remove(card);

  static void _takeOne(Duration _) {
    _soon = false;
    while (_waiting.isNotEmpty) {
      final MapEntry(key: card, value: key) = _waiting.entries.first;
      _waiting.remove(card);
      if (card._take(key)) break;
    }
    if (_waiting.isEmpty) return;
    _soon = true;
    SchedulerBinding.instance.addPostFrameCallback(_takeOne);
    SchedulerBinding.instance.scheduleFrame();
  }
}

class _StillPainter extends CustomPainter {
  const _StillPainter(this.image, this.dpr);

  final ui.Image image;
  final double dpr;

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, size.width * dpr, size.height * dpr),
      Offset.zero & size,
      _paint,
    );
  }

  @override
  bool shouldRepaint(_StillPainter old) => old.image != image;
}
