"""Chip Rizz: dates of birth, people, the replies and chat readings Chip
allows a day, paying coins for more, refunds, a guest's people following
them into an account, and deleting an account."""
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


def one(sql, *args):
    return q(sql, *args)[0][0]


def raises(sql, *args):
    try:
        q(sql, *args)
        return None
    except Exception as e:  # noqa: BLE001
        return str(e).splitlines()[0]


def admin(sql, *args):
    harness.as_admin(db)
    return q(sql, *args)


def allow(user, kind="rizz", device=None, pay=False):
    harness.as_user(db, user)
    return one("select chip_allow(%s, %s, %s)", kind, device, pay)


def me(user, device=None):
    harness.as_user(db, user)
    return one("select rizz_me(%s)", device)


def balance(user):
    return admin("select balance from profiles where id = %s", user)[0][0]


PHONE = "phone-key-0123456789abcdef"
guest = harness.new_user(db)
guest2 = harness.new_user(db)
pat = harness.new_user(db, "pat@example.com")
sam = harness.new_user(db, "sam@example.com")
member = harness.new_user(db, "mo@example.com")
admin("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'm-1', now() + interval '20 days', true, 'production')", member)

# Dates of birth.
m = me(pat)
check("no date of birth at first", m["born"] is None and m["age"] is None and m["born_fixable"], m)
harness.as_user(db, pat)
check("an impossible date is refused", raises("select rizz_set_born(current_date + 1)") is not None)
check("giving it returns the age", one("select rizz_set_born((current_date - interval '20 years' - interval '3 days')::date)") == 20)
check("it can be corrected the same day", one("select rizz_set_born((current_date - interval '17 years')::date)") == 17)
admin("update rizz_ages set set_at = now() - interval '2 days' where user_id = %s", pat)
harness.as_user(db, pat)
check("but not after a day", raises("select rizz_set_born((current_date - interval '30 years')::date)") is not None)
check("…so it stays", me(pat)["age"] == 17 and not me(pat)["born_fixable"])
harness.as_user(db, sam)
check("nobody else can read it", q("select count(*) from rizz_ages")[0][0] == 0)
check("…or write it directly", raises("insert into rizz_ages (user_id, born) values (%s, '2000-01-01')", sam) is not None)

# People.
harness.as_user(db, pat)
tolu = one("insert into rizz_people (name, emoji, about) values ('  Tolu ', '💛', 'Met at a wedding') returning id")
check("a person is theirs, name trimmed",
      q("select user_id::text, name from rizz_people where id = %s", tolu)[0] == (pat, "Tolu"))
check("they can't set someone else as the owner",
      raises("insert into rizz_people (user_id, name) values (%s, 'X')", sam) is not None)
check("they can't fake when Chip learned", raises("update rizz_people set learned_at = now() where id = %s", tolu) is not None)
q("update rizz_people set memory = 'Loves jollof. Hates double texts.' where id = %s", tolu)
check("they can edit what Chip remembers", one("select memory from rizz_people where id = %s", tolu).startswith("Loves"))
harness.as_user(db, sam)
check("nobody else sees them", q("select count(*) from rizz_people")[0][0] == 0)
check("…or changes them", q("update rizz_people set name = 'Hacked' where id = %s returning id", tolu) == [])
harness.as_user(db, pat)
check("an empty name is refused", raises("insert into rizz_people (name) values ('   ')") is not None)
harness.as_user(db, sam)
for i in range(100):
    q("insert into rizz_people (name) values (%s)", f"P{i}")
check("at most 100 people each", raises("insert into rizz_people (name) values ('One more')") == "too many people")

# Allowances.
got = [allow(guest, device=PHONE) for _ in range(6)]
check("a guest gets 5 sets of replies a day", all(r["ok"] for r in got[:5]) and got[5]["why"] == "guest", got[5])
check("…shared by guests on the same device", allow(guest2, device=PHONE)["why"] == "guest")
check("rizz_me counts the device's", me(guest2, PHONE)["rizz_left"] == 0 and me(guest2, PHONE)["guest"])
check("a guest reads 1 chat a day", allow(guest2, "learn", "tablet-key-0123456789abcd")["ok"]
      and allow(guest2, "learn", "tablet-key-0123456789abcd")["why"] == "guest")

check("a free account starts with 15", me(pat)["rizz_left"] == 15 and me(pat)["tier"] == "free")
got = [allow(pat) for _ in range(16)]
check("…and gets 15", all(r["ok"] for r in got[:15]) and got[15]["why"] == "limit" and got[15]["price"] == 300, got[15])
check("…which rizz_me shows", me(pat)["rizz_left"] == 0)
check("Utopia's chats are counted apart", allow(pat, "chat")["ok"])
before = balance(pat)
paid = allow(pat, pay=True)
check("then replies for 300 coins", paid["ok"] and paid["paid"] and balance(pat) == before - 300, paid)
check("…while Utopia's chats still cost 20", me(pat)["price"] == 300
      and admin("select chat_coins from chip_settings")[0][0] == 20)
admin("select chip_refund(%s, 'rizz')", pat)
check("a refund gives back 300", balance(pat) == before)
check("a paid set that failed is refunded", balance(pat) == before
      and admin("select rizzes from chip_usage where user_id = %s and day = (now() at time zone 'utc')::date", pat)[0][0] == 15)
admin("select _ledger_move(%s, 'admin_adjustment', %s, null)", sam, -(balance(sam) - 299))
for _ in range(15):
    allow(sam)
check("not without 300 coins", allow(sam, pay=True)["why"] == "coins" and allow(sam, pay=True)["price"] == 300)
check("chat readings can't be bought", allow(pat, "learn")["ok"] and allow(pat, "learn")["ok"] and allow(pat, "learn")["ok"]
      and allow(pat, "learn", pay=True)["why"] == "limit")
harness.as_user(db, pat)
check("only the server refunds", raises("select chip_refund(%s, 'rizz')", pat) is not None)
check("a member gets plenty", me(member)["rizz_left"] == 300 and me(member)["tier"] == "maestro")
check("Utopia's kinds are unchanged", allow(sam, "chat")["ok"] and allow(sam, "draw")["ok"])
check("an unknown kind is refused", raises("select chip_allow('nope')") == "unknown kind")

# A guest who signs in to an existing account brings their people.
g = harness.new_user(db)
harness.as_user(db, g)
one("select rizz_set_born('2001-05-04')")
q("insert into rizz_people (name) values ('Ada')")
ticket = one("select guest_transfer_start()")
harness.as_user(db, member)
check("the transfer works", one("select guest_transfer_finish(%s)", ticket).get("moved") is True)
harness.as_user(db, member)
check("their people move to the account", [r[0] for r in q("select name from rizz_people")] == ["Ada"])
check("…and their date of birth", str(me(member)["born"]) == "2001-05-04")
g2 = harness.new_user(db)
harness.as_user(db, g2)
one("select rizz_set_born('2008-01-01')")
ticket = one("select guest_transfer_start()")
harness.as_user(db, member)
one("select guest_transfer_finish(%s)", ticket)
check("an account's own date of birth wins", str(me(member)["born"]) == "2001-05-04")

# Deleting an account.
admin("select anonymize_account(%s)", pat)
check("deleting an account deletes their people and date of birth",
      admin("select count(*) from rizz_people where user_id = %s", pat)[0][0] == 0
      and admin("select count(*) from rizz_ages where user_id = %s", pat)[0][0] == 0)

print()
print("All Chip Rizz checks passed." if not fails else f"{len(fails)} failed: {fails}")
sys.exit(1 if fails else 0)
