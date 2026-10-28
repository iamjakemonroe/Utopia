"""8-ball pool (20261028120000_pool.sql): cues sold for coins, upgraded a
level at a time (bought ones only, to their tier's top), equipped; the
coin tables, where a game against Chip costs its entry, one left
unfinished is lost, the cue is fixed when it starts, the referee's shots
are saved in order and the winner takes the pot; resigning; and nobody
writes any of it but the server."""
import json
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


def attempt(user, sql, *args):
    """Runs [sql] as [user] (or as the service role, for 'service'); the
    first row's first value, or the error's first line."""
    if user == "service":
        harness.as_admin(db)
        with db.cursor() as c:
            c.execute("set role service_role")
    else:
        harness.as_user(db, user)
    try:
        with db.cursor() as c:
            c.execute(sql, args)
            try:
                rows = c.fetchall()
                return rows[0][0] if rows else None
            except Exception:
                return "ok"
    except Exception as e:
        return "ERROR " + str(e).split("\n")[0]
    finally:
        harness.as_admin(db)


def ok(result):
    """Whether a call that returns nothing went through (psycopg2 reads a
    void as an empty string)."""
    return result in (None, "", "ok")


def balance(user):
    harness.as_admin(db)
    return one("select balance from profiles where id = %s", user)


def give(user, coins):
    harness.as_admin(db)
    one("update profiles set balance = %s where id = %s returning 1", coins, user)


STATE = json.dumps({"balls": {"x": [0.5] * 16, "y": [0.5] * 16, "on": [True] * 16},
                    "turn": 0, "groups": [None, None], "hand": "kitchen", "break": True})

me = harness.new_user(db, "me@example.com")
other = harness.new_user(db, "other@example.com")

# ── The catalog ─────────────────────────────────────────────────────────
check("twelve cues", one("select count(*) from pool_cues") == 12)
check("eleven sold for coins (the classic is free)",
      one("select count(*) from store_coin_prices where product_id like 'utopia.cue.%%'") == 11)
check("the classic cue is free", one("select _free_item('cue_classic')") is True)
check("a mythic cue costs 200,000",
      one("select coins from store_coin_prices where product_id = 'utopia.cue.dragon'") == 200000)
regular = [one("select _pool_cue_upgrade_cost('regular', %s)", lvl) for lvl in range(1, 6)]
check("regular cues climb to level 5", regular == [2000, 4000, 7000, 12000, None], regular)
mythic = [one("select _pool_cue_upgrade_cost('mythic', %s)", lvl) for lvl in range(1, 11)]
check("mythic cues climb to 10, at twice the rare price",
      mythic == [6000, 10000, 16000, 24000, 34000, 46000, 60000, 80000, 100000, None], mythic)
check("the epic step is a quarter dearer than the rare",
      one("select _pool_cue_upgrade_cost('epic', 1)") == 3750)
check("anyone reads the tables", attempt(other, "select count(*) from pool_tables") == 4)
check("a table's pot is twice its entry, less 5%",
      one("select bool_and(prize = entry * 2 * 95 / 100) from pool_tables"))
check("players see the cue someone plays with",
      attempt(other, "select equipped_pool_cue from profiles where id = %s", me) == "cue_classic")

# ── Buying, upgrading, equipping ────────────────────────────────────────
give(me, 100000)
check("the classic cue upgrades for 2,000",
      attempt(me, "select upgrade_pool_cue('cue_classic')") == 2 and balance(me) == 98000)
check("a cue not bought can't be upgraded",
      "buy the cue" in str(attempt(me, "select upgrade_pool_cue('cue_neon')")))
check("an unknown cue can't be upgraded",
      "unknown cue" in str(attempt(me, "select upgrade_pool_cue('cue_nope')")))
check("buying a cue", ok(attempt(me, "select buy_with_coins('utopia.cue.neon')"))
      and balance(me) == 48000)
check("a bought cue upgrades (rare: 3,000 to level 2)",
      attempt(me, "select upgrade_pool_cue('cue_neon')") == 2 and balance(me) == 45000)
check("the levels are the player's to read",
      attempt(me, "select level from user_pool_cues where cue_id = 'cue_neon'") == 2)
check("not another player's",
      attempt(other, "select count(*) from user_pool_cues") == 0)
check("nobody writes a level", "ERROR" in str(attempt(
    me, "insert into user_pool_cues (user_id, cue_id, level) values (%s, 'cue_neon', 10)", me)))
give(me, 1000000)
for _ in range(3):
    attempt(me, "select upgrade_pool_cue('cue_classic')")
check("regular cues stop at level 5",
      "top level" in str(attempt(me, "select upgrade_pool_cue('cue_classic')"))
      and one("select level from user_pool_cues where user_id = %s and cue_id = 'cue_classic'", me) == 5)
give(me, 100)
check("an upgrade needs the coins",
      "insufficient balance" in str(attempt(me, "select upgrade_pool_cue('cue_neon')"))
      and one("select level from user_pool_cues where user_id = %s and cue_id = 'cue_neon'", me) == 2)
harness.as_admin(db)
one("insert into world_rentals (user_id, world_id, expires_at) values (%s, 'cue_galaxy', now() + interval '1 day') returning 1", me)
give(me, 100000)
check("a lent cue isn't upgraded",
      "buy the cue" in str(attempt(me, "select upgrade_pool_cue('cue_galaxy')")))
check("but it can be played with",
      ok(attempt(me, "select equip_item('pool_cue', 'cue_galaxy')"))
      and one("select equipped_pool_cue from profiles where id = %s", me) == "cue_galaxy")
check("a cue not owned isn't equipped",
      "don't own" in str(attempt(me, "select equip_item('pool_cue', 'cue_dragon')")))
check("equipping still works for the other kinds",
      ok(attempt(me, "select equip_item('chess_pieces', 'classic')")))

# ── The coin tables ─────────────────────────────────────────────────────
give(me, 10000)
check("players can't open a game themselves",
      "ERROR" in str(attempt(me, "select pool_open(%s, 'lagoon', %s::jsonb)", me, STATE)))
g1 = attempt("service", "select pool_open(%s, 'lagoon', %s::jsonb)", me, STATE)
check("a game opens, its entry paid", g1 and "ERROR" not in str(g1) and balance(me) == 9800, g1)
row = one("select row_to_json(g) from pool_games g where id = %s", g1)
check("the lent galaxy cue plays, at level 1", row["cue_id"] == "cue_galaxy" and row["cue_level"] == 1, row)
check("Chip's cue is the table's", row["bot"] == "easy" and row["bot_cue"] == "cue_classic")
check("the player reads their game",
      attempt(me, "select count(*) from pool_games where id = %s", g1) == 1)
check("nobody else does", attempt(other, "select count(*) from pool_games") == 0)
check("nobody writes a game", "ERROR" in str(attempt(
    me, "update pool_games set status = 'won' where id = %s", g1)) or
    one("select status from pool_games where id = %s", g1) == "active")

harness.as_admin(db)
one("update world_rentals set expires_at = now() - interval '1 minute' where user_id = %s returning 1", me)
g2 = attempt("service", "select pool_open(%s, 'dunes', %s::jsonb)", me, STATE)
row = one("select row_to_json(g) from pool_games g where id = %s", g2)
check("a cue whose loan ran out falls back to the classic, at its level",
      row["cue_id"] == "cue_classic" and row["cue_level"] == 5, row)
check("the unfinished game is lost",
      one("select status || '/' || result from pool_games where id = %s", g1) == "lost/abandoned")
check("one game at a time", one("select count(*) from pool_games where user_id = %s and status = 'active'", me) == 1)
check("the dunes entry paid", balance(me) == 8800, balance(me))

give(me, 100)
bad = attempt("service", "select pool_open(%s, 'neon', %s::jsonb)", me, STATE)
check("a table needs its entry", "insufficient balance" in str(bad), bad)
check("and then the game in play isn't lost",
      one("select status from pool_games where id = %s", g2) == "active")
check("an unknown table", "unknown table" in str(attempt("service", "select pool_open(%s, 'moon', %s::jsonb)", me, STATE)))

# Shots, in order.
check("players can't record shots",
      "ERROR" in str(attempt(me, "select pool_record(%s, 0, %s::jsonb, '{}'::jsonb, null, null)", g2, STATE)))
r = attempt("service", "select pool_record(%s, 0, %s::jsonb, '{\"by\":\"you\"}'::jsonb, null, null)", g2, STATE)
check("a shot is saved", isinstance(r, dict) and r["status"] == "active" and r["shots"] == 1, r)
check("a shot on a stale table is refused",
      "out of sync" in str(attempt("service", "select pool_record(%s, 0, %s::jsonb, '{}'::jsonb, null, null)", g2, STATE)))
r = attempt("service", "select pool_record(%s, 1, %s::jsonb, '{\"by\":\"you\"}'::jsonb, 0, 'eight')", g2, STATE)
check("winning pays the pot", r["status"] == "won" and r["prize"] == 1900 and balance(me) == 2000, (r, balance(me)))
check("and how it was won is kept",
      one("select result from pool_games where id = %s", g2) == "eight")
check("a game over takes no more shots",
      "game is over" in str(attempt("service", "select pool_record(%s, 2, %s::jsonb, '{}'::jsonb, null, null)", g2, STATE)))
check("the entry and pot are in the ledger",
      one("select array_agg(entry_type::text order by created_at) from ledger_entries where user_id = %s and entry_type::text like 'pool_%%'", me)
      [-2:] == ["pool_entry", "pool_prize"])

g3 = attempt("service", "select pool_open(%s, 'lagoon', %s::jsonb)", me, STATE)
r = attempt("service", "select pool_record(%s, 0, %s::jsonb, '{\"by\":\"chip\"}'::jsonb, 1, 'eight')", g3, STATE)
check("losing pays nothing", r["status"] == "lost" and r["prize"] == 0 and balance(me) == 1800, (r, balance(me)))

g4 = attempt("service", "select pool_open(%s, 'lagoon', %s::jsonb)", me, STATE)
attempt(other, "select pool_resign(%s)", g4)
check("nobody resigns another's game", one("select status from pool_games where id = %s", g4) == "active")
attempt(me, "select pool_resign(%s)", g4)
check("resigning loses the game",
      one("select status || '/' || result from pool_games where id = %s", g4) == "lost/resign")

print()
if fails:
    print(f"{len(fails)} failed: {', '.join(fails)}")
    sys.exit(1)
print("All pool checks passed.")
