"""tool/sql/ready_for_gifts.sql: a new account made ready to test sending
coins (dated past the wait, coins added, friends with whoever's named),
and the ones it can't be: guests, themselves, house players."""
import pathlib
import sys
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


def ready(who, friend="", coins=None):
    harness.as_admin(db)
    sql = (SQL / "ready_for_gifts.sql").read_text()
    sql = sql.replace("'their_username'", "'" + who + "'")
    sql = sql.replace("v_friend text := ''", "v_friend text := '" + friend + "'")
    if coins is not None:
        sql = sql.replace("v_coins int := 2000", f"v_coins int := {coins}")
    with db.cursor() as c:
        c.execute(sql)


def refused(name, words, *args, **kwargs):
    try:
        ready(*args, **kwargs)
        check(name, False, "it ran")
    except Exception as e:
        db.rollback() if not db.autocommit else None
        check(name, words in str(e), e)


def send(sender, to, coins):
    harness.as_user(db, sender)
    return one("select send_coin_gift(%s, %s, %s)", to, coins, str(uuid.uuid4()))


me = harness.new_user(db, "tester@example.com")
pal = harness.new_user(db, "pal@example.com")
harness.as_user(db, me)
check("a new account can't send yet", one("select coin_gift_allowance()")["why"] == "new")
harness.as_admin(db)
had = one("select balance from profiles where id = %s", me)
with db.cursor() as c:
    c.execute("insert into friend_requests (from_user, to_user) values (%s, %s)", (pal, me))

ready("Tester@Example.com", "pal@example.com")
harness.as_user(db, me)
allow = one("select coin_gift_allowance()")
check("by email: ready to send", allow["ok"] and allow["giftable"] == had + 2000, allow)
harness.as_admin(db)
low, high = sorted([me, pal])
check("…friends with the one named",
      one("select count(*) from friendships where user_low = %s and user_high = %s", low, high) == 1)
check("…their request answered",
      one("select status::text from friend_requests where from_user = %s and to_user = %s", pal, me) == "accepted")
gift = send(me, pal, 500)
check("…and a gift goes through", gift["ok"] and gift["coins"] == 500, gift)

harness.as_admin(db)
joined = one("select created_at from profiles where id = %s", me)
ready(me, coins=0)
harness.as_admin(db)
check("run again (by user ID, no coins): the date never moves forward, no coins added",
      one("select created_at from profiles where id = %s", me) == joined
      and one("select balance from profiles where id = %s", me) == had + 1500)

guest = harness.new_user(db)
refused("a guest is refused (accounts only)", "is a guest", guest)
refused("an unknown player is refused", "No account matches", "nobody@example.com")
refused("an unknown friend is refused", "No account matches friend", "tester@example.com", "nobody@example.com")
refused("not friends with themselves", "themselves", "tester@example.com", "tester@example.com")
harness.as_admin(db)
house = one("select id::text from house_players limit 1")
refused("not with a house player", "house player", "tester@example.com", house)

sys.exit(1 if fails else 0)
