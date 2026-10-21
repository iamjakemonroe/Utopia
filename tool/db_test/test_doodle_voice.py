"""Voice notes in Guess My Doodle (20261021390000_doodle_voice.sql): anyone
between turns; while someone draws, only those who know the word, heard
only by each other; the recordings only for the room's players."""
import sys
import uuid

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


def sent(res):
    return res == "ok" or isinstance(res, list)


def note(game, ext="m4a"):
    return f"voice:{game}/{uuid.uuid4()}.{ext}|3200|1234567890123"


ada, bo, cy, dee = (harness.new_user(db, f"{n}@example.com") for n in ("ada", "bo", "cy", "dee"))
harness.as_user(db, ada)
made = one("select create_doodle_game(false, 3, 80)")
game, code = made["id"], made["code"]
for p in (bo, cy):
    harness.as_user(db, p)
    one("select join_doodle_game(%s)", code)


def last_voice():
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("select sender_id::text, audience from doodle_messages"
                  " where game_id = %s and kind = 'voice' order by id desc limit 1", (game,))
        return c.fetchone()


check("in the lobby, anyone talks", sent(attempt(bo, "select send_doodle_voice(%s, %s)", game, note(game))))
check("…to everyone", last_voice() == (bo, "all"))
check("a browser's WAV is fine too",
      sent(attempt(cy, "select send_doodle_voice(%s, %s)", game, note(game, "wav"))))
check("a note from another game's folder isn't",
      attempt(cy, "select send_doodle_voice(%s, %s)", game, note(uuid.uuid4())) == "invalid voice note")
check("someone not in the room can't",
      attempt(dee, "select send_doodle_voice(%s, %s)", game, note(game)) == "not in this game")

harness.as_user(db, ada)
one("select start_doodle_game(%s)", game)
harness.as_admin(db)
drawer = str(one("select drawer_id from doodle_games where id = %s", game))
others = [p for p in (ada, bo, cy) if p != drawer]
with db.cursor() as c:
    c.execute("update doodle_games set status = 'drawing' where id = %s", (game,))

check("while someone draws, a guesser can't talk yet",
      attempt(others[0], "select send_doodle_voice(%s, %s)", game, note(game)) == "guess the word first")
check("the drawer can, heard only by those who know the word",
      sent(attempt(drawer, "select send_doodle_voice(%s, %s)", game, note(game)))
      and last_voice() == (drawer, "guessed"))
harness.as_admin(db)
with db.cursor() as c:
    c.execute("update doodle_players set guessed_turn = (select turn from doodle_games where id = %s)"
              " where game_id = %s and user_id = %s", (game, game, others[0]))
check("once they've guessed it, they can too, to the same few",
      sent(attempt(others[0], "select send_doodle_voice(%s, %s)", game, note(game)))
      and last_voice() == (others[0], "guessed"))
harness.as_user(db, others[1])
heard = one("select count(*) from doodle_messages where game_id = %s and kind = 'voice' and audience = 'guessed'", game)
check("…and the one still guessing hears none of it", heard == 0, heard)

for _ in range(3):
    attempt(drawer, "select send_doodle_voice(%s, %s)", game, note(game))
check("a flood of notes is slowed", attempt(drawer, "select send_doodle_voice(%s, %s)", game, note(game)) == "slow down")

harness.as_user(db, bo)
check("the room's players can reach its recordings", one("select public._is_ludo_voice_folder(%s)", str(game)) is True)
harness.as_user(db, dee)
check("…no one else", one("select public._is_ludo_voice_folder(%s)", str(game)) is False)

sys.exit(1 if fails else 0)
