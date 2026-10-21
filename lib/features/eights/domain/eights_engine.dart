import 'dart:math';

/// The four suits, in the order the card codes use (S, H, D, C).
enum CardSuit {
  spades('S'),
  hearts('H'),
  diamonds('D'),
  clubs('C');

  const CardSuit(this.code);

  /// The letter in a card's code ("QS" is the queen of spades).
  final String code;

  bool get red => this == hearts || this == diamonds;

  static CardSuit fromCode(String code) =>
      values.firstWhere((s) => s.code == code);
}

/// One playing card. Its [code] is the rank then the suit, as the server
/// keeps it: "AS", "7H", "TD" (ten), "KC".
class PlayingCard {
  const PlayingCard(this.rank, this.suit);

  /// 1 (ace) to 13 (king).
  final int rank;
  final CardSuit suit;

  static const _ranks = 'A23456789TJQK';

  String get code => '${_ranks[rank - 1]}${suit.code}';

  /// What's printed in the corner: "A", "2" to "10", "J", "Q", "K".
  String get label => rank == 10 ? '10' : _ranks[rank - 1];

  /// Eights are wild: they go on anything, and name the suit to follow.
  bool get isEight => rank == 8;

  static PlayingCard fromCode(String code) => PlayingCard(
    _ranks.indexOf(code[0]) + 1,
    CardSuit.fromCode(code.substring(1)),
  );

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => code;
}

/// Every card in a deck, in order.
final List<PlayingCard> kFullDeck = [
  for (final suit in CardSuit.values)
    for (var rank = 1; rank <= 13; rank++) PlayingCard(rank, suit),
];

/// Cards each player starts with: seven for two players, five for more.
int eightsHandSize(int players) => players == 2 ? 7 : 5;

/// What just happened at the table, for everyone to see (and animate).
enum EightsActionKind { deal, play, draw, pass, timeout, left }

class EightsAction {
  const EightsAction({
    required this.seat,
    required this.kind,
    this.card,
    this.suit,
  });

  final int seat;
  final EightsActionKind kind;

  /// The card played (a play), or null.
  final PlayingCard? card;

  /// The suit an eight named.
  final CardSuit? suit;

  Map<String, dynamic> toJson() => {
    'seat': seat,
    'kind': kind.name,
    'card': card?.code,
    'suit': suit?.code,
  };

  static EightsAction? fromJson(Object? json) {
    if (json is! Map) return null;
    final card = json['card'] as String?;
    final suit = json['suit'] as String?;
    return EightsAction(
      seat: (json['seat'] as num).toInt(),
      kind: EightsActionKind.values.byName(json['kind'] as String),
      card: card == null ? null : PlayingCard.fromCode(card),
      suit: suit == null ? null : CardSuit.fromCode(suit),
    );
  }
}

/// The table as everyone sees it: the card on top of the discard pile and
/// the suit to follow, how many cards each player holds (not which), how
/// many are left to draw, and whose turn it is. Seats are numbered from 0
/// in turn order. Matches the server's eights_matches.state.
class EightsTable {
  const EightsTable({
    required this.counts,
    required this.turn,
    required this.top,
    required this.suit,
    required this.drawCount,
    this.drawn = false,
    this.seq = 0,
    this.last,
    this.left = const [],
    this.winner,
  });

  /// Cards in each seat's hand.
  final List<int> counts;
  final int turn;

  /// The top of the discard pile.
  final PlayingCard top;

  /// The suit to follow: the top card's, or the one an eight named.
  final CardSuit suit;

  /// Cards left to draw.
  final int drawCount;

  /// The player on turn has drawn: they can play or pass now.
  final bool drawn;

  /// Goes up with every action, so each one can be told from the last.
  final int seq;
  final EightsAction? last;

  /// Seats that left (or ran out of time three times): skipped.
  final List<int> left;

  /// The seat that went out first, once someone has.
  final int? winner;

  int get seats => counts.length;

  bool get isOver => winner != null;

  /// Seats still playing.
  List<int> get active => [
    for (var s = 0; s < seats; s++)
      if (!left.contains(s)) s,
  ];

  /// The next seat after [from] still in the game.
  int nextSeat([int? from]) {
    final start = from ?? turn;
    for (var step = 1; step <= seats; step++) {
      final s = (start + step) % seats;
      if (!left.contains(s)) return s;
    }
    return start;
  }

  /// [card] can go on the pile now: it's an eight, or it matches the suit
  /// to follow or the top card's rank.
  bool canPlay(PlayingCard card) =>
      card.isEight || card.suit == suit || card.rank == top.rank;

  EightsTable copyWith({
    List<int>? counts,
    int? turn,
    PlayingCard? top,
    CardSuit? suit,
    int? drawCount,
    bool? drawn,
    int? seq,
    EightsAction? last,
    List<int>? left,
    int? winner,
  }) => EightsTable(
    counts: counts ?? this.counts,
    turn: turn ?? this.turn,
    top: top ?? this.top,
    suit: suit ?? this.suit,
    drawCount: drawCount ?? this.drawCount,
    drawn: drawn ?? this.drawn,
    seq: seq ?? this.seq,
    last: last ?? this.last,
    left: left ?? this.left,
    winner: winner ?? this.winner,
  );

  Map<String, dynamic> toJson() => {
    'counts': counts,
    'turn': turn,
    'top': top.code,
    'suit': suit.code,
    'draw': drawCount,
    'drawn': drawn,
    'seq': seq,
    'last': last?.toJson(),
    'left': left,
    'winner': winner,
  };

  factory EightsTable.fromJson(Map<String, dynamic> json) => EightsTable(
    counts: [for (final c in json['counts'] as List) (c as num).toInt()],
    turn: (json['turn'] as num).toInt(),
    top: PlayingCard.fromCode(json['top'] as String),
    suit: CardSuit.fromCode(json['suit'] as String),
    drawCount: (json['draw'] as num?)?.toInt() ?? 0,
    drawn: json['drawn'] as bool? ?? false,
    seq: (json['seq'] as num?)?.toInt() ?? 0,
    last: EightsAction.fromJson(json['last']),
    left: [
      for (final s in (json['left'] as List? ?? const [])) (s as num).toInt(),
    ],
    winner: (json['winner'] as num?)?.toInt(),
  );
}

/// A whole game, every card known: what a game on this phone (against
/// bots) keeps. Online, the server keeps this and each player only gets
/// the [EightsTable] and their own hand.
class EightsGame {
  const EightsGame({
    required this.table,
    required this.hands,
    required this.drawPile,
    required this.discard,
  });

  final EightsTable table;
  final List<List<PlayingCard>> hands;

  /// Face down, drawn from the end.
  final List<PlayingCard> drawPile;

  /// Played cards under the top one (the top is [EightsTable.top]).
  final List<PlayingCard> discard;

  EightsGame copyWith({
    EightsTable? table,
    List<List<PlayingCard>>? hands,
    List<PlayingCard>? drawPile,
    List<PlayingCard>? discard,
  }) => EightsGame(
    table: table ?? this.table,
    hands: hands ?? this.hands,
    drawPile: drawPile ?? this.drawPile,
    discard: discard ?? this.discard,
  );

  Map<String, dynamic> toJson() => {
    'table': table.toJson(),
    'hands': [
      for (final h in hands) [for (final c in h) c.code],
    ],
    'draw': [for (final c in drawPile) c.code],
    'discard': [for (final c in discard) c.code],
  };

  factory EightsGame.fromJson(Map<String, dynamic> json) {
    List<PlayingCard> cards(Object? list) => [
      for (final c in (list as List? ?? const []))
        PlayingCard.fromCode(c as String),
    ];
    return EightsGame(
      table: EightsTable.fromJson(
        (json['table'] as Map).cast<String, dynamic>(),
      ),
      hands: [for (final h in json['hands'] as List) cards(h)],
      drawPile: cards(json['draw']),
      discard: cards(json['discard']),
    );
  }
}

/// Why a move isn't allowed.
class EightsRuleError implements Exception {
  const EightsRuleError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Crazy Eights, the classic way. Match the top card's suit or rank, or
/// play an eight (wild) and name the suit. Can't (or won't)? Draw one; then
/// play a card or pass. First to empty their hand wins. Pure: no Flutter,
/// no network, the same rules the server's functions enforce.
class EightsEngine {
  const EightsEngine();

  /// Shuffles and deals for [players]: the top card of what's left starts
  /// the pile (never an eight: it's slipped back into the deck).
  EightsGame deal(int players, {Random? random, int firstTurn = 0}) {
    final rng = random ?? Random();
    final deck = [...kFullDeck]..shuffle(rng);
    final size = eightsHandSize(players);
    final hands = [
      for (var p = 0; p < players; p++)
        [for (var i = 0; i < size; i++) deck.removeLast()],
    ];
    var top = deck.removeLast();
    while (top.isEight) {
      deck.insert(rng.nextInt(deck.length), top);
      top = deck.removeLast();
    }
    return EightsGame(
      table: EightsTable(
        counts: [for (final h in hands) h.length],
        turn: firstTurn % players,
        top: top,
        suit: top.suit,
        drawCount: deck.length,
        last: EightsAction(
          seat: firstTurn % players,
          kind: EightsActionKind.deal,
        ),
      ),
      hands: hands,
      drawPile: deck,
      discard: const [],
    );
  }

  /// [seat] plays [card] (naming [suit] if it's an eight).
  EightsGame play(
    EightsGame game,
    int seat,
    PlayingCard card, {
    CardSuit? suit,
  }) {
    final t = game.table;
    if (t.isOver) throw const EightsRuleError('the game is over');
    if (seat != t.turn) throw const EightsRuleError('not your turn');
    final hand = game.hands[seat];
    if (!hand.contains(card)) throw const EightsRuleError('not in your hand');
    if (!t.canPlay(card)) throw const EightsRuleError("that card doesn't go");
    if (card.isEight && suit == null) {
      throw const EightsRuleError('name a suit for the eight');
    }
    final newHand = [...hand]..remove(card);
    final hands = [...game.hands]..[seat] = newHand;
    final out = newHand.isEmpty;
    return game.copyWith(
      hands: hands,
      discard: [...game.discard, t.top],
      table: t.copyWith(
        counts: [...t.counts]..[seat] = newHand.length,
        top: card,
        suit: card.isEight ? suit : card.suit,
        turn: out ? seat : t.nextSeat(seat),
        drawn: false,
        seq: t.seq + 1,
        last: EightsAction(
          seat: seat,
          kind: EightsActionKind.play,
          card: card,
          suit: card.isEight ? suit : null,
        ),
        winner: out ? seat : null,
      ),
    );
  }

  /// [seat] draws one card. When the pile is empty the played cards
  /// (all but the top) are shuffled back into it first; when there's
  /// nothing at all to draw, the turn just passes.
  EightsGame draw(EightsGame game, int seat, {Random? random}) {
    final t = game.table;
    if (t.isOver) throw const EightsRuleError('the game is over');
    if (seat != t.turn) throw const EightsRuleError('not your turn');
    if (t.drawn) throw const EightsRuleError('you already drew');
    var pile = [...game.drawPile];
    var discard = game.discard;
    if (pile.isEmpty) {
      pile = [...discard]..shuffle(random ?? Random());
      discard = const [];
    }
    if (pile.isEmpty) {
      return pass(game.copyWith(table: t.copyWith(drawn: true)), seat);
    }
    final card = pile.removeLast();
    final hand = [...game.hands[seat], card];
    return game.copyWith(
      hands: [...game.hands]..[seat] = hand,
      drawPile: pile,
      discard: discard,
      table: t.copyWith(
        counts: [...t.counts]..[seat] = hand.length,
        drawCount: pile.length,
        drawn: true,
        seq: t.seq + 1,
        last: EightsAction(seat: seat, kind: EightsActionKind.draw),
      ),
    );
  }

  /// [seat], having drawn, passes the turn on.
  EightsGame pass(EightsGame game, int seat, {bool timedOut = false}) {
    final t = game.table;
    if (t.isOver) throw const EightsRuleError('the game is over');
    if (seat != t.turn) throw const EightsRuleError('not your turn');
    if (!t.drawn && !timedOut) {
      throw const EightsRuleError('draw a card first');
    }
    return game.copyWith(
      table: t.copyWith(
        turn: t.nextSeat(seat),
        drawn: false,
        seq: t.seq + 1,
        last: EightsAction(
          seat: seat,
          kind: timedOut ? EightsActionKind.timeout : EightsActionKind.pass,
        ),
      ),
    );
  }

  /// [seat]'s time ran out: they draw (if they hadn't) and the turn passes.
  EightsGame timeOut(EightsGame game, int seat, {Random? random}) {
    var g = game;
    if (!g.table.drawn) g = draw(g, seat, random: random);
    if (g.table.turn != seat) return g;
    return pass(g, seat, timedOut: true);
  }

  /// [seat] leaves: their cards go back under the draw pile, and with one
  /// player left they win.
  EightsGame leave(EightsGame game, int seat, {Random? random}) {
    final t = game.table;
    if (t.left.contains(seat)) return game;
    final left = [...t.left, seat];
    final pile = [...game.hands[seat], ...game.drawPile];
    final remaining = [
      for (var s = 0; s < t.seats; s++)
        if (!left.contains(s)) s,
    ];
    return game.copyWith(
      hands: [...game.hands]..[seat] = const [],
      drawPile: pile,
      table: t.copyWith(
        counts: [...t.counts]..[seat] = 0,
        drawCount: pile.length,
        left: left,
        turn: t.turn == seat ? t.copyWith(left: left).nextSeat(seat) : t.turn,
        drawn: t.turn == seat ? false : t.drawn,
        seq: t.seq + 1,
        last: EightsAction(seat: seat, kind: EightsActionKind.left),
        winner: remaining.length == 1 ? remaining.single : null,
      ),
    );
  }
}

/// The suit [hand] holds most of (not counting eights): what a player
/// names with an eight.
CardSuit favoriteSuit(List<PlayingCard> hand, {CardSuit? fallback}) {
  final counts = {for (final s in CardSuit.values) s: 0};
  for (final c in hand) {
    if (!c.isEight) counts[c.suit] = counts[c.suit]! + 1;
  }
  final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
  return best.value == 0 ? (fallback ?? CardSuit.hearts) : best.key;
}

/// A computer player's move: the card to play (and the suit an eight
/// names), or null to draw (or, having drawn, to pass). It keeps its
/// eights for when nothing else goes, plays from the suit it has most of,
/// and gets rid of high cards first.
(PlayingCard, CardSuit?)? chooseEightsPlay(
  List<PlayingCard> hand,
  EightsTable table, {
  Random? random,
}) {
  final playable = [
    for (final c in hand)
      if (table.canPlay(c)) c,
  ];
  if (playable.isEmpty) return null;
  final plain = [
    for (final c in playable)
      if (!c.isEight) c,
  ];
  if (plain.isEmpty) {
    final eight = playable.first;
    final rest = [...hand]..remove(eight);
    return (eight, favoriteSuit(rest, fallback: table.suit));
  }
  final suitCounts = {for (final s in CardSuit.values) s: 0};
  for (final c in hand) {
    suitCounts[c.suit] = suitCounts[c.suit]! + 1;
  }
  plain.sort((a, b) {
    // Changing to a suit we hold lots of keeps our options open.
    final bySuit = suitCounts[b.suit]!.compareTo(suitCounts[a.suit]!);
    if (bySuit != 0) return bySuit;
    return b.rank.compareTo(a.rank);
  });
  // Now and then a less careful pick, so bots don't all play alike.
  final pick = (random != null && plain.length > 1 && random.nextInt(5) == 0)
      ? plain[1]
      : plain.first;
  return (pick, null);
}
