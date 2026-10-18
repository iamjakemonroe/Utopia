# Utopia

A multiplayer mini-games platform for iOS and Android, built with Flutter and
Supabase. Players hop between living, animated worlds, play real-time games
with friends or bots, and collect cosmetics that change how the world around
them looks and behaves.

## Highlights

- **Real-time multiplayer games**: Chess, Checkers, Ludo (2 to 6 players) and
  Guess My Doodle, a drawing-and-guessing party game. Online matchmaking,
  private rooms with share codes, friend challenges, turn timers and clocks.
- **Bots for offline play**: chess and checkers engines with three difficulty
  levels, and Ludo tables filled with bots.
- **Living worlds**: 14 hand-animated worlds drawn entirely in code (no image
  assets), from a neon city and the deep sea to a samurai dojo with a
  fire-breathing dragon, plus 36 colour themes.
- **Cosmetics and sets**: animated avatar frames ("auras") from common to
  Mythic. Wearing an aura in its matching world completes a set that
  restyles the world and the Chip mascot.
- **Chip, an AI companion**: a mascot backed by Claude through a Supabase
  Edge Function. He chats about anything, knows every screen in the app,
  offers shortcuts, reacts to the music playing, and draws coloring pages on
  request for a shared picture library.
- **Sketchbook**: a drawing studio with speed-sensitive brushes, pinch zoom,
  undo/redo and tap-to-fill coloring pages, traced into regions on device.
- **Social**: friends, in-game chat with stickers and voice notes,
  notifications, and in-app bug reports with replies.
- **Virtual economy**: coins earned from a streak-based daily reward and
  games with an entry; a store for worlds, rentals, piece sets and auras.

## Tech stack

| Layer | Tools |
| --- | --- |
| App | Flutter 3.44, Dart 3.12, Riverpod, go_router, CustomPainter animation |
| Backend | Supabase: Postgres, Row Level Security, SECURITY DEFINER RPCs, Realtime (postgres changes and broadcast), pg_cron, Storage |
| Server code | Supabase Edge Functions (Deno, TypeScript) |
| AI | Anthropic Claude API (chat, structured output, web search) |
| Native | Kotlin media session listener (Android), Swift app delegate (iOS) |
| Tooling | flutter_test widget and golden tests, migration tests on a throwaway Postgres (tool/db_test), GitHub Actions CI, CoreGraphics icon renderer, Supabase CLI migrations |

## Architecture

```
lib/
  core/        Shared services and UI: theme and worlds, audio, router,
               profiles, notifications, the Chip mascot and widgets
  features/    One folder per feature, each split into data / domain /
               presentation (chess, checkers, ludo, guess_doodle,
               doodle_studio, store, auras, friends, chip, ...)
supabase/
  migrations/  Schema, RLS policies and game logic as SQL
  functions/   Edge Functions (Chip's brain, account deletion)
test/          Unit and widget tests; test/tool renders art preview sheets
tool/          Icon renderer, sound synthesis, database tests (db_test)
               and support scripts
```

Game rules that decide outcomes (moves, timers, scoring, coin transfers) run
in Postgres functions, so clients can't cheat by editing local state.
Realtime channels carry moves, chat and drawing strokes; the database stays
the source of truth, and clients resync on reconnect.

## Getting started

1. Install Flutter 3.44 or later and the Supabase CLI.
2. Create `env/local.json` with your project's settings:

   ```json
   {
     "SUPABASE_URL": "https://<project>.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "<publishable key>"
   }
   ```

3. Apply the database schema: `supabase db push`
4. Run the app:

   ```sh
   flutter pub get
   flutter run --dart-define-from-file=env/local.json
   ```

Chip's AI features need an Anthropic API key stored as a Supabase secret
(`supabase secrets set ANTHROPIC_API_KEY=...`); without it everything else
works and Chip tells players his brain is still waking up.

## Testing

```sh
flutter analyze
flutter test
```

Art preview sheets (worlds, auras, dragons, chess pieces) render on demand:

```sh
flutter test --run-skipped --update-goldens test/tool
```
