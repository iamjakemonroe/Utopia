"""Friends' birthdays: friends are told, and can wish them happy birthday."""
import datetime as dt
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


def befriend(a, b):
    lo, hi = sorted([a, b])
    admin("insert into friendships (user_low, user_high) values (%s, %s)", lo, hi)


def notes(user, kind):
    return admin("select count(*) from notifications where user_id = %s and kind = %s", user, kind)[0][0]


ann, bob, cat, dan = (harness.new_user(db, f"{n}@example.com") for n in ("ann", "bob", "cat", "dan"))
befriend(ann, bob)
befriend(ann, dan)
today = dt.datetime.now(dt.timezone.utc).date()
far = today + dt.timedelta(days=90)

harness.as_user(db, ann)
q("select set_birthday(%s, %s)", today.month, today.day)
q("select start_birthday(now() + interval '5 hours')")
check("friends are told", notes(bob, "friend_birthday") == 1 and notes(dan, "friend_birthday") == 1)
check("strangers aren't", notes(cat, "friend_birthday") == 0)
harness.as_user(db, ann)
q("select start_birthday(now() + interval '5 hours')")
check("once a year", notes(bob, "friend_birthday") == 1)

harness.as_user(db, bob)
check("a friend can wish", raises("select wish_happy_birthday(%s)", ann) is None)
check("the wish arrives", notes(ann, "birthday_wish") == 1)
harness.as_user(db, bob)
q("select wish_happy_birthday(%s)", ann)
check("once each", notes(ann, "birthday_wish") == 1)
harness.as_user(db, cat)
check("strangers can't", "not friends" in (raises("select wish_happy_birthday(%s)", ann) or ""))
harness.as_user(db, bob)
q("select set_birthday(%s, %s)", far.month, far.day)
harness.as_user(db, ann)
check("not on another day", "not their birthday" in (raises("select wish_happy_birthday(%s)", bob) or ""))

# Keeping it quiet.
eve = harness.new_user(db, "eve@example.com")
befriend(eve, cat)
harness.as_user(db, eve)
q("select set_birthday(%s, %s)", today.month, today.day)
q("select set_birthday_sharing(false)")
q("select start_birthday(now() + interval '5 hours')")
check("quiet when sharing's off", notes(cat, "friend_birthday") == 0)
check("the party still starts", admin("select equipped_theme from profiles where id = %s", eve)[0][0] == "utopia_birthday")

print("ALL PASSED" if not fails else f"{len(fails)} FAILED: {fails}")
sys.exit(1 if fails else 0)
