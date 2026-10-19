"""A guest saving to an email that already has an account: everything the
guest had moves into the account, and the guest is retired."""
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
    rows = admin(sql, *args)
    return rows[0][0] if rows else None


def raises(sql, *args):
    try:
        q(sql, *args)
        return None
    except Exception as e:
        return str(e).splitlines()[0]


def admin(sql, *args):
    harness.as_admin(db)
    return q(sql, *args)


def befriend(a, b):
    lo, hi = sorted([a, b])
    admin("insert into friendships (user_low, user_high) values (%s, %s)", lo, hi)


account = harness.new_user(db, "me@example.com")
guest = harness.new_user(db)
friend, other, asker = (harness.new_user(db, f"{n}@example.com") for n in ("fay", "oli", "ash"))
admin("update profiles set username = 'me_for_real', display_name = 'Me' where id = %s", account)
admin("update profiles set username = 'guesty', display_name = 'Guesty' where id = %s", guest)

# The guest's days: the welcome pass, winnings, things bought and rented,
# Maestro, an event, rankings, games, friends, Chip.
harness.as_user(db, guest)
q("select start_welcome_week()")
welcome_until = one("select welcome_until from profiles where id = %s", guest)
admin("select _ledger_move(%s, 'match_payout', 750, null)", guest)
admin("insert into user_entitlements (user_id, item_id, source) values (%s, 'utopia_alien', 'coins'), (%s, 'chess_neon', 'coins')", guest, guest)
admin("insert into user_entitlements (user_id, item_id, source) values (%s, 'utopia_alien', 'coins')", account)
# (Renting a world the welcome week lent them makes it longer.)
admin("insert into world_rentals values (%s, 'utopia_tech', now() + interval '30 days') on conflict (user_id, world_id) do update set expires_at = excluded.expires_at", guest)
admin("insert into world_rentals values (%s, 'utopia_tech', now() + interval '2 days')", account)
# (Renting a frame the welcome pass lent them makes it longer.)
admin("insert into user_auras values (%s, 'zombie', now() + interval '20 days') on conflict (user_id, aura_id) do update set expires_at = excluded.expires_at", guest)
admin("select maestro_record(%s, 'ios', 'utopia.maestro.monthly', 'apple-1', now() + interval '25 days', true, 'production')", guest)
admin("insert into purchase_receipts (user_id, platform, product_id, transaction_id) values (%s, 'ios', 'utopia.coins.pouch', 't-1')", guest)
admin("insert into event_progress (user_id, event_id, games, days, last_day) values (%s, 'halloween_2026', 12, 3, current_date)", guest)
admin("insert into event_progress (user_id, event_id, games, days, last_day) values (%s, 'halloween_2026', 5, 4, current_date - 1)", account)
admin("insert into daily_rewards values (%s, current_date, 5)", guest)
admin("insert into daily_rewards values (%s, current_date - 1, 3)", account)
admin("insert into player_ratings (user_id, game, rating, games, best) values (%s, 'chess', 1340, 30, 1360)", guest)
admin("insert into player_ratings (user_id, game, rating, games, best) values (%s, 'chess', 1100, 4, 1120)", account)
admin("insert into player_ratings (user_id, game, rating, games, best) values (%s, 'checkers', 1210, 9, 1210)", account)
vs_friend = one("insert into matches (player_white, player_black, winner_id, status, stake) values (%s, %s, %s, 'completed', 0) returning id", guest, friend, guest)
vs_me = one("insert into matches (player_white, player_black, status, stake) values (%s, %s, 'completed', 0) returning id", guest, account)
admin("insert into match_moves (match_id, ply, player_id, from_square, to_square, san, fen_after) values (%s, 1, %s, 'e2', 'e4', 'e4', 'x')", vs_friend, guest)
befriend(guest, friend)
befriend(guest, account)
admin("insert into friend_requests (from_user, to_user, status) values (%s, %s, 'pending')", asker, guest)
admin("insert into chip_memories (user_id, note) values (%s, 'Loves the zombie world')", guest)
page = one("insert into coloring_pages (key, status, title, search, paths, owner, art) values ('mine', 'ready', 'My cat', 'cat', '[]', %s, %s) returning id", guest, f"{guest}/cat.png")
balance_before = one("select balance from profiles where id = %s", account)
guest_balance = one("select balance from profiles where id = %s", guest)

check("only a guest can start a transfer",
      (harness.as_user(db, account), raises("select guest_transfer_start()"))[1] == "not a guest")
harness.as_user(db, guest)
ticket = q("select guest_transfer_start()")[0][0]
check("a guest can't finish one", raises("select guest_transfer_finish(%s)", ticket) == "sign in first")

harness.as_user(db, account)
result = q("select guest_transfer_finish(%s)", ticket)[0][0]
check("it moves", result.get("moved") is True, result)

moved = guest_balance - 1000
check("coins move, all but the 1,000 every player starts with",
      one("select balance from profiles where id = %s", account) == balance_before + moved and result.get("coins") == moved,
      (balance_before, guest_balance, one("select balance from profiles where id = %s", account)))
check("the ledger shows the move on both sides",
      one("select count(*) from ledger_entries where entry_type = 'guest_transfer' and user_id in (%s, %s)", guest, account) == 2)
check("things bought move (and no duplicates)",
      sorted(r[0] for r in admin("select item_id from user_entitlements where user_id = %s", account)) == ["chess_neon", "utopia_alien"])
check("a rental moves at its longer length",
      one("select expires_at > now() + interval '29 days' from world_rentals where user_id = %s and world_id = 'utopia_tech'", account))
check("the welcome pass's lent worlds and sets don't move",
      one("select count(*) from world_rentals where user_id = %s and expires_at = %s", account, welcome_until) == 0)
check("a rented frame moves; the pass's frames (the halo) don't",
      one("select count(*) from user_auras where user_id = %s and aura_id = 'zombie'", account) == 1
      and one("select count(*) from user_auras where user_id = %s and aura_id = 'halo'", account) == 0)
check("Maestro moves, with its frame",
      one("select original_id from maestro_subscriptions where user_id = %s", account) == "apple-1"
      and one("select count(*) from user_auras where user_id = %s and aura_id = 'maestro'", account) == 1)
check("purchase receipts move", one("select count(*) from purchase_receipts where user_id = %s", account) == 1)
check("event progress keeps the further of each",
      admin("select games, days from event_progress where user_id = %s and event_id = 'halloween_2026'", account)[0] == (12, 4))
check("the daily streak takes today's claim (no second claim today)",
      admin("select last_day = current_date, streak from daily_rewards where user_id = %s", account)[0] == (True, 5))
check("rankings: the record with more games wins, per game",
      admin("select game, rating from player_ratings where user_id = %s order by game", account) == [("checkers", 1210), ("chess", 1340)])
check("a game against someone else moves, with its moves",
      admin("select player_white, winner_id from matches where id = %s", vs_friend)[0] == (account, account)
      and one("select player_id from match_moves where match_id = %s", vs_friend) == account)
check("a game against the account itself stays with the guest",
      admin("select player_white, player_black from matches where id = %s", vs_me)[0] == (guest, account))
lo, hi = sorted([account, friend])
check("friends move", one("select count(*) from friendships where user_low = %s and user_high = %s", lo, hi) == 1)
check("friend requests move", one("select count(*) from friend_requests where from_user = %s and to_user = %s", asker, account) == 1)
check("Chip's notes and pictures move",
      one("select count(*) from chip_memories where user_id = %s", account) == 1
      and one("select owner from coloring_pages where id = %s", page) == account)
check("the account keeps its own name",
      admin("select username, display_name from profiles where id = %s", account)[0] == ("me_for_real", "Me"))
check("the guest is retired",
      admin("select username, display_name from profiles where id = %s", guest)[0] == (None, "Deleted player")
      and one("select count(*) from friendships where %s in (user_low, user_high)", guest) == 0)
harness.as_user(db, account)
check("a ticket works once", q("select guest_transfer_finish(%s)", ticket)[0][0].get("moved") is False)
# A second ticket the guest got before it moved finds nothing to move.
admin("insert into guest_transfers (guest_id) values (%s)", guest)
spare = one("select ticket from guest_transfers where guest_id = %s and done_at is null", guest)
harness.as_user(db, friend)
again = q("select guest_transfer_finish(%s)", spare)[0][0]
check("a moved guest can't be moved again", again.get("moved") is False
      and one("select balance from profiles where id = %s", friend) == 1000)

# An account with no username yet takes the guest's.
fresh = harness.new_user(db, "new@example.com")
guest2 = harness.new_user(db)
admin("update profiles set username = 'ghosty' where id = %s", guest2)
harness.as_user(db, guest2)
ticket2 = q("select guest_transfer_start()")[0][0]
harness.as_user(db, fresh)
q("select guest_transfer_finish(%s)", ticket2)
check("an account without a username takes the guest's",
      one("select username from profiles where id = %s", fresh) == "ghosty")

# A guest that saved itself to its own email meanwhile isn't taken.
guest3 = harness.new_user(db)
harness.as_user(db, guest3)
ticket3 = q("select guest_transfer_start()")[0][0]
admin("update auth.users set is_anonymous = false, email = 'g3@example.com' where id = %s", guest3)
harness.as_user(db, account)
check("a guest that became an account of its own stays put",
      q("select guest_transfer_finish(%s)", ticket3)[0][0].get("moved") is False
      and one("select count(*) from auth.users where id = %s", guest3) == 1)

sys.exit(1 if fails else 0)
