<p align="center">
  <img src="https://utopia.kaivon.app/og-image.jpg" alt="Utopia: games with friends, in a world that feels alive" width="100%">
</p>

<h1 align="center">Utopia</h1>

<p align="center">
  <strong>Games with friends, in a world that feels alive.</strong><br>
  A real-time multiplayer games platform for iOS, Android and the web, by <a href="https://kaivon.app">Kaivon</a>.
</p>

<p align="center">
  <a href="https://utopia.kaivon.app/game/"><strong>Play in your browser</strong></a> ·
  <a href="https://utopia.kaivon.app">Website</a> ·
  <a href="https://utopia.kaivon.app/privacy.html">Privacy</a>
</p>

---

## Overview

Utopia brings classic games and a party game into a living, animated world. Players hop between
hand-animated worlds, play real-time matches with friends or against bots, climb ranked ladders,
and collect frames and worlds that change how everything looks and sounds. Chip, Utopia's AI
companion, knows every screen, chats, plays along and draws.

One codebase runs on phones and in the browser, where the same app runs as WebAssembly with its
own audio engine and can be installed as an app.

## Features

| | |
| --- | --- |
| **Real-time games** | Chess, Checkers, Ludo (2 to 6 players), Crazy Eights (the server deals and keeps every hand hidden) and Guess My Doodle, a drawing party game for up to 20. Matchmaking, private rooms with share links, friend challenges, clocks and turn timers. |
| **Rankings** | Elo ratings for online chess, checkers and Guess My Doodle; tiers from Bronze to Legend; the top 100 on every board; each player's stats shown as a hologram in their tier's aura. |
| **Bots and house players** | Chess and checkers engines (negamax with alpha-beta) at three levels; Ludo and card tables filled with bots; house players when no one is free, always labelled and never on prize boards. |
| **Living worlds** | 17 worlds drawn entirely in code, from a neon city and the deep sea to a snowy winter lake, plus 36 colour themes. Each world has its own music and sound, in step with what's on screen. |
| **Events and collecting** | Seasonal events whose worlds and frames are earned by playing, birthday worlds and parties, weekly quests, and animated frames from common to Mythic that complete sets with their worlds. |
| **Chip** | An AI companion backed by Anthropic's Claude through a Supabase Edge Function: he chats, takes players anywhere in the app, reacts to their music, and draws colouring pages, portraits and doodles to guess. |
| **Social** | Friends with live presence, chat with stickers and voice notes, notifications, coin gifts protected by a gift PIN, friends' birthdays, and in-app reports that get answered. |
| **Economy** | Coins from games, a daily reward and quests; worlds, frames and piece sets to rent or buy; optional coin packs and Chip Maestro through the App Store, Google Play and, on the web, Flutterwave, priced in the buyer's own currency. Every purchase ends in a clear result and a notification. |

## Fair play by design

Anything that decides an outcome (moves, clocks, scoring, ratings, coin transfers and rewards)
runs in Postgres functions behind row-level security. A client can't change its own state to win:
it asks, and the database decides. Realtime carries moves, chat and drawing strokes, the database
stays the source of truth, and clients resync on reconnect.

## Tech stack

| Layer | Tools |
| --- | --- |
| App | Flutter 3.44, Dart 3.12, Riverpod, go_router, CustomPainter animation, gen-l10n |
| Backend | Supabase: Postgres, row-level security, security-definer functions, Realtime, pg_cron, Storage |
| Server code | Supabase Edge Functions (Deno, TypeScript) |
| AI | Anthropic Claude API: chat, structured output, web search |
| Web | WebAssembly (skwasm) and JavaScript builds, Web Workers, Web Audio, Cloudflare hosting |
| Native | Kotlin (Android media session), Swift (iOS) |
| Payments | App Store and Google Play purchases; Flutterwave on the web |
| Quality | Unit, widget and golden tests; a pixel-exact render check; Postgres tests that play every migration as real players; a browser frame-time harness; GitHub Actions CI |

## Architecture

```
lib/
  core/        Shared services and UI: worlds and themes, audio, routing,
               profiles, notifications, the Chip mascot and widgets
  features/    One folder per feature, each split into data / domain /
               presentation (chess, checkers, ludo, eights, guess_doodle,
               rankings, events, coins, store, auras, friends, chip, ...)
  l10n/        Every word the app shows (app_en.arb)
supabase/
  migrations/  Schema, row-level security and game rules in SQL
  functions/   Edge Functions (Chip, purchases, house players, accounts)
test/          Unit, widget and golden tests
tool/          Database tests, sound synthesis, the web build and
               performance tools
```

## Running it locally

1. Install Flutter 3.44 or later and the Supabase CLI.
2. Create `env/local.json` with your own Supabase project's public settings:

   ```json
   {
     "SUPABASE_URL": "https://<project>.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "<publishable key>"
   }
   ```

3. Apply the schema with `supabase db push`, then run the app:

   ```sh
   flutter pub get
   flutter run --dart-define-from-file=env/local.json
   ```

Chip needs an Anthropic API key stored as a Supabase secret. Without one, everything else works
and Chip says he's still waking up.

## Tests

```sh
flutter analyze
flutter test                                                  # unit and widget tests
python3 tool/db_test/run_all.py                               # every migration, played as real players
flutter test --run-skipped test/tool/split_check_test.dart    # pixel-exact render check
```

## License

Copyright © 2026 Emmanuel Jake Okeowo. All rights reserved. The code is published to be read; it
may not be copied, reused or redistributed. See [LICENSE](LICENSE).

## Credits

Sound effects are built from public-domain (CC0) recordings listed in
`tool/sfx_sources/README.md`. Inter and Space Grotesk are under the SIL Open Font License
(`assets/google_fonts`).

---

<p align="center">Made by <a href="https://kaivon.app">Kaivon</a> · <a href="mailto:emmanueljakeokeowo@gmail.com">Contact</a></p>
