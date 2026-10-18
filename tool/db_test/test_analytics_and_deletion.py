"""Our own analytics, and deleting an account forgets everything personal."""
import json
import sys

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


def raises(sql, *args):
    try:
        q(sql, *args)
        return None
    except Exception as e:
        return str(e).splitlines()[0]


def admin(sql, *args):
    harness.as_admin(db)
    return q(sql, *args)


ann = harness.new_user(db, "ann@example.com")
harness.as_user(db, ann)
batch = [
    {"name": "app_open", "props": {"guest": False}},
    {"name": "game_finished", "props": {"game": "ludo", "online": False}},
    {"name": "screen"},
    {"name": "Bad Name!", "props": {}},
    {"name": "store_purchase", "props": {"x": "y" * 3000}},
]
check("logs a batch", raises("select log_events(%s::jsonb)", json.dumps(batch)) is None)
names = sorted(r[0] for r in admin("select name from app_events where user_id = %s", ann))
check("keeps the good ones (with or without details)", names == ["app_open", "game_finished", "screen"], names)
harness.as_user(db, ann)
check("refuses a huge batch", raises("select log_events(%s::jsonb)", json.dumps([{"name": "x_y"}] * 101)) is not None)
check("players can't read events", raises("select count(*) from app_events") is not None)
check("players can't write them directly",
      raises("insert into app_events (user_id, name) values (%s, 'app_open')", ann) is not None)
check("players can't see the dashboards", raises("select * from analytics_daily") is not None)

d = admin("select day, new_players, active_players, games from analytics_daily")[0]
check("daily view counts", d[1] == 1 and d[2] == 1 and d[3] == 1, d)
r = admin("select joined, players, day_1_pct from analytics_retention")[0]
check("retention view", r[1] == 1 and r[2] == 0, r)
# Back the next day.
admin("update profiles set created_at = now() - interval '1 day' where id = %s", ann)
r = admin("select day_1_pct from analytics_retention")[0]
check("came back the next day: 100%", float(r[0]) == 100.0, r)

# Deleting the account forgets everything personal.
harness.as_admin(db)
q("insert into chip_memories (user_id, note) values (%s, 'likes dragons')", ann)
q("insert into user_birthdays (user_id, month, day) values (%s, 10, 18)", ann)
q("select anonymize_account(%s)", ann)
for table, col in [("chip_memories", "user_id"), ("user_birthdays", "user_id"),
                   ("app_events", "user_id")]:
    n = admin(f"select count(*) from {table} where {col} = %s", ann)[0][0]
    check(f"forgets {table}", n == 0, n)
check("the profile is anonymous", admin("select display_name, username from profiles where id = %s", ann)[0] == ("Deleted player", None))

print("ALL PASSED" if not fails else f"{len(fails)} FAILED: {fails}")
sys.exit(1 if fails else 0)
