# Pricing: Utopia, Chip Rizz and Wavee

Every price here is set so the product pays for itself. That holds even at
its daily or monthly limit, after Flutterwave's fees, except where noted.
The prices live in database tables, so they can change without a release
(see "Changing a price" below).

**Everything is priced and charged in US dollars**, in all three apps.
Flutterwave converts for cards in other currencies (a Nigerian card pays the
dollar price in naira at its bank's rate). Margins below assume Flutterwave's
international card fee on every payment, the worst case.

## What things cost us

| Cost | Amount |
| --- | --- |
| Claude Haiku 5.5 ("Quick Chip") | $0.10 in, $0.50 out per million tokens |
| Claude Sonnet 5.5 ("Smart Chip") | $2 in, $10 out per million tokens |
| Claude Opus 5.5 | $4 in, $20 out per million tokens |
| Flutterwave, Nigerian cards, transfer and USSD | 2% + 7.5% VAT on the fee = **2.15%** |
| Flutterwave, international cards | 4.8% + VAT = **5.16%** |
| App Store / Google Play (small business) | 15% |

Flutterwave can pass its fee to the customer. That's the default, set in the
Flutterwave dashboard. The numbers below assume **we** pay it, the worse case
for us.

These are estimates per use, from the prompts in the code:

| One… | Quick Chip (Haiku) | Smart Chip (Sonnet) |
| --- | --- | --- |
| set of Chip Rizz replies (text or 1–2 screenshots) | $0.0005 | $0.011 |
| chat Chip learns (an export, up to ~25k tokens) | $0.003 | $0.058 |
| Utopia Chip chat (Opus for Maestro today) | $0.0005 | $0.010 (Opus ≈ $0.019) |

The real cost of each call is logged in `chip_costs`. The daily totals are in
the `chip_spend` view: check them weekly.

## Chip Rizz

| Who | What they get | Model | Most it can cost us |
| --- | --- | --- | --- |
| Guest | 3 sets/day, 1 chat learned/day | Quick | $0.14 a month |
| Free account | 5 sets/day, 1 chat learned/day | Quick | $0.17 a month |
| A set bought with coins | 300 coins | Smart | $0.011 |
| **Pro weekly** | 40 sets/day (150/week), 3 chats learned/day (10/week) | Smart | $2.23 a week |
| **Pro monthly** | 40 sets/day (600/month), 3 chats learned/day (30/month) | Smart | $8.34 a month |

All free users together are also capped at **$20 a day**
(`chip_settings.daily_free_usd`, shared with Utopia's Chip). Past it, free
users are asked to come back later; paying users never notice.

| Plan | Price | What we keep after fees | At the limit | Typical use* |
| --- | --- | --- | --- | --- |
| Pro weekly | **$3.99** | $3.78 | +$1.55 (40%) | +$3.27 (87%) |
| Pro monthly | **$9.99** | $9.47 | +$1.13 (12%) | +$7.36 (78%) |
| 300 coins (one set) | $0.03 at the pouch rate, $0.019 at the biggest pack | | +$0.007 to +$0.018 | |

\* Typical: 5 sets a day and a couple of chats learned a week.

Coins also come free from playing Utopia, so some sets bought with coins earn
us nothing. Playing earns coins slowly, so that stays small. If `chip_costs`
shows it isn't, raise `chip_settings.rizz_coins`.

## Utopia

| Product | Price (web) | Notes |
| --- | --- | --- |
| Coin packs | $0.99 to $99.99 | The same as the stores. The web keeps about 5% for Flutterwave instead of 15% for the store. |
| **Chip Maestro** (monthly) | **$7.99** | The same membership as the stores. **Set the store price to $7.99 too.** |

Chip Maestro's fair use per day is now 60 chats, 6 drawings and 40 colorings
(was 200, 10 and 100). Even so:

- **Chip's brain for members is Opus by default.** A typical member (10
  chats and one drawing a day) costs about **$8.60 a month on Opus**, which
  is more than the plan. On Sonnet it's about **$4.70**, leaving roughly $3
  a month.
  - **Recommended:** set the `CHIP_MODEL` secret to `claude-sonnet-5-5` when
    this goes live. Sonnet 5.5 is a very strong model; members will still
    get "Chip at his best".
- Someone at every daily limit, every day, could cost $20–30 a month even on
  Sonnet. Few people do that.
  - If `chip_spend` shows heavy members, add a monthly cap the way Chip Rizz
    Pro has one.

## Wavee

| Product | Price | What it costs us | Margin |
| --- | --- | --- | --- |
| Boost, 100 listeners | $2.99 | almost nothing (a slot in the feed) | ~95% |
| Boost, 500 listeners | $9.99 | almost nothing | ~95% |
| Boost, 2,000 listeners | $29.99 | almost nothing | ~95% |
| **Artist Pro** (monthly) | **$4.99** | storage for bigger uploads (~$0.015 a GB a month on R2) and a free 100-listener Boost | ~95% |

Boosted plays never count toward the charts or trending. That keeps the
charts honest, which is what makes them worth climbing and Boost worth buying.

## Fixed costs

These depend on your plans with each service. Check each dashboard and write
the amounts here:

- Supabase: Free, or Pro at $25 a month per project (Utopia and Wavee).
- Cloudflare Workers: Free, or Paid at $5 a month.
- Resend (email): free up to 3,000 emails a month.
- Domains.

For example, with $60 a month of fixed costs, about 8 Chip Rizz Pro monthly
members, or 13 Wavee Artist Pro members, cover them. Everything after that is
profit.

## Changing a price

In the Supabase SQL editor of the right project:

```sql
-- Utopia / Chip Rizz project
update web_plan_prices set amount = 12.99, flw_plan_id = null
 where plan_id = 'rizz.pro.monthly' and currency = 'USD';
update chip_settings set rizz_coins = 400;          -- coins for one set
update chip_settings set daily_free_usd = 30;       -- free users' daily budget

-- Wavee project
update boost_prices set amount = 3.49 where pack = 'wavee.boost.100' and currency = 'USD';
update wavee_plan_prices set amount = 5.99, flw_plan_id = null
 where plan_id = 'wavee.pro.monthly' and currency = 'USD';
```

Setting `flw_plan_id = null` makes a new Flutterwave plan at the new price the
next time someone subscribes. Existing subscribers keep their old price until
they cancel.
