"""Weekly quests: coins for playing, a new set every week."""
import sys

import harness

db = harness.fresh()
fails = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


def q(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)
        try:
            return c.fetchall()
        except Exception:
            return None


def admin(sql, *args):
    harness.as_admin(db)
    return q(sql, *args)


def weekly(state):
    return next(e for e in state["events"] if e["season"] == "weekly")


def balance(user):
    return admin("select balance from profiles where id = %s", user)[0][0]


def play(user, n):
    state = None
    for _ in range(n):
        admin("update event_progress set last_offline_at = null, offline_today = 0 where user_id = %s", user)
        harness.as_user(db, user)
        state = q("select event_count_game('ludo')")[0][0]
    return state


ann = harness.new_user(db, "ann@example.com")
admin("update events set starts_at = now() - interval '1 day', ends_at = now() + interval '9 days' where id = 'halloween_2026'")
start = balance(ann)

harness.as_user(db, ann)
s = q("select event_visit()")[0][0]
check("this week's quests appear", any(e["season"] == "weekly" for e in s["events"]), s)
w = weekly(s)
check("three quests", [r["item_id"] for r in w["rewards"]] == ["games_5", "games_12", "days_3"], w)
check("seasonal event listed first", s["events"][0]["season"] == "halloween", [e["season"] for e in s["events"]])
check("they're coins", all(r["kind"] == "coins" and r["coins"] > 0 for r in w["rewards"]), w)
check("made once", admin("select count(*) from events where season = 'weekly'")[0][0] == 1)
harness.as_user(db, ann)
q("select event_visit()")
check("still once", admin("select count(*) from events where season = 'weekly'")[0][0] == 1)

s = play(ann, 5)
check("5 games: 1,500 coins", "games_5" in s["earned_now"] and balance(ann) == start + 1500, (s["earned_now"], balance(ann) - start))
check("in the ledger as a quest reward",
      admin("select count(*) from ledger_entries where user_id = %s and entry_type = 'quest_reward'", ann)[0][0] == 1)
s = play(ann, 1)
check("not paid twice", balance(ann) == start + 1500, balance(ann) - start)
s = play(ann, 4)
check("10 games: Jack's Lantern too", "jack" in s["earned_now"] or any(
    r["item_id"] == "jack" and r["earned"] for e in s["events"] for r in e["rewards"]), s["earned_now"])
admin("update event_progress set offline_day = null where user_id = %s", ann)
s = play(ann, 2)
check("12 games: 4,000 more", balance(ann) == start + 5500, balance(ann) - start)
check("both shown as earned", [r["earned"] for r in weekly(s)["rewards"]][:2] == [True, True], weekly(s))

for _ in range(2):
    admin("update event_progress set last_day = last_day - 1 where user_id = %s", ann)
    harness.as_user(db, ann)
    s = q("select event_visit()")[0][0]
check("3 days: 2,000 more", balance(ann) == start + 7500, balance(ann) - start)

# Next week: a new event, the same quests, paid again.
admin("update events set ends_at = now() - interval '1 minute', starts_at = now() - interval '8 days' where season = 'weekly'")
admin("""insert into events (id, season, title, starts_at, ends_at)
         values ('weekly_next', 'weekly', 'This week', now() - interval '1 minute', now() + interval '7 days')""")
admin("""insert into event_rewards (event_id, item_id, kind, games, days, coins, sort)
         values ('weekly_next', 'games_5', 'coins', 5, 0, 1500, 1)""")
s = play(ann, 5)
check("next week pays again", balance(ann) == start + 9000, balance(ann) - start)

harness.as_user(db, ann)
check("claims are private", q("select count(*) from event_claims")[0][0] >= 4)
bob = harness.new_user(db, "bob@example.com")
harness.as_user(db, bob)
check("others see none", q("select count(*) from event_claims")[0][0] == 0)
try:
    q("insert into event_claims (user_id, event_id, item_id) values (%s, 'weekly_next', 'x')", bob)
    blocked = False
except Exception:
    blocked = True
check("can't write claims yourself", blocked)

print("ALL PASSED" if not fails else f"{len(fails)} FAILED: {fails}")
sys.exit(1 if fails else 0)
