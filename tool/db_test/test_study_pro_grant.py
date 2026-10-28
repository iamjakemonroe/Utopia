"""tool/sql/give_study_pro.sql and take_study_pro.sql: Chip Study Pro given
free (by user ID or email) and taken back, a paid subscription untouched."""

import pathlib
import sys

import harness

db = harness.fresh()
fails = []
SQL = pathlib.Path(__file__).resolve().parents[1] / "sql"


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


def one(sql, *args):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute(sql, args)
        rows = c.fetchall()
        return rows[0][0] if rows else None


def run(script, people):
    """Runs [script] with its list of people set to [people]."""
    text = (SQL / script).read_text()
    listed = "array[" + ", ".join("'" + p + "'" for p in people) + "]"
    text = text.replace("array['their_username']", listed, 1)
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute(text)
        try:
            return c.fetchall()
        except Exception:
            return None


tier = lambda u: one("select public._study_tier(%s)", u)
amy = harness.new_user(db, "amy@example.com")
ben = harness.new_user(db, "ben@example.com")
cat = harness.new_user(db, "cat@example.com")

check("they start on the free plan", tier(amy) == "free" and tier(ben) == "free")
rows = run("give_study_pro.sql", [str(amy), "BEN@example.com"])
check("given by user ID and by email, both are Pro", tier(amy) == "pro" and tier(ben) == "pro", (tier(amy), tier(ben)))
check("someone not listed isn't", tier(cat) == "free")
check("the table lists both, about ten years out", rows and len(rows) == 2
      and all(r[3].year >= 2035 for r in rows), rows)
check("it costs nothing", one("select sum(amount) from web_subscriptions where ref like 'grant:study:%%'") == 0)
until = one("select period_end from web_subscriptions where ref = %s", f"grant:study:{amy}")
run("give_study_pro.sql", [str(amy)])
check("running it again keeps one grant each, never sooner",
      one("select count(*) from web_subscriptions where user_id = %s", amy) == 1
      and one("select period_end from web_subscriptions where ref = %s", f"grant:study:{amy}") >= until)
try:
    run("give_study_pro.sql", ["nobody@example.com"])
    check("an unknown person is refused", False)
except Exception as e:
    db.rollback()
    check("an unknown person is refused", "No account matches" in str(e), str(e))

one("""insert into web_subscriptions (user_id, plan_id, currency, amount, ref, email, status, period_end)
       values (%s, 'study.pro.monthly', 'USD', 4.99, 'kaivon-sub-paid', 'cat@example.com', 'active',
               now() + interval '20 days') returning 1""", cat)
run("take_study_pro.sql", [str(amy), "cat@example.com"])
check("taken back, Amy is free again", tier(amy) == "free", tier(amy))
check("Ben keeps his", tier(ben) == "pro")
check("a paid subscription is left alone", tier(cat) == "pro"
      and one("select status from web_subscriptions where ref = 'kaivon-sub-paid'") == "active")

print()
if fails:
    print(f"{len(fails)} failed")
    sys.exit(1)
print("All Chip Study Pro grant checks passed.")
