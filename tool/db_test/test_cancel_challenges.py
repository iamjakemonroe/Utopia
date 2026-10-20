"""Taking back a sent challenge (20261021320000_cancel_challenges.sql):
only its sender, only while it waits, the friend's notification goes with
it, and challenging again replaces the one waiting."""
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


def challenge(sender, to, game="chess"):
    harness.as_user(db, sender)
    return str(one("select send_board_invite(%s, %s, 0, 10, 0)", to, game))


def status(invite):
    harness.as_admin(db)
    return one("select status::text from match_invites where id = %s", invite)


def notified(invite):
    harness.as_admin(db)
    return one("select count(*) from notifications where kind = 'game_invite' and ref_id = %s", invite)


ada = harness.new_user(db, "ada@example.com")
bo = harness.new_user(db, "bo@example.com")
cy = harness.new_user(db, "cy@example.com")
harness.as_admin(db)
with db.cursor() as c:
    c.execute("insert into presence_status (user_id, online) values (%s, true)", (ada,))

first = challenge(ada, bo)
check("bo is told", notified(first) == 1)
check("bo can't cancel ada's challenge",
      attempt(bo, "select cancel_match_invite(%s)", first) == "invite not found")
check("nor can anyone else", attempt(cy, "select cancel_match_invite(%s)", first) == "invite not found")
check("still waiting", status(first) == "pending")
check("ada cancels it", attempt(ada, "select cancel_match_invite(%s)", first) == "ok")
check("…it's cancelled", status(first) == "cancelled")
check("…and bo's notification of it is gone", notified(first) == 0)
check("bo can't accept it now",
      attempt(bo, "select respond_match_invite(%s, true)", first) == "invite not found")
check("cancelling twice says it's answered",
      attempt(ada, "select cancel_match_invite(%s)", first) == "challenge already answered")

second = challenge(ada, bo)
check("accepted…", attempt(bo, "select respond_match_invite(%s, true)", second) == "ok")
check("…can't be taken back",
      attempt(ada, "select cancel_match_invite(%s)", second) == "challenge already answered")
check("…and the game stands", status(second) == "accepted")

third = challenge(ada, bo)
fourth = challenge(ada, bo)
check("challenging again replaces the one waiting",
      status(third) == "cancelled" and status(fourth) == "pending")
check("…and only the new one is in bo's notifications", notified(third) == 0 and notified(fourth) == 1)
checkers = challenge(ada, bo, "checkers")
check("a challenge to another game doesn't", status(fourth) == "pending" and status(checkers) == "pending")
other = challenge(ada, cy)
check("nor one to someone else", status(fourth) == "pending" and status(other) == "pending")
check("guests of the API can't call it",
      one("select has_function_privilege('anon', 'cancel_match_invite(uuid)', 'execute')") is False)

sys.exit(1 if fails else 0)
