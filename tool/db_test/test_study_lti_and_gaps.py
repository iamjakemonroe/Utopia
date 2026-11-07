"""Chip Study: learning platforms (20261107200000_study_lti.sql) and the
gaps the institution screens needed (20261107210000_study_institution_gaps.sql)."""

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


kaivon = harness.new_user(db, "jake@kaivon.app")
run(None, "insert into public.study_staff (user_id) values (%s)", kaivon)
ada = harness.new_user(db, "ada@uni.edu")
tom = harness.new_user(db, "tom@uni.edu")
sue = harness.new_user(db, "sue@uni.edu")
eve = harness.new_user(db, "eve@elsewhere.com")
inst = run(ada, "select study_institution_register('Uni', 'GB', 'university')")
run(kaivon, "select study_staff_review(%s, 'approved', 10, 90, 'uni.edu')", inst)

# ── Gaps ──────────────────────────────────────────────────────────────────
check("staff can ask if they're staff", run(kaivon, "select study_am_staff()") is True)
check("others are told no, without an error", run(ada, "select study_am_staff()") is False)
klass = run(ada, "select study_class_create(%s, 'HIST 210')", inst)
peek = run(eve, "select study_class_peek(%s)", klass["code"].lower())
check("a class code can be looked at before joining",
      peek["found"] and peek["class"] == "HIST 210" and peek["institution"] == "Uni" and peek["active"] and peek["member"] is None, peek)
check("an unknown code says so", run(eve, "select study_class_peek('ZZZZZZ')") == {"found": False})
t_tom = run(ada, "select token from study_institution_invite(%s, array['tom@uni.edu'], 'teacher', %s)", inst, klass["id"])
run(tom, "select study_invite_accept(%s)", t_tom)
run(ada, "select * from study_institution_invite(%s, array['a1@x.com', 'a2@x.com'], 'student')", inst)
run(tom, "select * from study_institution_invite(%s, array['c1@x.com'], 'student', %s)", inst, klass["id"])
admin_list = run(ada, "select study_institution_invites_list(%s)", inst)
teacher_list = run(tom, "select study_institution_invites_list(%s)", inst)
check("the admin lists every open invite", sorted(i["email"] for i in admin_list) == ["a1@x.com", "a2@x.com", "c1@x.com"], admin_list)
check("a teacher lists their class's", [i["email"] for i in teacher_list] == ["c1@x.com"], teacher_list)
check("a student can't list invites", "not allowed" in (refused(eve, "select study_institution_invites_list(%s)", inst) or ""))
tok_a1 = [i["token"] for i in admin_list if i["email"] == "a1@x.com"][0]
tok_c1 = [i["token"] for i in admin_list if i["email"] == "c1@x.com"][0]
check("a teacher can't cancel an invite outside their class", "not allowed" in (refused(tom, "select study_invite_revoke(%s)", tok_a1) or ""))
run(tom, "select study_invite_revoke(%s)", tok_c1)
check("but can cancel one into their class", [i["email"] for i in run(tom, "select study_institution_invites_list(%s)", inst)] == [])
run(kaivon, "select study_staff_review(%s, 'approved', p_clear_domain => true)", inst)
check("staff can remove a confirmed domain", run(None, "select email_domain from study_institutions where id = %s", inst) is None)
run(kaivon, "select study_staff_review(%s, 'approved', p_email_domain => 'uni.edu')", inst)
run(sue, "select study_class_join(%s)", klass["code"])
check("sue is a student", run(None, "select role from study_institution_members where user_id = %s", sue) == "student")
old_code = klass["code"]
check("a student can't change the class code", "not allowed" in (refused(sue, "select study_class_new_code(%s)", klass["id"]) or ""))
check("nor can an outsider", "not allowed" in (refused(eve, "select study_class_new_code(%s)", klass["id"]) or ""))
new_code = run(tom, "select study_class_new_code(%s)", klass["id"])
check("the class's teacher can give it a new code", new_code and new_code != old_code and len(new_code) == 6, new_code)
check("the old code stops working", run(eve, "select study_class_peek(%s)", old_code) == {"found": False})
check("the new one works", run(eve, "select study_class_peek(%s)", new_code)["class"] == "HIST 210")
check("and everyone stays in the class", run(None, "select count(*) from study_class_members where class_id = %s and user_id = %s", klass["id"], sue) == 1)
check("admins can too", len(run(ada, "select study_class_new_code(%s)", klass["id"])) == 6)
run(None, "select study_forget(%s)", sue)
check("deleting study data takes a student out of institutions and classes",
      run(None, "select count(*) from study_institution_members where user_id = %s", sue) == 0
      and run(None, "select count(*) from study_class_members where user_id = %s", sue) == 0)
run(None, "select study_forget(%s)", ada)
check("but an admin stays an admin", run(None, "select role from study_institution_members where user_id = %s", ada) == "admin")

# ── Learning platforms ────────────────────────────────────────────────────
args = ("Moodle", "https://moodle.uni.edu", "client-1", "dep-1",
        "https://moodle.uni.edu/mod/lti/auth.php", "https://moodle.uni.edu/mod/lti/certs.php")
check("a teacher can't register a platform",
      "not allowed" in (refused(tom, "select study_lti_platform_set(%s, %s, %s, %s, %s, %s, %s)", inst, *args) or ""))
plat = run(ada, "select study_lti_platform_set(%s, %s, %s, %s, %s, %s, %s)", inst, *args)
check("its admin can", plat is not None)
check("only https addresses",
      refused(ada, "select study_lti_platform_set(%s, 'x', 'http://evil', 'c', 'd', 'https://a', 'https://b')", inst) is not None)
other = run(eve, "select study_institution_register('Other College', 'GB', 'college')")
run(kaivon, "select study_staff_review(%s, 'approved', 10)", other)
check("another institution can't take over the same platform",
      "another institution" in (refused(eve, "select study_lti_platform_set(%s, %s, %s, %s, %s, %s, %s)", other, *args) or ""))
check("users can't enrol themselves through a platform",
      refused(eve, "select study_lti_enrol(%s, %s, true, 'c1', 'Course')", plat, eve) is not None)

learner = harness.new_user(db, "lea@uni.edu")
teacher = harness.new_user(db, "prof@uni.edu")
r = run(None, "select study_lti_enrol(%s, %s, false, 'course-77', 'History of Science')", plat, learner)
check("a launched learner becomes a student in a class for the course", r["role"] == "student" and r["class_id"] is not None, r)
check("the class is named after the course", run(None, "select name from study_classes where id = %s", r["class_id"]) == "History of Science")
r2 = run(None, "select study_lti_enrol(%s, %s, true, 'course-77', 'History of Science')", plat, teacher)
check("an instructor becomes a teacher of the same class", r2["role"] == "teacher" and r2["class_id"] == r["class_id"], r2)
check("the course maps to one class", run(None, "select count(*) from study_lti_contexts where platform_id = %s", plat) == 1)
check("the learner must still see the privacy terms",
      [p["name"] for p in run(learner, "select study_consent_pending()")] == ["Uni"])
check("people who joined by link or code already saw them", run(tom, "select study_consent_pending()") == [])
run(learner, "select study_consent_accept(%s)", inst)
check("and once seen, that's kept", run(learner, "select study_consent_pending()") == [])
check("a platform launch respects seats",
      run(None, "select seats - (select count(*) from study_institution_members where institution_id = %s and role = 'student') from study_institutions where id = %s", inst, inst) >= 0)
run(None, "update study_institutions set seats = 1 where id = %s", inst)
late = harness.new_user(db, "late@uni.edu")
check("no seat, no enrolment", "no seats left" in (refused(None, "select study_lti_enrol(%s, %s, false, 'course-77', 'x')", plat, late) or ""))
check("staff can see the platform", len(run(kaivon, "select study_lti_platforms(%s)", inst)) == 1)

# ── Who a platform can sign in ────────────────────────────────────────────
run(None, "update study_institutions set seats = 50 where id = %s", inst)
trusts = lambda e: run(None, "select study_lti_trusts_email(%s, %s)", plat, e)
check("the confirmed domain is trusted", trusts("lea@uni.edu") is True)
check("and its subdomains", trusts("x@student.uni.edu") is True and trusts("X@Student.Uni.Edu") is True)
check("look-alike domains are not",
      not any(trusts(e) for e in ["a@evil-uni.edu", "a@eviluni.edu", "a@uni.edu.evil.com", "a@gmail.com", "", None, "uni.edu", "a@b@uni.edu"]))
run(kaivon, "select study_staff_review(%s, 'approved', p_clear_domain => true)", inst)
check("nothing is trusted without a confirmed domain", trusts("lea@uni.edu") is False)
run(kaivon, "select study_staff_review(%s, 'approved', p_email_domain => 'uni.edu')", inst)
check("users can't ask what's trusted, link for others, or make waiting launches",
      all(refused(eve, sql, *a) is not None for sql, a in [
          ("select study_lti_trusts_email(%s, 'a@uni.edu')", (plat,)),
          ("select study_lti_bind(%s, 'sub-x', %s)", (plat, eve)),
          ("select study_lti_pending_add(%s, 'sub-x', 'eve@elsewhere.com', true, 'c', 'C')", (plat,))]))

run(None, "select study_lti_bind(%s, 'sub-lea', %s)", plat, learner)
check("a vouched-for user is linked", run(None, "select user_id from study_lti_users where sub = 'sub-lea'") == learner)
run(None, "select study_lti_bind(%s, 'sub-lea', %s)", plat, learner)
check("linking again changes nothing", run(None, "select count(*) from study_lti_users where sub = 'sub-lea'") == 1)
check("a platform user can't be moved to someone else",
      "linked to another account" in (refused(None, "select study_lti_bind(%s, 'sub-lea', %s)", plat, eve) or ""))

gus = harness.new_user(db, "gus@gmail.com")
tok = run(None, "select study_lti_pending_add(%s, 'sub-gus', 'Gus@Gmail.com', false, 'course-88', 'Ethics')", plat)
peek = run(None, "set local role anon; select study_lti_pending_peek(%s)", tok)
check("a waiting launch can be looked at before signing in",
      peek == {"found": True, "institution": "Uni", "platform": "Moodle", "course": "Ethics", "email": "gus@gmail.com", "teacher": False}, peek)
check("a wrong token finds nothing", run(None, "select study_lti_pending_peek('nope')") == {"found": False})
check("linking needs a signed-in person", refused(None, "set local role anon; select study_lti_link(%s)", tok) is not None)
r3 = run(gus, "select study_lti_link(%s)", tok)
check("once signed in, the person links it and joins the course",
      r3["role"] == "student" and run(None, "select name from study_classes where id = %s", r3["class_id"]) == "Ethics", r3)
check("their platform user is now theirs", run(None, "select user_id from study_lti_users where sub = 'sub-gus'") == gus)
check("a token works once", "link expired" in (refused(gus, "select study_lti_link(%s)", tok) or ""))
tok2 = run(None, "select study_lti_pending_add(%s, 'sub-gus', null, false, 'course-88', 'Ethics')", plat)
check("someone else can't take over a linked platform user",
      "linked to another account" in (refused(eve, "select study_lti_link(%s)", tok2) or ""))
run(None, "update study_lti_pending set created_at = now() - interval '2 hours' where token = %s", tok2)
check("waiting launches expire after an hour", "link expired" in (refused(gus, "select study_lti_link(%s)", tok2) or ""))
run(None, "select study_lti_pending_add(%s, 'sub-z', null, false, null, null)", plat)
check("and old ones are cleared away", run(None, "select count(*) from study_lti_pending where token = %s", tok2) == 0)

# ── Under-18s ─────────────────────────────────────────────────────────────
uni2 = run(eve, "select study_institution_register('Night College', 'GB', 'college')")
run(kaivon, "select study_staff_review(%s, 'approved', 10)", uni2)
cls2 = run(eve, "select study_class_create(%s, 'ESL 1')", uni2)
minor = harness.new_user(db, "minor@x.com")
run(minor, "select study_age_confirm('guardian')")
check("an under-18 can't join an institution that didn't allow under-18s",
      "under 18 not allowed here" in (refused(minor, "select study_class_join(%s)", cls2["code"]) or ""))
check("staff see the setting when they review",
      [i["minors_consent"] for i in run(kaivon, "select study_staff_institutions('all')") if i["id"] == str(uni2)] == [False])
check("only its admin can turn it on", "not allowed" in (refused(minor, "select study_institution_minors(%s, true)", uni2) or ""))
run(eve, "select study_institution_minors(%s, true)", uni2)
run(minor, "select study_class_join(%s)", cls2["code"])
check("once its admin confirms parents' consent, they can",
      run(None, "select role from study_institution_members where user_id = %s and institution_id = %s", minor, uni2) == "student")
grown = harness.new_user(db, "grown@x.com")
run(grown, "select study_age_confirm('adult')")
run(eve, "select study_institution_minors(%s, false)", uni2)
run(grown, "select study_class_join(%s)", cls2["code"])
check("adults join either way", run(None, "select role from study_institution_members where user_id = %s", grown) == "student")
sch = run(eve, "select study_institution_register('Hill School', 'GB', 'school', p_minors_consent => true)")
run(kaivon, "select study_staff_review(%s, 'approved', 10)", sch)
check("a school can't turn it off", "schools need it" in (refused(eve, "select study_institution_minors(%s, false)", sch) or ""))

print()
print("All platform and gap checks passed." if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
