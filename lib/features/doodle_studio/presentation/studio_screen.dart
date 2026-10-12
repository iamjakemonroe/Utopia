import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../data/art_store.dart';
import '../data/picture_library.dart';
import '../domain/art_doc.dart';
import '../domain/coloring_pages.dart';
import 'art_render.dart';
import 'studio_toolbar.dart';

/// Wider than this, the tools sit down the sides (tablets, landscape).
const _wideLayout = 720.0;

/// The drawing studio: a sheet of paper (or a coloring page) to draw on
/// with real artist's tools.
///
/// One finger draws; two fingers pinch to zoom and move the page, with a
/// soft bounce at the edges; the zoom buttons glide. With an Apple Pencil
/// the line follows its pressure, and a resting palm doesn't draw. Every
/// change saves itself a moment later (and always before leaving), so the
/// art is still here after changing worlds or closing the app.
class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({
    super.key,
    this.artId,
    this.kind = ArtKind.sketch,
    this.pageId,
  });

  /// A saved piece to carry on with; otherwise a new one of [kind].
  final String? artId;
  final ArtKind kind;

  /// The coloring page, for a new coloring.
  final String? pageId;

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

enum _Gesture { idle, drawing, zooming, waiting }

enum _Save { idle, pending, saving, saved, failed }

class _Splash {
  _Splash(this.at, this.color, this.started);

  final Offset at;
  final Color color;
  final Duration started;
}

class _StudioScreenState extends ConsumerState<StudioScreen>
    with TickerProviderStateMixin {
  ArtStore? _store;
  ArtDoc? _doc;
  ArtRender? _render;
  String? _error;

  /// The coloring page's name, once it's loaded.
  String? _pageName;

  /// Whether this piece is on the phone yet (a new one isn't until the
  /// first line).
  bool _stored = false;

  ArtTool _tool = ArtTool.pen;
  int _color = kArtPalette.first;
  int _sizeIndex = 1;

  // The view: page units to screen are scaled by [_scale], then moved by
  // [_offset].
  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _viewport = Size.zero;
  double _fit = 1;

  final _repaint = ValueNotifier<int>(0);
  final _clock = Stopwatch()..start();

  // Fingers and the pencil.
  final Map<int, Offset> _pointers = {};
  _Gesture _gesture = _Gesture.idle;
  int? _drawPointer;
  bool _stylusSeen = false;
  List<double>? _live;
  Duration _liveStarted = Duration.zero;
  Offset _lastPt = Offset.zero;
  Duration _lastAt = Duration.zero;
  double _lastW = 0;
  Offset? _tapAt;

  // Pinching.
  double _pinchSpan = 1;
  double _pinchScale = 1;
  Offset _pinchPage = Offset.zero;
  Offset _pinchCentroid = Offset.zero;

  // Gliding the view (zoom buttons, settling after a pinch).
  // Made in initState: created lazily, a first use in dispose would look
  // up the widget tree after it's gone.
  late final AnimationController _glide;
  double _fromScale = 1, _toScale = 1;
  Offset _fromOffset = Offset.zero, _toOffset = Offset.zero;

  // Paint-bucket splashes.
  final List<_Splash> _splashes = [];
  late final Ticker _splashTicker;

  // Saving.
  Timer? _saveTimer;
  bool _dirty = false;
  bool _leaving = false;
  bool _exporting = false;
  final _save = ValueNotifier<_Save>(_Save.idle);
  final _zoomLabel = ValueNotifier<double?>(null);
  Timer? _zoomLabelTimer;
  late final AppLifecycleListener _life;

  double get _size => kBrushSizes[_sizeIndex];

  void _onSplashTick(Duration _) {
    final now = _clock.elapsed;
    _splashes.removeWhere(
      (s) => now - s.started > const Duration(milliseconds: 520),
    );
    if (_splashes.isEmpty) _splashTicker.stop();
    _repaint.value++;
  }

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onHide: () => unawaited(_saveNow()));
    _glide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..addListener(_onGlide);
    _splashTicker = createTicker(_onSplashTick);
    _load();
  }

  Future<void> _load() async {
    try {
      final store = await ref.read(artStoreProvider.future);
      final ArtDoc doc;
      final id = widget.artId;
      if (id != null) {
        final saved = await store.load(id);
        if (saved == null) throw StateError('missing');
        doc = saved;
        _stored = true;
      } else {
        doc = ArtDoc.blank(widget.kind, pageId: widget.pageId);
      }
      PageArt? page;
      if (doc.kind == ArtKind.coloring) {
        final p =
            ColoringPage.byId(doc.pageId) ??
            await ref.read(pictureLibraryProvider).page(doc.pageId);
        if (p == null) throw StateError('page');
        _pageName = p.name;
        page = await PageArt.load(p);
      }
      final render = ArtRender(doc, page: page);
      await render.update();
      if (!mounted) {
        render.dispose();
        return;
      }
      setState(() {
        _store = store;
        _doc = doc;
        _render = render;
        if (doc.kind == ArtKind.coloring) {
          _tool = ArtTool.bucket;
          _color = 0xFF5AB8FF;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't open this one.");
    }
  }

  @override
  void dispose() {
    _life.dispose();
    _saveTimer?.cancel();
    _zoomLabelTimer?.cancel();
    // Normally saved on the way out already; never lose a last line.
    final doc = _doc;
    if (_dirty && doc != null && (_stored || !doc.isEmpty)) {
      unawaited(_store?.save(doc));
    }
    _glide.dispose();
    _splashTicker.dispose();
    _render?.dispose();
    _repaint.dispose();
    _save.dispose();
    _zoomLabel.dispose();
    super.dispose();
  }

  // ── view ───────────────────────────────────────────────────────────────

  /// Fits the page in a new viewport (first layout, or the screen turning).
  void _layout(Size viewport) {
    if (viewport == _viewport || viewport.isEmpty) return;
    final wasFit = _viewport.isEmpty || (_scale - _fit).abs() < 1e-3;
    final oldCenter = _viewport.isEmpty
        ? null
        : (_viewport.center(Offset.zero) - _offset) / _scale;
    _viewport = viewport;
    const margin = 18.0;
    _fit = math.min(
      (viewport.width - margin * 2) / kPageSize.width,
      (viewport.height - margin * 2) / kPageSize.height,
    );
    if (wasFit || oldCenter == null) {
      _scale = _fit;
      _offset = _clamp(Offset.zero, _fit);
    } else {
      _scale = _scale.clamp(_fit, _fit * 10);
      _offset = _clamp(
        viewport.center(Offset.zero) - oldCenter * _scale,
        _scale,
      );
    }
  }

  /// Keeps the page in view: centered when it fits, otherwise no further
  /// past its edges than a little margin (plus [slack] while a pinch is
  /// stretching it).
  Offset _clamp(Offset o, double s, {double slack = 0}) {
    double axis(double v, double page, double view) {
      if (page <= view) return (view - page) / 2;
      const margin = 40.0;
      return v.clamp(view - page - margin - slack, margin + slack);
    }

    return Offset(
      axis(o.dx, kPageSize.width * s, _viewport.width),
      axis(o.dy, kPageSize.height * s, _viewport.height),
    );
  }

  Offset _toPage(Offset local) => (local - _offset) / _scale;

  void _glideTo(double scale, {Offset? around}) {
    final s = scale.clamp(_fit, _fit * 10);
    final pivot = around ?? _viewport.center(Offset.zero);
    final pagePoint = _toPage(pivot);
    _fromScale = _scale;
    _fromOffset = _offset;
    _toScale = s;
    _toOffset = _clamp(pivot - pagePoint * s, s);
    _glide.forward(from: 0);
    _showZoom(s);
  }

  void _onGlide() {
    final k = Curves.easeOutCubic.transform(_glide.value);
    _scale = _fromScale + (_toScale - _fromScale) * k;
    _offset = Offset.lerp(_fromOffset, _toOffset, k)!;
    _repaint.value++;
  }

  void _showZoom(double scale) {
    _zoomLabel.value = scale / _fit;
    _zoomLabelTimer?.cancel();
    _zoomLabelTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _zoomLabel.value = null;
    });
  }

  // ── fingers ────────────────────────────────────────────────────────────

  void _onDown(PointerDownEvent e) {
    if (_render == null) return;
    if (e.kind == PointerDeviceKind.stylus ||
        e.kind == PointerDeviceKind.invertedStylus) {
      _stylusSeen = true;
    }
    _glide.stop();
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      // A second finger: the page is being pinched. A line only just
      // started was the first finger landing, not drawing.
      if (_gesture == _Gesture.drawing) {
        if (_clock.elapsed - _liveStarted < const Duration(milliseconds: 250)) {
          _cancelStroke();
        } else {
          _commitStroke();
        }
      }
      _startPinch();
      return;
    }
    if (_pointers.length > 2 || _gesture != _Gesture.idle) return;
    // With a pencil about, fingers only move the page: a resting palm
    // never draws.
    if (_stylusSeen && e.kind == PointerDeviceKind.touch) {
      _gesture = _Gesture.waiting;
      return;
    }
    if (_tool == ArtTool.bucket) {
      _tapAt = e.localPosition;
      _drawPointer = e.pointer;
      _gesture = _Gesture.drawing;
      return;
    }
    _beginStroke(e);
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    switch (_gesture) {
      case _Gesture.zooming:
        _updatePinch();
      case _Gesture.drawing when e.pointer == _drawPointer:
        if (_tool == ArtTool.bucket) {
          if ((e.localPosition - _tapAt!).distance > 14) _tapAt = null;
        } else {
          _extendStroke(e);
        }
      default:
    }
  }

  void _onUp(PointerEvent e, {bool cancelled = false}) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers.remove(e.pointer);
    switch (_gesture) {
      case _Gesture.drawing when e.pointer == _drawPointer:
        if (_tool == ArtTool.bucket) {
          final at = _tapAt;
          if (at != null && !cancelled) _fillAt(at);
          _tapAt = null;
        } else if (cancelled) {
          _cancelStroke();
        } else {
          _commitStroke();
        }
        _gesture = _Gesture.idle;
        _drawPointer = null;
      case _Gesture.zooming when _pointers.length < 2:
        _endPinch();
        _gesture = _pointers.isEmpty ? _Gesture.idle : _Gesture.waiting;
      default:
        if (_pointers.isEmpty) _gesture = _Gesture.idle;
    }
  }

  void _onSignal(PointerSignalEvent e) {
    // A mouse wheel or trackpad scroll zooms around the pointer.
    if (e is PointerScrollEvent && _render != null) {
      final s = (_scale * math.exp(-e.scrollDelta.dy / 400)).clamp(
        _fit,
        _fit * 10,
      );
      final page = _toPage(e.localPosition);
      _scale = s;
      _offset = _clamp(e.localPosition - page * s, s);
      _showZoom(s);
      _repaint.value++;
    }
  }

  void _startPinch() {
    final pts = _pointers.values.take(2).toList();
    _pinchSpan = math.max(1, (pts[0] - pts[1]).distance);
    _pinchCentroid = (pts[0] + pts[1]) / 2;
    _pinchScale = _scale;
    _pinchPage = _toPage(_pinchCentroid);
    _gesture = _Gesture.zooming;
  }

  void _updatePinch() {
    final pts = _pointers.values.take(2).toList();
    if (pts.length < 2) return;
    final span = math.max(1.0, (pts[0] - pts[1]).distance);
    _pinchCentroid = (pts[0] + pts[1]) / 2;
    // A little give past the limits, like stretching paper.
    final s = (_pinchScale * span / _pinchSpan).clamp(_fit * 0.7, _fit * 11);
    _scale = s;
    _offset = _clamp(_pinchCentroid - _pinchPage * s, s, slack: 90);
    _showZoom(s);
    _repaint.value++;
  }

  void _endPinch() {
    // Settle back inside the limits.
    final target = _scale.clamp(_fit, _fit * 10);
    _fromScale = _scale;
    _fromOffset = _offset;
    _toScale = target;
    final page = _toPage(_pinchCentroid);
    _toOffset = _clamp(_pinchCentroid - page * target, target);
    if ((_toScale - _fromScale).abs() > 1e-4 ||
        (_toOffset - _fromOffset).distance > 0.5) {
      _glide.forward(from: 0);
    }
  }

  // ── drawing ────────────────────────────────────────────────────────────

  double _widthFor(PointerEvent e, double screenSpeed) {
    if (e.kind == PointerDeviceKind.stylus && e.pressureMax > e.pressureMin) {
      final p = ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin))
          .clamp(0.0, 1.0);
      return _size * (0.3 + p * 1.2);
    }
    if (_tool != ArtTool.pen) return _size;
    // Ink thins as the pen speeds up (screen pixels per millisecond).
    return _size * (1.35 - screenSpeed * 0.4).clamp(0.45, 1.35);
  }

  void _beginStroke(PointerDownEvent e) {
    final p = _toPage(e.localPosition);
    _gesture = _Gesture.drawing;
    _drawPointer = e.pointer;
    _liveStarted = _clock.elapsed;
    _lastAt = _clock.elapsed;
    _lastPt = p;
    _lastW = _widthFor(e, 0.4);
    _live = [p.dx, p.dy, _lastW];
    _repaint.value++;
  }

  void _extendStroke(PointerMoveEvent e) {
    final live = _live;
    if (live == null) return;
    final p = _toPage(e.localPosition);
    final moved = (p - _lastPt).distance;
    // Less than a pixel on screen: nothing to add yet.
    if (moved * _scale < 1.2) return;
    final now = _clock.elapsed;
    final ms = math.max(1, (now - _lastAt).inMicroseconds) / 1000;
    final target = _widthFor(e, moved * _scale / ms);
    _lastW += (target - _lastW) * 0.35;
    live
      ..add(p.dx)
      ..add(p.dy)
      ..add(_lastW);
    _lastPt = p;
    _lastAt = now;
    _repaint.value++;
  }

  void _cancelStroke() {
    _live = null;
    _gesture = _Gesture.idle;
    _drawPointer = null;
    _repaint.value++;
  }

  void _commitStroke() {
    final pts = _live;
    _live = null;
    final doc = _doc;
    if (pts == null || pts.length < 3 || doc == null) return;
    doc.add(StrokeOp(tool: _tool, color: _color, size: _size, points: pts));
    _changed();
  }

  void _fillAt(Offset local) {
    final page = _render?.page;
    final doc = _doc;
    if (page == null || doc == null) return;
    final p = _toPage(local);
    final region = page.regions.regionAtPage(p.dx, p.dy);
    if (region == 0) return;
    if (doc.fills[region] == _color) return;
    doc.add(FillOp(region: region, color: _color));
    HapticFeedback.lightImpact();
    ref.read(gameAudioProvider).play(Sfx.tap, volume: 0.6);
    _splashes.add(_Splash(local, Color(_color), _clock.elapsed));
    if (!_splashTicker.isActive) _splashTicker.start();
    _changed();
  }

  /// After anything is drawn, filled, undone or redone: redraw, and save
  /// a moment later.
  Future<void> _changed() async {
    final render = _render;
    if (render == null) return;
    _scheduleSave();
    await render.update();
    if (!mounted) return;
    _repaint.value++;
    setState(() {});
  }

  void _undo() {
    if (_doc?.undo() != null) _changed();
  }

  void _redo() {
    if (_doc?.redoLast() != null) _changed();
  }

  // ── saving ─────────────────────────────────────────────────────────────

  void _scheduleSave() {
    _dirty = true;
    _save.value = _Save.pending;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), _saveNow);
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    final doc = _doc, store = _store, render = _render;
    if (!_dirty || doc == null || store == null || render == null) return;
    // A new page with nothing on it isn't worth keeping.
    if (doc.isEmpty && !_stored) {
      _dirty = false;
      _save.value = _Save.idle;
      return;
    }
    _dirty = false;
    _save.value = _Save.saving;
    try {
      final thumbnail = await render.toPng(0.3);
      await store.save(doc, thumbnail: thumbnail);
      _stored = true;
      if (!mounted) return;
      _save.value = _dirty ? _Save.pending : _Save.saved;
      ref.invalidate(myArtProvider);
    } catch (_) {
      _dirty = true;
      if (mounted) _save.value = _Save.failed;
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    if (_gesture == _Gesture.drawing) _commitStroke();
    await _saveNow();
    if (mounted) context.pop();
  }

  Future<void> _saveToPhotos() async {
    final render = _render;
    if (render == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) {
          if (mounted) {
            showUtopiaToast(
              context,
              'Allow Utopia to add to your photos in Settings, then try again.',
              kind: ToastKind.warning,
            );
          }
          return;
        }
      }
      final png = await render.toPng(2);
      await Gal.putImageBytes(png, name: 'utopia-${_doc!.id}');
      if (!mounted) return;
      ref.read(gameAudioProvider).play(Sfx.reaction);
      showUtopiaToast(
        context,
        'Saved to your photos',
        icon: Icons.photo_library_rounded,
        kind: ToastKind.success,
      );
    } catch (_) {
      if (mounted) {
        showUtopiaToast(
          context,
          "Couldn't save to your photos. Try again.",
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kStudioPaper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: kStudioInk, width: 2),
        ),
        title: Text(
          title,
          style: AppTextStyles.display(fontSize: 20, color: kStudioInk),
        ),
        content: Text(body, style: AppTextStyles.body(color: kStudioInk)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it', style: TextStyle(color: kStudioInk)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              action,
              style: const TextStyle(
                color: Color(0xFFE0361A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _startOver() async {
    final doc = _doc;
    if (doc == null || doc.isEmpty) return;
    if (!await _confirm(
      'Start over?',
      'Everything on this page will be cleared.',
      'Clear it',
    )) {
      return;
    }
    doc.ops.clear();
    doc.redo.clear();
    _changed();
  }

  Future<void> _delete() async {
    final doc = _doc, store = _store;
    if (doc == null || store == null) return;
    if (!await _confirm(
      'Delete this?',
      "It'll be gone from your sketchbook for good.",
      'Delete',
    )) {
      return;
    }
    _saveTimer?.cancel();
    _dirty = false;
    await store.delete(doc.id);
    ref.invalidate(myArtProvider);
    _leaving = true;
    if (mounted) context.pop();
  }

  // ── layout ─────────────────────────────────────────────────────────────

  List<ArtTool> get _tools => [
    if (_doc?.kind == ArtKind.coloring) ArtTool.bucket,
    ArtTool.pencil,
    ArtTool.pen,
    ArtTool.marker,
    ArtTool.soft,
    ArtTool.highlighter,
    ArtTool.eraser,
  ];

  String get _title {
    final doc = _doc;
    if (doc == null) return 'Sketchbook';
    if (doc.kind == ArtKind.coloring) return _pageName ?? 'Coloring';
    return 'Sketch';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideLayout;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: kStudioDesk,
        body: SafeArea(child: wide ? _wideBody() : _narrowBody()),
      ),
    );
  }

  Widget _narrowBody() {
    return Column(
      children: [
        _topBar(),
        Expanded(child: _canvasArea()),
        _rise(
          child: _panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ToolPicker(
                  tools: _tools,
                  selected: _tool,
                  onChanged: (t) => setState(() => _tool = t),
                ),
                Row(
                  children: [
                    SizePicker(
                      selected: _sizeIndex,
                      color: Color(_color),
                      enabled: _tool.usesSize,
                      onChanged: (i) => setState(() => _sizeIndex = i),
                    ),
                    Container(
                      width: 2,
                      height: 30,
                      color: kStudioInk.withValues(alpha: 0.15),
                    ),
                    Expanded(
                      child: ColorPicker(
                        selected: _color,
                        enabled: _tool.usesColor,
                        onChanged: (c) => setState(() => _color = c),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _wideBody() {
    return Row(
      children: [
        _rise(
          child: _panel(
            vertical: true,
            child: Column(
              children: [
                Expanded(
                  child: ToolPicker(
                    tools: _tools,
                    axis: Axis.vertical,
                    selected: _tool,
                    onChanged: (t) => setState(() => _tool = t),
                  ),
                ),
                SizePicker(
                  axis: Axis.vertical,
                  selected: _sizeIndex,
                  color: Color(_color),
                  enabled: _tool.usesSize,
                  onChanged: (i) => setState(() => _sizeIndex = i),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _topBar(),
              Expanded(child: _canvasArea()),
            ],
          ),
        ),
        _rise(
          child: _panel(
            vertical: true,
            width: 112,
            child: ColorPicker(
              axis: Axis.vertical,
              selected: _color,
              enabled: _tool.usesColor,
              onChanged: (c) => setState(() => _color = c),
            ),
          ),
        ),
      ],
    );
  }

  /// A panel of tools, sliding up into place when the studio opens.
  Widget _rise({required Widget child}) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeOutBack,
    builder: (context, v, child) => Transform.translate(
      offset: Offset(0, 80 * v),
      child: Opacity(opacity: (1 - v).clamp(0.0, 1.0), child: child),
    ),
    child: child,
  );

  Widget _panel({required Widget child, bool vertical = false, double? width}) {
    return Container(
      width: vertical ? (width ?? 76) : null,
      margin: EdgeInsets.fromLTRB(10, vertical ? 10 : 4, 10, 10),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: kStudioPaper,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kStudioInk, width: 2),
        boxShadow: [
          BoxShadow(
            color: kStudioInk.withValues(alpha: 0.14),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _topBar() {
    final doc = _doc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          StudioButton(
            tooltip: 'Back',
            icon: Icons.arrow_back_rounded,
            onTap: _leave,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.display(fontSize: 18, color: kStudioInk),
                ),
                ValueListenableBuilder<_Save>(
                  valueListenable: _save,
                  builder: (context, s, _) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      switch (s) {
                        _Save.idle =>
                          _stored
                              ? 'Saved in Utopia'
                              : _doc?.kind == ArtKind.coloring
                              ? 'Tap a shape to fill it'
                              : 'Draw anything',
                        _Save.pending || _Save.saving => 'Saving…',
                        _Save.saved => 'Saved in Utopia',
                        _Save.failed => "Couldn't save, will try again",
                      },
                      key: ValueKey(s),
                      style: AppTextStyles.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kStudioInk.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          StudioButton(
            tooltip: 'Undo',
            icon: Icons.undo_rounded,
            size: 42,
            enabled: doc?.canUndo ?? false,
            onTap: _undo,
          ),
          const SizedBox(width: 6),
          StudioButton(
            tooltip: 'Redo',
            icon: Icons.redo_rounded,
            size: 42,
            enabled: doc?.canRedo ?? false,
            onTap: _redo,
          ),
          const SizedBox(width: 6),
          StudioButton(
            tooltip: 'Save to Photos',
            size: 42,
            enabled: doc != null && !doc.isEmpty,
            onTap: _saveToPhotos,
            child: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: kStudioInk,
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
          const SizedBox(width: 2),
          PopupMenuButton<String>(
            tooltip: 'More',
            color: kStudioPaper,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: kStudioInk, width: 2),
            ),
            icon: const Icon(Icons.more_vert_rounded, color: kStudioInk),
            onSelected: (v) => switch (v) {
              'clear' => _startOver(),
              'delete' => _delete(),
              _ => null,
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('Start over')),
              if (_stored)
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _canvasArea() {
    if (_error != null) {
      return _Message(
        mood: BuddyMood.sad,
        text: _error!,
        action: ('Back', () => context.pop()),
      );
    }
    if (_render == null) {
      return const _Message(
        mood: BuddyMood.thinking,
        text: 'Getting your page ready…',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _layout(constraints.biggest);
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                key: const ValueKey('studio-canvas'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onDown,
                onPointerMove: _onMove,
                onPointerUp: _onUp,
                onPointerCancel: (e) => _onUp(e, cancelled: true),
                onPointerSignal: _onSignal,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) => Transform.scale(
                    scale: v,
                    child: Opacity(
                      opacity: ((v - 0.9) * 10).clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _StudioPainter(this),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(right: 12, bottom: 12, child: _zoomControls()),
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: ValueListenableBuilder<double?>(
                    valueListenable: _zoomLabel,
                    builder: (context, z, _) => AnimatedOpacity(
                      opacity: z == null ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: kStudioInk,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${((z ?? 1) * 100).round()}%',
                          style: AppTextStyles.body(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kStudioPaper,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _zoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioButton(
          tooltip: 'Zoom in',
          icon: Icons.add_rounded,
          size: 38,
          onTap: () => _glideTo(_scale * 1.6),
        ),
        const SizedBox(height: 6),
        StudioButton(
          tooltip: 'Zoom out',
          icon: Icons.remove_rounded,
          size: 38,
          onTap: () => _glideTo(_scale / 1.6),
        ),
        const SizedBox(height: 6),
        StudioButton(
          tooltip: 'Fit the page',
          icon: Icons.fit_screen_rounded,
          size: 38,
          onTap: () => _glideTo(_fit),
        ),
      ],
    );
  }
}

/// The page on the desk: a soft shadow, the art (with the line being drawn
/// and any bucket splashes), at the current zoom.
class _StudioPainter extends CustomPainter {
  _StudioPainter(this.s) : super(repaint: s._repaint);

  final _StudioScreenState s;

  @override
  void paint(Canvas canvas, Size size) {
    final render = s._render;
    if (render == null) return;
    final page = Rect.fromLTWH(
      s._offset.dx,
      s._offset.dy,
      kPageSize.width * s._scale,
      kPageSize.height * s._scale,
    );
    final sheet = RRect.fromRectAndRadius(page, const Radius.circular(18));
    canvas.drawRRect(
      sheet.shift(const Offset(0, 6)),
      Paint()
        ..color = kStudioInk.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.save();
    canvas.clipRRect(sheet);
    canvas.translate(s._offset.dx, s._offset.dy);
    canvas.scale(s._scale);
    final live = s._live;
    render.paint(
      canvas,
      live: live == null
          ? null
          : StrokeOp(
              tool: s._tool,
              color: s._color,
              size: s._size,
              points: live,
            ),
    );
    canvas.restore();
    canvas.drawRRect(
      sheet,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = kStudioInk,
    );
    final now = s._clock.elapsed;
    for (final splash in s._splashes) {
      final k = ((now - splash.started).inMilliseconds / 520).clamp(0.0, 1.0);
      final e = Curves.easeOutCubic.transform(k);
      canvas.drawCircle(
        splash.at,
        10 + 46 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - k) + 0.5
          ..color = splash.color.withValues(alpha: 1 - k),
      );
      canvas.drawCircle(
        splash.at,
        4 + 20 * e,
        Paint()..color = splash.color.withValues(alpha: 0.35 * (1 - k)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StudioPainter old) => true;
}

/// A friendly note in place of the page (loading, or something went wrong).
class _Message extends StatelessWidget {
  const _Message({required this.mood, required this.text, this.action});

  final BuddyMood mood;
  final String text;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinBuddy(mood: mood, size: 90),
          const SizedBox(height: 12),
          Text(
            text,
            style: AppTextStyles.body(
              fontWeight: FontWeight.w700,
              color: kStudioInk,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            StudioButton(
              tooltip: action!.$1,
              icon: Icons.arrow_back_rounded,
              onTap: action!.$2,
            ),
          ],
        ],
      ),
    );
  }
}
