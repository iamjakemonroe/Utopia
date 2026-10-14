import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/config/env.dart';
import '../../../core/chip/chip_brain.dart';
import '../../../core/now_playing/now_playing.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/world_sets.dart';
import '../../auras/domain/aura.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../coins/presentation/providers/coin_balance_provider.dart';
import '../../store/domain/store_catalog.dart';
import '../../store/presentation/store_controller.dart';
import '../../welcome/data/welcome_repository.dart';
import '../../home/domain/greeting.dart';

class ChipChatState {
  const ChipChatState({this.lines = const [], this.thinking = false});

  final List<ChipLine> lines;

  /// Waiting on Chip's answer.
  final bool thinking;

  /// The face Chip is making: thinking while he answers, then whatever his
  /// last answer called for.
  BuddyMood get mood {
    if (thinking) return BuddyMood.thinking;
    final last = lines.lastWhere(
      (l) => l.fromChip,
      orElse: () => const ChipLine(fromChip: true, text: '', mood: 'happy'),
    );
    return BuddyMood.values.where((m) => m.name == last.mood).firstOrNull ??
        BuddyMood.happy;
  }
}

/// The conversation with Chip, kept on the phone (per player) so he
/// remembers it next time, until the player starts a new chat.
class ChipChatController extends StateNotifier<ChipChatState> {
  ChipChatController(this._ref, this._prefs, this._player)
    : super(_restore(_prefs, _player));

  final Ref _ref;
  final SharedPreferences? _prefs;
  final String? _player;

  static const _maxLines = 40;

  static String _key(String player) => 'chip_chat_$player';

  static ChipChatState _restore(SharedPreferences? prefs, String? player) {
    if (prefs == null || player == null) return const ChipChatState();
    try {
      final raw = prefs.getString(_key(player));
      if (raw == null) return const ChipChatState();
      final list = jsonDecode(raw);
      if (list is! List) return const ChipChatState();
      return ChipChatState(
        lines: [for (final l in list) ?ChipLine.fromStore(l)],
      );
    } catch (_) {
      return const ChipChatState();
    }
  }

  void _keep() {
    final prefs = _prefs, player = _player;
    if (prefs == null || player == null) return;
    unawaited(
      prefs.setString(
        _key(player),
        jsonEncode([for (final l in state.lines) l.toStore()]),
      ),
    );
  }

  /// Starts over: Chip forgets this chat.
  void clear() {
    if (state.thinking) return;
    state = const ChipChatState();
    final prefs = _prefs, player = _player;
    if (prefs != null && player != null) unawaited(prefs.remove(_key(player)));
  }

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.thinking) return;
    final history = state.lines;
    final context = _context(history);
    state = ChipChatState(
      lines: [
        ...history,
        ChipLine(fromChip: false, text: message, at: DateTime.now()),
      ],
      thinking: true,
    );
    final reply = await _ref
        .read(chipBrainProvider)
        .chat(message, history: history, context: context);
    if (!mounted) return;
    final lines = [...state.lines, reply];
    state = ChipChatState(
      lines: lines.length > _maxLines
          ? lines.sublist(lines.length - _maxLines)
          : lines,
    );
    _keep();
    _ref.read(gameAudioProvider).play(Sfx.chat);
  }

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// "Monday 12 October 2026, 3:40 pm" on the phone's clock.
  static String _now() {
    final n = DateTime.now();
    final hour = n.hour % 12 == 0 ? 12 : n.hour % 12;
    final minute = n.minute.toString().padLeft(2, '0');
    return '${_days[n.weekday - 1]} ${n.day} ${_months[n.month - 1]} '
        '${n.year}, $hour:$minute ${n.hour < 12 ? 'am' : 'pm'}';
  }

  /// "about 3 hours" since [then], or null if it's been under 20 minutes.
  static String? _away(DateTime? then) {
    if (then == null) return null;
    final gap = DateTime.now().difference(then);
    if (gap < const Duration(minutes: 20)) return null;
    if (gap < const Duration(hours: 1)) return 'about ${gap.inMinutes} minutes';
    if (gap < const Duration(days: 1)) {
      final h = gap.inHours;
      return 'about $h hour${h == 1 ? '' : 's'}';
    }
    final d = gap.inDays;
    return 'about $d day${d == 1 ? '' : 's'}';
  }

  /// What Chip should know right now: who he's talking to, when and where
  /// they are, how long they've been away, their world, aura, set, coins,
  /// worlds and welcome week, whether they can color, and what's playing.
  /// What the coin shop sells, in their own currency, while real-money
  /// top-ups are on and the store answered (null otherwise).
  String? _topUps() {
    if (!Env.realMoneyStore) return null;
    final store = _ref.read(storeControllerProvider);
    final smallest = StoreCatalog.coinPacks.first;
    final price = store.products[smallest.id]?.price;
    if (price == null) return null;
    final starter = store.starterOffer
        ? store.products[StoreCatalog.starterPack.id]?.price
        : null;
    return 'on sale in the coin shop, from $price for '
        '${formatCoins(smallest.coins)} coins'
        '${starter == null ? '' : '; their one-time starter pack is ${formatCoins(StoreCatalog.starterPack.coins)} coins for $starter'}';
  }

  Map<String, String> _context(List<ChipLine> history) {
    final out = <String, String>{'now': _now()};
    final last = history.lastWhere(
      (l) => l.at != null,
      orElse: () => const ChipLine(fromChip: false, text: ''),
    );
    final away = _away(last.at);
    if (away != null) out['away'] = away;
    final week = _ref.read(welcomeWeekProvider);
    final welcomeOn = week != null && !week.over;
    if (week != null) {
      final left = week.until.difference(DateTime.now()).inDays + 1;
      out['welcome'] = welcomeOn
          ? 'every world and the Angel Halo are free, $left day${left == 1 ? '' : 's'} left'
          : 'over';
    }
    final store = _ref.read(storeControllerProvider);
    final owned = <String>[];
    final rented = <String>[];
    for (final item in StoreCatalog.themes) {
      if (item.free) continue;
      final name = UtopiaThemes.byId(item.id).name;
      if (store.isOwnedForever(item)) {
        owned.add(name);
      } else if (!welcomeOn) {
        final until = store.rentedUntil(item.id);
        if (until != null && until.isAfter(DateTime.now())) {
          final days = until.difference(DateTime.now()).inDays + 1;
          rented.add('$name ($days day${days == 1 ? '' : 's'} left)');
        }
      }
    }
    out['worlds'] = [
      if (welcomeOn) 'all of them through the welcome week',
      if (owned.isNotEmpty) 'own ${owned.take(6).join(', ')}',
      if (rented.isNotEmpty) 'renting ${rented.take(6).join(', ')}',
      if (!welcomeOn && owned.isEmpty && rented.isEmpty) 'only the free ones',
    ].join('; ');
    final doodleItem = StoreCatalog.themes
        .where((i) => i.id == UtopiaThemes.utopiaDoodle.id)
        .firstOrNull;
    final inDoodle = UtopiaThemes.active.world.biome == WorldBiome.doodle;
    out['sketchbook'] = inDoodle
        ? "they're in the Doodle world, so they can draw and color right now"
        : doodleItem != null && store.isOwned(doodleItem)
        ? "it's in the Doodle world, which they have; Color it takes them there"
        : "it's in the Doodle world, which they don't have yet (rent or unlock it in the store)";
    final sets = [
      if (WorldSets.dragon.on.value)
        'Dragon Coil in the Dojo (the dragon flies free, you wear a headband)',
      if (WorldSets.zombie.on.value)
        'Zombie Bite in the Zombie world (you got bitten)',
      if (WorldSets.heaven.on.value)
        'Angel Halo in Heaven (you have a halo and wings)',
      if (WorldSets.hell.on.value)
        'Inferno in Hell (you have horns and a tail)',
    ];
    if (sets.isNotEmpty) out['set'] = sets.first;
    final me = _ref.read(currentUserProvider)?.id;
    if (me != null) {
      final profile = _ref.read(profileByIdProvider(me)).valueOrNull;
      final name = greetingName(profile);
      if (name != null) out['name'] = name;
      final aura = Aura.byId(activeAura(profile));
      if (aura != null) out['aura'] = aura.name;
    }
    final coins = _ref.read(coinBalanceProvider).valueOrNull;
    if (coins != null) out['coins'] = '$coins';
    if (_ref.read(isAnonymousProvider)) out['guest'] = 'yes';
    final topUps = _topUps();
    if (topUps != null) out['topups'] = topUps;
    final path = currentPath(_ref.read(goRouterProvider));
    out['screen'] = _screenName(path);
    out['world'] = UtopiaThemes.active.name;
    final music = _ref.read(nowPlayingProvider);
    final track = music.track;
    if (track != null && track.playing) {
      final by = track.artist.isEmpty ? '' : ' by ${track.artist}';
      out['playing'] = '${track.title}$by (${track.kind.name})';
    } else if (music.otherAudio) {
      // He can hear it but the phone won't say what: they may tell him.
      out['playing'] =
          "something you can hear but can't see the name of (ask what it is, or take their word for it)";
    }
    return out;
  }

  static String _screenName(String path) {
    if (path.startsWith('/store?tab=auras')) return 'auras';
    if (path.startsWith('/store')) return 'store';
    if (path.startsWith('/sketchbook')) return 'Sketchbook';
    if (path.startsWith('/guess-my-doodle') ||
        path.startsWith('/doodle-game')) {
      return 'Guess My Doodle';
    }
    if (path.startsWith('/report-bug')) return 'report a bug';
    if (path.startsWith('/chess')) return 'chess';
    if (path.startsWith('/checkers')) return 'checkers';
    if (path.startsWith('/ludo')) return 'Ludo';
    if (path.startsWith('/profile')) return 'profile';
    if (path.startsWith('/settings')) return 'settings';
    if (path.startsWith('/notifications')) return 'notifications';
    if (path.startsWith('/how-to-play')) return 'how to play';
    return 'home';
  }
}

final chipChatProvider =
    StateNotifierProvider<ChipChatController, ChipChatState>((ref) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {
        // Not set up (some tests): the chat just isn't kept.
      }
      return ChipChatController(
        ref,
        prefs,
        ref.watch(currentUserProvider.select((u) => u?.id)),
      );
    });
