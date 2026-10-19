"""Friends online: checking in, seeing friends who are around, and only
friends."""
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


def run(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)


me = harness.new_user(db, "me@example.com")
friend = harness.new_user(db, "friend@example.com")
away = harness.new_user(db, "away@example.com")
stranger = harness.new_user(db, "stranger@example.com")
harness.as_admin(db)
for other in (friend, away):
    low, high = sorted([me, other])
    run("insert into friendships (user_low, user_high) values (%s, %s)", low, high)


def online_for(user):
    harness.as_user(db, user)
    return set(one("select friends_online()::text[]"))


check("nobody's around yet", online_for(me) == set())
for user in (friend, away, stranger):
    harness.as_user(db, user)
    run("select touch_presence()")
harness.as_admin(db)
run("update presence set seen_at = now() - interval '5 minutes' where user_id = %s", away)

check("a friend who checked in is online", friend in online_for(me))
check("a friend gone for 5 minutes isn't", away not in online_for(me))
check("someone who isn't a friend never shows", stranger not in online_for(me))
check("it goes both ways", me not in online_for(friend))
harness.as_user(db, me)
run("select touch_presence()")
check("…once I check in, my friend sees me", me in online_for(friend))
check("…and the stranger still sees nothing of me", me not in online_for(stranger))

harness.as_user(db, stranger)
try:
    one("select seen_at from presence where user_id = %s", me)
    read = True
except Exception:
    read = False
check("nobody can read when others were last on", not read)

sys.exit(1 if fails else 0)
