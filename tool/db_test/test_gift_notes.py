"""A note with a gift (20261021330000_gift_notes.sql): optional, kept with
the gift, cleaned on the way in, at most 140 characters (a longer one is
turned away before the PIN costs a try), and shown to the friend in their
notification. An app that sends none works as before."""
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
        c.execute(sql, args) if args else c.execute(sql)
        rows = c.fetchall()
        return rows[0][0] if rows else None


me = harness.new_user(db, "me@example.com")
friend = harness.new_user(db, "friend@example.com")
harness.as_admin(db)
low, high = sorted([me, friend])
one("insert into friendships (user_low, user_high) values (%s, %s) returning 1", low, high)
one("select _ledger_move(%s, 'admin_adjustment', 5000, null, '{}'::jsonb) is not null", me)
harness.as_user(db, me)
one("select set_gift_pin('2580')")


def send(coins, note=None, key=None, pin="2580", old_app=False):
    harness.as_user(db, me)
    key = key or str(uuid.uuid4())
    if old_app:
        return one("select send_coin_gift(%s, %s, %s, %s)", friend, coins, key, pin)
    return one("select send_coin_gift(%s, %s, %s, %s, %s)", friend, coins, key, pin, note)


def stored(gift):
    harness.as_admin(db)
    return one("select note from coin_gifts where id = %s", gift)


def told(gift):
    harness.as_admin(db)
    return one("select data from notifications where kind = 'coin_gift' and ref_id = %s", gift)


r = send(100, "Happy birthday!")
check("a gift with a note goes", r["ok"] and r["note"] == "Happy birthday!", r)
check("…kept with the gift", stored(r["gift"]) == "Happy birthday!")
check("…and your friend's told it", told(r["gift"]) == {"coins": 100, "note": "Happy birthday!"},
      told(r["gift"]))
harness.as_user(db, friend)
check("…which they can read", one("select note from coin_gifts where id = %s", r["gift"]) == "Happy birthday!")

r = send(100)
check("no note: the gift goes as before", r["ok"] and r["note"] is None, r)
check("…nothing kept", stored(r["gift"]) is None)
check("…and the notification has no note", told(r["gift"]) == {"coins": 100}, told(r["gift"]))

r = send(100, old_app=True)
check("an app that doesn't send a note still works", r["ok"] and stored(r["gift"]) is None, r)

for note, why in [("   ", "only spaces"), ("​‍", "only invisible"), ("", "empty")]:
    r = send(50, note)
    check(f"{why}: no note", r["ok"] and stored(r["gift"]) is None, (r, stored(r["gift"])))

r = send(50, "  for   the\n\nrematch ‮!  ")
check("cleaned: one space, no invisible marks, trimmed", stored(r["gift"]) == "for the rematch !",
      repr(stored(r["gift"])))

r = send(50, "\U0001F382 gg été")
check("emoji and accents stay", stored(r["gift"]) == "\U0001F382 gg été", repr(stored(r["gift"])))

r = send(50, "x" * 140)
check("140 characters is fine", r["ok"] and len(stored(r["gift"])) == 140, r)

harness.as_admin(db)
balance = one("select balance from profiles where id = %s", me)
r = send(50, "x" * 141, pin="9999")
check("141 is too long", r == {"ok": False, "why": "note_long"}, r)
harness.as_admin(db)
check("…nothing sent", one("select balance from profiles where id = %s", me) == balance)
check("…and the (wrong) PIN wasn't even tried",
      one("select coalesce(tries, 0) from gift_pins where user_id = %s", me) == 0)

key = str(uuid.uuid4())
first = send(70, "once", key=key)
again = send(70, "a different note", key=key)
check("a retry gives the same answer, note and all",
      again.get("again") and again["gift"] == first["gift"] and again["note"] == "once", again)

harness.as_user(db, me)
try:
    one("insert into coin_gifts (from_user, to_user, coins, client_key, note) values (%s, %s, 1, %s, 'x')",
        me, friend, str(uuid.uuid4()))
    wrote = True
except Exception:
    wrote = False
check("players can't write gifts (or notes) directly", not wrote)

sys.exit(1 if fails else 0)
