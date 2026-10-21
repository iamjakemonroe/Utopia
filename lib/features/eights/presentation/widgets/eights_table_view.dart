import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/strings.dart';
import '../../domain/eights_engine.dart';
import 'card_art.dart';

/// How far apart the cards go out in the deal.
const kEightsDealCard = Duration(milliseconds: 55);

double get _dealStep => kEightsDealCard.inMicroseconds / 1e6;

/// A card on its way somewhere: dealt, played, drawn. It travels from
/// [from] to [to] (growing or shrinking from [w0] to [w1] wide), turning
/// face up halfway when [flip] (it starts as a back), and calls [land] when
/// it gets there.
class _Flight {
  _Flight({
    required this.card,
    required this.from,
    required this.to,
    required this.w0,
    required this.w1,
    required this.start,
    this.duration = 0.42,
    this.a0 = 0,
    this.a1 = 0,
    this.flip = false,
    this.arc = 0.25,
    this.land,
  });

  final PlayingCard? card;
  final Offset from;
  final Offset to;
  final double w0, w1;
  final double start;
  final double duration;
  final double a0, a1;
  final bool flip;

  /// How high it arcs, in card heights.
  final double arc;
  final VoidCallback? land;
  bool landed = false;

  double get end => start + duration;
}

/// Where a card sits: its center and turn.
class _Pose {
  _Pose(this.at, this.angle);

  Offset at;
  double angle;
}

/// The card table: the draw pile and the discard pile in the middle, the
/// others' cards (face down) by their seats round the top, and my hand
/// fanned along the bottom, the cards that go lifted and glowing. Cards
/// fly: dealt round the table, played onto the pile (turning face up if
/// they were someone else's), drawn into a hand. An eight bursts its suit
/// over the pile, and a badge keeps showing the suit to follow.
///
/// All of it is one painting from card pictures kept as pixels (see
/// [drawCard]): a browser only places pictures each frame. Taps are found
/// from where the cards are drawn.
class EightsTableView extends ConsumerStatefulWidget {
  const EightsTableView({
    super.key,
    required this.table,
    required this.hand,
    required this.mySeat,
    required this.playable,
    required this.myTurn,
    required this.canDraw,
    required this.canPass,
    required this.onPlay,
    required this.onDraw,
    required this.onPass,
    required this.seatBuilder,
    this.deal = false,
  });

  final EightsTable table;
  final List<PlayingCard> hand;
  final int mySeat;

  /// My cards that can go on the pile now.
  final Set<PlayingCard> playable;
  final bool myTurn;
  final bool canDraw;
  final bool canPass;
  final ValueChanged<PlayingCard> onPlay;
  final VoidCallback onDraw;
  final VoidCallback onPass;

  /// The panel for another player's seat (avatar, name, timer).
  final Widget Function(int seat) seatBuilder;

  /// Deal the cards out (a game just starting).
  final bool deal;

  /// The table's clock, in seconds.
  static double clockNow() => _clock.elapsedMicroseconds / 1e6;
  static final Stopwatch _clock = Stopwatch()..start();

  @override
  ConsumerState<EightsTableView> createState() => _EightsTableViewState();
}

/// Sizes and places for one size of table.
class _Layout {
  _Layout(this.size, this.seats, this.mySeat) {
    final w = size.width;
    final h = size.height;
    cardW = math.min(w * 0.17, h * 0.135).clamp(52.0, 96.0).toDouble();
    final mid = Offset(w / 2, h * 0.47);
    deck = mid.translate(-cardW * 0.72, 0);
    pile = mid.translate(cardW * 0.72, 0);
    final others = [for (var i = 1; i < seats; i++) (mySeat + i) % seats];
    for (final (i, seat) in others.indexed) {
      final t = (i + 1) / (others.length + 1);
      final angle = math.pi + t * math.pi;
      final at = Offset(
        w / 2 + math.cos(angle) * w * 0.38,
        math.max(46.0, h * 0.31 + math.sin(angle) * h * 0.23),
      );
      seatAt[seat] = at;
      fanAt[seat] = at.translate(0, 50);
    }
    handY = h - cardH * 0.62 - 6;
  }

  final Size size;
  final int seats;
  final int mySeat;
  late final double cardW;
  double get cardH => cardW * kCardAspect;
  double get backW => cardW * 0.42;
  late final Offset deck;
  late final Offset pile;
  final Map<int, Offset> seatAt = {};
  final Map<int, Offset> fanAt = {};
  late final double handY;

  /// Where each of [n] cards in my hand rests.
  List<_Pose> hand(int n, {Set<int> lifted = const {}}) {
    if (n == 0) return const [];
    final w = size.width;
    final spread = n == 1
        ? 0.0
        : math.min(cardW * 0.62, (w - 24 - cardW) / (n - 1));
    final turn = math.min(0.05, 0.36 / n);
    return [
      for (var i = 0; i < n; i++)
        () {
          final k = i - (n - 1) / 2;
          final x = w / 2 + k * spread;
          final bow = math.pow(k * spread / (w * 0.5), 2) * cardH * 0.1;
          return _Pose(
            Offset(x, handY + bow - (lifted.contains(i) ? cardH * 0.14 : 0)),
            k * turn,
          );
        }(),
    ];
  }

  /// Where the [i]th of someone's face-down cards sits (showing up to six).
  Offset fanCard(int seat, int i, int count) {
    final shown = math.min(count, 6);
    final k = math.min(i, 5) - (shown - 1) / 2;
    return fanAt[seat]!.translate(k * backW * 0.34, 0);
  }
}

class _EightsTableViewState extends ConsumerState<EightsTableView>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _now = ValueNotifier(EightsTableView.clockNow());
  late final Ticker _ticker = createTicker((_) {
    final now = EightsTableView.clockNow();
    final busy = _flights.isNotEmpty || _settling || now < _burstEnd;
    // Pulsing glows need 30 frames a second; anything moving gets all.
    if (!busy && (now - _now.value) < (widget.myTurn ? 1 / 30 : 0.25)) return;
    _now.value = now;
  });

  _Layout? _layout;
  final List<_Flight> _flights = [];

  /// My cards where they're drawn now (they ease toward where they rest).
  final Map<PlayingCard, _Pose> _shown = {};

  /// My cards still in the air (dealt or drawn): not in the hand yet.
  final Set<PlayingCard> _incoming = {};

  /// Face-down cards on their way to each seat, not counted there yet.
  final Map<int, int> _toSeat = {};

  /// The top few cards of the pile, each a little askew.
  final List<(PlayingCard, double)> _pile = [];

  /// The pile's top card is in the air: it shows once it lands.
  bool _pileInFlight = false;

  /// A card shaken for not going: when.
  final Map<PlayingCard, double> _nope = {};

  bool _settling = false;
  double _lastFrame = EightsTableView.clockNow();
  CardSuit? _burstSuit;
  double _burstAt = -10;
  double get _burstEnd => _burstAt + 1.1;
  final _rng = math.Random();
  bool _dealt = false;

  GameAudio get _audio => ref.read(gameAudioProvider);

  @override
  void initState() {
    super.initState();
    _pile.add((widget.table.top, 0));
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  List<PlayingCard> get _sorted {
    const order = [
      CardSuit.spades,
      CardSuit.hearts,
      CardSuit.clubs,
      CardSuit.diamonds,
    ];
    return [...widget.hand]..sort((a, b) {
      final bySuit = order.indexOf(a.suit).compareTo(order.indexOf(b.suit));
      return bySuit != 0 ? bySuit : a.rank.compareTo(b.rank);
    });
  }

  /// My cards in the hand right now (not those still flying in).
  List<PlayingCard> get _handNow => [
    for (final c in _sorted)
      if (!_incoming.contains(c)) c,
  ];

  /// Where [card] rests in my hand.
  _Pose _restFor(PlayingCard card, _Layout l) {
    final hand = _handNow;
    final i = hand.indexOf(card);
    final poses = l.hand(hand.length, lifted: _liftedIndexes(hand));
    return i < 0 ? _Pose(l.deck, 0) : poses[i];
  }

  Set<int> _liftedIndexes(List<PlayingCard> hand) => {
    if (widget.myTurn)
      for (final (i, c) in hand.indexed)
        if (widget.playable.contains(c)) i,
  };

  // ── what changed ─────────────────────────────────────────────────────────

  @override
  void didUpdateWidget(covariant EightsTableView old) {
    super.didUpdateWidget(old);
    final l = _layout;
    final t = widget.table;
    if (l == null) return;
    if (t.seq == old.table.seq) {
      // My cards arriving on their own (fetched after a time-out).
      _syncHand(old, l, EightsTableView.clockNow());
      return;
    }
    final last = t.last;
    final now = EightsTableView.clockNow();
    final jumped = t.seq > old.table.seq + 1;

    if (last != null && !jumped && last.kind == EightsActionKind.play) {
      final card = last.card!;
      final mine = last.seat == widget.mySeat;
      final from = mine
          ? (_shown.remove(card) ?? _Pose(l.hand(1).first.at, 0))
          : _Pose(l.fanCard(last.seat, 0, 1), 0);
      _pileInFlight = true;
      _audio.play(Sfx.cardPlay);
      _flights.add(
        _Flight(
          card: card,
          from: from.at,
          to: l.pile,
          w0: mine ? l.cardW : l.backW,
          w1: l.cardW,
          a0: from.angle,
          a1: (_rng.nextDouble() - 0.5) * 0.5,
          flip: !mine,
          start: now,
          arc: 0.35,
          land: () {
            _pileInFlight = false;
            _pushPile(card, (_rng.nextDouble() - 0.5) * 0.5);
            if (card.isEight) {
              _burstSuit = t.suit;
              _burstAt = EightsTableView.clockNow();
              _audio.play(Sfx.cardWild);
            }
          },
        ),
      );
    } else if (last != null &&
        !jumped &&
        (last.kind == EightsActionKind.draw ||
            last.kind == EightsActionKind.timeout) &&
        t.counts[last.seat] > old.table.counts[last.seat]) {
      _drawTo(last.seat, l, now, old);
    } else if (_pile.isEmpty || _pile.last.$1 != t.top) {
      _pushPile(t.top, 0);
    }
    _syncHand(old, l, now);
  }

  /// A card drawn by [seat]: off the pile into their hand (face up, if
  /// it's mine).
  void _drawTo(int seat, _Layout l, double now, EightsTableView old) {
    _audio.play(Sfx.cardDraw);
    if (seat == widget.mySeat) {
      final added = [
        for (final c in widget.hand)
          if (!old.hand.contains(c)) c,
      ];
      for (final card in added) {
        _incoming.add(card);
        final rest = _restFor(card, l);
        _flights.add(
          _Flight(
            card: card,
            from: l.deck,
            to: rest.at,
            w0: l.cardW,
            w1: l.cardW,
            a1: rest.angle,
            flip: true,
            start: now,
            duration: 0.5,
            land: () {
              _incoming.remove(card);
              _shown[card] = _restFor(card, _layout!);
            },
          ),
        );
      }
      return;
    }
    _toSeat[seat] = (_toSeat[seat] ?? 0) + 1;
    _flights.add(
      _Flight(
        card: null,
        from: l.deck,
        to: l.fanCard(
          seat,
          widget.table.counts[seat] - 1,
          widget.table.counts[seat],
        ),
        w0: l.cardW,
        w1: l.backW,
        start: now,
        duration: 0.45,
        land: () => _toSeat[seat] = math.max(0, (_toSeat[seat] ?? 1) - 1),
      ),
    );
  }

  /// Cards that came into my hand some other way (a resync, my hand
  /// arriving after the table): they just slide in from the deck.
  void _syncHand(EightsTableView old, _Layout l, double now) {
    for (final c in [..._shown.keys]) {
      if (!widget.hand.contains(c)) _shown.remove(c);
    }
    for (final c in widget.hand) {
      if (!_shown.containsKey(c) && !_incoming.contains(c)) {
        _shown[c] = _Pose(l.deck, 0);
      }
    }
  }

  void _pushPile(PlayingCard card, double angle) {
    if (_pile.isNotEmpty && _pile.last.$1 == card) return;
    _pile.add((card, angle));
    if (_pile.length > 4) _pile.removeAt(0);
  }

  /// The deal: one card at a time round the table from the seat after
  /// whoever goes first, my cards landing face up, then the first card
  /// turns over onto the pile.
  void _startDeal(_Layout l) {
    _dealt = true;
    final t = widget.table;
    final now = EightsTableView.clockNow() + 0.15;
    final perSeat = eightsHandSize(t.seats);
    final mine = _sorted;
    var k = 0;
    _pileInFlight = true;
    _pile.clear();
    for (var round = 0; round < perSeat; round++) {
      for (var s = 0; s < t.seats; s++) {
        final seat = (t.turn + s) % t.seats;
        final at = now + k++ * _dealStep;
        if (seat == widget.mySeat) {
          if (round >= mine.length) continue;
          final card = mine[round];
          _incoming.add(card);
          _flights.add(
            _Flight(
              card: card,
              from: l.deck,
              to: Offset(l.size.width / 2, l.handY),
              w0: l.cardW,
              w1: l.cardW,
              flip: true,
              start: at,
              duration: 0.38,
              arc: 0.1,
              land: () {
                _incoming.remove(card);
                _shown[card] = _Pose(Offset(l.size.width / 2, l.handY), 0);
                _audio.play(Sfx.cardDeal, volume: 0.6);
              },
            ),
          );
        } else {
          _toSeat[seat] = (_toSeat[seat] ?? 0) + 1;
          _flights.add(
            _Flight(
              card: null,
              from: l.deck,
              to: l.fanCard(seat, round, perSeat),
              w0: l.cardW,
              w1: l.backW,
              start: at,
              duration: 0.38,
              arc: 0.1,
              land: () => _toSeat[seat] = math.max(0, (_toSeat[seat] ?? 1) - 1),
            ),
          );
        }
      }
    }
    final top = t.top;
    _flights.add(
      _Flight(
        card: top,
        from: l.deck,
        to: l.pile,
        w0: l.cardW,
        w1: l.cardW,
        flip: true,
        start: now + k * _dealStep + 0.25,
        duration: 0.45,
        a1: 0.05,
        land: () {
          _pileInFlight = false;
          _pushPile(top, 0.05);
          _audio.play(Sfx.cardPlay);
        },
      ),
    );
  }

  // ── taps ─────────────────────────────────────────────────────────────────

  void _onTap(TapUpDetails d) {
    final l = _layout;
    if (l == null) return;
    final p = d.localPosition;
    final hand = _handNow;
    for (final card in hand.reversed) {
      final pose = _shown[card];
      if (pose == null) continue;
      final rel = p - pose.at;
      final c = math.cos(-pose.angle), s = math.sin(-pose.angle);
      final local = Offset(rel.dx * c - rel.dy * s, rel.dx * s + rel.dy * c);
      if (Rect.fromCenter(
        center: Offset.zero,
        width: l.cardW,
        height: l.cardH,
      ).contains(local)) {
        if (widget.playable.contains(card)) {
          widget.onPlay(card);
        } else if (widget.myTurn) {
          _nope[card] = EightsTableView.clockNow();
          _audio.play(Sfx.tap, volume: 0.5);
        }
        return;
      }
    }
    if (Rect.fromCenter(
          center: l.deck,
          width: l.cardW * 1.2,
          height: l.cardH * 1.2,
        ).contains(p) &&
        widget.canDraw) {
      widget.onDraw();
    }
  }

  // ── drawing ──────────────────────────────────────────────────────────────

  void _paint(Canvas canvas, Size size, double now, double dpr) {
    final l = _layout!;
    final dt = (now - _lastFrame).clamp(0.0, 0.1);
    _lastFrame = now;
    final t = widget.table;

    _paintFelt(canvas, l);

    // The draw pile: a short stack, glowing when I can draw.
    final stack = math.min(3, (t.drawCount / 12).ceil());
    if (widget.canDraw) {
      final pulse = 0.5 + 0.5 * math.sin(now * 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: l.deck,
            width: l.cardW * (1.12 + 0.05 * pulse),
            height: l.cardH * (1.1 + 0.04 * pulse),
          ),
          Radius.circular(l.cardW * 0.14),
        ),
        Paint()
          ..color = AppColors.coinGold.withValues(alpha: 0.35 + 0.25 * pulse),
      );
    }
    for (var i = 0; i < stack; i++) {
      drawCard(
        canvas,
        null,
        at: l.deck.translate(-i * 1.5, -i * 2.0),
        width: l.cardW,
        dpr: dpr,
      );
    }
    if (t.drawCount == 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: l.deck, width: l.cardW, height: l.cardH),
          Radius.circular(l.cardW * 0.1),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.25),
      );
    }
    _label(canvas, '${t.drawCount}', l.deck.translate(0, l.cardH * 0.64), 12);

    // The pile, the top few a little askew.
    for (final (card, angle) in _pile) {
      drawCard(
        canvas,
        card,
        at: l.pile,
        width: l.cardW,
        dpr: dpr,
        angle: angle,
      );
    }

    // The suit to follow after an eight.
    if (t.top.isEight && !_pileInFlight) {
      final at = l.pile.translate(l.cardW * 0.62, -l.cardH * 0.45);
      final r = l.cardW * 0.22 * (1 + 0.06 * math.sin(now * 4));
      canvas.drawCircle(
        at,
        r * 1.15,
        Paint()..color = suitColor(t.suit).withValues(alpha: 0.35),
      );
      canvas.drawCircle(at, r, Paint()..color = Colors.white);
      drawSuit(canvas, t.suit, at, r * 1.1);
    }

    // Everyone else's cards, face down by their seats.
    for (var seat = 0; seat < t.seats; seat++) {
      if (seat == widget.mySeat || t.left.contains(seat)) continue;
      final count = math.max(0, t.counts[seat] - (_toSeat[seat] ?? 0));
      for (var i = 0; i < math.min(count, 6); i++) {
        drawCard(
          canvas,
          null,
          at: l.fanCard(seat, i, count),
          width: l.backW,
          dpr: dpr,
          angle: (i - (math.min(count, 6) - 1) / 2) * 0.12,
        );
      }
    }

    // My hand, easing toward where each card rests.
    final hand = _handNow;
    final rests = l.hand(hand.length, lifted: _liftedIndexes(hand));
    var settling = false;
    final follow = 1 - math.exp(-dt * 16);
    for (final (i, card) in hand.indexed) {
      final rest = rests[i];
      final pose = _shown.putIfAbsent(card, () => _Pose(rest.at, rest.angle));
      pose.at = Offset.lerp(pose.at, rest.at, follow)!;
      pose.angle += (rest.angle - pose.angle) * follow;
      if ((pose.at - rest.at).distance > 0.5) settling = true;
      var at = pose.at;
      final nope = _nope[card];
      if (nope != null) {
        final f = (now - nope) / 0.35;
        if (f >= 1) {
          _nope.remove(card);
        } else {
          at = at.translate(math.sin(f * math.pi * 6) * 5 * (1 - f), 0);
          settling = true;
        }
      }
      final glow = widget.myTurn && widget.playable.contains(card);
      if (glow) {
        final pulse = 0.5 + 0.5 * math.sin(now * 5 + i);
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(pose.angle);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: l.cardW + 8,
              height: l.cardH + 8,
            ),
            Radius.circular(l.cardW * 0.14),
          ),
          Paint()
            ..color = AppColors.coinGoldBright.withValues(
              alpha: 0.55 + 0.35 * pulse,
            ),
        );
        canvas.restore();
      }
      drawCard(
        canvas,
        card,
        at: at,
        width: l.cardW,
        dpr: dpr,
        angle: pose.angle,
      );
      if (widget.myTurn && !glow) {
        // Can't go now: dimmed.
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(pose.angle);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: l.cardW,
              height: l.cardH,
            ),
            Radius.circular(l.cardW * 0.1),
          ),
          Paint()..color = const Color(0xFF1A1440).withValues(alpha: 0.35),
        );
        canvas.restore();
      }
    }
    _settling = settling;

    // Cards in the air.
    for (final f in [..._flights]) {
      final p = ((now - f.start) / f.duration).clamp(0.0, 1.0);
      if (now < f.start) continue;
      if (p >= 1) {
        _flights.remove(f);
        if (!f.landed) {
          f.landed = true;
          f.land?.call();
        }
        continue;
      }
      final e = Curves.easeOutCubic.transform(p);
      final at =
          Offset.lerp(f.from, f.to, e)! -
          Offset(0, math.sin(p * math.pi) * l.cardH * f.arc);
      final w = f.w0 + (f.w1 - f.w0) * e;
      final angle = f.a0 + (f.a1 - f.a0) * e;
      final face = f.flip ? (p > 0.5 ? f.card : null) : f.card;
      final squeeze = f.flip
          ? (math.cos(p * math.pi)).abs().clamp(0.05, 1.0)
          : 1.0;
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle);
      canvas.scale(squeeze * w / l.cardW, w / l.cardW);
      // A soft shadow under it, further as it rises.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(4, 6 + math.sin(p * math.pi) * 10),
            width: l.cardW,
            height: l.cardH,
          ),
          Radius.circular(l.cardW * 0.1),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      drawCard(canvas, face, at: Offset.zero, width: l.cardW, dpr: dpr);
      canvas.restore();
    }

    // An eight: its suit bursts over the pile.
    final b = (now - _burstAt) / 1.1;
    if (b >= 0 && b < 1 && _burstSuit != null) {
      final grow = Curves.easeOutBack.transform(math.min(1.0, b / 0.35));
      final fade = b < 0.6 ? 1.0 : 1 - (b - 0.6) / 0.4;
      final reach = l.cardW * (0.6 + 1.2 * grow);
      final rays = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.8 * fade),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: l.pile, radius: reach));
      for (var k = 0; k < 12; k++) {
        final a = b * 1.5 + k * math.pi / 6;
        canvas.drawPath(
          Path()
            ..moveTo(l.pile.dx, l.pile.dy)
            ..lineTo(
              l.pile.dx + math.cos(a - 0.1) * reach,
              l.pile.dy + math.sin(a - 0.1) * reach,
            )
            ..lineTo(
              l.pile.dx + math.cos(a + 0.1) * reach,
              l.pile.dy + math.sin(a + 0.1) * reach,
            )
            ..close(),
          rays,
        );
      }
      canvas.drawCircle(
        l.pile,
        l.cardW * 0.5 * grow,
        Paint()..color = Colors.white.withValues(alpha: 0.9 * fade),
      );
      drawSuit(
        canvas,
        _burstSuit!,
        l.pile,
        l.cardW * 0.62 * grow,
        color: suitColor(_burstSuit!).withValues(alpha: fade),
      );
    }
  }

  /// A soft round mat the table sits on.
  void _paintFelt(Canvas canvas, _Layout l) {
    final rect = Rect.fromCenter(
      center: Offset(l.size.width / 2, l.deck.dy),
      width: l.size.width * 0.86,
      height: l.cardH * 2.1,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.28),
            AppColors.accent.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );
  }

  void _label(Canvas canvas, String text, Offset at, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTextStyles.body(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // On a dark pill, so it reads in any world.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: at,
          width: tp.width + 14,
          height: tp.height + 4,
        ),
        Radius.circular(tp.height),
      ),
      Paint()..color = const Color(0xAA1A1440),
    );
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final l = _layout?.size == size && _layout?.seats == widget.table.seats
            ? _layout!
            : (_layout = _Layout(size, widget.table.seats, widget.mySeat));
        if (widget.deal && !_dealt) {
          _startDeal(l);
        } else {
          _dealt = true;
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _onTap,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _TablePainter(this, dpr),
                    size: size,
                  ),
                ),
              ),
            ),
            for (final entry in l.seatAt.entries)
              Positioned(
                left: entry.value.dx - 55,
                top: entry.value.dy - 46,
                width: 110,
                child: widget.seatBuilder(entry.key),
              ),
            if (widget.canPass)
              Positioned(
                left: l.deck.dx - 50,
                top: l.deck.dy + l.cardH * 0.62 + 12,
                width: 100,
                child: _PassButton(onTap: widget.onPass),
              ),
          ],
        );
      },
    );
  }
}

class _TablePainter extends CustomPainter {
  _TablePainter(this.view, this.dpr) : super(repaint: view._now);

  final _EightsTableViewState view;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) =>
      view._paint(canvas, size, view._now.value, dpr);

  @override
  bool shouldRepaint(covariant _TablePainter old) => true;
}

class _PassButton extends StatelessWidget {
  const _PassButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Semantics(
        button: true,
        label: strings.eightsPass,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9EC4), Color(0xFFFF5C9C)],
              ),
              border: Border.all(color: Colors.white, width: 1.6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              strings.eightsPass,
              style: AppTextStyles.body(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
