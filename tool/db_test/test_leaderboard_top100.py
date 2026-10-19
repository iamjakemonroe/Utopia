"""Leaderboards: the top 100, and house players only while the switch is
on (and then counted in your place too)."""
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


harness.as_admin(db)
check("house players show for now", one("select show_house_players from leaderboard_settings") is True)

# 120 players with ratings from 1300 down; me in the middle.
players = [harness.new_user(db, f"p{i}@example.com") for i in range(120)]
harness.as_admin(db)
for i, p in enumerate(players):
    run("insert into player_ratings (user_id, game, rating, games, wins, losses, draws, best) "
        "values (%s, 'chess', %s, 10, 5, 5, 0, %s) on conflict (user_id, game) do update set rating = excluded.rating, games = 10",
        p, 1300 - i * 5, 1300 - i * 5)
me = players[60]
houses = one("select count(*) from player_ratings r join house_players h on h.id = r.user_id where r.game = 'chess' and r.games >= 5")

harness.as_user(db, me)
board = one("select get_leaderboard('chess')")
top = board["top"]
check("a hundred on the board", len(top) == 100, len(top))
check("best first, places in order", [e["place"] for e in top] == sorted(e["place"] for e in top) and top[0]["place"] == 1)
ids = {e["id"] for e in top}
harness.as_admin(db)
house_on_board = one("select count(*) from house_players where id = any(%s::uuid[])", list(ids))
check("house players on it, with the switch on", house_on_board > 0, house_on_board)
check("my place counts everyone shown above me", board["me"]["place"] == 1 + one(
    "select count(*) from player_ratings where game = 'chess' and games >= 5 and rating > %s", 1300 - 60 * 5), board["me"])

harness.as_admin(db)
run("update leaderboard_settings set show_house_players = false")
harness.as_user(db, me)
board = one("select get_leaderboard('chess')")
ids = [e["id"] for e in board["top"]]
harness.as_admin(db)
check("switch off: no house players", one("select count(*) from house_players where id = any(%s::uuid[])", ids) == 0)
check("…still a hundred", len(ids) == 100, len(ids))
check("…and my place without them", board["me"]["place"] == 61, board["me"])

harness.as_user(db, me)
try:
    run("update leaderboard_settings set show_house_players = true")
    flipped = True
except Exception:
    flipped = False
check("players can't flip the switch", not flipped)

sys.exit(1 if fails else 0)
