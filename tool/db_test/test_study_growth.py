"""Chip Study's growth round (20261107180000_study_growth.sql): invite a
friend, campus reps, the age rule, course tutors, and what a class is stuck
on (anonymous, 5 or more students, only for whoever runs the class)."""

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


def refused(user, sql, *args):
    try:
        run(user, sql, *args)
        return None
    except Exception as e:
        db.rollback()
        return str(e).split("\n")[0]


tier = lambda u: run(None, "select public._study_tier(%s)", u)
pro_until = lambda u: run(None, "select public._web_plan_until(%s, 'study_pro')", u)

kaivon = harness.new_user(db, "jake@kaivon.app")
run(None, "insert into public.study_staff (user_id) values (%s)", kaivon)
ama = harness.new_user(db, "ama@example.com")
ben = harness.new_user(db, "ben@example.com")
cal = harness.new_user(db, "cal@example.com")
old = harness.new_user(db, "old@example.com")
run(None, "update auth.users set created_at = now() - interval '30 days' where id = %s", old)
guest = harness.new_user(db)


def asks(user, n):
    run(None, """insert into study_usage (user_id, day, asks) values (%s, current_date, %s)
                 on conflict (user_id, day) do update set asks = study_usage.asks + excluded.asks""", user, n)


# ── Invite a friend ───────────────────────────────────────────────────────
mine = run(ama, "select study_my_referral()")
code = mine["code"]
check("everyone gets an 8-letter code", len(code) == 8 and mine["invited"] == 0, mine)
check("the same code next time", run(ama, "select study_my_referral()")["code"] == code)
check("a guest can't use one", "save your account" in (refused(guest, "select study_referral_redeem(%s)", code) or ""))
check("not your own", "your own code" in (refused(ama, "select study_referral_redeem(%s)", code) or ""))
check("not an old account", "too late" in (refused(old, "select study_referral_redeem(%s)", code) or ""))
check("a made-up code is refused", "no such code" in (refused(ben, "select study_referral_redeem('ZZZZZZZZ')") or ""))
got = run(ben, "select study_referral_redeem(%s)", code.lower())
check("a new account can say who brought them", got is not None and "referrer" in got, got)
check("only once", "already referred" in (refused(ben, "select study_referral_redeem(%s)", code) or ""))
check("no Pro until they've really used it", tier(ben) == "free" and tier(ama) == "free")
asks(ben, 2)
run(ben, "select study_my_referral()")
check("2 questions isn't enough", tier(ben) == "free")
asks(ben, 1)
mine = run(ama, "select study_my_referral()")
check("after 3, both get a week", tier(ben) == "pro" and tier(ama) == "pro" and mine["active"] == 1, mine)
days = run(None, "select extract(day from (public._web_plan_until(%s, 'study_pro') - now()))", ama)
check("a week, not more", 6 <= float(days) <= 7, days)
run(ama, "select study_my_referral()")
check("settling again gives nothing extra",
      run(None, "select count(*) from web_subscriptions where user_id = %s and ref like 'referral:%%'", ama) == 1)
run(cal, "select study_referral_redeem(%s)", code)
asks(cal, 3)
before = pro_until(ama)
run(cal, "select study_my_referral()")
after = pro_until(ama)
check("a second friend adds a week after the first", (after - before).days == 7, (before, after))

# The yearly cap: 12 weeks.
for i in range(14):
    u = harness.new_user(db, f"f{i}@example.com")
    run(u, "select study_referral_redeem(%s)", code)
    asks(u, 3)
    run(u, "select study_my_referral()")
check("a referrer earns at most 12 weeks a year",
      run(None, "select count(*) from web_subscriptions where user_id = %s and ref like 'referral:study:invited:%%'", ama) == 12)
check("their friends still get theirs", run(None, "select count(*) from web_subscriptions where ref like 'referral:study:joined:%%'") == 16)

# ── Campus reps ───────────────────────────────────────────────────────────
check("only staff make reps", "not allowed" in (refused(ama, "select study_staff_set_rep('ama@example.com', 'Ama, UNILAG')") or ""))
run(kaivon, "select study_staff_set_rep('ama@example.com', 'Ama, UNILAG')")
reps = run(kaivon, "select study_staff_reps()")
check("staff see a rep's sign-ups and who really used it",
      reps[0]["name"] == "Ama, UNILAG" and reps[0]["signups"] == 16 and reps[0]["active"] == 16, reps)
check("the rep sees their name", run(ama, "select study_my_referral()")["rep"] == "Ama, UNILAG")
run(kaivon, "select study_staff_set_rep('ama@example.com', null)")
check("and it can stop", run(kaivon, "select study_staff_reps()") == [])

# ── The age rule ──────────────────────────────────────────────────────────
check("no answer yet", run(ben, "select study_age_get()") is None)
check("only the two answers", "bad answer" in (refused(ben, "select study_age_confirm('child')") or ""))
run(ben, "select study_age_confirm('guardian')")
check("an answer is kept", run(ben, "select study_age_get()") == "guardian")
check("a school needs parental consent to register",
      "parental consent" in (refused(ama, "select study_institution_register('Green Hill School', 'NG', 'school')") or ""))
sch = run(ama, "select study_institution_register('Green Hill School', 'NG', 'school', p_minors_consent => true)")
check("with it, it registers", run(None, "select minors_consent from study_institutions where id = %s", sch) is True)

# ── Course tutors ─────────────────────────────────────────────────────────
uni = run(cal, "select study_institution_register('Kaduna Poly', 'NG', 'college')")
run(kaivon, "select study_staff_review(%s, 'approved', 20, 90)", uni)
klass = run(cal, "select study_class_create(%s, 'BIO 101')", uni)
check("a student can't set the tutor",
      "not allowed" in (refused(ben, "select study_class_tutor_set(%s, 'x', 'hints', '')", klass["id"]) or ""))
run(cal, "select study_class_tutor_set(%s, 'Cell biology, first year', 'hints', 'Use the Campbell textbook')", klass["id"])
check("its admin can", run(None, "select help_level from study_classes where id = %s", klass["id"]) == "hints")
check("a bad help level is refused",
      refused(cal, "select study_class_tutor_set(%s, '', 'write it for them', '')", klass["id"]) is not None)
stu = harness.new_user(db, "stu@example.com")
other = harness.new_user(db, "other@example.com")
run(stu, "select study_class_join(%s)", klass["code"])
a1 = run(None, "insert into study_assignments (user_id, title) values (%s, 'Mitosis essay') returning id", stu)
check("an outsider can't link someone's assignment",
      "not allowed" in (refused(other, "select study_assignment_set_class(%s, %s)", a1, klass["id"]) or ""))
check("you can't link to a class you're not in",
      "not allowed" in (refused(other, "select study_assignment_set_class(%s, %s)",
                                run(None, "insert into study_assignments (user_id, title) values (%s, 'x') returning id", other),
                                klass["id"]) or ""))
check("the student sees their classes", [c["name"] for c in run(stu, "select study_my_classes()")] == ["BIO 101"])
run(stu, "select study_assignment_set_class(%s, %s)", a1, klass["id"])
tutor = run(stu, "select study_assignment_tutor(%s)", a1)
check("Chip gets the course tutor for a linked assignment",
      tutor and tutor["help_level"] == "hints" and tutor["course_brief"] == "Cell biology, first year", tutor)
check("nobody else gets it", run(other, "select study_assignment_tutor(%s)", a1) is None)
check("the student can read their class's tutor", run(stu, "select study_class_tutor_get(%s)", klass["id"])["name"] == "BIO 101")
run(kaivon, "select study_staff_review(%s, 'suspended')", uni)
check("not once the institution is suspended", run(stu, "select study_assignment_tutor(%s)", a1) is None)
run(kaivon, "select study_staff_review(%s, 'approved')", uni)

# ── What a class is stuck on ──────────────────────────────────────────────
def ask_in_class(user, text):
    a = run(None, "select id from study_assignments where user_id = %s and class_id = %s", user, klass["id"])
    if a is None:
        a = run(None, "insert into study_assignments (user_id, title, class_id) values (%s, 'Work', %s) returning id", user, klass["id"])
    t = run(None, "insert into study_threads (assignment_id, user_id, title) values (%s, %s, 'q') returning id", a, user)
    run(None, "insert into study_messages (thread_id, assignment_id, user_id, role, mode, content) values (%s, %s, %s, 'user', 'explain', %s)",
        t, a, user, text)


ask_in_class(stu, "I don't get the difference between mitosis and meiosis")
students = [stu]
for i in range(3):
    s = harness.new_user(db, f"c{i}@example.com")
    run(s, "select study_class_join(%s)", klass["code"])
    ask_in_class(s, f"What happens in prophase {i}?")
    students.append(s)
src = run(cal, "select study_class_theme_source(%s)", klass["id"])
check("4 students isn't enough for themes", src["enough"] is False and src["questions"] == [], src)
s5 = harness.new_user(db, "c5@example.com")
run(s5, "select study_class_join(%s)", klass["code"])
ask_in_class(s5, "Why does crossing over matter?")
src = run(cal, "select study_class_theme_source(%s)", klass["id"])
check("5 students is", src["enough"] is True and src["students"] == 5 and len(src["questions"]) == 5, src)
check("the questions carry no names or emails", "@" not in str(src["questions"]))
check("a student can't ask for them", "not allowed" in (refused(stu, "select study_class_theme_source(%s)", klass["id"]) or ""))
check("an outsider can't", "not allowed" in (refused(other, "select study_class_themes_get(%s)", klass["id"]) or ""))
check("no themes made yet", run(cal, "select study_class_themes_get(%s)", klass["id"]) is None)

print()
print("All growth checks passed." if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
