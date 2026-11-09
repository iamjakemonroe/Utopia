"""Every credited purchase tells the buyer, once: coins on the web from any
app, a web subscription's first payment and its renewals, and coins or
Chip Maestro from the App Store and Google Play. Nothing for a checkout
that isn't paid, or a payment that's short."""
import sys
from datetime import datetime, timedelta, timezone

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
    rows = q(sql, *args)
    return rows[0][0] if rows else None


def raises(sql, *args):
    try:
        q(sql, *args)
        return None
    except Exception as e:  # noqa: BLE001
        return str(e).splitlines()[0]


def admin(sql, *args):
    harness.as_admin(db)
    return q(sql, *args)


def bought(user):
    """[user]'s purchase notifications' data, oldest first."""
    return [r[0] for r in admin("select data from notifications where user_id = %s and kind = 'purchase' "
                                "order by id", user)]


ada = harness.new_user(db, "ada@example.com")
bo = harness.new_user(db, "bo@example.com")
cy = harness.new_user(db, "cy@example.com")
di = harness.new_user(db, "di@example.com")

# ── Coins on the web ──────────────────────────────────────────────────────────
harness.as_user(db, ada)
naira = one("select web_checkout_start('utopia.coins.starter', 'NGN')")
check("a checkout started isn't a purchase", bought(ada) == [])
check("a short payment is refused…",
      (harness.as_admin(db), raises("select credit_web_payment(%s, 'flw-1', 900, 'NGN')", naira["ref"]))[1] is not None)
check("…and tells nobody anything", bought(ada) == [])
admin("select credit_web_payment(%s, 'flw-1', 1000, 'NGN')", naira["ref"])
news = bought(ada)
check("paid: one notification", len(news) == 1, news)
check("…with what was bought and paid",
      news and news[0] == {"app": "utopia", "product_id": "utopia.coins.starter", "title": "20,000 coins",
                           "coins": 20000, "amount": 1000, "currency": "NGN", "renewal": False,
                           "ref": naira["ref"]}, news)
admin("select credit_web_payment(%s, 'flw-1', 1000, 'NGN')", naira["ref"])
check("the webhook and the return both confirm: still one", len(bought(ada)) == 1, bought(ada))
harness.as_user(db, ada)
check("the buyer can read it", one("select count(*) from notifications where kind = 'purchase'") == 1)
harness.as_user(db, bo)
check("nobody else can", one("select count(*) from notifications where kind = 'purchase'") == 0)

harness.as_user(db, bo)
chip = one("select web_checkout_start('utopia.coins.sack', 'GBP', 'chip')")
admin("select credit_web_payment(%s, 'flw-2', 3.99, 'GBP')", chip["ref"])
check("coins bought in Chip Rizz say so, in pounds",
      bought(bo) == [{"app": "chip", "product_id": "utopia.coins.sack", "title": "55,000 coins", "coins": 55000,
                      "amount": 3.99, "currency": "GBP", "renewal": False, "ref": chip["ref"]}], bought(bo))
harness.as_user(db, bo)
study = one("select web_checkout_start('utopia.coins.chest', 'EUR', 'study')")
odd = one("select web_checkout_start('utopia.coins.chest', 'EUR', 'wavee')")
check("the app is kept with the checkout",
      admin("select app from web_payments where ref = %s", study["ref"])[0][0] == "study"
      and admin("select app from web_payments where ref = %s", odd["ref"])[0][0] == "utopia")
admin("select credit_web_payment(%s, 'flw-3', 9.49, 'EUR')", study["ref"])
check("coins bought in Chip Study, in euros", bought(bo)[-1]["app"] == "study"
      and bought(bo)[-1]["currency"] == "EUR" and float(bought(bo)[-1]["amount"]) == 9.49, bought(bo))
harness.as_user(db, bo)
check("an old web-pay (two arguments) still starts a checkout",
      one("select web_checkout_start('utopia.coins.pouch', 'USD')")["currency"] == "USD")

# ── Web subscriptions ────────────────────────────────────────────────────────
harness.as_user(db, cy)
maestro = one("select web_subscribe_start('utopia.maestro.monthly', 'GBP')")
check("a subscription started isn't a purchase", bought(cy) == [])
admin("select web_plan_flw('utopia.maestro.monthly', 'GBP', 'flw-plan-gbp', %s)", maestro["ref"])
check("a short first payment tells nothing",
      (harness.as_admin(db), raises("select credit_web_subscription(%s, 'tx-1', 5, 'GBP')", maestro["ref"]))[1] is not None
      and bought(cy) == [])
paid = one("select credit_web_subscription(%s, 'tx-1', 6.49, 'GBP')", maestro["ref"])
check("the confirm answers what was paid", paid["currency"] == "GBP" and float(paid["amount"]) == 6.49, paid)
news = bought(cy)
check("Chip Maestro's first payment: one notification (not two: the web plan is Maestro too)",
      news == [{"app": "utopia", "product_id": "utopia.maestro.monthly", "title": "Chip Maestro",
                "amount": 6.49, "currency": "GBP", "renewal": False, "period": "monthly",
                "ref": maestro["ref"]}], news)
admin("select credit_web_subscription(%s, 'tx-1', 6.49, 'GBP')", maestro["ref"])
check("…once", len(bought(cy)) == 1)
admin("select renew_web_subscription('flw-plan-gbp', 'CY@example.com', 'tx-2', 6.49, 'GBP')")
news = bought(cy)
check("a renewal says so", len(news) == 2 and news[1]["renewal"] is True and news[1]["title"] == "Chip Maestro", news)
admin("select renew_web_subscription('flw-plan-gbp', 'cy@example.com', 'tx-2', 6.49, 'GBP')")
check("…once", len(bought(cy)) == 2)

harness.as_user(db, di)
rizz = one("select web_subscribe_start('rizz.pro.weekly', 'USD')")
admin("select credit_web_subscription(%s, 'tx-3', 3.99, 'USD')", rizz["ref"])
check("Chip Rizz Pro is Chip Rizz's", bought(di)[-1]["app"] == "chip"
      and bought(di)[-1]["period"] == "weekly" and bought(di)[-1]["renewal"] is False, bought(di))
harness.as_user(db, di)
pro = one("select web_subscribe_start('study.pro.monthly', 'EUR')")
admin("select credit_web_subscription(%s, 'tx-4', 7.49, 'EUR')", pro["ref"])
check("Chip Study Pro is Chip Study's", bought(di)[-1]["app"] == "study"
      and bought(di)[-1]["title"] == "Chip Study Pro" and bought(di)[-1]["currency"] == "EUR", bought(di))

# ── The App Store and Google Play ─────────────────────────────────────────────
before = len(bought(ada))
admin("select credit_coin_purchase(%s, 'ios', 'apple-1', 'apple-orig-1', 'utopia.coins.chest', 1, 'sandbox', now())", ada)
news = bought(ada)
check("coins from the App Store: one notification, without a price (the store keeps it)",
      len(news) == before + 1 and news[-1] == {"app": "utopia", "product_id": "utopia.coins.chest",
                                               "title": "120,000 coins", "coins": 120000, "renewal": False,
                                               "platform": "ios"}, news)
admin("select credit_coin_purchase(%s, 'ios', 'apple-1', 'apple-orig-1', 'utopia.coins.chest', 1, 'sandbox', now())", ada)
check("…once (the store sends it again until the app finishes it)", len(bought(ada)) == before + 1)
check("someone else's purchase is refused…", raises(
    "select credit_coin_purchase(%s, 'ios', 'apple-1', 'apple-orig-1', 'utopia.coins.chest', 1, 'sandbox', now())",
    bo) is not None)
check("…and tells them nothing", all(n.get("platform") is None for n in bought(bo)))
admin("select credit_coin_purchase(%s, 'android', 'gp-token-1', 'GPA.1', 'utopia.coins.vault', 1, 'production', now())", ada)
check("coins from Google Play", bought(ada)[-1]["platform"] == "android" and bought(ada)[-1]["coins"] == 260000)

month = datetime.now(timezone.utc) + timedelta(days=30)
admin("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'apple-sub-1', %s, true, 'sandbox')", ada, month)
news = bought(ada)
check("Chip Maestro from the App Store: on",
      news[-1] == {"app": "utopia", "product_id": "utopia.maestro.monthly", "title": "Chip Maestro",
                   "renewal": False, "period": "monthly", "platform": "ios"}, news[-1])
count = len(news)
admin("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'apple-sub-1', %s, true, 'sandbox')", ada, month)
check("checked again (restored, or a store notice): nothing new", len(bought(ada)) == count)
admin("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'apple-sub-1', %s, false, 'sandbox')", ada, month)
check("renewal switched off: nothing", len(bought(ada)) == count)
past = datetime.now(timezone.utc) - timedelta(days=1)
admin("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'apple-sub-1', %s, false, 'sandbox')", ada, past)
check("expired: nothing", len(bought(ada)) == count)
admin("select maestro_record(%s, 'android', 'utopia.maestro.monthly', 'gp-sub-1', %s, true, 'production')", ada, month)
check("joined again after it ran out: on again", len(bought(ada)) == count + 1
      and bought(ada)[-1]["platform"] == "android")
admin("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'apple-old', %s, false, 'sandbox')", bo, past)
check("an old, expired plan coming back tells nothing", all(n["product_id"] != "utopia.maestro.monthly" for n in bought(bo)))

# ── Only the server writes them ───────────────────────────────────────────────
harness.as_user(db, ada)
check("players can't write purchase notifications",
      raises("insert into notifications (user_id, kind, data) values (%s, 'purchase', '{}')", ada) is not None)
check("…or call the helper", raises("select _purchase_notify(%s, '{}')", ada) is not None)
check("purchase notifications go out live",
      admin("select count(*) from pg_publication_tables where pubname = 'supabase_realtime' "
            "and tablename = 'notifications'")[0][0] == 1)

print()
print("All purchase notification checks passed." if not fails else f"{len(fails)} failed: {fails}")
sys.exit(1 if fails else 0)
