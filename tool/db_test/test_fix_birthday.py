"""tool/sql/fix_birthday.sql: a locked birthday corrected by support, and
still locked after; nonsense dates and unknown players refused."""
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
    with db.cursor() as c:
        c.execute(sql, args)
        if c.description is None:
            return None
        rows = c.fetchall()
        return rows[0][0] if rows else None


def fix(who, month, day):
    harness.as_admin(db)
    sql = (SQL / "fix_birthday.sql").read_text().replace("'their_username'", f"'{who}'")
    sql = sql.replace("v_month int := 12;", f"v_month int := {month};").replace("v_day int := 21;", f"v_day int := {day};")
    with db.cursor() as c:
        c.execute(sql)


me = harness.new_user(db, "me@example.com")
harness.as_user(db, me)
one("select set_birthday(10, 19)")
harness.as_admin(db)
one("update user_birthdays set set_at = now() - interval '3 days' where user_id = %s", me)
harness.as_user(db, me)
try:
    one("select set_birthday(12, 21)")
    locked = False
except Exception as e:
    db.rollback() if not db.autocommit else None
    locked = "locked" in str(e)
check("set a few days ago: the player can't change it", locked)

fix("me@example.com", 12, 21)
harness.as_admin(db)
check("support corrects it", one("select (month, day) = (12, 21) from user_birthdays where user_id = %s", me))
harness.as_user(db, me)
try:
    one("select set_birthday(1, 1)")
    still = False
except Exception as e:
    db.rollback() if not db.autocommit else None
    still = "locked" in str(e)
check("…and it stays locked", still)

for label, args in [("not a real date", ("me@example.com", 2, 30)), ("an unknown player", ("nobody@example.com", 12, 21))]:
    try:
        fix(*args)
        check(f"refused: {label}", False)
    except Exception as e:
        db.rollback() if not db.autocommit else None
        check(f"refused: {label}", "real date" in str(e) or "No account" in str(e), e)

sys.exit(1 if fails else 0)
