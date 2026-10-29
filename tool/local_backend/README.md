# Trying payments and Chip Rizz locally

Everything below runs on this Mac with **Flutterwave test keys**: no real
money, and nothing is deployed.

There's no Docker on this Mac, so the apps use the **live databases**. The
database changes therefore have to be applied first (step 1). Flutterwave's
webhook can't reach a Mac, so a payment is credited when you come back from
checkout. Renewals and cancellations made from Flutterwave's emails only
arrive once the webhook is deployed.

Paths below are under `~/Desktop/Projects/ProjectX`. `chip-rizz` is the
branch with this work, checked out at `.worktrees/utopia-chip-rizz`.

## 1. The database changes (you run these)

They add tables and functions. One change is visible to players straight
away: Chip Maestro's daily fair use drops to 60 chats, 6 drawings and 40
colorings. Everything else waits for the new screens.

```sh
cd ~/Desktop/Projects/ProjectX/.worktrees/utopia-chip-rizz
supabase db push --linked        # chip_rizz + web_plans (Utopia's project)

cd ~/Desktop/Projects/ProjectX/Wavee
supabase db push --linked        # money (Boost, Artist Pro)
```

## 2. Keys (once)

These scripts save the Supabase keys into git-ignored files without printing
them:

```sh
cd ~/Desktop/Projects/ProjectX/.worktrees/utopia-chip-rizz
node tool/local_backend/keys.mjs           # Utopia's keys, for the game and Chip Rizz

cd ~/Desktop/Projects/ProjectX/Wavee/apps/frontend
npm run keys                               # Wavee's service key
```

The Flutterwave test keys are already in place. For Chip Rizz to write
replies, add `ANTHROPIC_API_KEY=` to `utopia/env/local_backend.env`;
payments work without it.

## 3. Run them

**Utopia and Chip Rizz** share one local backend:

```sh
cd ~/Desktop/Projects/ProjectX/.worktrees/utopia-chip-rizz
node tool/local_backend/serve.mjs          # keep it running

# The game (another terminal): coins and Chip Maestro in its store
cd ~/Desktop/Projects/ProjectX/.worktrees/utopia-chip-rizz
flutter run -d chrome --web-port 8080 --dart-define-from-file=env/local_pay.json

# Chip Rizz (another terminal): replies, coins and Chip Rizz Pro
cd ~/Desktop/Projects/ProjectX/chip
npm run dev:local                          # http://localhost:5180
```

**Wavee** (stop any other dev server on port 5173 first: a plain `npm run dev`
sends payments to the live site, which doesn't have them yet):

```sh
cd ~/Desktop/Projects/ProjectX/Wavee/apps/frontend
npm run dev:api                            # the Worker, http://localhost:8787
npm run dev:local                          # the app, http://localhost:5173
```

## 4. Paying (test mode)

Every price is in US dollars; Flutterwave converts for cards in other
currencies.

Flutterwave's test card: **5531 8866 5214 2950**, expiry **09/32**, CVV
**564**, PIN **3310**, OTP **12345**. More test cards are in Flutterwave's
docs under "Testing".

Pay with a signed-in account; guests are asked to save their account first.

What to try:

| App | Where | What should happen |
| --- | --- | --- |
| Utopia | Store > coins | the coins arrive when you're back |
| Utopia | Chip > Chip Maestro > Join | back in the game: "Welcome to Chip Maestro"; Manage your plan > cancel |
| Chip Rizz | Account > Get coins | "… coins added" |
| Chip Rizz | Account > Go Pro (weekly or monthly) | "Welcome to Chip Rizz Pro", 40 sets a day, Smart Chip |
| Wavee | a song's ••• > Boost this song | Library > Boosts shows it live; it's Promoted in other people's feeds |
| Wavee | Library > Boosts > Artist Pro | "Welcome to Artist Pro", a free Boost, Stats with every day |

## Going live later

Not now, only when you say so:

1. Deploy the functions: `chip-rizz`, `web-pay` and `web-pay-hook`.
2. Set the live Flutterwave keys as secrets (`tool/push_payment_keys.sh`).
3. Point Flutterwave's webhook at `web-pay-hook`. It passes Wavee's events
   on to Wavee.
4. Deploy Wavee's Worker with its secrets: `FLW_SECRET_KEY`,
   `FLW_WEBHOOK_HASH` and `SUPABASE_SERVICE_ROLE_KEY`.
5. Deploy Chip Rizz to chip.kaivon.app.

Prices and margins are in `docs/PRICING.md`.
