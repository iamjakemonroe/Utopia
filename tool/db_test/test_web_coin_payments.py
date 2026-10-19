"""Coins bought on the web: a price per currency, a checkout per payment,
and the coins exactly once, for the price asked."""
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


def balance(user):
    return admin("select balance from profiles where id = %s", user)[0][0]


buyer = harness.new_user(db, "buyer@example.com")
guest = harness.new_user(db)

harness.as_user(db, buyer)
naira = {r[0]: (r[1], float(r[2]), r[3]) for r in q("select * from web_coin_shop('ngn')")}
check("prices in naira for Nigeria", naira["utopia.coins.sack"] == ("NGN", 7500.0, 55000), naira.get("utopia.coins.sack"))
cedi = {r[0]: r[1] for r in q("select * from web_coin_shop('GHS')")}
check("dollars where there's no local price", cedi["utopia.coins.sack"] == "USD")

harness.as_user(db, guest)
check("guests can't buy", raises("select web_checkout_start('utopia.coins.sack', 'NGN')") == "save your account first")
harness.as_user(db, buyer)
check("an unknown pack can't be bought", raises("select web_checkout_start('utopia.coins.nope', 'USD')") == "unknown coin pack")

start = q("select web_checkout_start('utopia.coins.sack', 'NGN')")[0][0]
check("a checkout has its price and reference", start["currency"] == "NGN" and float(start["amount"]) == 7500
      and start["ref"].startswith("utopia-") and start["coins"] == 55000, start)
before = balance(buyer)
check("too little isn't paid for",
      (harness.as_admin(db), raises("select credit_web_payment(%s, 'flw-1', 7000, 'NGN')", start["ref"]))[1] is not None)
check("another currency isn't either",
      raises("select credit_web_payment(%s, 'flw-1', 7500, 'USD')", start["ref"]) is not None)
paid = admin("select credit_web_payment(%s, 'flw-1', 7500, 'NGN')", start["ref"])[0][0]
check("paid in full: the coins", paid["credited"] is True and balance(buyer) == before + 55000, paid)
again = admin("select credit_web_payment(%s, 'flw-1', 7500, 'NGN')", start["ref"])[0][0]
check("…once (the webhook and the return both confirm)", again["credited"] is False and balance(buyer) == before + 55000)
check("the payment shows as paid",
      admin("select status, provider_id from web_payments where ref = %s", start["ref"])[0] == ("paid", "flw-1"))

harness.as_user(db, buyer)
starter = q("select web_checkout_start('utopia.coins.starter', 'USD')")[0][0]
admin("select credit_web_payment(%s, 'flw-2', 0.99, 'USD')", starter["ref"])
harness.as_user(db, buyer)
check("the starter pack once", raises("select web_checkout_start('utopia.coins.starter', 'USD')") == "starter pack already bought")

coins = balance(buyer)
admin("select take_back_coin_purchase('web', 'flw-1', now())")
check("a refund takes the coins back", balance(buyer) == coins - 55000)

harness.as_user(db, buyer)
check("players can't credit themselves",
      raises("select credit_web_payment('x', 'y', 1, 'USD')") is not None)

sys.exit(1 if fails else 0)
