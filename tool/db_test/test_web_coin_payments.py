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
# Buyers in Nigeria pay in naira: the dollar digits times 1,000
# (20261107120000_naira_prices.sql).
check("asked in naira, prices in naira", naira["utopia.coins.sack"] == ("NGN", 4990.0, 55000), naira.get("utopia.coins.sack"))
cedi = {r[0]: r[1] for r in q("select * from web_coin_shop('GHS')")}
check("dollars everywhere else", cedi["utopia.coins.sack"] == "USD")
dollars = {r[0]: float(r[2]) for r in q("select * from web_coin_shop('USD')")}
check("no pack under a dollar: Flutterwave refuses dollar charges under $1",
      min(dollars.values()) >= 1 and dollars["utopia.coins.starter"] == 1.0 and dollars["utopia.coins.pouch"] == 1.0, dollars)
check("and the smallest naira price is N1,000", naira["utopia.coins.pouch"][1] == 1000.0, naira.get("utopia.coins.pouch"))
# Buyers in the UK pay in pounds, at prices the founder set
# (20261109120000_pound_and_euro_prices.sql).
pounds = {r[0]: (r[1], float(r[2])) for r in q("select * from web_coin_shop('GBP')")}
check("asked in pounds, prices in pounds",
      pounds == {"utopia.coins.starter": ("GBP", 1.0), "utopia.coins.pouch": ("GBP", 1.0),
                 "utopia.coins.sack": ("GBP", 3.99), "utopia.coins.chest": ("GBP", 7.99),
                 "utopia.coins.vault": ("GBP", 15.99), "utopia.coins.mountain": ("GBP", 39.99),
                 "utopia.coins.hoard": ("GBP", 79.99)}, pounds)
check("every pack sold in dollars is sold in pounds", set(pounds) == set(dollars), (set(pounds), set(dollars)))
# And in the euro countries, in euros: about 93% of the dollar price,
# rounded to .49 or .99, at least EUR 1.
euros = {r[0]: (r[1], float(r[2])) for r in q("select * from web_coin_shop('EUR')")}
check("asked in euros, prices in euros",
      euros == {"utopia.coins.starter": ("EUR", 1.0), "utopia.coins.pouch": ("EUR", 1.0),
                "utopia.coins.sack": ("EUR", 4.49), "utopia.coins.chest": ("EUR", 9.49),
                "utopia.coins.vault": ("EUR", 18.49), "utopia.coins.mountain": ("EUR", 46.49),
                "utopia.coins.hoard": ("EUR", 92.99)}, euros)
check("a currency without prices still gets dollars", all(r[1] == "USD" for r in q("select * from web_coin_shop('CHF')")))

harness.as_user(db, guest)
check("guests can't buy", raises("select web_checkout_start('utopia.coins.sack', 'USD')") == "save your account first")
harness.as_user(db, buyer)
check("an unknown pack can't be bought", raises("select web_checkout_start('utopia.coins.nope', 'USD')") == "unknown coin pack")

start = q("select web_checkout_start('utopia.coins.sack', 'USD')")[0][0]
check("a checkout has its price and reference", start["currency"] == "USD" and float(start["amount"]) == 4.99
      and start["ref"].startswith("utopia-") and start["coins"] == 55000, start)
before = balance(buyer)
check("too little isn't paid for",
      (harness.as_admin(db), raises("select credit_web_payment(%s, 'flw-1', 4, 'USD')", start["ref"]))[1] is not None)
check("another currency isn't either",
      raises("select credit_web_payment(%s, 'flw-1', 7500, 'NGN')", start["ref"]) is not None)
paid = admin("select credit_web_payment(%s, 'flw-1', 4.99, 'USD')", start["ref"])[0][0]
check("paid in full: the coins", paid["credited"] is True and balance(buyer) == before + 55000, paid)
again = admin("select credit_web_payment(%s, 'flw-1', 4.99, 'USD')", start["ref"])[0][0]
check("…once (the webhook and the return both confirm)", again["credited"] is False and balance(buyer) == before + 55000)
check("the payment shows as paid",
      admin("select status, provider_id from web_payments where ref = %s", start["ref"])[0] == ("paid", "flw-1"))

harness.as_user(db, buyer)
starter = q("select web_checkout_start('utopia.coins.starter', 'USD')")[0][0]
admin("select credit_web_payment(%s, 'flw-2', 1.00, 'USD')", starter["ref"])
harness.as_user(db, buyer)
check("the starter pack once", raises("select web_checkout_start('utopia.coins.starter', 'USD')") == "starter pack already bought")

coins = balance(buyer)
admin("select take_back_coin_purchase('web', 'flw-1', now())")
check("a refund takes the coins back", balance(buyer) == coins - 55000)

harness.as_user(db, buyer)
check("players can't credit themselves",
      raises("select credit_web_payment('x', 'y', 1, 'USD')") is not None)

# Paying in pounds.
quid = q("select web_checkout_start('utopia.coins.chest', 'GBP')")[0][0]
check("a checkout in pounds", quid["currency"] == "GBP" and float(quid["amount"]) == 7.99 and quid["coins"] == 120000, quid)
check("…isn't paid in dollars",
      (harness.as_admin(db), raises("select credit_web_payment(%s, 'flw-gbp', 7.99, 'USD')", quid["ref"]))[1] is not None)
before = balance(buyer)
paid = admin("select credit_web_payment(%s, 'flw-gbp', 7.99, 'GBP')", quid["ref"])[0][0]
check("…and is paid in pounds", paid["credited"] is True and balance(buyer) == before + 120000, paid)

# Paying in euros.
harness.as_user(db, buyer)
euro = q("select web_checkout_start('utopia.coins.sack', 'EUR')")[0][0]
check("a checkout in euros", euro["currency"] == "EUR" and float(euro["amount"]) == 4.49, euro)
check("…isn't paid short",
      (harness.as_admin(db), raises("select credit_web_payment(%s, 'flw-eur', 4.00, 'EUR')", euro["ref"]))[1] is not None)
before = balance(buyer)
paid = admin("select credit_web_payment(%s, 'flw-eur', 4.49, 'EUR')", euro["ref"])[0][0]
check("…and is paid in euros", paid["credited"] is True and balance(buyer) == before + 55000, paid)

sys.exit(1 if fails else 0)
