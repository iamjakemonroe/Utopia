"""The gift PIN: set once (four digits, not an obvious one), kept only as a
hash no player can read, asked for on every gift, five wrong tries lock
gifts for 15 minutes, changed with the old one, and reset only in a
session just proved with a code from the account's email."""
import pathlib
import sys
import time
import uuid

import harness

db = harness.fresh()
fails = []
SQL = pathlib.Path(__file__).resolve().parents[1] / "sql"


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
        # (With no arguments, a script's % signs are left alone.)
        c.execute(sql, args) if args else c.execute(sql)


me = harness.new_user(db, "me@example.com")
friend = harness.new_user(db, "friend@example.com")
harness.as_admin(db)
low, high = sorted([me, friend])
run("insert into friendships (user_low, user_high) values (%s, %s)", low, high)
run("select _ledger_move(%s, 'admin_adjustment', 5000, null, '{}'::jsonb)", me)
friend_had = one("select balance from profiles where id = %s", friend)


def send(coins, pin):
    harness.as_user(db, me)
    return one("select send_coin_gift(%s, %s, %s, %s)", friend, coins, str(uuid.uuid4()), pin)


def set_pin(pin, current=None, user=None):
    harness.as_user(db, user or me)
    return one("select set_gift_pin(%s, %s)", pin, current)


def reset_pin(pin, amr=None):
    harness.as_user(db, me, {"amr": amr} if amr is not None else None)
    return one("select reset_gift_pin(%s)", pin)


def status():
    harness.as_user(db, me)
    return one("select gift_pin_status()")


# No PIN yet.
check("no PIN at first", status()["set"] is False)
harness.as_user(db, me)
check("…the allowance says so", one("select coin_gift_allowance()")["pin_set"] is False)
check("…and a gift asks for one first", send(100, "2580")["why"] == "no_pin")

# Choosing one.
for pin, why in [("123", "format"), ("12345", "format"), ("12a4", "format"), (None, "format"),
                 ("0000", "weak"), ("7777", "weak"), ("1234", "weak"), ("6789", "weak"),
                 ("9876", "weak"), ("3210", "weak")]:
    check(f"not {pin!r}: {why}", set_pin(pin)["why"] == why)
check("2580 will do", set_pin("2580")["ok"])
check("…it's set", status()["set"] is True)
harness.as_admin(db)
stored = one("select pin_hash from gift_pins where user_id = %s", me)
check("…kept only as a hash", stored and "2580" not in stored, stored)
harness.as_user(db, me)
try:
    one("select pin_hash from gift_pins")
    read = True
except Exception:
    read = False
check("…which no player can read", not read)
guest = harness.new_user(db)
check("a guest can't have one (they can't send gifts)", set_pin("2580", user=guest)["why"] == "guest")

# Every gift asks for it.
check("the right PIN sends", send(100, "2580")["ok"])
wrong = send(100, "1111")
check("a wrong one doesn't, and says how many tries are left",
      wrong["why"] == "wrong_pin" and wrong["tries_left"] == 4, wrong)
check("…the right one again goes through (and the count starts over)", send(100, "2580")["ok"])
for i in range(4):
    send(100, "1111")
locked = send(100, "1111")
check("five wrong in a row lock gifts", locked["why"] == "locked" and locked["locked_until"], locked)
check("…even the right PIN waits", send(100, "2580")["why"] == "locked")
check("…the status says until when", status()["locked_until"] is not None)
harness.as_admin(db)
run("update gift_pins set locked_until = now() - interval '1 second' where user_id = %s", me)
check("after the 15 minutes, the right PIN works", send(100, "2580")["ok"])
harness.as_admin(db)
check("…and only the right ones moved coins (three gifts of 100)",
      one("select balance from profiles where id = %s", friend) == friend_had + 300
      and one("select count(*) from coin_gifts where to_user = %s", friend) == 3)

# Changing it.
check("changing it needs the current one", set_pin("4826")["why"] == "wrong_pin")
check("…a wrong current one is a wrong try", set_pin("4826", "1111")["tries_left"] == 3)
check("…with the right one it changes", set_pin("4826", "2580")["ok"])
check("…the old one no longer sends", send(100, "2580")["why"] == "wrong_pin")
check("…the new one does", send(100, "4826")["ok"])

# Forgotten: a new one, only in a session just proved by email.
now = int(time.time())
check("not without proving the email", reset_pin("1590")["why"] == "verify")
check("not in a session signed in with a password",
      reset_pin("1590", [{"method": "password", "timestamp": now}])["why"] == "verify")
check("not with a code from 20 minutes ago",
      reset_pin("1590", [{"method": "otp", "timestamp": now - 1200}])["why"] == "verify")
check("not with something that isn't a list", reset_pin("1590", "otp")["why"] == "verify")
check("still not an obvious one", reset_pin("1111", [{"method": "otp", "timestamp": now}])["why"] == "weak")
for i in range(5):
    send(100, "0001")
check("(locked again)", send(100, "4826")["why"] == "locked")
check("with a code from the email just now, a new one",
      reset_pin("1590", [{"method": "otp", "timestamp": now}])["ok"])
check("…which works at once, the lock gone", send(100, "1590")["ok"])
check("a link from the email does too",
      reset_pin("3571", [{"method": "magiclink", "timestamp": now - 60}])["ok"]
      and send(100, "3571")["ok"])

# The team's ready_for_gifts script can set one for a test account.
tester = harness.new_user(db, "tester@example.com")
harness.as_admin(db)
sql = (SQL / "ready_for_gifts.sql").read_text()
sql = sql.replace("'their_username'", "'tester@example.com'").replace("v_pin text := ''", "v_pin text := '8642'")
run(sql)
harness.as_user(db, tester)
check("ready_for_gifts sets a test account's PIN", one("select gift_pin_status()")["set"] is True)
harness.as_admin(db)
bad = (SQL / "ready_for_gifts.sql").read_text()
bad = bad.replace("'their_username'", "'tester@example.com'").replace("v_pin text := ''", "v_pin text := '1234'")
try:
    run(bad)
    refused = False
except Exception as e:
    refused = "won't do" in str(e)
check("…but not an obvious one", refused)

sys.exit(1 if fails else 0)
