import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/coin_buddy.dart';

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
const _earlyMorning = (
  titles: ['Good morning, {name}', 'Rise and shine, {name}', 'Morning, {name}'],
  lines: [
    'The islands are just waking up.',
    'Fresh skies, fresh games.',
    'Coffee and a quick game?',
    'The early bird gets the first roll.',
  ],
  mood: BuddyMood.happy,
  icon: Icons.wb_twilight_rounded,
);

const _morning = (
  titles: ['Good morning, {name}', 'Morning, {name}', 'Hey {name}'],
  lines: [
    'The world is bright and busy today.',
    'Perfect weather for a win.',
    'The board is set. Your move.',
  ],
  mood: BuddyMood.happy,
  icon: Icons.wb_sunny_rounded,
);

const _afternoon = (
  titles: ['Good afternoon, {name}', 'Hey {name}', 'Welcome back, {name}'],
  lines: [
    'Take a break. The board is waiting.',
    'The sun is high over Utopia.',
    'Time for a quick round?',
    'A good afternoon for a long game.',
  ],
  mood: BuddyMood.excited,
  icon: Icons.light_mode_rounded,
);

const _evening = (
  titles: ['Good evening, {name}', 'Evening, {name}', 'Welcome back, {name}'],
  lines: [
    'Lanterns are lighting up across the islands.',
    'Wind down with a game or two.',
    'The sunset looks great from here.',
  ],
  mood: BuddyMood.happy,
  icon: Icons.wb_twilight_rounded,
);

const _night = (
  titles: ['Hello, night owl', 'Still up, {name}?', 'Good evening, {name}'],
  lines: [
    'The stars are out over Utopia.',
    'One more game before bed?',
    'Quiet night. Loud dice.',
  ],
  mood: BuddyMood.idle,
  icon: Icons.nightlight_round,
);

const _lateNight = (
  titles: [
    'Burning the midnight oil?',
    'Still awake, {name}?',
    'Hello, night owl',
  ],
  lines: [
    'Utopia never sleeps. Apparently neither do you.',
    'The moon is keeping score tonight.',
    'Just one more game. Probably.',
  ],
  mood: BuddyMood.thinking,
  icon: Icons.nightlight_round,
);

// All day on the player's birthday, whatever the time.
const _birthday = (
  titles: [
    'Happy birthday, {name}!',
    "It's your day, {name}!",
    'Party time, {name}!',
  ],
  lines: [
    'The whole sky is partying for you today.',
    'Make a wish! Mine is that you win today.',
    'Cake first, then games. Birthday rules.',
    'Every firework out there is for you.',
    'Your birthday world is open all day. Enjoy it!',
    "Another trip around the sun. Let's celebrate!",
    'I put my party hat on just for you.',
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
    if (title == 'Hey') title = 'Hey there';
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
