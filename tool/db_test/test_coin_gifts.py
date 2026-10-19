"""Coin gifts: friends only, accounts a week old, coins bought lately held
back, daily limits both ways, a retry never sends twice, and the friend
hears about it."""
import sys
import uuid

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


def run(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)


def balance(user):
    harness.as_admin(db)
    return one("select balance from profiles where id = %s", user)


def player(email, coins=5000, days=30):
    user = harness.new_user(db, email)
    harness.as_admin(db)
    run("update profiles set created_at = now() - make_interval(days => %s) where id = %s", days, user)
    have = one("select balance from profiles where id = %s", user)
    run("select _ledger_move(%s, 'admin_adjustment', %s, null, '{}'::jsonb)", user, coins - have)
    return user


def befriend(a, b):
    harness.as_admin(db)
    low, high = sorted([a, b])
    run("insert into friendships (user_low, user_high) values (%s, %s)", low, high)


def send(sender, to, coins, key=None):
    harness.as_user(db, sender)
    return one("select send_coin_gift(%s, %s, %s)", to, coins, key or str(uuid.uuid4()))


me = player("me@example.com")
friend = player("friend@example.com", coins=100)
stranger = player("stranger@example.com")
befriend(me, friend)

# The happy path.
gift = send(me, friend, 250)
check("a gift to a friend goes through", gift["ok"] and gift["coins"] == 250 and gift["balance"] == 4750, gift)
check("…their coins arrive", balance(friend) == 350, balance(friend))
harness.as_admin(db)
check("…both sides are in the ledger", one(
    "select count(*) from ledger_entries where entry_type = 'coin_gift' and metadata->>'gift' = %s", gift["gift"]) == 2)
check("…and the friend hears about it", one(
    "select data->>'coins' from notifications where user_id = %s and kind = 'coin_gift' and actor_id = %s",
    friend, me) == "250")

# A retry never sends twice.
key = str(uuid.uuid4())
first = send(me, friend, 100, key)
again = send(me, friend, 100, key)
check("the same gift sent twice (a retry) only goes once",
      first["ok"] and again["ok"] and again.get("again") and balance(me) == 4650, (again, balance(me)))

# Who can't.
check("not to yourself", send(me, me, 50)["why"] == "self")
check("not to someone who isn't a friend", send(me, stranger, 50)["why"] == "not_friends")
check("…and nothing moved", balance(stranger) == 5000)
guest = harness.new_user(db)
befriend(guest, friend)
check("guests can't send", send(guest, friend, 50)["why"] == "guest")
fresh = player("fresh@example.com", days=2)
befriend(fresh, friend)
check("an account under a week old can't send", send(fresh, friend, 50)["why"] == "new")
harness.as_user(db, fresh)
check("…and is told when it can", one("select coin_gift_allowance()")["ready_at"] is not None)
harness.as_admin(db)
house = one("select id::text from house_players limit 1")
befriend(me, house)
check("not to a house player", send(me, house, 50)["why"] == "house")
had = balance(guest)
check("a guest can receive, from a friend", send(friend, guest, 20)["ok"] and balance(guest) == had + 20, balance(guest))

# Amounts.
check("not under the least gift", send(me, friend, 5)["why"] == "amount")
check("not over the most for one gift", send(me, friend, 1001)["why"] == "amount")
poor = player("poor@example.com", coins=40)
befriend(poor, friend)
check("not more than you have", send(poor, friend, 50)["why"] == "balance")

# Daily limits: 2,000 sent, 10 gifts, 5,000 received.
rich = player("rich@example.com", coins=20000)
pal = player("pal@example.com", coins=0)
befriend(rich, pal)
for _ in range(2):
    send(rich, pal, 1000)
check("no more than 2,000 sent a day", send(rich, pal, 10)["why"] == "daily_send", balance(pal))
chatty = player("chatty@example.com", coins=20000)
befriend(chatty, pal)
for _ in range(10):
    send(chatty, pal, 10)
check("no more than 10 gifts a day", send(chatty, pal, 10)["why"] == "daily_send")
harness.as_user(db, chatty)
check("…the allowance says so", one("select coin_gift_allowance()")["gifts_left"] == 0)
givers = [player(f"giver{i}@example.com") for i in range(3)]
for g in givers:
    befriend(g, pal)
got = [send(g, pal, 1000)["ok"] for g in givers]
check("no more than 5,000 received a day (2,100 already, then 1,000 each)",
      got == [True, True, False] and send(givers[2], pal, 900)["ok"] is True, (got, balance(pal)))
check("…the one that didn't fit says why", send(givers[2], pal, 1000)["why"] == "daily_receive")

# Coins bought lately can't be passed on (a refund couldn't get them back).
buyer = player("buyer@example.com", coins=500)
befriend(buyer, friend)
harness.as_admin(db)
run("insert into coin_purchases (user_id, platform, transaction_id, product_id, coins) "
    "values (%s, 'ios', 'tx-1', 'utopia.coins.pouch', 1000)", buyer)
run("select _ledger_move(%s, 'purchase_credit', 1000, null, '{}'::jsonb)", buyer)
harness.as_user(db, buyer)
allow = one("select coin_gift_allowance()")
check("bought coins are held for two weeks", allow["giftable"] == 500 and allow["held"] == 1000, allow)
check("…so a gift of them says why", send(buyer, friend, 600)["why"] == "held")
check("…while older coins can go", send(buyer, friend, 400)["ok"])
harness.as_admin(db)
run("update coin_purchases set created_at = now() - interval '15 days' where transaction_id = 'tx-1'")
check("…and after two weeks they can too", send(buyer, friend, 900)["ok"])

# The switch.
harness.as_admin(db)
run("update gift_settings set enabled = false")
check("gifts can be turned off at once", send(me, friend, 50)["why"] == "off")
harness.as_admin(db)
run("update gift_settings set enabled = true")

# Nobody can write gifts or settings, or see other people's gifts.
harness.as_user(db, stranger)
check("strangers see none of my gifts", one("select count(*) from coin_gifts where from_user = %s", me) == 0)
harness.as_user(db, friend)
check("the friend sees the gifts they got", one("select count(*) from coin_gifts where to_user = %s", friend) >= 2)
for sql in ("insert into coin_gifts (from_user, to_user, coins, client_key) values (%s, %s, 5, gen_random_uuid())",
            "update gift_settings set max_gift = 999999"):
    harness.as_user(db, me)
    try:
        run(sql, me, friend) if "insert" in sql else run(sql)
        wrote = True
    except Exception:
        wrote = False
    check("players can't write: " + sql.split()[0] + " " + sql.split()[2 if "insert" in sql else 1], not wrote)

harness.as_admin(db)
total_gifted = one("select coalesce(sum(amount), 0) from ledger_entries where entry_type = 'coin_gift'")
check("every gift's coins left one balance and reached another (ledger sums to 0)", total_gifted == 0, total_gifted)

sys.exit(1 if fails else 0)
