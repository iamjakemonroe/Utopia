"""Coin gifts: friends only, accounts a week old, coins bought lately held
back, daily limits both ways (by account age, and never more than half
the day's coins), new friends capped, a retry never sends twice, the
friend hears about it, and the team can take gifts back."""
import pathlib
import sys
import uuid

import harness

db = harness.fresh()
fails = []
SQL = pathlib.Path(__file__).resolve().parents[1] / "sql"


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


def player(email, coins=5000, days=60):
    user = harness.new_user(db, email)
    harness.as_admin(db)
    run("update profiles set created_at = now() - make_interval(days => %s) where id = %s", days, user)
    have = one("select balance from profiles where id = %s", user)
    run("select _ledger_move(%s, 'admin_adjustment', %s, null, '{}'::jsonb)", user, coins - have)
    return user


def befriend(a, b, days=10):
    harness.as_admin(db)
    low, high = sorted([a, b])
    run("insert into friendships (user_low, user_high, created_at) "
        "values (%s, %s, now() - make_interval(days => %s))", low, high, days)


def send(sender, to, coins, key=None):
    harness.as_user(db, sender)
    return one("select send_coin_gift(%s, %s, %s)", to, coins, key or str(uuid.uuid4()))


def allowance(user, to=None):
    harness.as_user(db, user)
    return one("select coin_gift_allowance(%s)", to)


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
check("…and is told when it can", allowance(fresh)["ready_at"] is not None)
harness.as_admin(db)
house = one("select id::text from house_players limit 1")
befriend(me, house)
check("not to a house player", send(me, house, 50)["why"] == "house")
had = balance(guest)
check("a guest can receive, from a friend", send(friend, guest, 20)["ok"] and balance(guest) == had + 20, balance(guest))

# Amounts.
check("not under the least gift", send(me, friend, 5)["why"] == "amount")
check("not over the most for one gift (50,000)", send(me, friend, 50001)["why"] == "amount")
poor = player("poor@example.com", coins=40)
befriend(poor, friend)
check("not more than you have", send(poor, friend, 50)["why"] == "balance")

# Bigger gifts: one of 50,000 goes, from a well-off old account.
whale = player("whale@example.com", coins=1_000_000)
pal = player("pal@example.com", coins=0)
befriend(whale, pal)
check("a gift of 50,000 goes through", send(whale, pal, 50000)["ok"], balance(pal))
check("…and another (100,000 a day for an account 30 days old)", send(whale, pal, 50000)["ok"])
check("…then that's the day's", send(whale, pal, 10)["why"] == "daily_send")
allow = allowance(whale)
check("…the allowance says so", allow["left_today"] == 0 and allow["cap_left"] == 0 and allow["daily_cap"] == 100000, allow)

# Younger accounts (a week to 30 days): 10,000 a day.
young = player("young@example.com", coins=100_000, days=10)
befriend(young, pal)
allow = allowance(young)
check("an account 10 days old can send 10,000 a day", allow["young"] and allow["left_today"] == 10000, allow)
check("…so a gift of 10,001 is too many", send(young, pal, 10001)["why"] == "daily_send")
check("…10,000 goes", send(young, pal, 10000)["ok"])

# Never more than half the coins they had today.
half = player("half@example.com", coins=8000)
befriend(half, pal)
check("half their coins: 4,000 of 8,000 can go", allowance(half)["share_left"] == 4000)
check("…not 4,001", send(half, pal, 4001)["why"] == "share")
check("…3,000 goes", send(half, pal, 3000)["ok"])
allow = allowance(half)
check("…then 1,000 more is the day's half (of the 8,000 they had)",
      allow["share_left"] == 1000 and allow["left_today"] == 1000, allow)
check("…and they can never empty their wallet in a day", send(half, pal, 1001)["why"] == "share")

# New friends: 5,000 a day for their first three days.
newpal = player("newpal@example.com", coins=0)
befriend(whale, newpal, days=0)
rich = player("rich@example.com", coins=1_000_000)
befriend(rich, newpal, days=0)
allow = allowance(rich, newpal)
check("to a friend made today, up to 5,000", allow["friend_left"] == 5000 and allow["friend_ready_at"], allow)
check("…not 5,001", send(rich, newpal, 5001)["why"] == "new_friend")
check("…5,000 goes", send(rich, newpal, 5000)["ok"])
check("…then no more to them today", send(rich, newpal, 10)["why"] == "new_friend")
check("…an old friend has no such cap", allowance(rich, pal)["friend_left"] is None)
harness.as_admin(db)
low, high = sorted([rich, newpal])
run("update friendships set created_at = now() - interval '4 days' where user_low = %s and user_high = %s", low, high)
check("…and after three days, they're an old friend", send(rich, newpal, 20000)["ok"])

# Gifts a day: 20.
chatty = player("chatty@example.com", coins=100_000)
befriend(chatty, pal)
for _ in range(20):
    send(chatty, pal, 10)
check("no more than 20 gifts a day", send(chatty, pal, 10)["why"] == "daily_send")
check("…the allowance says so", allowance(chatty)["gifts_left"] == 0)

# Received a day: 200,000 (pal has had 100,000 + 10,000 + 3,000 + 200 so far).
givers = [player(f"giver{i}@example.com", coins=1_000_000) for i in range(2)]
for g in givers:
    befriend(g, pal)
got = [send(givers[0], pal, 50000)["ok"], send(givers[0], pal, 36800)["ok"]]
check("no more than 200,000 received a day", got == [True, True] and send(givers[1], pal, 10)["why"] == "daily_receive",
      (got, balance(pal)))

# Coins bought lately can't be passed on (a refund couldn't get them back).
buyer = player("buyer@example.com", coins=500)
befriend(buyer, friend)
harness.as_admin(db)
run("insert into coin_purchases (user_id, platform, transaction_id, product_id, coins) "
    "values (%s, 'ios', 'tx-1', 'utopia.coins.pouch', 1000)", buyer)
run("select _ledger_move(%s, 'purchase_credit', 1000, null, '{}'::jsonb)", buyer)
allow = allowance(buyer)
check("bought coins are held for two weeks", allow["giftable"] == 500 and allow["held"] == 1000, allow)
check("…so a gift of them says why", send(buyer, friend, 600)["why"] == "held")
check("…while older coins can go", send(buyer, friend, 400)["ok"])
harness.as_admin(db)
run("update coin_purchases set created_at = now() - interval '15 days' where transaction_id = 'tx-1'")
check("…and after two weeks they can too (up to half the day's)", send(buyer, friend, 300)["ok"])

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


# The team takes gifts back (tool/sql/reverse_gift.sql).
def reverse(gift=None, sender=None, hours=24):
    harness.as_admin(db)
    sql = (SQL / "reverse_gift.sql").read_text()
    if gift:
        sql = sql.replace("v_gift uuid := null;", f"v_gift uuid := '{gift}';")
    else:
        sql = sql.replace("'their_username'", f"'{sender}'").replace("v_hours int := 24;", f"v_hours int := {hours};")
    with db.cursor() as c:
        c.execute(sql)


victim = player("victim@example.com", coins=20000)
thief = player("thief@example.com", coins=0)
befriend(victim, thief)
g1 = send(victim, thief, 4000)
g2 = send(victim, thief, 3000)
before = (balance(victim), balance(thief))
reverse(gift=g1["gift"])
check("one gift taken back: its coins go home", (balance(victim), balance(thief)) == (before[0] + 4000, before[1] - 4000),
      (before, balance(victim), balance(thief)))
reverse(gift=g1["gift"])
check("…never twice", balance(victim) == before[0] + 4000)
harness.as_admin(db)
run("select _ledger_move(%s, 'admin_adjustment', -2000, null, '{}'::jsonb)", thief)  # spent some
reverse(sender="victim@example.com")
harness.as_admin(db)
check("everything they sent lately, as much as the friend still has",
      balance(thief) == 0 and one("select reversed_coins from coin_gifts where id = %s", g2["gift"]) == 1000,
      (balance(thief), one("select reversed_coins from coin_gifts where id = %s", g2["gift"])))

harness.as_admin(db)
total_gifted = one("select coalesce(sum(amount), 0) from ledger_entries where entry_type = 'coin_gift'")
check("every gift's coins left one balance and reached another (ledger sums to 0)", total_gifted == 0, total_gifted)

sys.exit(1 if fails else 0)
