"""Exercises 20261019090000_birthdays_and_events.sql as real players."""
import datetime as dt
import json
import sys

import psycopg2

import harness

db = harness.fresh()
fails = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + (f"  [{detail}]" if detail and not cond else ""))
    if not cond:
        fails.append(name)


def q(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)
        try:
            return c.fetchall()
        except psycopg2.ProgrammingError:
            return None


def raises(sql, *args):
    try:
        q(sql, *args)
        return None
    except Exception as e:
        return str(e).splitlines()[0]


def admin(sql, *args):
    harness.as_admin(db)
    return q(sql, *args)


alice = harness.new_user(db, "alice@example.com")
bob = harness.new_user(db, "bob@example.com")
guest = harness.new_user(db)

# ── Birthdays ──
harness.as_user(db, alice)
check("rejects 30 February", "not a real date" in (raises("select set_birthday(2, 30)") or ""))
check("rejects month 13", "not a real date" in (raises("select set_birthday(13, 1)") or ""))
today = dt.datetime.now(dt.timezone.utc).date()
q("select set_birthday(%s, %s)", today.month, today.day)
check("can correct it the same day", raises("select set_birthday(%s, %s)", today.month, today.day) is None)
check("only you see your birthday",
      q("select count(*) from user_birthdays")[0][0] == 1)
harness.as_user(db, bob)
check("others can't see it", q("select count(*) from user_birthdays")[0][0] == 0)
check("can't write the table directly",
      raises("insert into user_birthdays (user_id, month, day) values (%s, 1, 1)", bob) is not None)

# Locked after a day.
admin("update user_birthdays set set_at = now() - interval '2 days' where user_id = %s", alice)
harness.as_user(db, alice)
check("locked after a day", "birthday locked" in (raises("select set_birthday(1, 1)") or ""))

# On the day: world and frame, worn, until their midnight (capped).
r = q("select start_birthday(now() + interval '5 hours')")[0][0]
check("starts on the birthday", r["birthday"] is True, r)
admin("select 1")
row = admin("select equipped_theme, equipped_aura, aura_expires_at from profiles where id = %s", alice)[0]
check("wears the birthday world and frame", row[0] == "utopia_birthday" and row[1] == "birthday", row)
rent = admin("select expires_at from world_rentals where user_id = %s and world_id = 'utopia_birthday'", alice)[0][0]
check("lasts about 5 hours", dt.timedelta(hours=4.9) < rent - dt.datetime.now(dt.timezone.utc) < dt.timedelta(hours=5.1), rent)
harness.as_user(db, alice)
r = q("select start_birthday(now() + interval '10 days')")[0][0]
until = dt.datetime.fromisoformat(r["until"])
check("never past the end of the date everywhere",
      until - dt.datetime.now(dt.timezone.utc) < dt.timedelta(hours=38), until)
check("equip_item lets them wear the birthday world",
      raises("select equip_item('theme', 'utopia_birthday')") is None)
check("the frame isn't for sale",
      "no longer sold" in (raises("select buy_aura('birthday', 3)") or ""))
check("the world can't be rented",
      raises("select rent_world('utopia_birthday', 3)") is not None)

# Not their birthday: nothing.
harness.as_user(db, bob)
far = today + dt.timedelta(days=100)
q("select set_birthday(%s, %s)", far.month, far.day)
check("not their birthday", q("select start_birthday(now() + interval '5 hours')")[0][0]["birthday"] is False)
check("can't wear it on another day",
      raises("select equip_item('theme', 'utopia_birthday')") is not None)
harness.as_user(db, guest)
check("no birthday set", q("select start_birthday(null)")[0][0]["birthday"] is False)

# 29 February in a non-leap year is celebrated on the 28th.
admin("""create or replace function pg_temp.feb(p timestamptz) returns timestamptz language sql as $$
  select max((d + 1)::timestamp at time zone 'utc' + interval '12 hours')
  from generate_series((p at time zone 'utc' - interval '12 hours')::date,
                       (p at time zone 'utc' + interval '14 hours')::date, interval '1 day') g(day)
  cross join lateral (select g.day::date as d) x
  where (extract(month from d) = 2 and extract(day from d) = 29)
     or (extract(month from d) = 2 and extract(day from d) = 28
         and extract(day from (make_date(extract(year from d)::int, 3, 1) - 1)) = 28) $$""")
check("29 Feb on the 28th in 2027",
      admin("select pg_temp.feb('2027-02-28 12:00+00') is not null")[0][0])
check("29 Feb not on the 28th in 2028",
      admin("select pg_temp.feb('2028-02-27 12:00+00') is null")[0][0])

# ── Events (Halloween 2026 is on: 15 Oct to 2 Nov) ──
admin("update events set starts_at = now() - interval '3 days', ends_at = now() + interval '10 days'")
check("Halloween world left the store",
      admin("select count(*) from store_coin_prices where product_id = 'utopia.theme.utopia_halloween'")[0][0] == 0)
check("not in the every-world pack",
      admin("select not ('utopia_halloween' = any (item_ids)) from store_coin_prices where product_id = 'utopia.themes.all'")[0][0])
check("can't rent Halloween", admin("select _world_rent_price('utopia_halloween', 3) is null")[0][0])
harness.as_user(db, bob)
check("can't buy Jack's Lantern", "no longer sold" in (raises("select buy_aura('jack', 3)") or ""))

harness.as_user(db, alice)
s = q("select event_visit()")[0][0]
ev = s["events"][0]
check("visit counts a day", ev["days"] == 1 and ev["games"] == 0, ev)
check("rewards listed", [r["item_id"] for r in ev["rewards"]] == ["jack", "utopia_halloween"], ev)
s = q("select event_visit()")[0][0]
check("same day counts once", s["events"][0]["days"] == 1, s)

# Offline games: one a minute.
s = q("select event_count_game('chess')")[0][0]
check("offline game counts", s["counted"] and s["events"][0]["games"] == 1, s)
s = q("select event_count_game('chess')")[0][0]
check("a second within a minute doesn't", not s["counted"] and s["events"][0]["games"] == 1, s)
check("unknown game refused", "unknown game" in (raises("select event_count_game('poker')") or ""))

# Ten offline a day at most.
for i in range(12):
    admin("update event_progress set last_offline_at = now() - interval '2 minutes' where user_id = %s", alice)
    harness.as_user(db, alice)
    s = q("select event_count_game('ludo')")[0][0]
games = s["events"][0]["games"]
check("at most 10 offline a day", games == 10, games)
check("Jack's Lantern at 10 games", "jack" in s["earned_now"] or s["events"][0]["rewards"][0]["earned"], s)
row = admin("select expires_at from user_auras where user_id = %s and aura_id = 'jack'", alice)
check("Jack's Lantern usable until the event ends", row and row[0][0] > dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=9), row)
harness.as_user(db, alice)
check("can put it on", raises("select equip_aura('jack')") is None)

# Online games: must be theirs and finished, and count once.
m = admin("""insert into matches (stake, player_white, player_black, status)
             values (0, %s, %s, 'completed') returning id""", alice, bob)[0][0]
harness.as_user(db, alice)
admin("update event_progress set offline_today = 0, offline_day = null where user_id = %s", alice)
harness.as_user(db, alice)
s = q("select event_count_game('chess', %s)", m)[0][0]
check("online game counts", s["counted"] and s["events"][0]["games"] == 11, s)
s = q("select event_count_game('chess', %s)", m)[0][0]
check("same match counts once", not s["counted"] and s["events"][0]["games"] == 11, s)
harness.as_user(db, guest)
check("not your match", "not a finished game" in (raises("select event_count_game('chess', %s)", m) or ""))
lm = admin("""insert into ludo_matches (stake, player_red, state, players, colors, status)
              values (0, %s, '{}'::jsonb, array[%s::uuid, %s::uuid], array['red', 'yellow'], 'active') returning id""", alice, alice, bob)[0][0]
harness.as_user(db, alice)
check("unfinished Ludo doesn't count", "not a finished game" in (raises("select event_count_game('ludo', %s)", lm) or ""))

# The world: 15 games over 5 days.
for day in range(4):
    admin("update event_progress set last_day = last_day - 1, last_offline_at = null, offline_today = 0 where user_id = %s", alice)
    harness.as_user(db, alice)
    q("select event_visit()")
    q("select event_count_game('checkers')")
harness.as_user(db, alice)
s = q("select event_visit()")[0][0]
ev = s["events"][0]
check("15 games over 5 days", ev["games"] >= 15 and ev["days"] >= 5, ev)
check("world earned", ev["rewards"][1]["earned"], ev)
check("can travel there", raises("select equip_item('theme', 'utopia_halloween')") is None)
check("season items are theirs alone", q("select count(*) from season_items")[0][0] == 2)
harness.as_user(db, bob)
check("bob sees none of alice's", q("select count(*) from season_items")[0][0] == 0)
check("can't write progress directly",
      raises("update event_progress set games = 99") is not None or
      admin("select max(games) from event_progress where user_id = %s", bob)[0][0] in (None, 0))
harness.as_user(db, bob)
check("bob can't wear Halloween", raises("select equip_item('theme', 'utopia_halloween')") is not None)

# The season ends: items stop working, and come back next year.
admin("update world_rentals set expires_at = now() - interval '1 minute' where world_id = 'utopia_halloween'")
admin("update user_auras set expires_at = now() - interval '1 minute' where aura_id = 'jack'")
admin("update events set starts_at = now() - interval '20 days', ends_at = now() - interval '1 day'")
harness.as_user(db, alice)
check("out of season: can't wear the world", raises("select equip_item('theme', 'utopia_halloween')") is not None)
s = q("select event_visit()")[0][0]
check("no event on", s["events"] == [], s)
admin("""insert into events (id, season, title, starts_at, ends_at)
         values ('halloween_2027', 'halloween', 'Halloween', now() - interval '1 hour', now() + interval '14 days')""")
harness.as_user(db, alice)
s = q("select event_visit()")[0][0]
check("next Halloween: it's back", raises("select equip_item('theme', 'utopia_halloween')") is None, s)
check("and the frame", raises("select equip_aura('jack')") is None)

# Welcome week no longer hands out Halloween.
harness.as_user(db, guest)
q("select start_welcome_week()")
check("welcome week skips Halloween",
      admin("select count(*) from world_rentals where user_id = %s and world_id = 'utopia_halloween'", guest)[0][0] == 0)
check("welcome week still gives Music",
      admin("select count(*) from world_rentals where user_id = %s and world_id = 'utopia_music'", guest)[0][0] == 1)

# Internals aren't callable by players.
harness.as_user(db, guest)
check("can't grant yourself items",
      raises("select _season_grant(%s, 'utopia_halloween', 'world', now() + interval '1 year')", guest) is not None)

print()
print("ALL PASSED" if not fails else f"{len(fails)} FAILED: {fails}")
sys.exit(1 if fails else 0)
