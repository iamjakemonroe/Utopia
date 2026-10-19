"""Voice messages from a browser (.wav) post to the chat, like the apps'
(.m4a); anything else is still turned away."""
import sys
import uuid

import harness

db = harness.fresh()
fails = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


def q(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)
        try:
            return c.fetchall()
        except Exception:
            return None


def sends(user, match, body):
    harness.as_user(db, user)
    try:
        q("select send_chess_chat(%s, 'voice', %s)", match, body)
        return True
    except Exception as e:
        return str(e).splitlines()[0]


a = harness.new_user(db, "a@example.com")
b = harness.new_user(db, "b@example.com")
harness.as_admin(db)
match = q("select _board_create_match('chess', %s, %s, 0, 10, 0)", a, b)[0][0]
note = lambda ext: f"voice:{match}/{uuid.uuid4()}.{ext}|2400|0123456789"
check("a browser's .wav note posts", sends(a, match, note("wav")) is True)
check("the apps' .m4a still does", sends(b, match, note("m4a")) is True)
check("anything else doesn't", sends(a, match, note("ogg")) is not True)
sys.exit(1 if fails else 0)
