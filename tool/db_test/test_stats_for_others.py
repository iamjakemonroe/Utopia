"""Other players' holograms: anyone's stats, from the rankings, unless
they hide them (Settings > Show my stats); they always see their own."""
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


ada = harness.new_user(db, "ada@example.com")
bo = harness.new_user(db, "bo@example.com")
harness.as_admin(db)
with db.cursor() as c:
    c.execute("insert into player_ratings (user_id, game, rating, best, games, wins, losses, draws) "
              "values (%s, 'chess', 1420, 1460, 12, 8, 3, 1)", (bo,))

harness.as_user(db, ada)
mine = one("select get_rank_insights('chess')")
check("my own, as before", mine.get("rating") == 1000 and not mine.get("hidden"), mine)
theirs = one("select get_rank_insights('chess', %s)", bo)
check("another player's, who shows them", theirs.get("rating") == 1420 and theirs.get("wins") == 8
      and not theirs.get("hidden"), theirs)
check("whether they show them is public", one("select show_stats from profiles where id = %s", bo) is True)

harness.as_user(db, bo)
one("select set_show_stats(false)")
harness.as_user(db, ada)
hidden = one("select get_rank_insights('chess', %s)", bo)
check("hidden: nothing but that", hidden == {"game": "chess", "hidden": True}, hidden)
check("…and the app can tell", one("select show_stats from profiles where id = %s", bo) is False)
harness.as_user(db, bo)
own = one("select get_rank_insights('chess', %s)", bo)
check("they still see their own", own.get("rating") == 1420 and not own.get("hidden"), own)

harness.as_user(db, ada)
try:
    one("update profiles set show_stats = true where id = %s returning 1", bo)
    changed = one("select show_stats from profiles where id = %s", bo)
except Exception:
    changed = False
check("nobody else can change it", changed is not True, changed)

sys.exit(1 if fails else 0)
