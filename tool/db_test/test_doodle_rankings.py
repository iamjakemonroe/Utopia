"""Rankings for Guess My Doodle: public games played to the end."""
import sys

import harness

db = harness.fresh()
fails = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


def admin(sql, *args):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute(sql, args) if args else c.execute(sql)
        try:
            return c.fetchall()
        except Exception:
            return None


codes = iter(f"GAME{i:02d}" for i in range(99))


def play(scores, public=True, finished=True, left=(), game=None, turn=9):
    """A doodle game ending with these {user: score}; returns its id."""
    host = next(iter(scores))
    if game is None:
        game = admin("""insert into doodle_games (code, is_public, host_id, status, rounds, round, turn)
                        values (%s, %s, %s, 'drawing', 3, %s, %s) returning id""",
                     next(codes), public, host, 3 if finished else 2, turn)[0][0]
        for seq, (user, score) in enumerate(scores.items()):
            admin("insert into doodle_players (game_id, user_id, score, join_seq, left_at) values (%s, %s, %s, %s, %s)",
                  game, user, score, seq, "now()" if user in left else None)
    else:
        admin("update doodle_games set status = 'drawing', turn = %s where id = %s", turn, game)
        for user, score in scores.items():
            admin("update doodle_players set score = %s where game_id = %s and user_id = %s", score, game, user)
    admin("update doodle_games set status = 'over' where id = %s", game)
    return game


def rating(user):
    row = admin("select rating, games, wins, losses from player_ratings where user_id = %s and game = 'doodle'", user)
    return tuple(row[0]) if row else None


ann, bob, cat, dan = (harness.new_user(db, f"{n}@example.com") for n in ("ann", "bob", "cat", "dan"))

g = play({ann: 300, bob: 200, cat: 100})
check("first place gains", rating(ann)[0] > 1000, rating(ann))
check("the middle of evens stays put", rating(bob)[0] == 1000, rating(bob))
check("last place drops", rating(cat)[0] < 1000, rating(cat))
check("a win is first place", rating(ann)[2:] == (1, 0) and rating(bob)[2:] == (0, 1), (rating(ann), rating(bob)))
check("the change is kept", admin("select count(*) from rating_changes where game = 'doodle'")[0][0] == 3)

play({ann: 100, bob: 200}, game=g, turn=20)
check("a public room's next game is rated too", rating(bob)[1] == 2 and rating(bob)[0] > 1000, rating(bob))

before = (rating(ann), rating(bob))
play({ann: 500, bob: 0}, public=False)
check("private rooms aren't rated", (rating(ann), rating(bob)) == before)
play({ann: 500, bob: 0}, finished=False)
check("games stopped early aren't rated", (rating(ann), rating(bob)) == before)
play({ann: 500, dan: 0}, left=(dan,))
check("one player left: not rated", rating(dan) is None and rating(ann) == before[0])
eve, fay = (harness.new_user(db, f"{n}@example.com") for n in ("eve", "fay"))
play({eve: 0, fay: 0})
check("a tie between equals moves nobody", rating(eve)[0] == 1000 == rating(fay)[0], (rating(eve), rating(fay)))
check("and nobody wins a game no one scored in", rating(eve)[2] == 0, rating(eve))

harness.as_user(db, ann)
admin("update player_ratings set games = 5 where game = 'doodle'")
harness.as_user(db, ann)
with db.cursor() as c:
    c.execute("select get_leaderboard('doodle')")
    board = c.fetchone()[0]
    c.execute("select get_player_stats(%s)", (ann,))
    stats = c.fetchone()[0]
check("doodle has a board", len(board["top"]) == 5 and board["me"]["place"] is not None, board)
check("stats carry the doodle rating", stats["doodle_rating"] == rating(ann)[0], stats)

print("ALL PASSED" if not fails else f"{len(fails)} FAILED: {fails}")
sys.exit(1 if fails else 0)
