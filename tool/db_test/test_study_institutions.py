"""Chip Study for institutions (20261107160000_study_institutions.sql):
signing up, Kaivon's review, invites, class codes, school email domains,
seats, Pro through an institution, what admins and teachers can see (never
chats or the AI-use log's prompt and output), and who may do what."""

import sys

import harness

db = harness.fresh()
fails = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


def run(user, sql, *args):
    """Runs [sql] as [user] (None: as the database), answering the first value."""
    if user:
        harness.as_admin(db)
        harness.as_user(db, user)
    else:
        harness.as_admin(db)
    with db.cursor() as c:
        c.execute(sql, args)
        try:
            rows = c.fetchall()
        except Exception:
            rows = []
    db.commit()
    return rows[0][0] if rows else None


def rows(user, sql, *args):
    harness.as_admin(db)
    harness.as_user(db, user)
    with db.cursor() as c:
        c.execute(sql, args)
        out = c.fetchall()
    db.commit()
    return out


def refused(user, sql, *args):
    """The error's first line, or None if [sql] went through."""
    try:
        run(user, sql, *args)
        return None
    except Exception as e:
        db.rollback()
        return str(e).split("\n")[0]


tier = lambda u: run(None, "select public._study_tier(%s)", u)

kaivon = harness.new_user(db, "jake@kaivon.app")
run(None, "insert into public.study_staff (user_id) values (%s)", kaivon)
ada = harness.new_user(db, "ada@unilag.edu.ng")      # registers the institution
tom = harness.new_user(db, "tom@unilag.edu.ng")      # becomes a teacher
s1 = harness.new_user(db, "s1@gmail.com")
s2 = harness.new_user(db, "s2@gmail.com")
s3 = harness.new_user(db, "s3@gmail.com")
s4 = harness.new_user(db, "s4@unilag.edu.ng")        # joins by school email
nosy = harness.new_user(db, "nosy@gmail.com")
guest = harness.new_user(db)

# ── Signing up ────────────────────────────────────────────────────────────
check("a guest can't register an institution",
      "save your account" in (refused(guest, "select study_institution_register('Guest U', 'NG', 'university')") or ""))
inst = run(ada, "select study_institution_register('University of Lagos', 'ng', 'university', 'unilag.edu.ng', 'unilag.edu.ng', 'Ada Obi', 'Dean')")
check("registering makes a pending institution with its creator as admin",
      run(None, "select status from study_institutions where id = %s", inst) == "pending"
      and run(None, "select role from study_institution_members where institution_id = %s and user_id = %s", inst, ada) == "admin")
check("the country is stored in capitals", run(None, "select country from study_institutions where id = %s", inst) == "NG")
check("the requested domain waits for Kaivon",
      run(None, "select email_domain is null and domain_requested = 'unilag.edu.ng' from study_institutions where id = %s", inst))
check("tables can't be read directly", "permission denied" in (refused(ada, "select * from study_institutions") or "")
      or rows(ada, "select * from study_institutions") == [])
check("no Pro while pending", tier(ada) == "free")
check("no student invites while pending",
      "not active" in (refused(ada, "select * from study_institution_invite(%s, array['s1@gmail.com'], 'student')", inst) or ""))

# ── Kaivon's review ───────────────────────────────────────────────────────
check("only Kaivon staff see the queue", "not allowed" in (refused(ada, "select study_staff_institutions()") or ""))
queue = run(kaivon, "select study_staff_institutions()")
check("staff see it waiting", any(q["id"] == inst for q in queue), queue)
check("a public email domain is refused",
      "public email" in (refused(kaivon, "select study_staff_review(%s, 'approved', 3, 30, 'gmail.com')", inst) or ""))
check("only staff can approve", "not allowed" in (refused(ada, "select study_staff_review(%s, 'approved')", inst) or ""))
run(kaivon, "select study_staff_review(%s, 'approved', 3, 30, 'unilag.edu.ng', 'Checked the website')", inst)
check("approved: a 30-day pilot, 3 seats, the domain confirmed",
      run(None, """select status = 'approved' and seats = 3 and pilot_ends = current_date + 30 and email_domain = 'unilag.edu.ng'
                     from study_institutions where id = %s""", inst))
check("its admin gets Pro once it's active", tier(ada) == "pro")

# ── Invites ───────────────────────────────────────────────────────────────
invites = rows(ada, "select * from study_institution_invite(%s, array['S1@gmail.com', 's2@gmail.com', 'nope'], 'student')", inst)
by_email = {r[0]: (r[1], r[2]) for r in invites}
check("invites are made per email, lower-cased, bad ones flagged",
      by_email["s1@gmail.com"][1] == "invited" and by_email["nope"][1] == "invalid", invites)
again = rows(ada, "select * from study_institution_invite(%s, array['s1@gmail.com'], 'student')", inst)
check("inviting again reuses the open link", again[0][1] == by_email["s1@gmail.com"][0])
t1 = by_email["s1@gmail.com"][0]
check("someone else can't use another's invite",
      "another email" in (refused(nosy, "select study_invite_accept(%s)", t1) or ""))
peek = run(s1, "select study_invite_peek(%s)", t1)
check("the invite says what it's for", peek["institution"] == "University of Lagos" and peek["email_matches"] is True, peek)
run(s1, "select study_invite_accept(%s)", t1)
check("accepting makes them a student with Pro", run(None, "select role from study_institution_members where institution_id = %s and user_id = %s", inst, s1) == "student"
      and tier(s1) == "pro")
check("an invite works once", "not open" in (refused(s1, "select study_invite_accept(%s)", t1) or ""))

# ── Classes and teachers ──────────────────────────────────────────────────
klass = run(ada, "select study_class_create(%s, 'CSC 101')", inst)
check("a class gets a 6-letter code", len(klass["code"]) == 6, klass)
tt = rows(ada, "select * from study_institution_invite(%s, array['tom@unilag.edu.ng'], 'teacher', %s)", inst, klass["id"])[0][1]
run(tom, "select study_invite_accept(%s)", tt)
check("an invited teacher joins as a teacher of that class",
      run(None, "select role from study_class_members where class_id = %s and user_id = %s", klass["id"], tom) == "teacher")
run(s2, "select study_class_join(%s)", klass["code"].lower())
check("a class code brings a student into the class and the institution",
      run(None, "select role from study_institution_members where institution_id = %s and user_id = %s", inst, s2) == "student"
      and run(None, "select count(*) from study_class_members where class_id = %s and user_id = %s", klass["id"], s2) == 1)
check("a teacher can't join as a student", "already staff" in (refused(tom, "select study_class_join(%s)", klass["code"]) or ""))

# ── School email ──────────────────────────────────────────────────────────
mine = run(s4, "select study_my_institutions()")
check("a school email is offered its institution", any(s["id"] == inst for s in mine["suggested"]), mine)
check("another email isn't", run(s3, "select study_my_institutions()")["suggested"] == [])
check("a non-school email can't join that way",
      "not allowed" in (refused(s3, "select study_institution_join_by_email(%s)", inst) or ""))
run(s4, "select study_institution_join_by_email(%s)", inst)
check("joining by school email works", tier(s4) == "pro")

# ── Seats ─────────────────────────────────────────────────────────────────
t3 = rows(ada, "select * from study_institution_invite(%s, array['s3@gmail.com'], 'student')", inst)[0][1]
check("no seat, no join: 3 seats, 3 students", "no seats left" in (refused(s3, "select study_invite_accept(%s)", t3) or ""))
run(kaivon, "select study_staff_review(%s, 'approved', 10)", inst)
run(s3, "select study_invite_accept(%s)", t3)
check("more seats, and they're in", tier(s3) == "pro")

# ── What staff see ────────────────────────────────────────────────────────
a1 = run(None, "insert into study_assignments (user_id, title) values (%s, 'Essay on Lagos') returning id", s1)
run(None, "insert into study_ai_log (assignment_id, user_id, action, summary, prompt, output, words) values (%s, %s, 'explain', 'Explained thesis statements', 'my secret prompt', 'secret output', 120)", a1, s1)
run(None, "insert into study_focus (user_id, assignment_id, minutes) values (%s, %s, 25)", s1, a1)
run(None, "insert into study_practice (user_id, assignment_id, kind, correct, total) values (%s, %s, 'quiz', 8, 10)", s1, a1)
run(None, "insert into study_class_members (class_id, user_id, role) values (%s, %s, 'student')", klass["id"], s1)

admin_sees = {r[0] for r in rows(ada, "select * from study_institution_students(%s)", inst)}
check("the admin sees every member", {ada, tom, s1, s2, s3, s4} <= admin_sees, admin_sees)
teacher_sees = {r[0] for r in rows(tom, "select * from study_institution_students(%s)", inst)}
check("a teacher sees only their class's students", teacher_sees == {s1, s2}, teacher_sees)
row = [r for r in rows(ada, "select * from study_institution_students(%s)", inst) if r[0] == s1][0]
check("the list shows study time, practice and AI use", row[7] == 25 and row[8] == 80 and row[11] == 1, row)
detail = run(tom, "select study_institution_student(%s, %s)", inst, s1)
ai = detail["assignments"][0]["ai_use"][0]
check("a student's page shows the AI-use record", ai["action"] == "explain" and ai["summary"] == "Explained thesis statements", detail)
check("but never the prompt or output text", "secret" not in str(detail))
check("a teacher can't open a student outside their classes",
      "not allowed" in (refused(tom, "select study_institution_student(%s, %s)", inst, s3) or ""))
check("a student can't see the dashboard", "not allowed" in (refused(s1, "select study_institution_overview(%s)", inst) or ""))
check("an outsider can't either", "not allowed" in (refused(nosy, "select study_institution_students(%s)", inst) or ""))
ov = run(ada, "select study_institution_overview(%s)", inst)
check("the overview counts this week's activity",
      ov["week"]["active_students"] == 1 and ov["week"]["focus_minutes"] == 25 and ov["week"]["practice_score"] == 80
      and ov["counts"]["students"] == 4 and len(ov["weeks"]) == 8, ov["week"])

# ── The monthly cap on the best model ────────────────────────────────────
run(None, "insert into study_usage (user_id, day, best_usd) values (%s, date_trunc('month', now())::date, 3.10), (%s, (date_trunc('month', now()) - interval '3 days')::date, 9)", s1, s1)
check("institution Pro counts the best model by calendar month", float(run(None, "select public._study_period_best(%s)", s1)) == 3.10)
check("someone with neither a plan nor an institution counts nothing", float(run(None, "select public._study_period_best(%s)", nosy)) == 0)

# ── Who may do what ───────────────────────────────────────────────────────
check("a teacher can't invite teachers",
      "not allowed" in (refused(tom, "select * from study_institution_invite(%s, array['x@y.com'], 'teacher', %s)", inst, klass["id"]) or ""))
check("a student can't invite", "not allowed" in (refused(s1, "select * from study_institution_invite(%s, array['x@y.com'], 'student')", inst) or ""))
check("the last admin can't leave", "last admin" in (refused(ada, "select study_institution_leave(%s)", inst) or ""))
check("the last admin can't be demoted", "last admin" in (refused(ada, "select study_institution_member_set(%s, %s, 'teacher')", inst, ada) or ""))
run(ada, "select study_institution_member_set(%s, %s, null)", inst, s2)
check("an admin can remove a student, from their classes too",
      run(None, "select count(*) from study_class_members where user_id = %s", s2) == 0 and tier(s2) == "free")
run(s3, "select study_institution_leave(%s)", inst)
check("a student can leave", tier(s3) == "free")
run(ada, "select study_institution_update(%s, p_domain_requested => 'gmail.com')", inst)
check("an admin can't set the email domain themselves",
      run(None, "select email_domain from study_institutions where id = %s", inst) == "unilag.edu.ng")
check("an outsider can't make a class", "not allowed" in (refused(nosy, "select study_class_create(%s, 'Hijack')", inst) or ""))
check("or list them", "not allowed" in (refused(nosy, "select study_classes_list(%s)", inst) or ""))
check("or rename one", "not allowed" in (refused(nosy, "select study_class_update(%s, 'Mine now')", klass["id"]) or ""))
check("or add people to one", "not allowed" in (refused(nosy, "select study_class_member_set(%s, %s, 'student')", klass["id"], s1) or ""))
check("or see the overview", "not allowed" in (refused(nosy, "select study_institution_overview(%s)", inst) or ""))

# ── When it stops ─────────────────────────────────────────────────────────
run(kaivon, "select study_staff_review(%s, 'suspended')", inst)
check("suspended: Pro stops for its students", tier(s1) == "free" and tier(s4) == "free")
run(kaivon, "select study_staff_review(%s, 'approved', p_plan => 'paid', p_paid_until => (current_date + 365))", inst)
check("paid for a year: Pro is back", tier(s1) == "pro")
run(None, "update study_institutions set paid_until = current_date - 1 where id = %s", inst)
check("past the paid date: Pro stops", tier(s1) == "free")

# ── tool/sql/make_study_staff.sql ─────────────────────────────────────────
import pathlib
script = (pathlib.Path(__file__).resolve().parents[1] / "sql" / "make_study_staff.sql").read_text()
script = script.replace("array['you@example.com']", "array['ada@unilag.edu.ng', 'nobody@nowhere.com']", 1)
harness.as_admin(db)
with db.cursor() as c:
    c.execute(script)
db.commit()
check("make_study_staff.sql makes someone staff by email, skipping unknown people",
      run(None, "select count(*) from study_staff where user_id = %s", ada) == 1
      and run(None, "select count(*) from study_staff") == 2)

print()
print("All institution checks passed." if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
