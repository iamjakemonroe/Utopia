"""Ludo plays on after the first finisher (20261021340000_ludo_play_on.sql):
the first home is paid at once and the game goes on while two or more are
still racing; turns skip whoever's finished; a finisher can go without a
forfeit; the game ends (paying no one twice) once at most one is racing;
and a piece sent home can react "sad" or "again"."""
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
        return "ok"
    except Exception as e:
        return str(e).split("\n")[0]


HOME = 56  # the classic board's finish
COLORS = ["red", "green", "yellow", "blue"]


def state(n, turn="red", finished=(), winner=None, left=(), legacy=False):
    colors = COLORS[:n]
    tokens = {c: ([HOME] * 4 if c in finished else [-1, -1, -1, -1]) for c in colors}
    s = {
        "board": "classic", "players": colors, "tokens": tokens, "turn": turn,
        "dice_value": None, "has_rolled": False, "consecutive_sixes": 0,
        "winner": winner, "left": list(left), "roll_seq": 0,
        "last_roll": None, "capture": None,
    }
    if not legacy:
        s["finished"] = list(finished)
    return s


def new_match(players, stake=100):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute(
            "insert into ludo_matches (status, stake, commission_bps, players, colors, state, mode, started_at)"
            " values ('active', %s, 0, %s::uuid[], %s, %s, 'public', now()) returning id",
            (stake, players, COLORS[:len(players)], json.dumps(state(len(players)))))
        return str(c.fetchone()[0])


def row(match):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("select status::text, winner_id::text, state, turn_count, missed_turns"
                  " from ludo_matches where id = %s", (match,))
        return c.fetchone()


def balance(user):
    harness.as_admin(db)
    return one("select balance from profiles where id = %s", user)


def move(user, match, st):
    turn = row(match)[3] + 1
    return attempt(user, "select record_ludo_move(%s, %s, 6, 0, false, true, %s)",
                   match, turn, json.dumps(st))


def report(user, match, winner):
    return attempt(user, "select report_ludo_match_result(%s, %s, 'win')", match, winner)


def go_quiet(match, seconds=20):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("update ludo_matches set updated_at = now() - make_interval(secs => %s)"
                  " where id = %s", (seconds, match))


def skip(user, match):
    r = row(match)
    return attempt(user, "select skip_ludo_turn(%s, %s, %s)",
                   match, r[3], r[2].get("roll_seq", 0))


ada, bo, cy = (harness.new_user(db, f"{n}@example.com") for n in ("ada", "bo", "cy"))
start = {u: balance(u) for u in (ada, bo, cy)}

# ── Three at the table: red finishes first ─────────────────────────────────
m = new_match([ada, bo, cy])
check("red brings the last piece home",
      move(ada, m, state(3, turn="green", finished=["red"], winner="red")) == "ok")
check("…and the game goes on", row(m)[0] == "active")
report(ada, m, ada)
report(bo, m, ada)
check("two agreeing reports pay red the pot at once",
      balance(ada) - start[ada] == 300, balance(ada) - start[ada])
check("…with the game still on", row(m)[0] == "active" and row(m)[1] == ada)
report(cy, m, ada)
check("a third report pays no more", balance(ada) - start[ada] == 300)

check("red can go without a forfeit", attempt(ada, "select resign_ludo_match(%s)", m) == "ok")
st = row(m)[2]
check("…keeping their place and pieces",
      "red" not in st["left"] and st["tokens"]["red"] == [HOME] * 4 and st["finished"] == ["red"])

check("red's game counts for events now",
      attempt(ada, "select event_count_game('ludo', %s)", m) == "ok")
check("cy's doesn't yet (still racing)",
      attempt(cy, "select event_count_game('ludo', %s)", m) == "not a finished game of yours")

go_quiet(m)
skip(bo, m)
check("green's time runs out: the turn goes to yellow", row(m)[2]["turn"] == "yellow")
go_quiet(m)
skip(bo, m)
check("yellow's runs out: back to green, past red", row(m)[2]["turn"] == "green")

# A turn stuck on someone who's finished passes on, and no one missed it.
harness.as_admin(db)
with db.cursor() as c:
    c.execute("update ludo_matches set state = jsonb_set(state, '{turn}', '\"red\"'),"
              " missed_turns = '{}' where id = %s", (m,))
go_quiet(m)
skip(cy, m)
check("a turn stuck on red moves on to green", row(m)[2]["turn"] == "green")
check("…and red isn't counted as missing it", "red" not in row(m)[4])

check("green comes home second: the game's over",
      move(bo, m, state(3, turn="green", finished=["red", "green"], winner="red")) == "ok"
      and row(m)[0] == "completed")
check("…red still the winner", row(m)[1] == ada)
check("…and no one else was paid",
      balance(bo) == start[bo] and balance(cy) == start[cy] and balance(ada) - start[ada] == 300)
check("cy's game counts once it's over",
      attempt(cy, "select event_count_game('ludo', %s)", m) == "ok")

# ── Someone leaves after red finished: the game ends, red keeps the pot ───
b = {u: balance(u) for u in (ada, bo, cy)}
m2 = new_match([ada, bo, cy])
move(ada, m2, state(3, turn="green", finished=["red"], winner="red"))
report(ada, m2, ada)
report(cy, m2, ada)
check("bo leaves: only cy is racing, so it's over",
      attempt(bo, "select resign_ludo_match(%s)", m2) == "ok" and row(m2)[0] == "completed")
check("…red keeps the pot and cy gets nothing",
      balance(ada) - b[ada] == 300 and balance(cy) == b[cy], (balance(ada) - b[ada], balance(cy) - b[cy]))

# ── …or leaves before the reports agreed: the first home is still paid ───
b = {u: balance(u) for u in (ada, bo, cy)}
m3 = new_match([ada, bo, cy])
move(ada, m3, state(3, turn="green", finished=["red"], winner="red"))
attempt(bo, "select resign_ludo_match(%s)", m3)
check("bo leaves before anyone reported: red is paid, not cy",
      row(m3)[0] == "completed" and row(m3)[1] == ada
      and balance(ada) - b[ada] == 300 and balance(cy) == b[cy])

# ── No one home yet: leaving works as before ──────────────────────────────
b = {u: balance(u) for u in (ada, bo, cy)}
m4 = new_match([ada, bo, cy])
attempt(ada, "select resign_ludo_match(%s)", m4)
check("one of three leaves early: the others play on", row(m4)[0] == "active")
check("…and the turn moved past them", row(m4)[2]["turn"] == "green")
attempt(bo, "select resign_ludo_match(%s)", m4)
check("two leave: the last one standing wins the pot",
      row(m4)[0] == "completed" and row(m4)[1] == cy and balance(cy) - b[cy] == 300)

# ── Two players: over as soon as one is home, as before ───────────────────
b = {u: balance(u) for u in (ada, bo)}
m5 = new_match([ada, bo])
move(ada, m5, state(2, turn="red", finished=["red"], winner="red"))
check("two players: still waiting on the reports", row(m5)[0] == "active")
report(ada, m5, ada)
report(bo, m5, ada)
check("…then it's over and paid", row(m5)[0] == "completed" and balance(ada) - b[ada] == 200)

# A game saved before `finished` existed still settles.
m6 = new_match([ada, bo])
move(ada, m6, state(2, turn="red", winner="red", legacy=True))
report(ada, m6, ada)
report(bo, m6, ada)
check("an older game with only a winner still ends", row(m6)[0] == "completed")

# ── Over but never settled (everyone closed the app) ─────────────────────
b = {u: balance(u) for u in (ada, bo, cy)}
m7 = new_match([ada, bo, cy])
move(ada, m7, state(3, turn="green", finished=["red"], winner="red"))
move(bo, m7, state(3, turn="green", finished=["red", "green"], winner="red"))
check("over, but no reports came", row(m7)[0] == "active")
go_quiet(m7, 20 * 60)
harness.as_admin(db)
with db.cursor() as c:
    c.execute("select forfeit_abandoned_ludo_matches()")
check("the cleanup settles it for the first home",
      row(m7)[0] == "completed" and row(m7)[1] == ada and balance(ada) - b[ada] == 300
      and balance(bo) == b[bo])

# ── Reactions from the piece sent home ───────────────────────────────────
m8 = new_match([ada, bo])
for body in ("war", "peace", "sad", "again"):
    check(f"'{body}' is a reaction",
          attempt(bo, "select send_ludo_chat(%s, 'reaction', %s)", m8, body) == "ok")
check("anything else isn't",
      attempt(bo, "select send_ludo_chat(%s, 'reaction', 'boo')", m8) == "invalid reaction")

print()
print("FAILED: " + ", ".join(fails) if fails else "ALL PASS")
sys.exit(1 if fails else 0)
