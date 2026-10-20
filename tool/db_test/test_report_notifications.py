"""A player hears back about their report: marked fixed (or not to be
done), they get a notification with the team's note; seen or still open,
nothing yet."""
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
harness.as_user(db, me)
bug = one("select submit_bug_report('The board froze after a capture', 'bug')")
idea = one("select submit_bug_report('A snowy world for winter', 'idea')")


def news(report):
    harness.as_admin(db)
    return one("select data from notifications where user_id = %s and kind = 'report_update' "
               "and ref_id = %s order by id desc limit 1", me, report)


harness.as_admin(db)
run("update bug_reports set status = 'triaged' where id = %s", bug)
check("seen (triaged): no notification yet", news(bug) is None)

harness.as_admin(db)
run("update bug_reports set status = 'fixed', resolution = 'Fixed in 1.0.1' where id = %s", bug)
n = news(bug)
check("fixed: the player hears, with the note",
      n is not None and n["status"] == "fixed" and n["note"] == "Fixed in 1.0.1" and n["idea"] is False, n)

harness.as_admin(db)
run("update bug_reports set resolution = 'Fixed in 1.0.1 (and 1.0.2)' where id = %s", bug)
check("…the note changed later: no second notification",
      one("select count(*) from notifications where user_id = %s and ref_id = %s", me, bug) == 1)

harness.as_admin(db)
run("update bug_reports set status = 'fixed', resolution = 'Coming this winter' where id = %s", idea)
check("an idea added: told it's an idea", (news(idea) or {}).get("idea") is True)

sys.exit(1 if fails else 0)
