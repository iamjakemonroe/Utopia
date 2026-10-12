import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/now_playing/media_kind.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';

const _min = 60 * 1000;

void main() {
  group('classifyMedia', () {
    test('a song in a music app is music', () {
      expect(
        classifyMedia(
          const MediaClues(
            package: 'com.spotify.music',
            title: 'Calm Down',
            artist: 'Rema',
            durationMs: 4 * _min,
          ),
        ),
        MediaKind.music,
      );
    });

    test('a YouTube video is a video, a YouTube music video is music', () {
      expect(
        classifyMedia(
          const MediaClues(
            package: 'com.google.android.youtube',
            title: 'I built a tiny house in 30 days',
            artist: 'Some Channel',
          ),
        ),
        MediaKind.video,
      );
      expect(
        classifyMedia(
          const MediaClues(
            package: 'com.google.android.youtube',
            title: 'Burna Boy - Last Last (Official Music Video)',
            artist: 'Burna Boy',
          ),
        ),
        MediaKind.music,
      );
    });

    test('a long message from a pastor on YouTube is a sermon', () {
      expect(
        classifyMedia(
          const MediaClues(
            package: 'com.google.android.youtube',
            title: 'Walking in Faith | Pastor Jerry Eze',
            artist: 'Streams of Joy',
            durationMs: 55 * _min,
          ),
        ),
        MediaKind.sermon,
      );
    });

    test('a worship song by a pastor is still a song', () {
      expect(
        classifyMedia(
          const MediaClues(
            package: 'com.spotify.music',
            title: 'Imela',
            artist: 'Pastor Nathaniel Bassey',
            durationMs: 6 * _min,
          ),
        ),
        MediaKind.music,
      );
    });

    test('anything titled a sermon is a sermon', () {
      expect(
        classifyMedia(const MediaClues(title: 'Sunday Sermon: Grace')),
        MediaKind.sermon,
      );
    });

    test('podcasts: by app, by episode link, by long episode on Spotify', () {
      expect(
        classifyMedia(
          const MediaClues(
            package: 'au.com.shiftyjelly.pocketcasts',
            title: 'How sleep works',
            artist: 'Science Weekly',
          ),
        ),
        MediaKind.podcast,
      );
      expect(
        classifyMedia(
          const MediaClues(
            package: 'com.spotify.music',
            title: 'The interview',
            artist: 'A Show',
            mediaId: 'spotify:episode:4rOoJ6Egrf8K2IrywzwOMk',
          ),
        ),
        MediaKind.podcast,
      );
      expect(
        classifyMedia(
          const MediaClues(
            package: 'com.spotify.music',
            title: 'Ep. 212: Building things',
            artist: 'A Show',
            durationMs: 70 * _min,
          ),
        ),
        MediaKind.podcast,
      );
    });

    test('the phone saying what it is wins (iPhone Apple Music)', () {
      expect(
        classifyMedia(const MediaClues(kind: 'audiobook', title: 'Dune')),
        MediaKind.audiobook,
      );
      expect(
        classifyMedia(const MediaClues(kind: 'podcast', title: 'News today')),
        MediaKind.podcast,
      );
      expect(
        classifyMedia(
          const MediaClues(kind: 'music', title: 'Holy', artist: 'Pastor X'),
        ),
        MediaKind.music,
      );
    });

    test('stories and radio', () {
      expect(
        classifyMedia(
          const MediaClues(package: 'com.audible.application', title: 'Dune'),
        ),
        MediaKind.audiobook,
      );
      expect(
        classifyMedia(
          const MediaClues(package: 'tunein.player', title: 'Cool FM 96.9'),
        ),
        MediaKind.radio,
      );
    });

    test('with no clues, Chip does not guess', () {
      expect(classifyMedia(const MediaClues()), MediaKind.unknown);
    });
  });

  group('chipMediaLine', () {
    test('music: vibing, with lines that fit the song', () {
      final plain = chipMediaLine(
        kind: MediaKind.music,
        title: 'Calm Down',
        artist: 'Rema',
        seed: 0,
      );
      expect(plain.mood, BuddyMood.vibing);
      expect(plain.headline, isNot(contains("I see you're listening to")));

      final hype = chipMediaLine(
        kind: MediaKind.music,
        title: 'x',
        artist: 'y',
        seed: 0,
        flavor: ChipFlavor.hype,
      );
      expect(hype.flavor, ChipFlavor.hype);
      expect(hype.headline, isNot(plain.headline));
    });

    test('a guess at the vibe from the words', () {
      expect(
        guessFlavor(
          MediaKind.music,
          const MediaClues(title: 'lofi beats to study to'),
        ),
        ChipFlavor.chill,
      );
      expect(
        guessFlavor(
          MediaKind.video,
          const MediaClues(title: 'Organic Chemistry Lecture 4'),
        ),
        ChipFlavor.study,
      );
      expect(
        guessFlavor(
          MediaKind.video,
          const MediaClues(title: 'Minecraft Hardcore Gameplay #12'),
        ),
        ChipFlavor.gaming,
      );
      expect(
        guessFlavor(
          MediaKind.music,
          const MediaClues(title: 'Way Maker (Live Worship)'),
        ),
        ChipFlavor.worship,
      );
    });

    test('moods follow the kind', () {
      ChipMediaLine of(MediaKind k) =>
          chipMediaLine(kind: k, title: 'x', artist: 'y', seed: 1);
      expect(of(MediaKind.video).mood, BuddyMood.watching);
      expect(of(MediaKind.podcast).mood, BuddyMood.listening);
      expect(of(MediaKind.sermon).mood, BuddyMood.listening);
      expect(of(MediaKind.audiobook).mood, BuddyMood.listening);
    });

    test('the same track always gets the same words', () {
      final a = chipMediaLine(
        kind: MediaKind.video,
        title: 'x',
        artist: 'y',
        seed: 'track-1'.hashCode,
      );
      final b = chipMediaLine(
        kind: MediaKind.video,
        title: 'x',
        artist: 'y',
        seed: 'track-1'.hashCode,
      );
      expect(a.headline, b.headline);
    });
  });
}
