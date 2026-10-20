"""Guess My Doodle rooms of up to 20 players, online and with friends; a
public room's rounds follow how many are in, a friends' room keeps the
host's."""
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


players = [harness.new_user(db, f"p{i}@example.com") for i in range(21)]

# A room of friends: 20 fit, the 21st doesn't.
harness.as_user(db, players[0])
made = one("select create_doodle_game(false, 4, 80)")
game, code = made["game"] if "game" in made else made["id"], made["code"]
for p in players[1:20]:
    harness.as_user(db, p)
    one("select join_doodle_game(%s)", code)
harness.as_admin(db)
check("a room of friends takes 20", one("select public._doodle_active(%s)", game) == 20)
check("…and says so", one("select max_players from doodle_games where id = %s", game) == 20)
harness.as_user(db, players[20])
try:
    one("select join_doodle_game(%s)", code)
    full = False
except Exception as e:
    db.rollback() if not db.autocommit else None
    full = "full" in str(e)
check("…the 21st is turned away", full)
harness.as_user(db, players[0])
one("select start_doodle_game(%s)", game)
harness.as_admin(db)
check("…and plays the host's 4 rounds, however many are in",
      one("select rounds from doodle_games where id = %s", game) == 4)


# Public rooms: rounds by how many are in as a game begins.
def public_room(n):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("update doodle_players set left_at = now() where left_at is null")
        c.execute("update doodle_games set status = 'closed'")
    harness.as_user(db, players[0])
    room = one("select quick_play_doodle()")
    for p in players[1:n]:
        harness.as_user(db, p)
        one("select quick_play_doodle()")
    harness.as_admin(db)
    in_room = one("select public._doodle_active(%s)", room)
    with db.cursor() as c:
        c.execute("select public._doodle_begin(%s)", (room,))
    return in_room, one("select rounds from doodle_games where id = %s", room)


for n, rounds in [(5, 3), (10, 2), (20, 1)]:
    got = public_room(n)
    check(f"a public room of {n}: all in one room, {rounds} round(s)", got == (n, rounds), got)

sys.exit(1 if fails else 0)
