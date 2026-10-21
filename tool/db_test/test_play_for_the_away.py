"""Away from a game by accident (20261021370000_play_for_the_away.sql):
online Ludo and Crazy Eights play an away player's turns for them and
keep them in, however long they're gone; Guess My Doodle finds the room a
player was dropped from, and lets them back in with their points."""
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
    harness.as_user(db, user)
    try:
        with db.cursor() as c:
            c.execute(sql, args)
            try:
                return c.fetchall()
            except Exception:
                return "ok"
    except Exception as e:
        return str(e).split("\n")[0]


ada, bo, cy = (harness.new_user(db, f"{n}@example.com") for n in ("ada", "bo", "cy"))

# ── Ludo: the careful move ────────────────────────────────────────────────
HOME = 56
COLORS = ["red", "green", "yellow", "blue"]


def ludo_state(tokens, turn="red"):
    colors = list(tokens)
    return {
        "board": "classic", "players": colors, "tokens": tokens, "turn": turn,
        "dice_value": None, "has_rolled": False, "consecutive_sixes": 0,
        "winner": None, "left": [], "finished": [], "roll_seq": 0,
        "last_roll": None, "capture": None,
    }


def pick(tokens, dice):
    harness.as_admin(db)
    return one("select public._ludo_pick(%s::jsonb, %s)", json.dumps(ludo_state(tokens)), dice)


check("a six: out of the yard before a step along",
      pick({"red": [-1, 10, -1, -1], "green": [-1] * 4}, 6) == 0)
check("not a six: the one piece that can move",
      pick({"red": [-1, 10, -1, -1], "green": [-1] * 4}, 3) == 1)
check("one that gets home comes first",
      pick({"red": [HOME - 2, 30, -1, -1], "green": [-1] * 4}, 2) == 0)
# Red's square 20 is the ring's 20; green starts at 13, so green's 7 is
# there too (and not a safe square).
check("a capture beats everything",
      pick({"red": [HOME - 3, 17, -1, -1], "green": [7, -1, -1, -1]}, 3) == 1)
check("nothing can move: none",
      pick({"red": [-1] * 4, "green": [-1] * 4}, 4) is None)


# ── Ludo: away, and played for ────────────────────────────────────────────
def new_match(players, st):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute(
            "insert into ludo_matches (status, stake, commission_bps, players, colors, state, mode, started_at)"
            " values ('active', 0, 0, %s::uuid[], %s, %s, 'public', now()) returning id",
            (players, COLORS[:len(players)], json.dumps(st)))
        return str(c.fetchone()[0])


def row(match):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("select status::text, state, turn_count, missed_turns"
                  " from ludo_matches where id = %s", (match,))
        return c.fetchone()


def rig(match, **changes):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("update ludo_matches set state = state || %s::jsonb where id = %s",
                  (json.dumps(changes), match))


def skip(user, match, seconds=20):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("update ludo_matches set updated_at = now() - make_interval(secs => %s)"
                  " where id = %s", (seconds, match))
    r = row(match)
    return attempt(user, "select skip_ludo_turn(%s, %s, %s)",
                   match, r[2], r[1].get("roll_seq", 0))


m = new_match([ada, bo], ludo_state({"red": [-1, 10, -1, -1], "green": [-1] * 4}))
rig(m, dice_value=3, has_rolled=True)
skip(bo, m)
st = row(m)[1]
check("red rolled a 3 and went quiet: the piece that can move is moved",
      st["tokens"]["red"] == [-1, 13, -1, -1] and st["turn"] == "green", st)
check("…and red is counted away once", row(m)[3].get("red") == 1)
check("…the move is in red's history",
      one("select count(*) from ludo_moves where match_id = %s and player_id = %s", m, ada) == 1)

for i in range(5):
    rig(m, turn="red", dice_value=None, has_rolled=False)
    skip(bo, m)
st = row(m)[1]
check("five more turns gone by: red is still in", row(m)[0] == "active" and st["left"] == [], st["left"])
check("…each one rolled for red", st["last_roll"]["color"] == "red")
check("…and red is counted away six times", row(m)[3].get("red") == 6, row(m)[3])

rig(m, turn="red", dice_value=None, has_rolled=False)
check("red's back and rolls", attempt(ada, "select roll_ludo_dice(%s)", m) != "not your turn")
check("…and isn't away any more", row(m)[3].get("red") is None, row(m)[3])

check("rolling for someone else isn't a thing players can do",
      "permission denied" in str(attempt(bo, "select public._ludo_roll(%s, %s)", m, ada)))
check("…nor moving for them",
      "permission denied" in str(attempt(bo, "select public._ludo_move(%s, %s, 0)", m, ada)))

# ── Crazy Eights: the careful card ────────────────────────────────────────
def epick(hand, top, suit):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("select card, suit from public._eights_pick(%s, %s, %s)", (hand, top, suit))
        return c.fetchone()


check("a card that goes, of the suit held most",
      epick(["2C", "5H", "3C", "9S"], "9H", "H") in (("9S", None), ("5H", None)))
check("…the suit held most wins a tie of goers",
      epick(["2C", "3C", "4C", "KH", "9H"], "9C", "C")[0] in ("2C", "3C", "4C"))
check("an eight only when nothing else goes, naming the suit held most",
      epick(["8D", "2C", "3C", "KS"], "9H", "H") == ("8D", "C"))
check("only eights: names its own suit", epick(["8D"], "9H", "H") == ("8D", "D"))
check("nothing goes: none", epick(["2C", "3S"], "9H", "H") is None)

# ── Guess My Doodle: back to the room you dropped from ────────────────────
harness.as_user(db, ada)
made = one("select create_doodle_game(false, 3, 80)")
game, code = made["id"], made["code"]
for p in (bo, cy):
    harness.as_user(db, p)
    one("select join_doodle_game(%s)", code)
harness.as_user(db, ada)
one("select start_doodle_game(%s)", game)
harness.as_admin(db)
with db.cursor() as c:
    c.execute("update doodle_players set score = 240 where game_id = %s and user_id = %s", (game, bo))
    # Bo's phone went quiet, and the game noticed.
    c.execute("update doodle_presence set last_seen = now() - interval '2 minutes'"
              " where game_id = %s and user_id = %s", (game, bo))
    c.execute("select public._doodle_advance(%s)", (game,))
dropped = one("select left_at is not null and not left_by_self from doodle_players"
              " where game_id = %s and user_id = %s", game, bo)
check("bo went quiet: dropped from the room", dropped)
check("…and the app still finds it for him",
      str(attempt(bo, "select my_doodle_game()")[0][0]) == str(game))
attempt(bo, "select tick_doodle(%s)", game)
harness.as_admin(db)
check("checking in puts him back, with his 240 points",
      one("select left_at is null and score = 240 from doodle_players"
          " where game_id = %s and user_id = %s", game, bo))

harness.as_user(db, bo)
one("select leave_doodle_game(%s)", game)
check("leaving on purpose: no way back offered",
      attempt(bo, "select my_doodle_game()")[0][0] is None)

harness.as_admin(db)
with db.cursor() as c:
    c.execute("update doodle_players set left_by_self = false where game_id = %s and user_id = %s",
              (game, bo))
    c.execute("update doodle_games set status = 'closed' where id = %s", (game,))
check("a room that's closed isn't offered",
      attempt(bo, "select my_doodle_game()")[0][0] is None)

sys.exit(1 if fails else 0)
