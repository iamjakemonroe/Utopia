"""The welcome pass: a new player's first three days with everything the
store sells (not Maestro, not coins, not earned things), then back to
normal, keeping whatever they paid for."""
import sys

import harness

db = harness.fresh()
fails = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


def one(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)
        rows = c.fetchall()
        return rows[0][0] if rows else None


def run(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)


def raises(sql, *args):
    try:
        run(sql, *args)
        return None
    except Exception as e:
        db.rollback() if not db.autocommit else None
        return str(e).splitlines()[0]


me = harness.new_user(db, "new@example.com")
harness.as_admin(db)
coins_before = one("select balance from profiles where id = %s", me)
sold = set(one("select array_agg(distinct i) from store_coin_prices, unnest(item_ids) i where not _free_item(i)"))
frames = set(one("select array_agg(id) from aura_catalog where not retired"))

harness.as_user(db, me)
started = one("select start_welcome_week()")
check("a new player's pass starts", started["fresh"] is True)
harness.as_admin(db)
days = one("select round(extract(epoch from welcome_until - now()) / 86400) from profiles where id = %s", me)
check("…for three days", days == 3, days)
lent = set(one("select array_agg(world_id) from world_rentals where user_id = %s and expires_at > now()", me))
check("every world, chess set and piece set the store sells", sold <= lent, sold - lent)
check("…chess and piece sets among them",
      {"chess_crystal", "candy", "utopia_doodle", "ruby_dawn"} <= lent)
check("every frame on sale", frames <= set(one(
    "select array_agg(aura_id) from user_auras where user_id = %s and expires_at > now()", me)))
check("the Angel Halo on", one("select equipped_aura from profiles where id = %s", me) == "halo")
check("not Chip Maestro", one("select count(*) from maestro_subscriptions where user_id = %s", me) == 0)
check("not coins", one("select balance from profiles where id = %s", me) == coins_before)
check("not the Halloween world or frame (earned in the event)",
      "utopia_halloween" not in lent and one(
          "select count(*) from user_auras where user_id = %s and aura_id = 'jack'", me) == 0)

harness.as_user(db, me)
again = one("select start_welcome_week()")
check("only once: the next time it just says when it ends", again["fresh"] is False)

# Using it.
harness.as_user(db, me)
run("select equip_item('chess_pieces', 'chess_crystal')")
run("select equip_item('ludo_pieces', 'candy')")
run("select equip_item('theme', 'utopia_doodle')")
harness.as_admin(db)
check("any of it can be put on: sets and worlds",
      one("select equipped_chess_pieces || ',' || equipped_ludo_pieces || ',' || equipped_theme "
          "from profiles where id = %s", me) == "chess_crystal,candy,utopia_doodle")

# Buy one to keep (with coins), and buy coins, and have Maestro.
run("insert into user_entitlements (user_id, item_id, source) values (%s, 'chess_crystal', 'coins')", me)
run("select _ledger_move(%s, 'purchase_credit', 3300, null, '{}'::jsonb)", me)
run("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'apple-9', now() + interval '20 days', true, 'production')", me)
coins_kept = one("select balance from profiles where id = %s", me)

# Three days later.
run("update world_rentals set expires_at = now() - interval '1 minute' where user_id = %s", me)
run("update user_auras set expires_at = now() - interval '1 minute' where user_id = %s and aura_id <> 'maestro'", me)
run("update profiles set welcome_until = now() - interval '1 minute', aura_expires_at = now() - interval '1 minute' where id = %s", me)
settled = one("select settle_lent_sets()")
check("a lent set still on goes back to the classic one",
      one("select equipped_ludo_pieces from profiles where id = %s", me) == "classic", settled)
check("…but a set they bought stays on", one(
    "select equipped_chess_pieces from profiles where id = %s", me) == "chess_crystal")
check("bought coins stay", one("select balance from profiles where id = %s", me) == coins_kept)
check("Maestro they paid for stays", one("select _maestro_until(%s) is not null", me))
harness.as_user(db, me)
check("lent things can't be put on any more",
      (raises("select equip_item('ludo_pieces', 'jelly')") or "").startswith("you don't own that yet"))
harness.as_user(db, me)
run("select equip_item('ludo_pieces', 'bubble')")
check("free ones always can", True)

# Others' sets are never touched.
other = harness.new_user(db, "other@example.com")
harness.as_admin(db)
run("insert into user_entitlements (user_id, item_id, source) values (%s, 'royal', 'coins')", other)
run("update profiles set equipped_ludo_pieces = 'royal' where id = %s", other)
house = one("select id from house_players limit 1")
run("update profiles set equipped_chess_pieces = 'chess_neon' where id = %s", house)
one("select settle_lent_sets()")
check("an owned set stays on", one("select equipped_ludo_pieces from profiles where id = %s", other) == "royal")
check("house players are left alone", one("select equipped_chess_pieces from profiles where id = %s", house) == "chess_neon")

harness.as_user(db, me)
check("players can't run the clean-up", raises("select settle_lent_sets()") is not None)

sys.exit(1 if fails else 0)
