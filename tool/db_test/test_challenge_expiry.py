"""Challenges last 10 minutes, and a game only starts while the one who
sent it is online: accepting one whose sender stepped away says so (and
it waits), an expired one can't be accepted, and the sweep clears them."""
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


def online(user, yes):
    harness.as_admin(db)
    run("insert into presence_status (user_id, online) values (%s, %s) "
        "on conflict (user_id) do update set online = excluded.online, changed_at = now()",
        user, yes)


def challenge(sender, to):
    harness.as_user(db, sender)
    return str(one("select send_board_invite(%s, 'chess', 0, 10, 0)", to))


def answer(user, invite, accept=True):
    harness.as_user(db, user)
    try:
        return ("ok", one("select respond_match_invite(%s, %s)", invite, accept))
    except Exception as e:
        return ("refused", str(e).split("\n")[0])


def status(invite):
    harness.as_admin(db)
    return one("select status::text from match_invites where id = %s", invite)


ada = harness.new_user(db, "ada@example.com")
bo = harness.new_user(db, "bo@example.com")

online(ada, True)
first = challenge(ada, bo)
harness.as_admin(db)
left = one("select extract(epoch from expires_at - now()) from match_invites where id = %s", first)
check("a challenge lasts 10 minutes", 590 <= left <= 600, left)
got = answer(bo, first)
check("accepted while its sender's here: the game starts", got[0] == "ok" and got[1], got)
check("…and it's accepted", status(first) == "accepted")

second = challenge(ada, bo)
online(ada, False)
got = answer(bo, second)
check("its sender stepped away: no game starts", got == ("refused", "challenger away"), got)
check("…and it waits for them", status(second) == "pending")
harness.as_admin(db)
check("…no match was made", one("select count(*) from matches") == 1)
online(ada, True)
check("back again: it starts", answer(bo, second)[0] == "ok")

third = challenge(ada, bo)
harness.as_admin(db)
run("update match_invites set expires_at = now() - interval '1 second' where id = %s", third)
got = answer(bo, third)
check("an expired challenge can't be accepted", got == ("refused", "challenge expired"), got)
harness.as_admin(db)
check("the sweep marks it expired", one("select expire_challenges()") == 1 and status(third) == "expired")
check("…and it's gone from the answerable", answer(bo, third) == ("refused", "invite not found"))

fourth = challenge(ada, bo)
online(ada, False)
check("declining works whoever's here", answer(bo, fourth, accept=False)[0] == "ok"
      and status(fourth) == "declined")

harness.as_admin(db)
check("the sweep runs every 30 seconds",
      one("select schedule from cron.job where jobname = 'expire-challenges'") == "30 seconds")
harness.as_user(db, bo)
try:
    one("select expire_challenges()")
    ran = True
except Exception:
    ran = False
check("players can't run the sweep themselves", not ran)

sys.exit(1 if fails else 0)
