"""Ludo's rules on the server (20261021360000_ludo_server_moves.sql): the
server rolls the die and works out every move, captures and wins included;
an app can't send its own board or report its own result any more."""
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
            rows = c.fetchall()
            return rows[0][0] if rows else None
    except Exception as e:
        return "ERR " + str(e).split("\n")[0]


COLORS4 = ["red", "green", "yellow", "blue"]


def initial(colors, board="classic"):
    return {
        "board": board, "players": colors,
        "tokens": {c: [-1, -1, -1, -1] for c in colors},
        "turn": colors[0], "dice_value": None, "has_rolled": False,
        "consecutive_sixes": 0, "winner": None, "finished": [], "left": [],
        "roll_seq": 0, "last_roll": None, "capture": None,
    }


def new_match(players, colors, stake=0, board="classic"):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute(
            "insert into ludo_matches (status, stake, commission_bps, players, colors, board, state, mode, started_at)"
            " values ('active', %s, 0, %s::uuid[], %s, %s, %s, 'public', now()) returning id",
            (stake, players, colors, board, json.dumps(initial(colors, board))))
        return str(c.fetchone()[0])


def state(m):
    harness.as_admin(db)
    return one("select state from ludo_matches where id = %s", m)


def row(m):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("select status::text, winner_id::text, turn_count from ludo_matches where id = %s", (m,))
        return c.fetchone()


def rig(m, **changes):
    """Sets the board up as a test needs it ({"tokens": {"red": [...]}} merges)."""
    st = state(m)
    for k, v in changes.items():
        if k == "tokens":
            st["tokens"].update(v)
        else:
            st[k] = v
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("update ludo_matches set state = %s where id = %s", (json.dumps(st), m))


def balance(user):
    harness.as_admin(db)
    return one("select balance from profiles where id = %s", user)


ada, bo = harness.new_user(db, "ada@example.com"), harness.new_user(db, "bo@example.com")
harness.as_admin(db)
with db.cursor() as c:
    c.execute("update profiles set balance = balance + 1000 where id in (%s, %s)", (ada, bo))

m = new_match([ada, bo], ["red", "yellow"], stake=100)

# ── rolling ───────────────────────────────────────────────────────────────
check("only the player on turn rolls",
      attempt(bo, "select roll_ludo_dice(%s)", m) == "ERR not your turn")
check("no moving before rolling",
      attempt(ada, "select move_ludo_token(%s, 0)", m) == "ERR roll first")

seen = set()
for _ in range(40):
    rig(m, turn="red", has_rolled=False, dice_value=None, consecutive_sixes=0,
        tokens={"red": [-1, -1, -1, -1]})
    before = state(m)["roll_seq"]
    r = attempt(ada, "select roll_ludo_dice(%s)", m)
    st = r["state"]
    v = st["last_roll"]["value"]
    seen.add(v)
    if not (1 <= v <= 6 and st["roll_seq"] == before + 1 and st["last_roll"]["color"] == "red"):
        check("a roll is 1 to 6, for everyone to see", False, st)
        break
    if v == 6 and not (st["has_rolled"] and st["dice_value"] == 6 and st["turn"] == "red"):
        check("a six out of the yard stands", False, st)
        break
    if v != 6 and not (not st["has_rolled"] and st["turn"] == "yellow"):
        check("anything else with all in the yard passes the turn", False, st)
        break
else:
    check("rolls are 1 to 6, shown to everyone; a roll no piece can use passes", True)
check("the server's die isn't stuck on one number", len(seen) >= 4, seen)

rig(m, turn="red", has_rolled=True, dice_value=4)
check("one roll a turn", attempt(ada, "select roll_ludo_dice(%s)", m) == "ERR already rolled")

# Three sixes in a row: void, and the turn passes.
for tries in range(300):
    rig(m, turn="red", has_rolled=False, dice_value=None, consecutive_sixes=2,
        tokens={"red": [5, -1, -1, -1]})
    st = attempt(ada, "select roll_ludo_dice(%s)", m)["state"]
    if st["last_roll"]["value"] == 6:
        check("a third six is void and the turn passes",
              st["turn"] == "yellow" and not st["has_rolled"] and st["consecutive_sixes"] == 0)
        break
else:
    check("a third six is void and the turn passes", False, "never rolled a six")

# ── moving ────────────────────────────────────────────────────────────────
rig(m, turn="red", has_rolled=True, dice_value=3, consecutive_sixes=0,
    tokens={"red": [-1, -1, -1, -1], "yellow": [-1, -1, -1, -1]})
check("out of the yard only on a six",
      attempt(ada, "select move_ludo_token(%s, 0)", m) == "ERR that piece can't move")
check("there are four pieces",
      attempt(ada, "select move_ludo_token(%s, 7)", m) == "ERR no such piece")

rig(m, dice_value=6, consecutive_sixes=1)
st = attempt(ada, "select move_ludo_token(%s, 0)", m)["state"]
check("a six brings a piece out onto its start square", st["tokens"]["red"][0] == 0)
check("…and another go", st["turn"] == "red" and not st["has_rolled"] and st["consecutive_sixes"] == 1)

# Red from 10 by 2 lands on square 12; yellow's piece 38 along its path is
# on square 12 too (yellow starts at 26).
rig(m, turn="red", has_rolled=True, dice_value=2, consecutive_sixes=0,
    tokens={"red": [10, -1, -1, -1], "yellow": [38, -1, -1, -1]}, capture=None)
st = attempt(ada, "select move_ludo_token(%s, 0)", m)["state"]
check("landing on someone sends them home", st["tokens"]["yellow"][0] == -1 and st["tokens"]["red"][0] == 12)
check("…recorded as a capture",
      st["capture"] == {"seq": 1, "by": "red", "token": 0, "victims": [{"color": "yellow", "token": 0}]})
check("…and a capture earns another go", st["turn"] == "red")

# Square 8 is a star (safe): red from 5 by 3; yellow at 34 is on square 8.
rig(m, turn="red", has_rolled=True, dice_value=3, tokens={"red": [5, -1, -1, -1], "yellow": [34, -1, -1, -1]})
st = attempt(ada, "select move_ludo_token(%s, 0)", m)["state"]
check("no captures on a safe square", st["tokens"]["yellow"][0] == 34 and st["tokens"]["red"][0] == 8)
check("…and a plain move passes the turn", st["turn"] == "yellow")

rig(m, turn="red", has_rolled=True, dice_value=4, tokens={"red": [53, -1, -1, -1]})
check("no going past home", attempt(ada, "select move_ludo_token(%s, 0)", m) == "ERR that piece can't move")
rig(m, turn="red", has_rolled=True, dice_value=6, tokens={"red": [50, -1, -1, -1]})
st = attempt(ada, "select move_ludo_token(%s, 0)", m)["state"]
check("up the home stretch and home", st["tokens"]["red"][0] == 56 and st["turn"] == "red")

# ── what apps used to send ────────────────────────────────────────────────
fake = initial(["red", "yellow"])
fake["tokens"]["red"] = [56, 56, 56, 56]
fake["winner"] = "red"
check("an app can't send its own board",
      attempt(ada, "select record_ludo_move(%s, 99, 6, 0, false, true, %s)", m, json.dumps(fake))
      == "ERR update Utopia to keep playing")
check("…or its own roll",
      attempt(ada, "select record_ludo_roll(%s, %s)", m, json.dumps(fake)) == "ERR update Utopia to keep playing")
attempt(ada, "select report_ludo_match_result(%s, %s, 'win')", m, ada)
attempt(bo, "select report_ludo_match_result(%s, %s, 'win')", m, ada)
check("…and reported results settle nothing", row(m)[0] == "active" and row(m)[1] is None)

# ── winning ───────────────────────────────────────────────────────────────
b = balance(ada)
rig(m, turn="red", has_rolled=True, dice_value=1, tokens={"red": [56, 56, 56, 55]})
r = attempt(ada, "select move_ludo_token(%s, 3)", m)
check("the last piece home wins", r["state"]["winner"] == "red" and r["state"]["finished"] == ["red"])
check("…the server settles it at once", row(m)[0] == "completed" and row(m)[1] == ada)
check("…and pays the pot", balance(ada) - b == 200, balance(ada) - b)

# ── the six-arm board ─────────────────────────────────────────────────────
players6 = [harness.new_user(db, f"p{i}@example.com") for i in range(6)]
colors6 = ["red", "orange", "yellow", "green", "blue", "purple"]
m6 = new_match(players6, colors6, board="hex")
rig(m6, turn="purple", has_rolled=True, dice_value=6, tokens={"purple": [76, -1, -1, -1]})
st = attempt(players6[5], "select move_ludo_token(%s, 0)", m6)["state"]
check("the six-arm board has a 78-square ring", st["tokens"]["purple"][0] == 82)
# Purple starts at 65; 2 along is square 67. Red's piece 67 along is there too.
rig(m6, turn="purple", has_rolled=True, dice_value=2, tokens={"purple": [0, -1, -1, -1], "red": [67, -1, -1, -1]})
st = attempt(players6[5], "select move_ludo_token(%s, 0)", m6)["state"]
check("…and captures across it", st["tokens"]["red"][0] == -1)

print()
print("FAILED: " + ", ".join(fails) if fails else "ALL PASS")
sys.exit(1 if fails else 0)
