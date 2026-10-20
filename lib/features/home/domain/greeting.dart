import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/coin_buddy.dart';
import '../../../l10n/strings.dart';

/// The line at the top of home: picked for the time of day (or, on the
/// player's birthday, all about that), with a little variety so it isn't
/// the same every visit.
class Greeting {
  const Greeting({
    required this.title,
    required this.line,
    required this.mood,
    required this.icon,
  });

  final String title;
  final String line;
  final BuddyMood mood;
  final IconData icon;
}

typedef _Pool = ({
  List<String> titles,
  List<String> lines,
  BuddyMood mood,
  IconData icon,
});

// {name} is replaced with the player's name, or dropped with its comma.
final _earlyMorning = (
  titles: ['Good morning, {name}', 'Rise and shine, {name}', 'Morning, {name}'],
  lines: [
    'The islands are just waking up.',
    strings.greetingFreshSkiesFreshGames,
    strings.greetingCoffeeAndAQuickGame,
    strings.greetingTheEarlyBirdGetsThe,
  ],
  mood: BuddyMood.happy,
  icon: Icons.wb_twilight_rounded,
);

final _morning = (
  titles: ['Good morning, {name}', 'Morning, {name}', 'Hey {name}'],
  lines: [
    'The world is bright and busy today.',
    strings.greetingPerfectWeatherForAWin,
    strings.greetingTheBoardIsSetYour,
  ],
  mood: BuddyMood.happy,
  icon: Icons.wb_sunny_rounded,
);

final _afternoon = (
  titles: ['Good afternoon, {name}', 'Hey {name}', 'Welcome back, {name}'],
  lines: [
    'Take a break. The board is waiting.',
    strings.greetingTheSunIsHighOver,
    strings.greetingTimeForAQuickRound,
    strings.greetingAGoodAfternoonForA,
  ],
  mood: BuddyMood.excited,
  icon: Icons.light_mode_rounded,
);

final _evening = (
  titles: ['Good evening, {name}', 'Evening, {name}', 'Welcome back, {name}'],
  lines: [
    'Lanterns are lighting up across the islands.',
    strings.greetingWindDownWithAGame,
    strings.greetingTheSunsetLooksGreatFrom,
  ],
  mood: BuddyMood.happy,
  icon: Icons.wb_twilight_rounded,
);

final _night = (
  titles: ['Hello, night owl', 'Still up, {name}?', 'Good evening, {name}'],
  lines: [
    'The stars are out over Utopia.',
    strings.greetingOneMoreGameBeforeBed,
    strings.greetingQuietNightLoudDice,
  ],
  mood: BuddyMood.idle,
  icon: Icons.nightlight_round,
);

final _lateNight = (
  titles: [
    'Burning the midnight oil?',
    'Still awake, {name}?',
    strings.greetingHelloNightOwl,
  ],
  lines: [
    'Utopia never sleeps. Apparently neither do you.',
    strings.greetingTheMoonIsKeepingScore,
    strings.greetingJustOneMoreGameProbably,
  ],
  mood: BuddyMood.thinking,
  icon: Icons.nightlight_round,
);

// All day on the player's birthday, whatever the time.
final _birthday = (
  titles: [
    'Happy birthday, {name}!',
    "It's your day, {name}!",
    'Party time, {name}!',
  ],
  lines: [
    'The whole sky is partying for you today.',
    strings.greetingMakeAWishMineIs,
    strings.greetingCakeFirstThenGamesBirthday,
    strings.greetingEveryFireworkOutThereIs,
    strings.greetingYourBirthdayWorldIsOpen,
    strings.greetingAnotherTripAroundTheSun,
    strings.greetingIPutMyPartyHat,
  ],
  mood: BuddyMood.excited,
  icon: Icons.cake_rounded,
);

_Pool _poolFor(int hour) {
  if (hour >= 5 && hour < 9) return _earlyMorning;
  if (hour >= 9 && hour < 12) return _morning;
  if (hour >= 12 && hour < 17) return _afternoon;
  if (hour >= 17 && hour < 21) return _evening;
  if (hour >= 21) return _night;
  return _lateNight;
}

/// What Chip calls the player: their nickname if they set one, else their
/// username, each word starting with a capital ("mira k" -> "Mira K",
/// "maya42" -> "Maya42"). Null when they have neither.
String? greetingName(Map<String, dynamic>? profile) {
  final nickname = (profile?['display_name'] as String?)?.trim() ?? '';
  final username = (profile?['username'] as String?)?.trim() ?? '';
  final name = nickname.isNotEmpty ? nickname : username;
  if (name.isEmpty) return null;
  return capitalizeWords(name);
}

/// Upper-cases the first letter of each word and leaves the rest as typed.
String capitalizeWords(String text) => text
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// [birthday]: it's the player's birthday, so Chip talks about nothing
/// else.
Greeting pickGreeting(
  DateTime now,
  String? name, [
  math.Random? random,
  bool birthday = false,
]) {
  final rng = random ?? math.Random();
  final pool = birthday ? _birthday : _poolFor(now.hour);
  var title = pool.titles[rng.nextInt(pool.titles.length)];
  if (name == null || name.trim().isEmpty) {
    title = title
        .replaceAll(', {name}', '')
        .replaceAll(' {name}', '')
        .replaceAll('{name}', '');
    if (title == 'Hey') title = strings.greetingHeyThere;
  } else {
    title = title.replaceAll('{name}', capitalizeWords(name.trim()));
  }
  return Greeting(
    title: title,
    line: pool.lines[rng.nextInt(pool.lines.length)],
    mood: pool.mood,
    icon: pool.icon,
  );
}
