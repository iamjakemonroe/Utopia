"""Chip Study's pricing (20261029100000_study_pricing.sql): Pro at $7.99 with
more of the best model, the student plan at $5.99 for a confirmed school
email, each plan's allowance, and both plans in profit even at the limit."""

import sys

import harness

db = harness.fresh()
fails = []

# Flutterwave's worst-case fee (international cards: 4.8% + VAT), docs/PRICING.md.
FEE = 0.0516


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


def attempt(user, sql, *args):
    harness.as_admin(db)
    harness.as_user(db, user)
    try:
        with db.cursor() as c:
            c.execute(sql, args)
            rows = c.fetchall()
            return rows[0][0] if rows else None
    except Exception as e:
        db.rollback()
        return "ERROR " + str(e).split("\n")[0]
    finally:
        harness.as_admin(db)


def subscribe(user, plan, days_left=20):
    one("""insert into web_subscriptions (user_id, plan_id, currency, amount, ref, email, status, period_end)
           values (%s, %s, 'USD', 1, 'kaivon-sub-' || gen_random_uuid(), 'x@example.com', 'active',
                   now() + make_interval(days => %s)) returning 1""", user, plan, days_left)


school = lambda email: one("select public._study_school_email(%s)", email)

# ── Which emails are a school's ────────────────────────────────────────────
for email in ["ada@harvard.edu", "ada@mail.mit.edu", "ada@unilag.edu.ng", "ada@student.unimelb.edu.au",
              "ada@strath.ac.uk", "ada@student.uj.ac.za", "ada@u-tokyo.ac.jp", "ada@mail.utoronto.ca",
              "ada@student.uva.nl", "ada@ETHZ.CH"]:
    check(f"a school email: {email}", school(email) is True)
for email in ["ada@gmail.com", "ada@edu.com", "ada@education.org", "ada@harvard.edu.fake.com",
              "ada@notutoronto.ca", "ada@yahoo.co.uk", "ada@", "", None]:
    check(f"not a school email: {email!r}", school(email) is False)

# ── The prices ─────────────────────────────────────────────────────────────
pro = harness.new_user(db, "pro@gmail.com")
student = harness.new_user(db, "kim@strath.ac.uk")
unconfirmed = harness.new_user(db, "lee@harvard.edu")
one("update auth.users set email_confirmed_at = null where id = %s returning 1", unconfirmed)
guest = harness.new_user(db)

shop = attempt(pro, """select json_agg(json_build_object('plan', plan_id, 'amount', amount) order by plan_id)
                         from web_plan_shop('USD') where product = 'study_pro'""")
check("Pro is $7.99 and the student plan $5.99",
      shop == [{"plan": "study.pro.monthly", "amount": 7.99}, {"plan": "study.pro.student.monthly", "amount": 5.99}], shop)
check("the new price gets a new Flutterwave plan",
      one("select flw_plan_id is null from web_plan_prices where plan_id = 'study.pro.monthly'") is True)

me = attempt(student, "select study_me()")
check("study_me tells a school email it gets the student price",
      me["student"] == {"eligible": True, "domain": "strath.ac.uk"} and float(me["student_price"]["amount"]) == 5.99
      and float(me["price"]["amount"]) == 7.99 and me["plan"] is None, me)
me = attempt(pro, "select study_me()")
check("and anyone else that they don't", me["student"] == {"eligible": False, "domain": "gmail.com"}, me["student"])
check("an unconfirmed school email doesn't count",
      attempt(unconfirmed, "select study_me() -> 'student' ->> 'eligible'") == "false")

# ── Subscribing ────────────────────────────────────────────────────────────
r = attempt(student, "select web_subscribe_start('study.pro.student.monthly', 'USD')")
check("a student can start the student plan at $5.99", isinstance(r, dict) and float(r["amount"]) == 5.99, r)
r = attempt(pro, "select web_subscribe_start('study.pro.student.monthly', 'USD')")
check("anyone else can't", isinstance(r, str) and "not a school email" in r, r)
r = attempt(unconfirmed, "select web_subscribe_start('study.pro.student.monthly', 'USD')")
check("nor an unconfirmed school email", isinstance(r, str) and "not a school email" in r, r)
r = attempt(pro, "select web_subscribe_start('study.pro.monthly', 'USD')")
check("anyone can start Pro at $7.99", isinstance(r, dict) and float(r["amount"]) == 7.99, r)
r = attempt(student, "select web_subscribe_start('study.pro.monthly', 'USD')")
check("a student can choose full Pro instead", isinstance(r, dict) and float(r["amount"]) == 7.99, r)

# ── The allowances ─────────────────────────────────────────────────────────
subscribe(student, "study.pro.student.monthly")
subscribe(pro, "study.pro.monthly")
me = attempt(student, "select study_me()")
check("the student plan is Pro, with its own best-model limits",
      me["tier"] == "pro" and me["plan"] == "student" and float(me["best"]["cap"]) == 0.45
      and float(me["best"]["period_cap"]) == 3.30 and float(me["fast"]["cap"]) == 0.06
      and me["uploads"]["max_mb"] == 20 and me["readings"]["cap"] == 30, me)
me = attempt(pro, "select study_me()")
check("Pro's are bigger", me["plan"] == "pro" and float(me["best"]["cap"]) == 0.60
      and float(me["best"]["period_cap"]) == 4.50 and float(me["fast"]["cap"]) == 0.06, me)

day = one("select (now() at time zone 'utc')::date")
for user in (student, pro):
    one("insert into study_usage (user_id, day, best_usd) values (%s, %s, 0.45) on conflict (user_id, day) do update set best_usd = 0.45 returning 1", user, day)
r = attempt(student, "select study_allow('best')")
check("past $0.45 of the best model today, a student carries on with Fast", r["model"] == "fast" and r["note"] == "best_used", r)
r = attempt(pro, "select study_allow('best')")
check("Pro still has the best model", r["model"] == "best", r)
one("update study_usage set best_usd = 0 where day = %s returning 1", day)
for user in (student, pro):
    one("insert into study_usage (user_id, day, best_usd) values (%s, %s - 5, 3.30) returning 1", user, day)
check("past $3.30 this month, a student's best model is used up",
      attempt(student, "select study_allow('best')")["model"] == "fast")
check("Pro's month goes on to $4.50", attempt(pro, "select study_allow('best')")["model"] == "best")

# Someone with both (a student who also took full Pro) gets full Pro's.
both = harness.new_user(db, "both@harvard.edu")
subscribe(both, "study.pro.student.monthly")
subscribe(both, "study.pro.monthly")
check("with both plans, full Pro's limits", float(attempt(both, "select study_me() -> 'best' ->> 'period_cap'")) == 4.50)

# ── In profit even at the limit ────────────────────────────────────────────
s = dict(zip(["pro_best_period", "pro_fast", "student_best_period"],
             [float(v) for v in one("select array[pro_best_period_usd, pro_fast_day_usd, student_best_period_usd] from study_settings")]))
pro_keeps = 7.99 * (1 - FEE)
student_keeps = 5.99 * (1 - FEE)
pro_most = s["pro_best_period"] + 31 * s["pro_fast"]
student_most = s["student_best_period"] + 31 * s["pro_fast"]
check(f"Pro keeps ${pro_keeps:.2f} and costs at most ${pro_most:.2f}: in profit", pro_keeps - pro_most > 1.0,
      (pro_keeps, pro_most))
check(f"the student plan keeps ${student_keeps:.2f} and costs at most ${student_most:.2f}: in profit",
      student_keeps - student_most > 0.3, (student_keeps, student_most))

print()
if fails:
    print(f"{len(fails)} failed")
    sys.exit(1)
print("All Chip Study pricing checks passed.")
