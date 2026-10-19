import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/audio/game_audio.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/features/rankings/data/rankings_repository.dart';
import 'package:utopia/features/rankings/domain/rank_insights.dart';
import 'package:utopia/features/rankings/presentation/hologram/hologram_painters.dart';
import 'package:utopia/features/rankings/presentation/hologram/rank_hologram.dart';
import 'package:utopia/features/rankings/presentation/hologram/reveal.dart';

/// Hears what the hologram plays, and when (on the test's clock).
class _Ears extends GameAudio {
  _Ears(this.now) : super(const SoundSettings(musicOn: false, sfxOn: false));

  final DateTime Function() now;
  final heard = <(Sfx, DateTime)>[];
  final looping = <Sfx>[];
  final stopped = <Sfx>[];

  @override
  void play(Sfx sfx, {double volume = 1}) => heard.add((sfx, now()));

  @override
  AmbientLoop startAmbient(Sfx sfx, {double volume = 1}) {
    looping.add(sfx);
    return AmbientLoop(() => stopped.add(sfx));
  }
}

bool _blip(Sfx s) => s.name.startsWith('holoBlip');

RankInsights get _legend => RankInsights.fromJson({
  'game': 'chess',
  'rating': 1800,
  'best': 1824,
  'games': 64,
  'wins': 37,
  'losses': 22,
  'draws': 5,
  'week': 46,
  'month': 131,
  'games_week': 11,
  'biggest_gain': 31,
  'biggest_drop': -24,
  'ranked': 412,
  'top_percent': 1,
  'streak': 4,
  'streak_kind': 'W',
  'best_streak': 7,
  'white': {'games': 33, 'wins': 21},
  'black': {'games': 31, 'wins': 16},
  'avg_moves': 34,
  'fastest_win': 11,
  'avg_opponent': 1760,
  'clock': '10+0',
  'wins_by': {'checkmate': 19, 'resignation': 12, 'timeout': 6},
  'losses_by': {'checkmate': 9, 'timeout': 8, 'resignation': 5},
  'since': '2026-10-02T10:00:00Z',
});

void main() {
  testWidgets('the hologram sounds in step with what it shows', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ears = _Ears(() => tester.binding.clock.now());
    late BuildContext host;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          gameAudioProvider.overrideWithValue(ears),
          rankInsightsProvider.overrideWith((ref, game) async => _legend),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                host = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    final opened = tester.binding.clock.now();
    int ms(DateTime t) => t.difference(opened).inMilliseconds;
    Future<void> frames(int millis) async {
      for (var t = 0; t < millis; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    showRankHologram(
      host,
      game: 'chess',
      rating: 1800,
      place: 3,
      line: [for (var i = 0; i < 20; i++) 1700 + i * 5],
    );
    await frames(2900);

    expect(ears.heard.first.$1, Sfx.holoOn, reason: 'the power-up first');
    expect(ears.looping, [Sfx.holoAmbLegend], reason: "Legend's aura, looping");

    final blips = [
      for (final (s, at) in ears.heard)
        if (_blip(s)) ms(at),
    ];
    expect(
      blips.first,
      inInclusiveRange(440, 520),
      reason: 'the first readout, as the hologram is up',
    );
    for (var k = 1; k < blips.length; k++) {
      expect(
        blips[k] - blips[k - 1],
        inInclusiveRange(70, 120),
        reason: 'one readout after another, a beat apart: $blips',
      );
    }
    final shownAtFirst = blips.length;
    expect(shownAtFirst, lessThan(10), reason: 'only the readouts in view');

    final ticks = [
      for (final (s, at) in ears.heard)
        if (s == Sfx.holoTick) ms(at),
    ];
    expect(ticks.length, greaterThan(15), reason: 'the counters tick');
    expect(
      ticks.last,
      lessThan(blips.last + 1400),
      reason: 'and stop once they have counted',
    );
    expect(
      ticks.first,
      greaterThanOrEqualTo(blips.first),
      reason: 'not before their readout comes up',
    );

    final thunder = [
      for (final (s, at) in ears.heard)
        if (s.name.startsWith('hwThunder')) ms(at),
    ];
    expect(thunder, hasLength(1));
    expect(
      (thunder.first - legendStrikeAt(0) * 1000).abs(),
      lessThan(40),
      reason: 'the boom with the strike',
    );

    // Scrolling down: the next readouts come up as they come into view,
    // each with its blip right then.
    final scrolled = ms(tester.binding.clock.now());
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await frames(700);
    final later = [
      for (final (s, at) in ears.heard)
        if (_blip(s) && ms(at) >= scrolled) ms(at),
    ];
    expect(later, isNotEmpty, reason: 'scrolled-to readouts come up');
    expect(later.first - scrolled, lessThan(200), reason: 'straight away');

    // Closed: quiet, the aura stopped.
    Navigator.of(host).pop();
    await frames(300);
    final closed = ms(tester.binding.clock.now());
    await frames(8000);
    expect(
      [
        for (final (_, at) in ears.heard)
          if (ms(at) > closed) at,
      ],
      isEmpty,
      reason: 'nothing once it has gone',
    );
    expect(ears.stopped, [Sfx.holoAmbLegend]);
  });

  testWidgets('scrolling up and down, every readout in view still comes up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ears = _Ears(() => tester.binding.clock.now());
    late BuildContext host;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          gameAudioProvider.overrideWithValue(ears),
          rankInsightsProvider.overrideWith((ref, game) async => _legend),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                host = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    Future<void> frames(int millis) async {
      for (var t = 0; t < millis; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    showRankHologram(
      host,
      game: 'chess',
      rating: 1800,
      place: 3,
      line: [for (var i = 0; i < 20; i++) 1700 + i * 5],
    );
    await frames(1500);

    // Up and down, again and again, quickly.
    for (var k = 0; k < 16; k++) {
      await tester.drag(
        find.byType(ListView),
        Offset(0, k.isEven ? -700 : 700),
      );
      await frames(64);
    }
    // And flung, coasting on after the finger's gone.
    for (var k = 0; k < 6; k++) {
      await tester.fling(
        find.byType(ListView),
        Offset(0, k.isEven ? -400 : 400),
        2500,
      );
      await frames(k == 5 ? 0 : 120);
    }
    await frames(1500);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await frames(500);

    // Everything on screen has come up.
    final view = tester.getRect(find.byType(ListView));
    for (final card in tester.widgetList(find.byType(RevealOnView))) {
      final rect = tester.getRect(find.byWidget(card));
      final shown = rect.intersect(view);
      if (shown.height < 60) continue;
      final opacity = tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byWidget(card),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(
        opacity,
        1.0,
        reason: 'readout ${(card as RevealOnView).index} in view is up',
      );
    }

    // And none came up (or sounded) twice.
    final blips = [
      for (final (s, _) in ears.heard)
        if (_blip(s)) s,
    ];
    final perCard = <Sfx, int>{};
    for (final b in blips) {
      perCard[b] = (perCard[b] ?? 0) + 1;
    }
    expect(
      blips.length,
      lessThanOrEqualTo(13),
      reason: 'one blip per readout at most: ${blips.length}',
    );

    Navigator.of(host).pop();
    await frames(300);
  });
}
