"""Chip Study for institutions: its price, and the allowance of students who
have Pro only through their institution (20261108010000_study_institution_price.sql)."""

import sys

import harness

db = harness.fresh()
fails = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


def run(user, sql, *args):
    harness.as_admin(db)
    if user:
        harness.as_user(db, user)
    with db.cursor() as c:
        c.execute(sql, args)
        try:
            rows = c.fetchall()
        except Exception:
            rows = []
    db.commit()
    return rows[0][0] if rows else None


def usage(user, fast=0.0, best=0.0):
    run(None, """insert into study_usage (user_id, day, fast_usd, best_usd) values (%s, (now() at time zone 'utc')::date, %s, %s)
                 on conflict (user_id, day) do update set fast_usd = excluded.fast_usd, best_usd = excluded.best_usd""",
        user, fast, best)


prices = run(None, "set local role anon; select study_institution_prices()")
check("the price is public, per student per year, from 50 students",
      {k: (float(v["per_student_year"]), v["min_students"]) for k, v in prices.items()}
      == {"GBP": (36.0, 50), "USD": (45.0, 50), "EUR": (42.0, 50), "NGN": (45000.0, 50)}, prices)

staff = harness.new_user(db, "staff@kaivon.app")
run(None, "insert into public.study_staff (user_id) values (%s)", staff)
ada = harness.new_user(db, "ada@uni.edu")
sue = harness.new_user(db, "sue@uni.edu")
pam = harness.new_user(db, "pam@uni.edu")
solo = harness.new_user(db, "solo@gmail.com")
inst = run(ada, "select study_institution_register('Uni', 'GB', 'university')")
run(staff, "select study_staff_review(%s, 'approved', 50, 90, 'uni.edu')", inst)
klass = run(ada, "select study_class_create(%s, 'BIO 101')", inst)
for u in (sue, pam):
    run(u, "select study_class_join(%s)", klass["code"])

me = run(sue, "select study_me()")
check("a student with Pro through their institution is Pro, and says so",
      me["tier"] == "pro" and me["plan"] == "pro" and me["via_institution"] is True, me)
check("with the institution's allowance",
      (float(me["fast"]["cap"]), float(me["best"]["cap"]), float(me["best"]["period_cap"])) == (0.04, 0.30, 1.50), me)
check("worst case a month stays under the price",
      30 * float(me["fast"]["cap"]) + float(me["best"]["period_cap"]) < 45 / 12, me)
a = run(sue, "select study_allow('best')")
check("they get the best model while there's allowance", a["ok"] and a["model"] == "best", a)
usage(sue, best=0.30)
a = run(sue, "select study_allow('best')")
check("past a day's best allowance, Chip answers with the fast model", a["ok"] and a["model"] == "fast" and a["note"] == "best_used", a)
usage(sue, fast=0.04, best=0.30)
a = run(sue, "select study_allow('fast')")
check("past the day's fast allowance, they wait for tomorrow", not a["ok"] and a["why"] == "limit", a)

run(None, """insert into web_subscriptions (user_id, plan_id, currency, amount, ref, email, status, period_end)
             values (%s, 'study.pro.monthly', 'USD', 1, 'kaivon-sub-' || gen_random_uuid(), 'pam@uni.edu', 'active',
                     now() + interval '20 days')""", pam)
me = run(pam, "select study_me()")
check("someone who also pays for Pro keeps full Pro",
      me["via_institution"] is False and (float(me["fast"]["cap"]), float(me["best"]["cap"]), float(me["best"]["period_cap"])) == (0.06, 0.60, 4.50), me)
usage(pam, best=0.30)
check("and keeps the best model past the institution's day allowance", run(pam, "select study_allow('best')")["model"] == "best")

me = run(solo, "select study_me()")
check("a free account is unchanged", me["tier"] == "free" and me["via_institution"] is False and me["best"] is None
      and float(me["fast"]["cap"]) == 0.03, me)
run(staff, "select study_staff_review(%s, 'suspended')", inst)
me = run(sue, "select study_me()")
check("when the institution is paused, its students are back on free", me["tier"] == "free" and me["via_institution"] is False, me)

print()
print("All institution price checks passed." if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
