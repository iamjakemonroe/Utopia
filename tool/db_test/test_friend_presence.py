"""Friends online: checking in, seeing friends who are around, and only
friends; coming and going at once (presence_status, live to friends only),
and a quiet app swept offline after a minute."""
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


def status(user):
    harness.as_admin(db)
    return one("select online from presence_status where user_id = %s", user)


def changed(user):
    harness.as_admin(db)
    return one("select changed_at from presence_status where user_id = %s", user)


# Coming and going, at once.
check("checking in: online", status(me) is True)
was = changed(me)
harness.as_user(db, me)
run("select touch_presence()")
check("…checking in again changes nothing (no message to friends each beat)", changed(me) == was)
harness.as_user(db, me)
run("select go_offline()")
check("leaving the app: offline at once", status(me) is False)
check("…and gone from my friend's list", me not in online_for(friend))
harness.as_user(db, me)
run("select touch_presence()")
check("back: online again at once", status(me) is True and me in online_for(friend))

# Only friends hear about it (the live messages are read through this).
harness.as_user(db, friend)
check("a friend can see whether I'm online", one(
    "select online from presence_status where user_id = %s", me) is True)
harness.as_user(db, stranger)
check("a stranger can't", one("select count(*) from presence_status where user_id = %s", me) == 0)
harness.as_admin(db)
check("it's sent live (in the realtime publication)", one(
    "select count(*) from pg_publication_tables where pubname = 'supabase_realtime' "
    "and tablename = 'presence_status'") == 1)

# An app that stopped without saying.
harness.as_admin(db)
run("update presence set seen_at = now() - interval '70 seconds' where user_id = %s", friend)
run("select sweep_presence()")
check("quiet for over a minute: swept offline", status(friend) is False)
check("…and the sweep runs every 20 seconds", one(
    "select schedule from cron.job where jobname = 'sweep-presence'") == '20 seconds')

sys.exit(1 if fails else 0)
