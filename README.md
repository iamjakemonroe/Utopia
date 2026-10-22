# Utopia

Games with friends, in a world that feels alive. Utopia is a multiplayer
games platform for iOS, Android and the web, built with Flutter and
Supabase. Players hop between living, animated worlds, play real-time games
with friends, and collect things that change how their world looks and
behaves.

Play it in the browser: https://utopia.kaivon.app/game/

## Highlights

- **Real-time multiplayer games**: Chess, Checkers, Ludo (2 to 6 players,
  and play goes on for the places after the winner), Guess My Doodle, a
  drawing-and-guessing party game for up to 20, and Crazy Eights, the first
  card game (2 to 6; the server deals and keeps every hand hidden).
  Matchmaking, private rooms with share links, friend challenges that last
  10 minutes (and can be taken back), clocks and turn timers.
- **Rankings**: Elo ratings for online chess, checkers and Guess My Doodle,
  tiers from Bronze to Legend, the top 100 on every board, and each
  player's stats as a hologram in their tier's aura.
- **Bots and house players**: chess and checkers engines (negamax with
  alpha-beta) at three levels, Ludo and card tables filled with bots, and house
  players when no one's free (always labelled, never on prize boards).
- **Living worlds**: 17 hand-animated worlds drawn entirely in code, from a
  neon city and the deep sea to a haunted Halloween hollow and a snowy
  Winter lake with Santa crossing the moon, plus 36 color themes. Each
  world has its own music and sounds, in step with what's on screen.
- **Events and quests**: seasonal events (Halloween, Winter) whose world and
  frame are earned by playing, a world and party on each player's birthday,
  and weekly quests that pay coins.
- **Frames and sets**: animated frames ("auras") from common to Mythic.
  Wearing one in its matching world completes a set that restyles the world
  and dresses Chip, the mascot.
- **Chip, an AI companion**: backed by Claude through a Supabase Edge
  Function. He chats, knows every screen in the app, takes players
  anywhere, reacts to the music they're playing, and draws: coloring pages,
  portraits, and a shared deck of doodles to guess.
- **Social**: friends with live online status, chat with stickers and voice
  notes, notifications, coin gifts with a note (kept safe by a gift PIN),
  friends' birthdays, and in-app bug reports that get answered.
- **Economy**: coins from games, a daily reward and quests; worlds, frames
  and piece sets to rent or buy; real-money coin packs on phones and the web.
- **Web**: the same app in the browser (WebAssembly where supported), with
  its own audio engine, an install-as-app flow and refresh-on-update.
- **Ready for translation**: every word the app shows is in
  `lib/l10n/app_en.arb`.

## Tech stack

| Layer | Tools |
| --- | --- |
| App | Flutter 3.44, Dart 3.12, Riverpod, go_router, CustomPainter animation, gen-l10n |
| Backend | Supabase: Postgres, Row Level Security, SECURITY DEFINER functions, Realtime, pg_cron, Storage |
| Server code | Supabase Edge Functions (Deno, TypeScript) |
| AI | Anthropic Claude API (chat, structured output, web search) |
| Web | WebAssembly (skwasm) and JavaScript builds, Web Workers, WebAudio, Cloudflare Workers hosting |
| Native | Kotlin media session listener (Android), Swift (iOS) |
| Payments | App Store and Google Play purchases; Flutterwave on the web (on once its keys are set) |
| Tooling | Widget and golden tests, a pixel-exact render check, Postgres migration tests (tool/db_test), browser speed harness (tool/perf), GitHub Actions CI |

## Architecture

```
lib/
  core/        Shared services and UI: theme and worlds, audio, router,
               profiles, notifications, the Chip mascot and widgets
  features/    One folder per feature, each split into data / domain /
               presentation (chess, checkers, ludo, eights, guess_doodle, rankings,
               events, coins, store, auras, friends, chip, ...)
  l10n/        Every word the app shows (app_en.arb) and how it's read
supabase/
  migrations/  Schema, RLS policies and game rules as SQL
  functions/   Edge Functions (Chip, purchases, house players, accounts)
test/          Unit and widget tests; test/tool renders art and screens
tool/          Database tests, sound synthesis, the web build and deploy,
               speed tools and support scripts (tool/sql)
```

Anything that decides an outcome (moves, clocks, scoring, ratings, coin
transfers, rewards) runs in Postgres functions behind row-level security,
so a client can't cheat by editing its own state. Realtime carries moves,
chat and drawing strokes; the database stays the source of truth and
clients resync on reconnect.

## Getting started

1. Install Flutter 3.44 or later and the Supabase CLI.
2. Create `env/local.json` with your project's settings:

   ```json
   {
     "SUPABASE_URL": "https://<project>.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "<publishable key>"
   }
   ```

   Optional: `SENTRY_DSN` turns on crash reports.

3. Apply the database schema: `supabase db push`
4. Run the app:

   ```sh
   flutter pub get
   flutter run --dart-define-from-file=env/local.json
   ```

Chip needs an Anthropic API key stored as a Supabase secret
(`supabase secrets set ANTHROPIC_API_KEY=...`); without it everything else
works and Chip says his brain is still waking up.

## Testing

```sh
flutter analyze
flutter test                                   # unit and widget tests
python3 tool/db_test/run_all.py                # every migration, as real players
flutter test --run-skipped test/tool/split_check_test.dart   # pixel check
```

Art and screen sheets render on demand:
`flutter test --run-skipped --update-goldens test/tool`.

## License

All rights reserved: you're welcome to read the code, but not to copy or
reuse it (see [LICENSE](LICENSE)).

## Credits

Sounds built from public domain (CC0) recordings are listed in
`tool/sfx_sources/README.md`. Inter and Space Grotesk are under the SIL Open
Font License (`assets/google_fonts`).
