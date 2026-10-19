"""Leaderboards: the top 100; house players, tagged, only while the switch
is on and the game has fewer real ranked players than the mark (and then
counted in your place too)."""
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


def board_as(user, offset=0, limit=100):
    harness.as_user(db, user)
    return one("select get_leaderboard('chess', false, %s, %s)", offset, limit)


harness.as_admin(db)
check("house players show for now, until 50 real players",
      one("select show_house_players and house_until_players = 50 from leaderboard_settings"))
house_ids = set(one("select array_agg(id::text) from house_players"))

# 120 real players with ratings from 1300 down; me in the middle.
players = [harness.new_user(db, f"p{i}@example.com") for i in range(120)]
harness.as_admin(db)
for i, p in enumerate(players):
    run("insert into player_ratings (user_id, game, rating, games, wins, losses, draws, best) "
        "values (%s, 'chess', %s, 10, 5, 5, 0, %s) on conflict (user_id, game) do update set rating = excluded.rating, games = 10",
        p, 1300 - i * 5, 1300 - i * 5)
me = players[60]
real_above_me = 60

# With the mark above the real players, house players fill in.
run("update leaderboard_settings set house_until_players = 200")
board = board_as(me)
top = board["top"]
check("a hundred on the board", len(top) == 100, len(top))
check("best first, places in order", [e["place"] for e in top] == sorted(e["place"] for e in top) and top[0]["place"] == 1)
check("house players on it while it fills up", any(e["house"] for e in top))
check("each row says whether it's a house player", all(e["house"] == (e["id"] in house_ids) for e in top))
harness.as_admin(db)
houses_above = one("select count(*) from player_ratings r join house_players h on h.id = r.user_id "
                   "where r.game = 'chess' and r.games >= 5 and r.rating > %s", 1300 - 60 * 5)
check("my place counts the house players shown above me",
      board["me"]["place"] == 1 + real_above_me + houses_above, (board["me"], houses_above))

# A page at a time: 25 first, then the next as they scroll, to 100.
first = board_as(me, 0, 25)
check("the board opens on its first 25", len(first["top"]) == 25 and first["more"] is True, len(first["top"]))
pages = [first] + [board_as(me, o, 25) for o in (25, 50, 75)]
check("…the pages join up into the same top 100",
      [e["id"] for pg in pages for e in pg["top"]] == [e["id"] for e in top])
check("…the last page says there's no more", pages[-1]["more"] is False)
check("…nothing past the top 100", board_as(me, 100, 25)["top"] == [])
harness.as_user(db, me)
old_way = one("select get_leaderboard('chess')")
check("called the old way, it's the first page", len(old_way["top"]) == 25)
check("…and still says where I stand", old_way["me"]["place"] == board["me"]["place"])

# Once it has enough real players (120, mark 100), they leave by themselves.
harness.as_admin(db)
run("update leaderboard_settings set house_until_players = 100")
board = board_as(me)
check("enough real players: no house players", not any(e["house"] for e in board["top"]))
check("…still a hundred", len(board["top"]) == 100, len(board["top"]))
check("…and my place without them", board["me"]["place"] == 61, board["me"])

# The switch takes them off whatever the count.
harness.as_admin(db)
run("update leaderboard_settings set house_until_players = 200, show_house_players = false")
board = board_as(me)
check("switch off: no house players", not any(e["house"] for e in board["top"]))

harness.as_user(db, me)
try:
    run("update leaderboard_settings set show_house_players = true")
    flipped = True
except Exception:
    flipped = False
check("players can't change the settings", not flipped)

sys.exit(1 if fails else 0)
