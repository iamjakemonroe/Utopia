"""Rank insights: what the hologram tells a player about their games."""
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


me = harness.new_user(db, "me@example.com")
ada = harness.new_user(db, "ada@example.com")
kofi = harness.new_user(db, "kofi@example.com")
lena = harness.new_user(db, "lena@example.com")
harness.as_admin(db)
for user, name in ((ada, "Ada"), (kofi, "Kofi"), (lena, "Lena")):
    run("update profiles set display_name = %s where id = %s", name, user)
# Strong opponents, so wins over them count.
run("insert into player_ratings (user_id, game, rating, games, best) values "
    "(%s, 'chess', 1400, 30, 1400), (%s, 'chess', 1250, 30, 1250), (%s, 'chess', 1100, 30, 1100)",
    ada, kofi, lena)


def play(white, black, winner, result, plies, minutes=10):
    """A finished, rated chess game (completed the way the app does)."""
    harness.as_admin(db)
    match = one(
        "insert into matches (game, status, stake, player_white, player_black, ply_count, "
        "clock_initial_ms, clock_increment_ms) values ('chess', 'active', 0, %s, %s, %s, %s, 0) returning id",
        white, black, plies, minutes * 60000)
    run("update matches set status = 'completed', winner_id = %s, result = %s, ended_at = now() where id = %s",
        winner, result, match)
    # Past the three-a-day limit between two players.
    run("update rating_changes set created_at = now() - interval '2 days' where match_id = %s", match)


# In order: W W L L L D W W W.
play(me, kofi, me, "checkmate", 40)
play(me, kofi, me, "resignation", 60)
play(kofi, me, kofi, "checkmate", 30)
play(ada, me, ada, "timeout", 80)
play(me, ada, ada, "checkmate", 50)
play(me, lena, None, "draw", 90, minutes=5)
play(lena, me, me, "checkmate", 24)
play(me, ada, me, "resignation", 70)
play(me, lena, me, "timeout", 64)

harness.as_user(db, me)
got = one("select get_rank_insights('chess')")
check("the record", (got["games"], got["wins"], got["losses"], got["draws"]) == (9, 5, 3, 1), got)
check("as white and as black",
      got["white"] == {"games": 6, "wins": 4} and got["black"] == {"games": 3, "wins": 1}, (got["white"], got["black"]))
check("how they win", got["wins_by"] == {"checkmate": 2, "resignation": 2, "timeout": 1}, got["wins_by"])
check("how they lose", got["losses_by"] == {"checkmate": 2, "timeout": 1}, got["losses_by"])
check("the fastest win, in moves", got["fastest_win"] == 12, got["fastest_win"])
check("the average game, in moves", got["avg_moves"] == round(sum([40, 60, 30, 80, 50, 90, 24, 70, 64]) / 9 / 2))
check("their usual clock", got["clock"] == "10+0", got["clock"])
check("the best win is over the highest rated beaten (Ada)",
      got["best_win"]["display_name"] == "Ada" and got["best_win"]["rating"] > 1300, got.get("best_win"))
check("the rival is who they play most (3 each: the latest, Lena)",
      got["rival"]["display_name"] == "Lena" and got["rival"]["games"] == 3 and got["rival"]["wins"] == 2,
      got.get("rival"))
check("the nemesis is who they lose to most (Ada, 2)",
      got["nemesis"]["display_name"] == "Ada" and got["nemesis"]["losses"] == 2, got.get("nemesis"))
check("the streak now: 3 wins (W W L L L D W W W)",
      got["streak"] == 3 and got["streak_kind"] == "W", (got["streak"], got["streak_kind"]))
check("the best streak: 3", got["best_streak"] == 3, got["best_streak"])
check("ranked, with where they sit", got["ranked"] >= 1 and 1 <= got["top_percent"] <= 100, got.get("top_percent"))
check("the biggest climb and drop", got["biggest_gain"] > 0 and got["biggest_drop"] < 0)
check("the best rating, and when", got["best"] >= got["rating"] and got["peak_at"] is not None)

# Somebody with no games yet.
harness.as_user(db, lena)
empty = one("select get_rank_insights('checkers')")
check("no games yet: a fresh record, nothing made up",
      empty["games"] == 0 and "rival" not in empty and empty["best_streak"] == 0 and "top_percent" not in empty, empty)
harness.as_user(db, me)
doodle = one("select get_rank_insights('doodle')")
check("doodle works too", doodle["game"] == "doodle" and "white" not in doodle)
try:
    one("select _rated_matches(%s, 'chess')", ada)
    peeked = True
except Exception:
    peeked = False
check("nobody can read someone else's games through it", not peeked)

sys.exit(1 if fails else 0)
