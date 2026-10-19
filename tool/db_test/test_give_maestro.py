"""tool/sql/give_maestro.sql and take_maestro.sql: Chip at full for one
player (guests too), and back, never touching a paid subscription."""
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


def run(script, who):
    harness.as_admin(db)
    sql = (SQL / script).read_text().replace("'their_username'", "'" + who + "'")
    with db.cursor() as c:
        c.execute(sql)


def one(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)
        return c.fetchone()[0]


def tier(user):
    harness.as_user(db, user)
    return one("select chip_allow('chat') ->> 'tier'")


player = harness.new_user(db, "tester@example.com")
guest = harness.new_user(db)
check("a player starts free", tier(player) == "free")

run("give_maestro.sql", "Tester@Example.com")
check("by email: Chip is at full (Maestro)", tier(player) == "maestro")
harness.as_admin(db)
check("…for 30 days, with the frame", one(
    "select expires_at::date = (now() + interval '30 days')::date from maestro_subscriptions where user_id = %s", player)
    and one("select count(*) from user_auras where user_id = %s and aura_id = 'maestro'", player) == 1)

run("give_maestro.sql", guest)
check("by user ID, a guest too", tier(guest) == "maestro")

run("take_maestro.sql", "tester@example.com")
check("taken back: free again", tier(player) == "free")
run("take_maestro.sql", guest)
check("…the guest too", tier(guest) == "guest")

paid = harness.new_user(db, "paid@example.com")
harness.as_admin(db)
one("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'apple-123', now() + interval '9 days', true, 'production')", paid)
run("give_maestro.sql", "paid@example.com")
run("take_maestro.sql", "paid@example.com")
still = tier(paid)
harness.as_admin(db)
check("a paid subscription is never touched", still == "maestro" and one(
    "select original_id = 'apple-123' and auto_renew from maestro_subscriptions where user_id = %s", paid))

try:
    run("give_maestro.sql", "nobody@example.com")
    check("an unknown player is refused", False)
except Exception as e:
    db.rollback() if not db.autocommit else None
    check("an unknown player is refused", "No account matches" in str(e), e)

sys.exit(1 if fails else 0)
