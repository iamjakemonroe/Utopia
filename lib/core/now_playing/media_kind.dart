import '../widgets/coin_buddy.dart';

/// What the player has on, as best Chip can tell.
enum MediaKind { music, video, podcast, sermon, audiobook, radio, unknown }

/// Everything the phone told us about what's playing, as clues.
class MediaClues {
  const MediaClues({
    this.kind,
    this.package,
    this.source,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.genre = '',
    this.show,
    this.mediaId = '',
    this.durationMs,
  });

  /// The phone's own label ('music', 'podcast', 'audiobook', 'video'),
  /// when it gives one (iPhone does for Apple Music).
  final String? kind;

  /// The Android app playing it.
  final String? package;
  final String? source;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final String? show;
  final String mediaId;
  final int? durationMs;
}

const _videoApps = [
  'com.google.android.youtube',
  'com.google.android.apps.youtube.kids',
  'com.netflix',
  'tv.twitch',
  'com.zhiliaoapp.musically',
  'com.ss.android.ugc',
  'com.instagram',
  'com.facebook',
  'com.mxtech',
  'org.videolan',
  'com.amazon.avod',
  'com.disney',
  'com.hbo',
  'com.showmax',
];

const _podcastApps = [
  'au.com.shiftyjelly.pocketcasts',
  'com.google.android.apps.podcasts',
  'fm.castbox',
  'com.bambuna.podcastaddict',
  'fm.player',
  'com.spreaker',
  'com.podbean',
];

const _audiobookApps = ['com.audible', 'com.storytel', 'com.scribd'];

const _radioApps = ['tunein', 'radiotime', 'com.audials', 'com.streema'];

const _musicApps = [
  'com.spotify',
  'com.apple.android.music',
  'com.google.android.apps.youtube.music',
  'com.boomplaymusic',
  'com.audiomack',
  'deezer',
  'com.deezer',
  'com.aspiro.tidal',
  'com.soundcloud',
  'com.amazon.mp3',
];

bool _from(String? package, List<String> apps) =>
    package != null && apps.any(package.startsWith);

// Words that mark a sermon or a message from the pulpit. Matched on whole
// words, so "Rev." matches but "Revolution" doesn't.
final _sermonWords = RegExp(
  r'\b(sermon|homily|khutbah|pastor|bishop|apostle|reverend|rev\.|evangelist|'
  r'ministries|preach(?:ing|er)?|devotional|bible study|sunday service|'
  r'church service)\b',
  caseSensitive: false,
);

// Episode numbers and the like: "Ep. 12", "Episode 4", "#231".
final _episodeWords = RegExp(
  r'\b(ep\.?\s*\d+|episode\s*\d+|podcast)\b|#\d{2,}',
  caseSensitive: false,
);

final _chapterWords = RegExp(
  r'\b(chapter\s*\d+|audiobook|unabridged)\b',
  caseSensitive: false,
);

// A music video on a video app: "(Official Video)", "Lyrics", "Audio"...
final _musicVideoWords = RegExp(
  r'official (music )?video|official audio|lyric|visualizer|\(audio\)|'
  r'ft\.|feat\.|remix',
  caseSensitive: false,
);

/// Works out what's playing from the clues. Errs toward [MediaKind.unknown]
/// rather than calling something music that isn't.
MediaKind classifyMedia(MediaClues c) {
  final text = [c.title, c.artist, c.album, c.show ?? ''].join(' · ');
  final genre = c.genre.toLowerCase();
  final long = (c.durationMs ?? 0) > 12 * 60 * 1000;
  final kind = c.kind;

  // A sermon can come through any app. Worship songs by a pastor are still
  // songs, so a "pastor" alone only counts when it isn't labelled music
  // and runs long, the way a sermon does.
  final sermonTitle = RegExp(
    r'\b(sermon|homily|khutbah)\b',
    caseSensitive: false,
  ).hasMatch(text);
  if (sermonTitle) return MediaKind.sermon;
  if (_sermonWords.hasMatch(text) &&
      kind != 'music' &&
      (long || kind != null)) {
    return MediaKind.sermon;
  }

  switch (kind) {
    case 'podcast':
      return genre.contains('religion') || genre.contains('spirituality')
          ? MediaKind.sermon
          : MediaKind.podcast;
    case 'audiobook':
      return MediaKind.audiobook;
    case 'video':
      return _musicVideoWords.hasMatch(text)
          ? MediaKind.music
          : MediaKind.video;
    case 'music':
      return MediaKind.music;
  }

  final package = c.package;
  final id = c.mediaId.toLowerCase();
  if (_from(package, _audiobookApps) || _chapterWords.hasMatch(text)) {
    return MediaKind.audiobook;
  }
  if (_from(package, _podcastApps) ||
      id.contains(':episode:') ||
      id.contains('/episode/') ||
      genre.contains('podcast')) {
    return _sermonWords.hasMatch(text) ? MediaKind.sermon : MediaKind.podcast;
  }
  if (_from(package, _radioApps) || genre.contains('radio')) {
    return MediaKind.radio;
  }
  if (_from(package, _videoApps)) {
    if (_musicVideoWords.hasMatch(text)) return MediaKind.music;
    if (_sermonWords.hasMatch(text)) return MediaKind.sermon;
    return MediaKind.video;
  }
  if (genre.contains('audiobook') || genre.contains('spoken')) {
    return MediaKind.audiobook;
  }
  if (genre.contains('talk') || genre.contains('news')) {
    return MediaKind.podcast;
  }
  if (_from(package, _musicApps)) {
    // Spotify and friends carry podcasts too: a long track with an
    // episode-ish title is one.
    if (long && _episodeWords.hasMatch(text)) return MediaKind.podcast;
    return MediaKind.music;
  }
  if (_episodeWords.hasMatch(text)) return MediaKind.podcast;
  if (c.title.isNotEmpty && c.artist.isNotEmpty) return MediaKind.music;
  return MediaKind.unknown;
}

/// What Chip says and how he looks about what's playing.
class ChipMediaLine {
  const ChipMediaLine({
    required this.headline,
    required this.detail,
    required this.mood,
    this.flavor = ChipFlavor.none,
    this.comment,
  });

  /// The short line on top of the bubble.
  final String headline;

  /// The line under it: usually what's playing and who made it.
  final String detail;
  final BuddyMood mood;

  /// How Chip vibes with it: bouncing to a hype track, glasses on for a
  /// lesson.
  final ChipFlavor flavor;

  /// One more thing Chip has to say about it, when his brain had a thought.
  final String? comment;
}

final _flavorWords = <ChipFlavor, RegExp>{
  ChipFlavor.worship: RegExp(
    r'\b(worship|praise|gospel|hymn|hallelujah|jesus|holy|amen)\b',
    caseSensitive: false,
  ),
  ChipFlavor.chill: RegExp(
    r'\b(lo-?fi|chill|sleep|relax|ambient|acoustic|calm|rain sounds)\b',
    caseSensitive: false,
  ),
  ChipFlavor.romantic: RegExp(
    r'\b(love|baby|heart|kiss|darling|forever|romance)\b',
    caseSensitive: false,
  ),
  ChipFlavor.sad: RegExp(
    r'\b(sad|cry|crying|tears|broken|alone|goodbye|miss you|lonely)\b',
    caseSensitive: false,
  ),
  ChipFlavor.dance: RegExp(
    r'\b(remix|party|dance|club|amapiano|afrobeats?|edm|house|disco)\b',
    caseSensitive: false,
  ),
  ChipFlavor.hype: RegExp(
    r'\b(hype|workout|gym|trap|drill|rap|anthem|turn up)\b',
    caseSensitive: false,
  ),
};

final _videoFlavorWords = <ChipFlavor, RegExp>{
  ChipFlavor.study: RegExp(
    r'\b(lesson|lecture|tutorial|explained|how to|course|class|study|learn|'
    r'exam|revision|math|physics|chemistry|biology|history|coding|'
    r'documentary|crash course|khan academy|news)\b',
    caseSensitive: false,
  ),
  ChipFlavor.gaming: RegExp(
    r'\b(gameplay|gaming|minecraft|fortnite|roblox|fifa|ea fc|gta|cod|'
    r'walkthrough|speedrun|let.?s play)\b',
    caseSensitive: false,
  ),
  ChipFlavor.sports: RegExp(
    r'\b(highlights|goals?|vs\.?|match|nba|premier league|ufc|boxing)\b',
    caseSensitive: false,
  ),
  ChipFlavor.funny: RegExp(
    r'\b(funny|comedy|prank|meme|try not to laugh|skit|bloopers)\b',
    caseSensitive: false,
  ),
};

/// A quick guess at the feel of something from its words, for when Chip's
/// brain hasn't weighed in (offline, or not switched on).
ChipFlavor guessFlavor(MediaKind kind, MediaClues c) {
  final text = [c.title, c.artist, c.album, c.genre, c.show ?? ''].join(' ');
  final table = switch (kind) {
    MediaKind.music || MediaKind.radio => _flavorWords,
    MediaKind.video => _videoFlavorWords,
    MediaKind.sermon => {ChipFlavor.worship: RegExp('.')},
    _ => const <ChipFlavor, RegExp>{},
  };
  for (final entry in table.entries) {
    if (entry.value.hasMatch(text)) return entry.key;
  }
  return ChipFlavor.none;
}

/// Chip's take on what's playing. [seed] picks among a few phrasings and
/// should stay the same for a track (its id), so the words don't change
/// every time the phone is asked again.
ChipMediaLine chipMediaLine({
  required MediaKind kind,
  required String? title,
  required String artist,
  String? source,
  String? show,
  required int seed,
  ChipFlavor flavor = ChipFlavor.none,
}) {
  String pick(List<String> options) => options[seed.abs() % options.length];
  final by = artist.isNotEmpty ? artist : (show ?? source ?? '');
  String detailOr(String fallback) {
    if (title == null || title.isEmpty) return fallback;
    return by.isEmpty ? title : '$title · $by';
  }

  switch (kind) {
    case MediaKind.music:
      return ChipMediaLine(
        headline: pick(switch (flavor) {
          ChipFlavor.hype => [
            'This beat goes hard',
            'Turn it up!',
            'Okay, this one hits',
          ],
          ChipFlavor.dance => [
            "I can't stop dancing",
            'Party mode: on',
            'My feet are moving',
          ],
          ChipFlavor.chill => [
            'Ahh, so smooth',
            'Perfect chill vibes',
            'Nice and easy',
          ],
          ChipFlavor.romantic => [
            'Aww, a love song',
            'This one is sweet',
            'So much heart',
          ],
          ChipFlavor.sad => [
            'Oof, right in the feels',
            'A sad one, huh',
            "I'm here with you",
          ],
          ChipFlavor.worship => [
            'Such a peaceful song',
            'This lifts me up',
            'Beautiful praise',
          ],
          _ => [
            'Ooh, good taste',
            "Now that's a tune",
            "This one's a vibe",
            if (artist.isNotEmpty) 'Is that $artist?',
          ],
        }),
        detail: detailOr("Something good. I'm vibing along."),
        mood: BuddyMood.vibing,
        flavor: flavor,
      );
    case MediaKind.video:
      final where = source == null ? '' : ' on $source';
      return ChipMediaLine(
        headline: pick(switch (flavor) {
          ChipFlavor.study => [
            "Study time? I'm in",
            'Ooh, learning stuff',
            "Glasses on. Let's learn",
          ],
          ChipFlavor.funny => [
            "Haha, this one's funny",
            "I can't stop laughing",
            'Okay that got me',
          ],
          ChipFlavor.gaming => [
            'Gaming videos are my thing',
            "Who's winning?",
            'Ooh, nice play',
          ],
          ChipFlavor.sports => [
            'What a match!',
            'Did you see that?',
            'Go go go!',
          ],
          _ => [
            'What are we watching?',
            'Ooh, a video!',
            'Watching something$where?',
            'Is it a good one?',
          ],
        }),
        detail: detailOr("Don't mind me, I'm watching too."),
        mood: BuddyMood.watching,
        flavor: flavor,
      );
    case MediaKind.podcast:
      return ChipMediaLine(
        headline: pick([
          'Learning something new?',
          'A podcast? Smart.',
          "Ooh, what's this one about?",
          'A good listen, I bet',
        ]),
        detail: detailOr("I'm all ears."),
        mood: BuddyMood.listening,
      );
    case MediaKind.sermon:
      return ChipMediaLine(
        headline: pick([
          'A good word today',
          'Taking in a sermon',
          'Some peace for the soul',
        ]),
        detail: detailOr("I'm listening quietly."),
        mood: BuddyMood.listening,
      );
    case MediaKind.audiobook:
      return ChipMediaLine(
        headline: pick([
          'Story time!',
          'Which chapter are we on?',
          'A good book, nice',
        ]),
        detail: detailOr("Don't tell me how it ends."),
        mood: BuddyMood.listening,
      );
    case MediaKind.radio:
      return ChipMediaLine(
        headline: pick(['Tuned in to the radio', 'Radio on, nice']),
        detail: detailOr(source ?? 'Live and on air.'),
        mood: BuddyMood.vibing,
      );
    case MediaKind.unknown:
      // He can hear it but can't see it: he wants to know.
      return ChipMediaLine(
        headline: pick([
          'Ooh, what is this?',
          'What are we listening to?',
          'I hear something good',
        ]),
        detail: detailOr("Tap me and tell me what's on."),
        mood: BuddyMood.listening,
      );
  }
}
