"""Chip draws, you guess: the shared deck of Chip's doodles."""
import sys

import harness

db = harness.fresh()
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


def claim():
    return admin("select _chip_doodle_claim()")[0][0]


def ready(word):
    admin("update chip_doodles set status = 'ready', strokes = array['M 100 100 L 900 900'] where word = %s", word)


def pick(user, fresh_only=True):
    rows = admin("select word, strokes, fresh from _chip_doodle_pick(%s, %s)", user, fresh_only)
    return rows[0] if rows else None


ann, bob = (harness.new_user(db, f"{n}@example.com") for n in ("ann", "bob"))

# Claiming words to draw.
w1 = claim()
level = admin("select level from doodle_words where word = %s", w1)[0][0]
check("everyday words are drawn first", level == 1, (w1, level))
check("a claimed word is being drawn", admin("select status from chip_doodles where word = %s", w1)[0][0] == "drawing")
w2 = claim()
check("each claim is a new word", w2 not in (None, w1), (w1, w2))
admin("update chip_doodles set updated_at = now() - interval '11 minutes' where word = %s", w1)
check("a stuck drawing is tried again", claim() == w1)
admin("update chip_doodles set status = 'failed', updated_at = now() where word = %s", w2)
w3 = claim()
check("a fresh failure waits", w3 != w2, w3)
admin("update chip_doodles set updated_at = now() - interval '25 hours' where word = %s", w2)
check("a day-old failure is tried again", claim() == w2)

# Rounds.
for w in (w1, w2, w3):
    ready(w)
check("a ready doodle is dealt", pick(bob) is not None)
got = set()
for _ in range(3):
    r = pick(ann)
    check("a fresh doodle, with its strokes", r is not None and r[2] and r[1] == ["M 100 100 L 900 900"], r)
    got.add(r[0])
check("all three, no repeats", got == {w1, w2, w3}, got)
check("no fresh ones left", pick(ann) is None)
admin("update chip_doodle_seen set seen_at = now() - interval '1 hour' where user_id = %s and word = %s", ann, w2)
r = pick(ann, False)
check("then the one seen longest ago", r is not None and r[0] == w2 and r[2] is False, r)
admin("update chip_doodles set status = 'drawing' where word = %s", w3)
check("only ready doodles are dealt", all(pick(ann, False)[0] != w3 for _ in range(4)))

# Out of reach of players.
harness.as_user(db, ann)
check("players can't read the doodles", raises("select * from chip_doodles") is not None)
check("or deal themselves rounds", raises("select * from _chip_doodle_pick(%s, true)", ann) is not None)
check("or claim words", raises("select _chip_doodle_claim()") is not None)

# The allowance.
harness.as_user(db, ann)
takes = [q("select chip_take('doodle')")[0][0] for _ in range(7)]
check("6 new doodles a day", takes == [True] * 6 + [False], takes)

# Every word drawn: nothing left to claim.
admin("insert into chip_doodles (word, status) select word, 'ready' from doodle_words on conflict (word) do update set status = 'ready'")
check("nothing to claim once every word is drawn", claim() is None)

admin("select anonymize_account(%s)", ann)
check("deleting an account forgets what they've seen",
      admin("select count(*) from chip_doodle_seen where user_id = %s", ann)[0][0] == 0)

print("ALL PASSED" if not fails else f"{len(fails)} FAILED: {fails}")
sys.exit(1 if fails else 0)
