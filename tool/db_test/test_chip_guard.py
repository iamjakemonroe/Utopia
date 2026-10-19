"""Chip's guard: allowances by who's asking, guests sharing one per device,
the day's budget, and more chats for coins."""
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


def admin(sql, *args):
    harness.as_admin(db)
    return q(sql, *args)


def allow(user, kind="chat", device=None, pay=False):
    harness.as_user(db, user)
    return q("select chip_allow(%s, %s, %s)", kind, device, pay)[0][0]


def take(user, n, kind="chat", device=None):
    return [allow(user, kind, device) for _ in range(n)]


def balance(user):
    return admin("select balance from profiles where id = %s", user)[0][0]


PHONE = "phone-key-0123456789abcdef"
guest = harness.new_user(db)
guest2 = harness.new_user(db)
other_guest = harness.new_user(db)
player = harness.new_user(db, "pat@example.com")
member = harness.new_user(db, "mo@example.com")
admin("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'm-1', now() + interval '20 days', true, 'production')", member)

got = take(guest, 11, device=PHONE)
check("a guest gets 10 chats a day", all(r["ok"] for r in got[:10]) and got[10]["why"] == "guest", got[10])
check("…as a guest", got[0]["tier"] == "guest")
check("a new guest on the same device gets none", allow(guest2, device=PHONE)["why"] == "guest")
check("a guest on another device gets their own", allow(other_guest, device="tablet-key-0123456789abcd")["ok"])
check("a guest's drawing: 1 a day", allow(other_guest, "draw")["ok"] and allow(other_guest, "draw")["why"] == "guest")

got = take(player, 21)
check("a free account gets 20 chats", all(r["ok"] for r in got[:20]) and got[20]["why"] == "limit"
      and got[20]["price"] == 20 and got[0]["tier"] == "free", got[20])
before = balance(player)
paid = allow(player, pay=True)
check("then a chat for 20 coins", paid["ok"] and paid["paid"] and balance(player) == before - 20, paid)
admin("select _ledger_move(%s, 'admin_adjustment', %s, null)", player, -(balance(player) - 10))
check("not without the coins", allow(player, pay=True)["why"] == "coins")
admin("select chip_refund_chat(%s)", player)
check("a paid chat that failed is refunded", balance(player) == 30)
harness.as_user(db, guest)
q("select 1")
check("a guest can't pay coins for more", allow(guest, pay=True, device=PHONE)["why"] == "guest")

check("a member chats as a member", allow(member)["tier"] == "maestro")

# The day's budget.
admin("select chip_log_cost('chat', 'claude-haiku-5-5', 'guest', 1, 1, 0, 0, 0, 7)")
fresh_guest = harness.new_user(db)
check("past the guests' share, guests are asked to save their account",
      allow(fresh_guest, device="new-key-0123456789abcdefg")["why"] == "guest")
fresh_player = harness.new_user(db, "fay@example.com")
check("…while accounts carry on", allow(fresh_player)["ok"])
admin("select chip_log_cost('draw', 'claude-sonnet-5-5', 'free', 1, 1, 0, 0, 0, 14)")
busy = allow(fresh_player)
check("past the whole budget, accounts can pay coins", busy["why"] == "busy" and busy["price"] == 20, busy)
check("…and paying works", allow(fresh_player, pay=True)["ok"])
check("members never notice", allow(member)["ok"])
admin("update chip_settings set daily_free_usd = 100")
check("the budget can be raised", allow(fresh_player)["ok"])

check("chip_take still answers yes or no", (harness.as_user(db, member), q("select chip_take('chat')"))[1][0][0] is True)
spend = admin("select usd, guest_usd, free_usd, calls from chip_spend")[0]
check("chip_spend adds up the day", float(spend[0]) == 21 and float(spend[1]) == 7 and float(spend[2]) == 14 and spend[3] == 2, spend)
harness.as_user(db, player)
try:
    q("select chip_log_cost('chat', 'x', 'free', 1, 1, 0, 0, 0, 1000)")
    check("players can't write the cost log", False)
except Exception as e:
    check("players can't write the cost log", "permission denied" in str(e), e)

sys.exit(1 if fails else 0)
