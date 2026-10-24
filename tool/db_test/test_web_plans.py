"""Subscriptions on the web (Flutterwave payment plans): starting one,
the first payment, renewals, cancelling, Chip Maestro bought on the web,
Chip Rizz Pro and its fair use, and Chip Maestro's new daily limits."""
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


def as_(user):
    harness.as_user(db, user)


guest = harness.new_user(db)
ada = harness.new_user(db, "ada@example.com")
bo = harness.new_user(db, "bo@example.com")
cy = harness.new_user(db, "cy@example.com")

# The shop.
as_(ada)
rows = q("select plan_id, currency, amount, until from web_plan_shop('USD')")
check("three plans, in dollars", [r[0] for r in rows] == ["utopia.maestro.monthly", "rizz.pro.weekly", "rizz.pro.monthly"]
      and [float(r[2]) for r in rows] == [7.99, 3.99, 9.99] and all(r[1] == "USD" for r in rows), rows)
check("asking in naira still gets dollars", all(r[1] == "USD" for r in q("select plan_id, currency from web_plan_shop('NGN')")))
check("coins are in dollars too", admin("select count(*) from web_coin_prices where currency <> 'USD'")[0][0] == 0)

check("nobody's a member yet", all(r[3] is None for r in rows))

# Starting one.
as_(guest)
check("a guest can't subscribe", raises("select web_subscribe_start('rizz.pro.monthly', 'USD')") == "save your account first")
as_(ada)
start = one("select web_subscribe_start('rizz.pro.monthly', 'USD')")
check("an account can", start["ref"].startswith("kaivon-sub-") and float(start["amount"]) == 9.99
      and start["currency"] == "USD" and start["email"] == "ada@example.com" and start["flw_plan_id"] is None, start)
check("unknown plans are refused", raises("select web_subscribe_start('nope', 'USD')") == "unknown plan")
check("players can't read subscriptions directly", raises("select * from web_subscriptions") is not None)

# The function makes Flutterwave's plan and pays.
admin("select web_plan_flw('rizz.pro.monthly', 'USD', 'flw-111', %s)", start["ref"])
check("the plan is kept for the price", admin("select flw_plan_id from web_plan_prices where plan_id = 'rizz.pro.monthly' and currency = 'USD'")[0][0] == "flw-111")
check("…and on the checkout", admin("select flw_plan_id from web_subscriptions where ref = %s", start["ref"])[0][0] == "flw-111")
as_(bo)
check("the next checkout gets it straight away", one("select web_subscribe_start('rizz.pro.monthly', 'USD')")["flw_plan_id"] == "flw-111")

check("paying less is refused", admin("select 1 from (select 1) x") is not None
      and (harness.as_admin(db), raises("select credit_web_subscription(%s, 'tx-1', 1, 'USD', 'sandbox')", start["ref"]))[1] is not None)
paid = admin("select credit_web_subscription(%s, 'tx-1', 9.99, 'USD', 'sandbox')", start["ref"])[0][0]
check("the first payment starts it", paid["product"] == "rizz_pro" and paid["user_id"] == ada)
sub = admin("select status, period_end > now() + interval '30 days', period_end < now() + interval '32 days', environment from web_subscriptions where ref = %s", start["ref"])[0]
check("…for a month and a day's grace, in test mode", sub == ("active", True, True, "sandbox"), sub)
again = admin("select credit_web_subscription(%s, 'tx-1', 9.99, 'USD', 'sandbox')", start["ref"])[0][0]
check("the same payment twice counts once", again.get("again") is True)

# Chip Rizz Pro.
as_(ada)
m = one("select rizz_me(null)")
check("a Pro member", m["tier"] == "pro" and m["pro_until"] is not None and m["rizz_left"] == 40 and m["learn_left"] == 3, m)
check("…can't subscribe again", raises("select web_subscribe_start('rizz.pro.weekly', 'USD')") == "already a member")
check("…sees it in the shop", one("select until from web_plan_shop('USD') where plan_id = 'rizz.pro.monthly'") is not None)
got = [one("select chip_allow('rizz', null, false)") for _ in range(41)]
check("40 sets a day", all(r["ok"] and r["tier"] == "pro" for r in got[:40]) and got[40]["why"] == "limit", got[40])
# Fair use across the period: 600 a month. (Ten days into the month.)
admin("update web_subscriptions set period_end = now() + interval '21 days' where ref = %s", start["ref"])
admin("delete from chip_usage where user_id = %s", ada)
admin("insert into chip_usage (user_id, day, rizzes) values (%s, (now() at time zone 'utc')::date - 40, 500)", ada)
admin("insert into chip_usage (user_id, day, rizzes) values (%s, (now() at time zone 'utc')::date - 3, 590)", ada)
as_(ada)
check("only this period counts", one("select rizz_me(null)")["rizz_left"] == 10)
got = [one("select chip_allow('rizz', null, false)") for _ in range(11)]
check("past the month's 600, a set needs coins", all(r["ok"] for r in got[:10]) and got[10]["why"] == "limit", got[10])
check("…which still works", one("select chip_allow('rizz', null, true)")["paid"] is True)
admin("delete from chip_usage where user_id = %s", ada)
admin("update web_subscriptions set period_end = now() + interval '31 days' where ref = %s", start["ref"])

# Renewals and cancelling.
before = admin("select period_end from web_subscriptions where ref = %s", start["ref"])[0][0]
renew = admin("select renew_web_subscription('flw-111', 'ADA@example.com', 'tx-2', 9.99, 'USD', 'sandbox')")[0][0]
after = admin("select period_end from web_subscriptions where ref = %s", start["ref"])[0][0]
check("a renewal adds a month to the end", (after - before).days == 31 and renew["product"] == "rizz_pro", (before, after))
check("an unknown renewal is refused", (harness.as_admin(db), raises("select renew_web_subscription('flw-999', 'x@example.com', 'tx-3', 1, 'USD')"))[1] == "unknown subscription")
ended = admin("select end_web_subscription('flw-111', 'ada@example.com')")[0][0]
check("cancelling keeps what's paid for", ended["ended"] is True
      and admin("select status from web_subscriptions where ref = %s", start["ref"])[0][0] == "cancelled")
as_(ada)
check("…still Pro until then", one("select rizz_me(null)")["tier"] == "pro")
mine = one("select web_subscription_mine('rizz_pro')")
check("the member's own plan, to cancel", mine["flw_plan_id"] == "flw-111" and mine["status"] == "cancelled")
admin("update web_subscriptions set period_end = now() - interval '1 minute' where ref = %s", start["ref"])
as_(ada)
check("then back to free", one("select rizz_me(null)")["tier"] == "free")

# Chip Maestro on the web.
as_(cy)
ms = one("select web_subscribe_start('utopia.maestro.monthly', 'USD')")
check("Chip Maestro in dollars", float(ms["amount"]) == 7.99 and ms["product"] == "maestro")
admin("select web_plan_flw('utopia.maestro.monthly', 'USD', 'flw-222', %s)", ms["ref"])
admin("select credit_web_subscription(%s, 'tx-9', 7.99, 'USD', 'sandbox')", ms["ref"])
row = admin("select platform, original_id, auto_renew, environment from maestro_subscriptions where user_id = %s", cy)[0]
check("a web member is a Maestro member", row == ("web", "web:" + ms["ref"], True, "sandbox"), row)
as_(cy)
check("…with Maestro's Chip", one("select chip_allow('chat', null, false)")["tier"] == "maestro")
check("…and the frame", admin("select count(*) from user_auras where user_id = %s and aura_id = 'maestro'", cy)[0][0] == 1)
as_(cy)
check("…who can't buy it twice", raises("select web_subscribe_start('utopia.maestro.monthly', 'USD')") == "already a member")
admin("select end_web_subscription('flw-222', 'cy@example.com')")
check("cancelling Maestro stops its renewal", admin("select auto_renew from maestro_subscriptions where user_id = %s", cy)[0][0] is False)

# Chip Maestro's fair use a day.
as_(cy)
got = [one("select chip_allow('chat', null, false)") for _ in range(60)]  # one was used above
check("60 chats a day for members", all(r["ok"] for r in got[:59]) and not got[59]["ok"], got[59])
check("Maestro limits: 6 drawings, 40 colorings", one("select _chip_limit('draw', 'maestro')") == 6
      and one("select _chip_limit('paint', 'maestro')") == 40)

print()
print("All subscription checks passed." if not fails else f"{len(fails)} failed: {fails}")
sys.exit(1 if fails else 0)
