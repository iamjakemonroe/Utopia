"""Chip Study rooms (20261107230000_study_rooms.sql): who may open, join and
edit a room, its limits by plan, class rooms for invited students, and the
room server saving the shared work back to the host's assignment."""

import json
import sys
import uuid

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


def assignment(user, title="Essay on climate"):
    return run(user, "insert into study_assignments (title) values (%s) returning id", title)


def adult(user):
    run(user, "select study_age_confirm('adult')")


# ── Personal rooms ────────────────────────────────────────────────────────
amy = harness.new_user(db, "amy@example.com")
ben = harness.new_user(db, "ben@example.com")
cal = harness.new_user(db, "cal@example.com")
kid = harness.new_user(db, "kid@example.com")
run(None, "update profiles set display_name = 'Amy' where id = %s", amy)
run(None, "update profiles set display_name = 'Ben' where id = %s", ben)
a1 = assignment(amy)
doc = run(amy, "insert into study_documents (assignment_id, title, content, text) values (%s, 'Draft', '{\"type\":\"doc\"}', 'hello') returning id", a1)
run(amy, "insert into study_notes (assignment_id, body) values (%s, 'remember the IPCC report')", a1)

check("a room needs an age answer first", "adults only" in (refused(amy, "select study_room_open(%s)", a1) or ""))
adult(amy)
check("only on your own assignment", "no such assignment" in (refused(ben, "select study_room_open(%s)", a1) or ""))
room = run(amy, "select study_room_open(%s)", a1)
check("a free host gets 4 people and an hour",
      room["max_people"] == 4 and room["ends_at"] is not None and room["edit_mode"] == "everyone" and room["admission"] == "link", room)
check("the host is in it and can edit",
      [(m["name"], m["role"], m["can_edit"]) for m in room["members"]] == [("Amy", "host", True)], room["members"])
check("opening again answers the same room", run(amy, "select study_room_open(%s)", a1)["id"] == room["id"])

peek = run(ben, "select study_room_peek(%s)", room["token"])
check("a link can be looked at first", peek["found"] and peek["title"] == "Essay on climate" and peek["host"] == "Amy", peek)
check("but joining a personal room needs an adult", peek["reason"] == "age_unknown" and not peek["can_join"], peek)
check("so joining is refused", "age_unknown" in (refused(ben, "select study_room_join(%s)", room["token"]) or ""))
run(kid, "select study_age_confirm('guardian')")
check("under-18s can't join personal rooms", "adults_only" in (refused(kid, "select study_room_join(%s)", room["token"]) or ""))
adult(ben)
j = run(ben, "select study_room_join(%s)", room["token"])
check("an adult with the link joins and can edit", j["state"] == "in" and j["role"] == "member" and j["can_edit"], j)
check("joining twice changes nothing", run(ben, "select study_room_join(%s)", room["token"]) == j)
check("a wrong link finds nothing", run(ben, "select study_room_peek('nope')") == {"found": False})

acc = run(ben, "select study_room_access(%s)", room["id"])
check("the room server learns who they are and what they may do",
      acc["name"] == "Ben" and acc["can_edit"] and acc["live"] and acc["max_people"] == 4 and acc["state"] == "in", acc)
check("names never come from emails", "@" not in json.dumps(run(amy, "select study_room_get(%s)", room["id"])))
check("strangers get nothing from the room server", "not a member" in (refused(cal, "select study_room_access(%s)", room["id"]) or ""))

ws = run(ben, "select study_room_workspace(%s)", room["id"])
check("a member sees the shared workspace",
      ws["assignment"]["title"] == "Essay on climate" and [d["id"] for d in ws["documents"]] == [str(doc)]
      and [n["body"] for n in ws["notes"]] == ["remember the IPCC report"], ws)
check("without reading the host's rows directly", run(ben, "select count(*) from study_documents") == 0)
check("a stranger can't see the workspace", "not allowed" in (refused(cal, "select study_room_workspace(%s)", room["id"]) or ""))

check("members can't change settings", "not allowed" in (refused(ben, "select study_room_settings(%s, 'chosen')", room["id"]) or ""))
r = run(amy, "select study_room_settings(%s, 'chosen', 'ask')", room["id"])
check("the host chooses who edits", [m["can_edit"] for m in r["members"] if m["name"] == "Ben"] == [False])
run(amy, "select study_room_member_set(%s, %s, p_can_edit => true)", room["id"], ben)
check("and can let one person edit", run(ben, "select study_room_access(%s)", room["id"])["can_edit"] is True)
adult(cal)
jc = run(cal, "select study_room_join(%s)", room["token"])
check("when the host lets people in, newcomers wait", jc["state"] == "waiting" and not jc["can_edit"], jc)
check("a waiting person can't see the workspace", "not allowed" in (refused(cal, "select study_room_workspace(%s)", room["id"]) or ""))
run(amy, "select study_room_member_set(%s, %s, 'in')", room["id"], cal)
check("let in, they can", run(cal, "select study_room_workspace(%s)", room["id"])["assignment"]["title"] == "Essay on climate")
check("but can't edit until chosen", run(cal, "select study_room_access(%s)", room["id"])["can_edit"] is False)
check("members can't take others out", "not allowed" in (refused(ben, "select study_room_member_set(%s, %s, 'removed')", room["id"], cal) or ""))
check("nobody can take the host out", "not allowed" in (refused(amy, "select study_room_member_set(%s, %s, 'removed')", room["id"], amy) or ""))
run(amy, "select study_room_member_set(%s, %s, 'removed')", room["id"], cal)
check("someone taken out can't come back", "removed" in (refused(cal, "select study_room_join(%s)", room["token"]) or ""))
check("or see anything", "not allowed" in (refused(cal, "select study_room_workspace(%s)", room["id"]) or ""))
old = room["token"]
new = run(amy, "select study_room_new_link(%s)", room["id"])["token"]
dan = harness.new_user(db, "dan@example.com")
adult(dan)
check("a new link: the old one stops working", new != old and run(dan, "select study_room_peek(%s)", old) == {"found": False})
check("members already in stay in", run(ben, "select study_room_access(%s)", room["id"])["state"] == "in")
check("rooms I'm in are listed", [x["id"] for x in run(ben, "select study_rooms_mine()")] == [room["id"]])

# The room server saves the shared work.
note_id, task_id = str(uuid.uuid4()), str(uuid.uuid4())
new_doc = str(uuid.uuid4())
check("users can't save through the room server's door",
      refused(ben, "select study_room_save(%s, '[]'::jsonb)", room["id"]) is not None)
run(None, "select study_room_save(%s, %s::jsonb, %s::jsonb, %s::jsonb)", room["id"],
    json.dumps([{"id": str(doc), "kind": "doc", "title": "Draft", "content": {"type": "doc", "content": []}, "text": "hello world", "words": 2},
                {"id": new_doc, "kind": "code", "title": "analysis.py", "content": {"code": "print(1)"}, "text": "print(1)", "words": 1, "sort": 1}]),
    json.dumps([{"id": note_id, "body": "new shared note", "pinned": True}]),
    json.dumps([{"id": task_id, "title": "Find 3 sources", "due_on": "", "done": False}]))
check("documents are saved to the host's assignment",
      run(None, "select text from study_documents where id = %s", doc) == "hello world"
      and run(None, "select user_id from study_documents where id = %s", new_doc) == amy)
check("notes and tasks match the room's",
      run(None, "select array_agg(body) from study_notes where assignment_id = %s", a1) == ["new shared note"]
      and run(None, "select title from study_tasks where id = %s", task_id) == "Find 3 sources")
check("the assignment's word count follows its main document", run(None, "select words from study_assignments where id = %s", a1) == 2)
other = assignment(ben, "Ben's own")
ben_doc = run(ben, "insert into study_documents (assignment_id, title, text) values (%s, 'Mine', 'private') returning id", other)
run(None, "select study_room_save(%s, %s::jsonb)", room["id"], json.dumps([{"id": str(ben_doc), "kind": "doc", "text": "overwritten"}]))
check("a room can't write to someone else's document", run(None, "select text from study_documents where id = %s", ben_doc) == "private")

# Time limits and plans.
run(None, "update study_rooms set ends_at = now() - interval '1 minute' where id = %s", room["id"])
check("a free room ends after its hour", run(ben, "select study_room_access(%s)", room["id"])["live"] is False)
check("and can't be joined", run(dan, "select study_room_peek(%s)", new)["reason"] == "ended")
room2 = run(amy, "select study_room_open(%s)", a1)
check("the host can open a new one", room2["id"] != room["id"])
run(amy, "select study_room_end(%s)", room2["id"])
run(None, "select public._study_give_week(%s, 'referral:study:test')", amy)
room3 = run(amy, "select study_room_open(%s)", a1)
check("a Pro host gets 10 people and no time limit", room3["max_people"] == 10 and room3["ends_at"] is None, room3)
run(None, "update study_rooms set last_active_at = now() - interval '7 hours' where id = %s", room3["id"])
check("a room nobody used for hours ends by itself", run(amy, "select study_room_access(%s)", room3["id"])["live"] is False)
check("and opening again starts fresh", run(amy, "select study_room_open(%s)", a1)["id"] != room3["id"])

# ── Class rooms ───────────────────────────────────────────────────────────
staff = harness.new_user(db, "staff@kaivon.app")
run(None, "insert into public.study_staff (user_id) values (%s)", staff)
ada = harness.new_user(db, "ada@uni.edu")
tom = harness.new_user(db, "tom@uni.edu")
sue = harness.new_user(db, "sue@uni.edu")
max_ = harness.new_user(db, "max@uni.edu")
teen = harness.new_user(db, "teen@uni.edu")
inst = run(ada, "select study_institution_register('Uni', 'KE', 'university')")
run(staff, "select study_staff_review(%s, 'approved', 100, 90, 'uni.edu')", inst)
hist = run(ada, "select study_class_create(%s, 'HIST 210')", inst)
bio = run(ada, "select study_class_create(%s, 'BIO 101')", inst)
t_tom = run(ada, "select token from study_institution_invite(%s, array['tom@uni.edu'], 'teacher', %s)", inst, hist["id"])
run(tom, "select study_invite_accept(%s)", t_tom)
for u in (sue, teen):
    run(u, "select study_class_join(%s)", hist["code"])
run(max_, "select study_class_join(%s)", bio["code"])
run(teen, "select study_age_confirm('guardian')")

lesson = assignment(tom, "Lesson: the printing press")
check("a student can't open a class room", "not allowed" in (refused(sue, "select study_room_open(%s, %s)", assignment(sue), inst) or ""))
cr = run(tom, "select study_room_open(%s, %s)", lesson, inst)
check("a teacher opens a class room: 50 people, no time limit, only chosen editors, invited only",
      cr["max_people"] == 50 and cr["ends_at"] is None and cr["edit_mode"] == "chosen" and cr["admission"] == "invited", cr)
check("a teacher can't invite a class they don't teach",
      "not your class" in (refused(tom, "select study_room_invite(%s, array[%s]::uuid[])", cr["id"], bio["id"]) or ""))
check("or another class's student",
      "not your student" in (refused(tom, "select study_room_invite(%s, '{}', array[%s]::uuid[])", cr["id"], max_) or ""))
check("or someone outside the institution",
      "not in the institution" in (refused(tom, "select study_room_invite(%s, '{}', array[%s]::uuid[])", cr["id"], amy) or ""))
check("before an invite, students can't join", run(sue, "select study_room_peek(%s)", cr["token"])["reason"] == "not_invited")
cr = run(tom, "select study_room_invite(%s, array[%s]::uuid[])", cr["id"], hist["id"])
check("the teacher invites their class", [c["name"] for c in cr["invited_classes"]] == ["HIST 210"])
js = run(sue, "select study_room_join(%s)", cr["token"])
check("a student of the class joins, without editing", js["state"] == "in" and js["role"] == "member" and not js["can_edit"], js)
check("under-18s can join their institution's class rooms", run(teen, "select study_room_join(%s)", cr["token"])["state"] == "in")
check("a student of another class can't", "not_invited" in (refused(max_, "select study_room_join(%s)", cr["token"]) or ""))
check("nor an outsider with the link", "not_invited" in (refused(amy, "select study_room_join(%s)", cr["token"]) or ""))
check("class rooms can't be switched to anyone-with-the-link",
      "bad admission" in (refused(tom, "select study_room_settings(%s, null, 'link')", cr["id"]) or ""))
run(tom, "select study_room_member_set(%s, %s, p_can_edit => true)", cr["id"], sue)
check("the teacher chooses who edits", run(sue, "select study_room_access(%s)", cr["id"])["can_edit"] is True
      and run(teen, "select study_room_access(%s)", cr["id"])["can_edit"] is False)
ja = run(ada, "select study_room_join(%s)", cr["token"])
check("the institution's admin joins as a co-host", ja["role"] == "cohost" and ja["can_edit"], ja)
check("a co-host can't take the host out", "not allowed" in (refused(ada, "select study_room_member_set(%s, %s, 'removed')", cr["id"], tom) or ""))
run(ada, "select study_room_invite(%s, '{}', array[%s]::uuid[])", cr["id"], max_)
check("an admin can invite anyone in the institution", run(max_, "select study_room_join(%s)", cr["token"])["state"] == "in")
check("invited students see the room listed before joining",
      [x["title"] for x in run(sue, "select study_rooms_mine()")] == ["Lesson: the printing press"])
run(tom, "select study_room_uninvite(%s, p_class => %s)", cr["id"], hist["id"])
newbie = harness.new_user(db, "new@uni.edu")
run(newbie, "select study_class_join(%s)", hist["code"])
check("after uninviting a class, its students can't join", "not_invited" in (refused(newbie, "select study_room_join(%s)", cr["token"]) or ""))
run(tom, "select study_room_end(%s)", cr["id"])
check("ended: nobody can join or see it", run(sue, "select study_room_access(%s)", cr["id"])["live"] is False
      and "not allowed" in (refused(sue, "select study_room_workspace(%s)", cr["id"]) or ""))
check("members can't end a room", "not allowed" in (refused(sue, "select study_room_end(%s)", cr["id"]) or ""))
run(None, "select study_room_close(%s)", room2["id"])
check("users can't close rooms through the room server's door", refused(ben, "select study_room_close(%s)", room2["id"]) is not None)

print()
print("All room checks passed." if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
