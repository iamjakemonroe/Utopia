"""The Winter event (20261021310000_winter_event.sql) and its preview
scripts (tool/sql/give_winter.sql, take_winter.sql): when it runs, what it
gives and for what, that neither the world nor the Snow Globe is ever sold
or handed out in the welcome week, and that a preview before it starts
lends them for a week without anyone earning them."""
import pathlib
import sys

import harness

db = harness.fresh()
fails = []
SQL = pathlib.Path(__file__).resolve().parents[1] / "sql"


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


def one(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)
        rows = c.fetchall()
        return rows[0][0] if rows else None


def raises(sql, *args):
    try:
        with db.cursor() as c:
            c.execute(sql, args)
        return None
    except Exception as e:
        return str(e).splitlines()[0]


def script(name, user):
    harness.as_admin(db)
    sql = (SQL / name).read_text().replace("00000000-0000-0000-0000-000000000000", user)
    with db.cursor() as c:
        c.execute(sql)


alice = harness.new_user(db, "alice@example.com")
bob = harness.new_user(db, "bob@example.com")

harness.as_admin(db)
event = one("select row_to_json(e) from events e where id = 'winter_2026'")
check("the event is Winter's", event and event["season"] == "winter" and event["title"] == "Winter", event)
check("it starts on 13 December",
      one("select starts_at = '2026-12-13 00:00+00' from events where id = 'winter_2026'"))
check("and runs through 2 January",
      one("select ends_at = '2027-01-03 12:00+00' from events where id = 'winter_2026'"))
rewards = one("""select json_agg(json_build_array(item_id, kind, games, days) order by sort)
                 from event_rewards where event_id = 'winter_2026'""")
check("the Snow Globe for 10 games, the world for 15 over 5 days",
      rewards == [["snow_globe", "aura", 10, 0], ["utopia_winter", "world", 15, 5]], rewards)

# Never sold.
check("the Snow Globe is in the catalog, retired",
      one("select retired from aura_catalog where id = 'snow_globe'") is True)
harness.as_admin(db)
one("update profiles set balance = 1000000 where id = %s returning 1", alice)
harness.as_user(db, alice)
check("it can't be bought",
      "no longer sold" in (raises("select buy_aura('snow_globe', 7)") or ""))
check("the world can't be rented", one("select _world_rent_price('utopia_winter', 7) is null"))
check("nor travelled to unearned",
      raises("select equip_item('theme', 'utopia_winter')") is not None)
harness.as_user(db, bob)
one("select start_welcome_week()")
harness.as_admin(db)
check("the welcome week doesn't hand them out",
      one("select count(*) from user_auras where user_id = %s and aura_id = 'snow_globe'", bob) == 0
      and one("select count(*) from world_rentals where user_id = %s and world_id = 'utopia_winter'", bob) == 0)

# A preview before it starts: a week of both, worn, nothing earned.
script("give_winter.sql", alice)
harness.as_admin(db)
left = one("""select extract(epoch from expires_at - now()) / 86400 from world_rentals
              where user_id = %s and world_id = 'utopia_winter'""", alice)
check("preview: the world for a week", left is not None and 6.9 < left <= 7, left)
check("preview: the frame for a week",
      6.9 < one("""select extract(epoch from expires_at - now()) / 86400 from user_auras
                   where user_id = %s and aura_id = 'snow_globe'""", alice) <= 7)
check("preview: both put on",
      one("select equipped_theme = 'utopia_winter' and equipped_aura = 'snow_globe' from profiles where id = %s",
          alice))
check("preview: nothing earned",
      one("select count(*) from season_items where user_id = %s", alice) == 0)
harness.as_user(db, alice)
check("preview: they can travel there", raises("select equip_item('theme', 'utopia_winter')") is None)

script("take_winter.sql", alice)
harness.as_admin(db)
check("taken back: gone and off",
      one("select count(*) from world_rentals where user_id = %s and world_id = 'utopia_winter'", alice) == 0
      and one("select equipped_theme <> 'utopia_winter' and equipped_aura is null from profiles where id = %s",
              alice))

# While it's on: earned, theirs until it ends.
harness.as_admin(db)
one("update events set starts_at = now() - interval '1 hour' where id = 'winter_2026' returning 1")
script("give_winter.sql", alice)
harness.as_admin(db)
check("in the event: both earned",
      one("select count(*) from season_items where user_id = %s and event_id = 'winter_2026' and season = 'winter'",
          alice) == 2)
check("in the event: theirs until it ends",
      one("""select expires_at = (select ends_at from events where id = 'winter_2026')
             from world_rentals where user_id = %s and world_id = 'utopia_winter'""", alice))
script("take_winter.sql", alice)
harness.as_admin(db)
check("taken back again: nothing left",
      one("select count(*) from season_items where user_id = %s", alice) == 0
      and one("select count(*) from event_progress where user_id = %s", alice) == 0)

sys.exit(1 if fails else 0)
