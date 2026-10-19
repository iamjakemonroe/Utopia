"""Rankings: Elo for online chess and checkers, and the leaderboard."""
import sys

import harness

db = harness.fresh()
# The boards as they're meant to be: real players only (house players can
# be shown for a while by a switch; see test_leaderboard_top100.py).
harness.as_admin(db)
with db.cursor() as _c:
    _c.execute("update leaderboard_settings set show_house_players = false")
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


def raises(sql, *args):
    try:
        q(sql, *args)
        return None
    except Exception as e:
        return str(e).splitlines()[0]


def admin(sql, *args):
    harness.as_admin(db)
    return q(sql, *args)


def play(white, black, winner, game="chess", result=None, plies=20):
    """An online game from start to finish; returns its id."""
    m = admin("""insert into matches (game, stake, player_white, player_black, status, ply_count)
                 values (%s, 0, %s, %s, 'active', %s) returning id""", game, white, black, plies)[0][0]
    admin("update matches set status = 'completed', winner_id = %s, result = %s where id = %s",
          winner, result or ("checkmate" if winner else "draw"), m)
    return m


def rating(user, game="chess"):
    row = admin("select rating, games from player_ratings where user_id = %s and game = %s", user, game)
    return tuple(row[0]) if row else None


ann, bob, cat, dan, eve = (harness.new_user(db, f"{n}@example.com") for n in ("ann", "bob", "cat", "dan", "eve"))
admin("update profiles set display_name = initcap(split_part(%s, '@', 1)) where id = %s", "ann@x", ann)

# Even players: the winner gains what the loser drops.
m = play(ann, bob, ann)
check("winner gains 20", rating(ann) == (1020, 1), rating(ann))
check("loser drops 20", rating(bob) == (980, 1), rating(bob))
harness.as_user(db, ann)
ch = q("select before, after from rating_changes where match_id = %s", m)
check("the change is kept for the result card", ch == [(1000, 1020)], ch)
harness.as_user(db, bob)
ch = q("select count(*) from rating_changes where match_id = %s and user_id = %s", m, ann)[0][0]
check("only your own changes are visible", ch == 0, ch)

# Upsets pay more.
admin("insert into player_ratings (user_id, game, rating) values (%s, 'chess', 1400) on conflict do nothing", cat)
play(dan, cat, dan)
r = rating(dan)[0]
check("beating a stronger player gains more", r > 1030, r)
play(cat, eve, None)
check("a draw with a weaker player costs the stronger", rating(cat)[0] < 1400 and rating(eve)[0] > 1000, (rating(cat), rating(eve)))

# Games that don't count.
before = rating(ann)
play(ann, bob, ann, result="aborted")
play(ann, bob, ann, plies=1)
check("called-off and one-move games aren't rated", rating(ann) == before, rating(ann))
check("checkers is rated apart", rating(ann, "checkers") is None)
play(ann, bob, bob, game="checkers")
check("checkers has its own rating", rating(ann, "checkers") == (980, 1), rating(ann, "checkers"))

# Three a day between the same two players.
play(bob, ann, ann)
play(ann, bob, ann)
g = rating(ann)[1]
play(ann, bob, ann)
check("at most 3 rated games a day per pair", rating(ann)[1] == g == 3, (g, rating(ann)))
admin("update player_ratings set rating = 10 where user_id = %s and game = 'chess'", bob)
play(bob, cat, cat)
check("never below 100", rating(bob)[0] >= 100, rating(bob))

# Writes only through games.
harness.as_user(db, ann)
check("players can't set their rating", raises("update player_ratings set rating = 3000 where user_id = %s", ann) is not None
      or admin("select rating from player_ratings where user_id = %s and game = 'chess'", ann)[0][0] != 3000)

# The board: ranked after 5 rated games.
harness.as_user(db, ann)
board = q("select get_leaderboard('chess')")[0][0]
check("nobody ranked before 5 games", board["top"] == [] and board["me"]["place"] is None, board)
admin("update player_ratings set games = 5")
harness.as_user(db, ann)
board = q("select get_leaderboard('chess')")[0][0]
ratings = [t["rating"] for t in board["top"]]
check("highest first", ratings == sorted(ratings, reverse=True) and len(ratings) == 5, ratings)
check("places count up", [t["place"] for t in board["top"]][0] == 1, board["top"])
mine = [t for t in board["top"] if t["id"] == ann][0]
check("my place matches the board", board["me"]["place"] == mine["place"], (board["me"], mine))
check("names and avatars come along", mine["display_name"] == "Ann" and "avatar_kind" in mine, mine)

lo, hi = sorted([ann, bob])
admin("insert into friendships (user_low, user_high) values (%s, %s)", lo, hi)
harness.as_user(db, ann)
friends = q("select get_leaderboard('chess', true)")[0][0]
ids = {t["id"] for t in friends["top"]}
check("friends board: me and my friends only", ids == {ann, bob}, ids)
check("unknown game refused", "unknown game" in (raises("select get_leaderboard('ludo')") or ""))

stats = q("select get_player_stats(%s)", ann)[0][0]
check("stats carry the rating", stats["chess_rating"] == rating(ann)[0] and stats["checkers_rating"] == 980, stats)
stats = q("select get_player_stats(%s)", eve)[0][0]
check("no checkers rating until played", stats["checkers_rating"] is None, stats)

# Deleting an account deletes its ratings.
admin("select anonymize_account(%s)", dan)
check("deleted accounts leave the board", rating(dan) is None)
check("and their changes go", admin("select count(*) from rating_changes where user_id = %s", dan)[0][0] == 0)

print("ALL PASSED" if not fails else f"{len(fails)} FAILED: {fails}")
sys.exit(1 if fails else 0)
