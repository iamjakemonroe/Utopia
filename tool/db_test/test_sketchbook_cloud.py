"""Paintings kept with the account (20261021380000_sketchbook_cloud.sql):
a private bucket, a folder per player, and a guest's folder readable by
the account the guest moved to."""
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


ada, guest, bo = (harness.new_user(db, f"{n}@example.com") for n in ("ada", "guest", "bo"))

harness.as_admin(db)
check("the sketchbook bucket is private",
      one("select public from storage.buckets where id = 'sketchbook'") is False)
with db.cursor() as c:
    c.execute("insert into guest_transfers (guest_id, done_at, done_by) values (%s, now(), %s)",
              (guest, ada))

harness.as_user(db, ada)
check("ada can read the guest's folder (the guest became her)",
      one("select public._art_from_guest(%s)", guest) is True)
check("…and finds it among hers to bring along",
      [str(g) for g in [one("select * from my_guest_folders()")]] == [str(guest)])
check("…but not bo's", one("select public._art_from_guest(%s)", bo) is False)

harness.as_user(db, bo)
check("bo can't read the guest's folder",
      one("select public._art_from_guest(%s)", guest) is False)
check("…and has no guests to bring along", one("select count(*) from my_guest_folders()") == 0)

sys.exit(1 if fails else 0)
