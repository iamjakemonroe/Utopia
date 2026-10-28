"""Chip Study (20261028140000_chip_study.sql): each student's study spaces
(topics and assignments), documents, sources, notes, tasks, focus sessions,
review deck and practice results are theirs alone;
Chip's conversations and the AI-use record are written by the server and
can't be edited by the student; saving a document checks its version; the
allowance is held before each call and settled after, by tier (free, Pro
with its best model by day and period, guests turned away); readings and
uploads are limited per tier; and forgetting a student removes their work
but not what they've used today."""
import json
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
    """Runs [sql] as [user] ('service' for the service role, 'anon' for
    someone signed out); the first row's first value, or the error's first
    line."""
    harness.as_admin(db)
    if user == "service":
        with db.cursor() as c:
            c.execute("set role service_role")
    elif user == "anon":
        with db.cursor() as c:
            c.execute("set role anon")
    else:
        harness.as_user(db, user)
    try:
        with db.cursor() as c:
            c.execute(sql, args)
            try:
                rows = c.fetchall()
                return rows[0][0] if rows else None
            except Exception:
                return "ok"
    except Exception as e:
        return "ERROR " + str(e).split("\n")[0]
    finally:
        harness.as_admin(db)


def ok(result):
    return result in (None, "", "ok")


def err(result, text=""):
    return isinstance(result, str) and result.startswith("ERROR") and text in result


def count(sql, *args):
    harness.as_admin(db)
    return one(sql, *args)


def make_pro(user, days_left=20):
    harness.as_admin(db)
    one("""insert into web_subscriptions (user_id, plan_id, currency, amount, ref, email, status, period_end)
           values (%s, 'study.pro.monthly', 'USD', 4.99, 'kaivon-sub-' || gen_random_uuid(), 'pro@example.com',
                   'active', now() + make_interval(days => %s)) returning 1""", user, days_left)


def usage(user):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("""select fast_usd, best_usd, asks, best_asks, uploads from study_usage
                      where user_id = %s and day = (now() at time zone 'utc')::date""", (user,))
        row = c.fetchone()
        return tuple(float(v) for v in row) if row else None


amy = harness.new_user(db, "amy@example.com")
ben = harness.new_user(db, "ben@example.com")
guest = harness.new_user(db)

# ── The plan ───────────────────────────────────────────────────────────
shop = attempt(amy, "select json_agg(s) from web_plan_shop('USD') s where s.product = 'study_pro'")
check("Chip Study Pro is on sale at $4.99 a month",
      shop and shop[0]["plan_id"] == "study.pro.monthly" and float(shop[0]["amount"]) == 4.99
      and shop[0]["period"] == "monthly" and shop[0]["until"] is None, shop)
start = attempt(amy, "select web_subscribe_start('study.pro.monthly', 'USD')")
check("an account can start subscribing to it", isinstance(start, dict) and start["product"] == "study_pro"
      and start["ref"].startswith("kaivon-sub-") and float(start["amount"]) == 4.99, start)
check("a guest can't", err(attempt(guest, "select web_subscribe_start('study.pro.monthly', 'USD')"),
                           "save your account"))
check("a pending checkout isn't Pro", attempt(amy, "select study_me() ->> 'tier'") == "free")

# ── Assignments are their owner's ──────────────────────────────────────
a1 = attempt(amy, "insert into study_assignments (title, course, brief, rubric) values "
                  "('Climate essay', 'GEO 101', 'Write 1500 words', 'Argument 40%%') returning id")
check("a student makes an assignment", a1 and not str(a1).startswith("ERROR"), a1)
check("it's theirs", count("select user_id::text from study_assignments where id = %s", a1) == amy)
check("someone else can't see it", attempt(ben, "select count(*) from study_assignments") == 0)
check("or change it", attempt(ben, "update study_assignments set title = 'x' where id = %s returning 1", a1) is None)
check("or delete it", attempt(ben, "delete from study_assignments where id = %s returning 1", a1) is None)
check("nobody signed out sees anything", err(attempt("anon", "select count(*) from study_assignments"),
                                            "permission denied"))
check("can't be made for someone else",
      err(attempt(ben, "insert into study_assignments (user_id, title) values (%s, 'sneaky')", amy)))
check("can't be given away",
      err(attempt(amy, "update study_assignments set user_id = %s where id = %s", ben, a1)))
check("a title is needed", err(attempt(amy, "insert into study_assignments (title) values ('')")))
b1 = attempt(ben, "insert into study_assignments (title) values ('Ben''s lab') returning id")

# ── Documents, sources, notes, tasks ───────────────────────────────────
d1 = attempt(amy, "insert into study_documents (assignment_id) values (%s) returning id", a1)
check("a document goes in your own assignment", d1 and not str(d1).startswith("ERROR"), d1)
check("not in someone else's",
      err(attempt(ben, "insert into study_documents (assignment_id) values (%s)", a1), "row-level security"))
check("someone else's documents aren't seen", attempt(ben, "select count(*) from study_documents") == 0)
check("a document can't move to another assignment",
      err(attempt(amy, "update study_documents set assignment_id = %s where id = %s", b1, d1)))

saved = attempt(amy, "select study_save_doc(%s, 1, %s::jsonb, 'Some words here', 3, 1, null)",
                d1, json.dumps({"type": "doc", "content": []}))
check("saving over the right version moves it on", saved == {"ok": True, "version": 2}, saved)
check("the assignment shows the document's words",
      count("select words from study_assignments where id = %s", a1) == 3)
stale = attempt(amy, "select study_save_doc(%s, 1, '{}'::jsonb, 'old', 1, 0, null)", d1)
check("saving over an old version doesn't, and says which is there", stale == {"ok": False, "version": 2}, stale)
check("the text from before stays", count("select text from study_documents where id = %s", d1) == "Some words here")
check("Chip's words can't be more than the document's",
      attempt(amy, "select study_save_doc(%s, 2, null, null, 5, 50, 'Final draft')", d1) == {"ok": True, "version": 3}
      and count("select chip_words from study_documents where id = %s", d1) == 5
      and count("select title from study_documents where id = %s", d1) == "Final draft")
check("someone else can't save it",
      err(attempt(ben, "select study_save_doc(%s, 3, '{}'::jsonb, 'x', 1, 0, null)", d1), "unknown document"))
code = attempt(amy, "insert into study_documents (assignment_id, kind, title, sort) values (%s, 'code', 'main.py', 1) returning id", a1)
attempt(amy, "select study_save_doc(%s, 1, '{}'::jsonb, 'print(1)', 1, 0, null)", code)
check("only the main document's words count on the assignment",
      count("select words from study_assignments where id = %s", a1) == 5)

s1 = attempt(amy, "insert into study_sources (assignment_id, kind, data) values (%s, 'book', %s::jsonb) returning id",
             a1, json.dumps({"authors": ["Smith, J."], "year": "2020", "title": "Climate"}))
check("a source goes in", s1 and not str(s1).startswith("ERROR"), s1)
check("not in someone else's assignment",
      err(attempt(ben, "insert into study_sources (assignment_id) values (%s)", a1)))
n1 = attempt(amy, "insert into study_notes (assignment_id, body) values (%s, 'idea') returning id", a1)
check("a note goes in", n1 and not str(n1).startswith("ERROR"), n1)
check("someone else's notes aren't seen", attempt(ben, "select count(*) from study_notes") == 0)

t1 = attempt(amy, "insert into study_tasks (assignment_id, title, due_on) values (%s, 'Outline', current_date + 2) returning id", a1)
check("a task goes in", t1 and not str(t1).startswith("ERROR"), t1)
attempt(amy, "update study_tasks set done = true where id = %s", t1)
check("ticking it off notes when", count("select done_at is not null from study_tasks where id = %s", t1) is True)
attempt(amy, "update study_tasks set done = false where id = %s", t1)
check("unticking clears it", count("select done_at is null from study_tasks where id = %s", t1) is True)
check("someone else can't tick it", attempt(ben, "update study_tasks set done = true where id = %s returning 1", t1) is None)

# ── Focus ──────────────────────────────────────────────────────────────
f1 = attempt(amy, "insert into study_focus (assignment_id, minutes) values (%s, 25) returning id", a1)
check("a focus session is kept", f1 and not str(f1).startswith("ERROR"), f1)
check("and adds to the assignment's minutes", count("select focus_minutes from study_assignments where id = %s", a1) == 25)
attempt(amy, "insert into study_focus (minutes) values (10)")
check("a session needn't be on an assignment", attempt(amy, "select sum(minutes) from study_focus") == 35)
check("not over four hours", err(attempt(amy, "insert into study_focus (minutes) values (241)")))
check("not in the future", err(attempt(amy, "insert into study_focus (minutes, started_at) values (5, now() + interval '1 hour')")))
check("not on someone else's assignment",
      err(attempt(ben, "insert into study_focus (assignment_id, minutes) values (%s, 5)", a1)))
attempt(amy, "delete from study_focus where id = %s", f1)
check("a deleted one comes off", count("select focus_minutes from study_assignments where id = %s", a1) == 0)

# ── Chip's side is the server's ────────────────────────────────────────
check("a student can't write Chip's conversations",
      err(attempt(amy, "insert into study_threads (assignment_id, user_id) values (%s, %s)", a1, amy), "permission denied"))
harness.as_admin(db)
th = one("insert into study_threads (assignment_id, user_id, title) values (%s, %s, 'Plan') returning id", a1, amy)
mu = one("insert into study_messages (thread_id, assignment_id, user_id, role, mode, content) values (%s, %s, %s, 'user', 'write', 'Draft my intro') returning id", th, a1, amy)
mc = one("""insert into study_messages (thread_id, assignment_id, user_id, role, mode, content, meta)
            values (%s, %s, %s, 'chip', 'write', 'Here is a draft', '{"model": "claude-opus-5-5"}') returning id""", th, a1, amy)
one("insert into study_ai_log (assignment_id, user_id, message_id, action, prompt, output, model) values (%s, %s, %s, 'write', 'Draft my intro', 'Here is a draft', 'claude-opus-5-5') returning 1", a1, amy, mc)
check("the student reads their conversation", attempt(amy, "select count(*) from study_messages") == 2)
check("someone else doesn't", attempt(ben, "select count(*) from study_messages") == 0)
check("a message can't be written", err(attempt(amy, "insert into study_messages (thread_id, assignment_id, user_id, role, mode, content) values (%s, %s, %s, 'chip', 'write', 'fake')", th, a1, amy), "permission denied"))
check("or edited", err(attempt(amy, "update study_messages set content = 'x'"), "permission denied"))
check("the record can't be edited", err(attempt(amy, "update study_ai_log set words = 0"), "permission denied"))
check("or have a line removed", err(attempt(amy, "delete from study_ai_log"), "permission denied"))
check("or have one written", err(attempt(amy, "insert into study_ai_log (assignment_id, user_id, action) values (%s, %s, 'write')", a1, amy), "permission denied"))

logged = attempt(amy, "select study_log_use(%s, 'inserted', %s, 120, 'Here is a draft')", a1, mc)
check("putting Chip's words in the document is noted", logged and not str(logged).startswith("ERROR"), logged)
check("with the words and the model",
      count("select words || ' ' || model || ' ' || action from study_ai_log where id = %s", logged) == "120 claude-opus-5-5 inserted")
check("only from Chip's own messages",
      err(attempt(amy, "select study_log_use(%s, 'inserted', %s, 5, '')", a1, mu), "unknown message"))
check("only things a student does",
      err(attempt(amy, "select study_log_use(%s, 'write', null, 5, '')", a1), "unknown action"))
check("only on their own assignment",
      err(attempt(ben, "select study_log_use(%s, 'added_tasks', null, 0, '')", a1), "unknown assignment"))
check("not with someone else's message",
      err(attempt(ben, "select study_log_use(%s, 'inserted', %s, 5, '')", b1, mc), "unknown message"))

check("clearing a conversation is allowed", ok(attempt(amy, "delete from study_threads where id = %s", th)))
check("it takes the messages", count("select count(*) from study_messages where thread_id = %s", th) == 0)
check("but the record keeps every line", count("select count(*) from study_ai_log where assignment_id = %s", a1) == 2)
check("pointing at nothing now", count("select count(*) from study_ai_log where message_id is not null and assignment_id = %s", a1) == 0)

# ── The allowance ──────────────────────────────────────────────────────
check("a guest is asked to save their account",
      attempt(guest, "select study_allow('fast')") == {"ok": False, "tier": "guest", "why": "account"})
r = attempt(amy, "select study_allow('fast')")
check("a free account gets Chip Fast", r and r["ok"] and r["model"] == "fast" and r["tier"] == "free"
      and float(r["hold"]) == 0.002, r)
check("and the call is held", usage(amy)[:3] == (0.002, 0.0, 1.0), usage(amy))
r = attempt(amy, "select study_allow('best')")
check("asking a free account's Chip for the best model gets Fast, and says why",
      r and r["ok"] and r["model"] == "fast" and r["note"] == "pro", r)
day = r["day"]
check("settling is the server's job",
      err(attempt(amy, "select study_spend(%s, %s, 'fast', 0.002, 'explain', 'claude-haiku-5-5', 1, 1, 0, 0, 0, 0.001)", amy, day),
          "permission denied"))
attempt("service", "select study_spend(%s, %s, 'fast', 0.002, 'explain', 'claude-haiku-5-5', 1000, 200, 0, 0, 0, 0.0005)", amy, day)
check("settling swaps the hold for what it cost", abs(usage(amy)[0] - 0.0025) < 1e-9, usage(amy))
check("and adds it to the day's costs",
      count("select usd || ' ' || calls || ' ' || tier from study_costs where feature = 'explain'") == "0.00050 1 free")
harness.as_admin(db)
one("update study_usage set fast_usd = 0.03 where user_id = %s and day = %s returning 1", amy, day)
r = attempt(amy, "select study_allow('fast')")
check("a free account's day can be used up", r and r["ok"] is False and r["why"] == "limit" and r["resets_at"], r)

me = attempt(ben, "select study_me()")
check("study_me: a free account's allowance",
      me and me["tier"] == "free" and float(me["fast"]["cap"]) == 0.03 and me["best"] is None
      and me["uploads"]["max_mb"] == 4 and me["readings"]["cap"] == 3 and float(me["price"]["amount"]) == 4.99, me)
check("study_me needs a signed-in student", err(attempt("anon", "select study_me()")))

harness.as_admin(db)
one("update study_settings set daily_free_usd = 0.001 returning 1")
r = attempt(ben, "select study_allow('fast')")
check("once free accounts together have used the day's budget, it's busy", r and r["why"] == "busy", r)
one("update study_settings set daily_free_usd = 15 returning 1")

# Uploads
r = attempt(ben, "select study_allow('fast', 'upload', 5 * 1048576)")
check("a free account's upload can't be over 4 MB", r == {"ok": False, "tier": "free", "why": "size", "max_mb": 4}, r)
for i in range(3):
    attempt(ben, "select study_allow('fast', 'upload', 1000)")
r = attempt(ben, "select study_allow('fast', 'upload', 1000)")
check("or more than 3 a day", r and r["why"] == "uploads", r)

# Pro
cat = harness.new_user(db, "cat@example.com")
make_pro(cat)
check("an active subscription is Pro", attempt(cat, "select study_me() ->> 'tier'") == "pro")
r = attempt(cat, "select study_allow('best')")
check("Pro gets the best model, held at more", r and r["ok"] and r["model"] == "best" and float(r["hold"]) == 0.05, r)
check("counted as a best-model ask", usage(cat)[1:4] == (0.05, 1.0, 1.0), usage(cat))
attempt("service", "select study_spend(%s, %s, 'best', 0.05, 'plan', 'claude-opus-5-5', 5000, 900, 3000, 0, 1, 0.031)", cat, r["day"])
check("Pro's cost is the Pro tier's", count("select tier from study_costs where feature = 'plan'") == "pro")
check("settled", abs(usage(cat)[1] - 0.031) < 1e-9, usage(cat))
harness.as_admin(db)
one("update study_usage set best_usd = 0.40 where user_id = %s returning 1", cat)
r = attempt(cat, "select study_allow('best')")
check("past the best model's day, Pro carries on with Fast", r and r["ok"] and r["model"] == "fast"
      and r["note"] == "best_used", r)
one("update study_usage set best_usd = 0.10, day = day - 3 where user_id = %s returning 1", cat)
one("insert into study_usage (user_id, day, best_usd) values (%s, (now() at time zone 'utc')::date - 10, 2.95) returning 1", cat)
r = attempt(cat, "select study_allow('best')")
check("and past the period's", r and r["model"] == "fast" and r["note"] == "best_used", r)
one("delete from study_usage where user_id = %s and day < (now() at time zone 'utc')::date - 5 returning 1", cat)
r = attempt(cat, "select study_allow('best')")
check("what was spent before the period started doesn't count", r and r["model"] == "best", r)
me = attempt(cat, "select study_me()")
check("study_me: Pro's allowance", me["tier"] == "pro" and me["pro_until"] and float(me["best"]["cap"]) == 0.4
      and float(me["best"]["period_cap"]) == 3.0 and float(me["fast"]["cap"]) == 0.05
      and me["uploads"]["max_mb"] == 20 and me["readings"]["cap"] == 30, me)
check("Pro can upload a bigger file", attempt(cat, "select study_allow('fast', 'upload', 15 * 1048576)")["ok"] is True)
one("update study_usage set fast_usd = 0.05 where user_id = %s and day = (now() at time zone 'utc')::date returning 1", cat)
r = attempt(cat, "select study_allow('fast')")
check("Pro's Fast has its own day", r and r["why"] == "limit", r)
r = attempt(cat, "select study_allow('best')")
check("which doesn't stop the best model", r and r["ok"] and r["model"] == "best", r)
check("the server can't be asked for an unknown kind", err(attempt(cat, "select study_allow('fast', 'draw')"), "unknown kind"))

# ── Readings ───────────────────────────────────────────────────────────
dan = harness.new_user(db, "dan@example.com")
ad = attempt(dan, "insert into study_assignments (title) values ('Reading list') returning id")
check("a free account's reading can't be over 60,000 characters",
      err(attempt(dan, "insert into study_sources (assignment_id, content) values (%s, repeat('a', 60001))", ad), "reading too long"))
for i in range(3):
    attempt(dan, "insert into study_sources (assignment_id, content) values (%s, 'chapter text')", ad)
check("or more than 3 a day",
      err(attempt(dan, "insert into study_sources (assignment_id, content) values (%s, 'one more')", ad), "readings limit"))
check("a source without a reading always goes in",
      not str(attempt(dan, "insert into study_sources (assignment_id, kind) values (%s, 'web') returning id", ad)).startswith("ERROR"))
check("and can have its note changed",
      attempt(dan, "update study_sources set note = 'read p.4' where content = 'chapter text' returning 1") == 1)
make_pro(dan)
check("Pro's readings can be longer",
      not str(attempt(dan, "insert into study_sources (assignment_id, content) values (%s, repeat('a', 300000)) returning id", ad)).startswith("ERROR"))

# ── Learning: topics, the review deck, practice ───────────────────────
eve = harness.new_user(db, "eve@example.com")
topic = attempt(eve, "insert into study_assignments (title, kind) values ('Organic chemistry: mechanisms', 'topic') returning id")
check("a study space can be something to learn", count("select kind from study_assignments where id = %s", topic) == "topic")
check("an assignment by default", count("select kind from study_assignments where id = %s", ad) == "assignment")
check("only those two kinds", err(attempt(eve, "insert into study_assignments (title, kind) values ('x', 'course')")))
c1 = attempt(eve, "insert into study_cards (assignment_id, front, back, created_by) values (%s, 'SN2', 'One step, backside attack', 'chip') returning id", topic)
check("a flashcard goes in the deck", c1 and not str(c1).startswith("ERROR"), c1)
check("due straight away", count("select due_at <= now() and interval_days = 0 and ease = 2.5 from study_cards where id = %s", c1) is True)
check("the student moves it on as they review it",
      attempt(eve, "update study_cards set interval_days = 3, ease = 2.6, reps = 1, due_at = now() + interval '3 days', reviewed_at = now() where id = %s returning interval_days", c1) == 3)
check("within sensible bounds", err(attempt(eve, "update study_cards set ease = 9 where id = %s", c1)))
check("someone else's deck isn't seen", attempt(ben, "select count(*) from study_cards") == 0)
check("or changed", attempt(ben, "update study_cards set front = 'x' where id = %s returning 1", c1) is None)
check("a card can't be filed under someone else's space",
      err(attempt(ben, "insert into study_cards (assignment_id, front, back) values (%s, 'a', 'b')", topic), "row-level security"))
check("a card needs both sides", err(attempt(eve, "insert into study_cards (front, back) values ('', 'b')")))
check("practice results are kept",
      not str(attempt(eve, "insert into study_practice (assignment_id, kind, correct, total) values (%s, 'quiz', 4, 5) returning id", topic)).startswith("ERROR"))
check("never more right than asked", err(attempt(eve, "insert into study_practice (kind, correct, total) values ('review', 6, 5)")))
check("and can't be edited afterwards", err(attempt(eve, "update study_practice set correct = 5"), "permission denied"))
check("someone else's results aren't seen", attempt(ben, "select count(*) from study_practice") == 0)
attempt(eve, "delete from study_assignments where id = %s", topic)
check("cards outlive the space they came from", count("select count(*) from study_cards where user_id = %s and assignment_id is null", eve) == 1)
check("so do results", count("select count(*) from study_practice where user_id = %s and assignment_id is null", eve) == 1)
harness.as_admin(db)
th2 = one("insert into study_threads (assignment_id, user_id) values (%s, %s) returning id", ad, dan)
check("Chip has a guiding mode", one("insert into study_messages (thread_id, assignment_id, user_id, role, mode, content) values (%s, %s, %s, 'chip', 'guide', 'What do you think?') returning mode", th2, ad, dan) == "guide")
check("and the record knows it", one("insert into study_ai_log (assignment_id, user_id, action) values (%s, %s, 'guide') returning action", ad, dan) == "guide")
check("forgetting takes the deck and the results", ok(attempt(eve, "select study_forget_me()"))
      and count("select count(*) from study_cards where user_id = %s", eve) == 0
      and count("select count(*) from study_practice where user_id = %s", eve) == 0)

# ── Forgetting ─────────────────────────────────────────────────────────
before = usage(amy)
check("a student can remove all their study data", ok(attempt(amy, "select study_forget_me()")))
check("their assignments go", count("select count(*) from study_assignments where user_id = %s", amy) == 0)
check("with everything in them", count("select count(*) from study_documents where user_id = %s", amy) == 0
      and count("select count(*) from study_ai_log where user_id = %s", amy) == 0
      and count("select count(*) from study_tasks where user_id = %s", amy) == 0)
check("and their focus sessions", count("select count(*) from study_focus where user_id = %s", amy) == 0)
check("but not what they've used today", usage(amy) == before, (usage(amy), before))
check("someone else's are untouched", count("select count(*) from study_assignments where user_id = %s", ben) == 1)
check("only the server forgets someone else", err(attempt(ben, "select study_forget(%s)", amy), "permission denied"))
check("which it can", ok(attempt("service", "select study_forget(%s)", ben))
      and count("select count(*) from study_assignments where user_id = %s", ben) == 0)

print()
if fails:
    print(f"{len(fails)} failed")
    sys.exit(1)
print("All Chip Study checks passed.")
