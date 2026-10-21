"""Crazy Eights (20261021350000_crazy_eights.sql): the server deals and
keeps the cards, each player sees only their own hand, every move is
checked, time-outs are played for whoever's away (they stay in), leaving
hands the cards back, and the
winner takes the pot. Rooms, quick match, chat and events too."""
import json
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


def rows(sql, *args):
    with db.cursor() as c:
        c.execute(sql, args)
        return c.fetchall()


def attempt(user, sql, *args):
    harness.as_user(db, user)
    try:
        with db.cursor() as c:
            c.execute(sql, args)
            try:
                return c.fetchall()
            except Exception:
                return "ok"
    except Exception as e:
        return str(e).split("\n")[0]


def match(m):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("select status::text, winner_id::text, state, missed_turns, players::text[]"
                  " from eights_matches where id = %s", (m,))
        return c.fetchone()


def hand(m, user):
    harness.as_admin(db)
    return one("select cards from eights_hands where match_id = %s and user_id = %s", m, user)


def deck(m):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("select draw_pile, discard from eights_decks where match_id = %s", (m,))
        return c.fetchone()


def balance(user):
    harness.as_admin(db)
    return one("select balance from profiles where id = %s", user)


def rig(m, hands=None, top=None, suit=None, turn=None, draw=None, discard=None):
    """Sets the cards up as a test needs them."""
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("select players::text[], state from eights_matches where id = %s", (m,))
        players, state = c.fetchone()
        for user, cards in (hands or {}).items():
            c.execute("update eights_hands set cards = %s where match_id = %s and user_id = %s",
                      (cards, m, user))
            state["counts"][players.index(user)] = len(cards)
        if top:
            state["top"] = top
            state["suit"] = suit or top[-1]
        if turn is not None:
            state["turn"] = turn
        state["drawn"] = False
        if draw is not None:
            c.execute("update eights_decks set draw_pile = %s where match_id = %s", (draw, m))
            state["draw"] = len(draw)
        if discard is not None:
            c.execute("update eights_decks set discard = %s where match_id = %s", (discard, m))
        c.execute("update eights_matches set state = %s where id = %s", (json.dumps(state), m))


def seat_of(m, user):
    return match(m)[4].index(user)


def turn_user(m):
    st, players = match(m)[2], match(m)[4]
    return players[st["turn"]]


def give(user, coins):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("update profiles set balance = balance + %s where id = %s", (coins, user))


ada, bo, cy, di = (harness.new_user(db, f"{n}@example.com") for n in ("ada", "bo", "cy", "di"))
for u in (ada, bo, cy, di):
    give(u, 1000)

# ── a friend room ─────────────────────────────────────────────────────────
harness.as_user(db, ada)
room = one("select create_eights_room(2, 50)")
code, room_id = room["code"], room["id"]
check("bo can't start ada's room",
      attempt(bo, "select start_eights_room(%s)", room_id) == "only the host can start the game")
check("ada can't start alone",
      attempt(ada, "select start_eights_room(%s)", room_id) == "need at least 2 players")
check("bo joins with the code", attempt(bo, "select join_eights_room(%s)", code.lower()) != "")
start = {u: balance(u) for u in (ada, bo)}
res = attempt(ada, "select start_eights_room(%s)", room_id)
m = str(res[0][0])
check("the entries are taken", balance(ada) == start[ada] - 50 and balance(bo) == start[bo] - 50)

status, _, st, _, players = match(m)
check("two players get seven cards each", st["counts"] == [7, 7]
      and len(hand(m, ada)) == 7 and len(hand(m, bo)) == 7)
draw_pile, discard = deck(m)
everything = hand(m, ada) + hand(m, bo) + draw_pile + discard + [st["top"]]
check("every card is somewhere, once", len(everything) == 52 and len(set(everything)) == 52)
check("the pile doesn't start on an eight", st["top"][0] != "8")
check("the draw count is right", st["draw"] == len(draw_pile) == 37)

# ── hidden cards ──────────────────────────────────────────────────────────
mine = attempt(bo, "select user_id::text, cards from eights_hands where match_id = %s", m)
check("bo sees only his own hand", len(mine) == 1 and mine[0][0] == bo)
check("no one can read the deck",
      "permission denied" in str(attempt(bo, "select * from eights_decks where match_id = %s", m)))
check("cy (not playing) sees nothing",
      attempt(cy, "select count(*) from eights_matches where id = %s", m)[0][0] == 0)

# ── the rules ─────────────────────────────────────────────────────────────
rig(m, hands={ada: ["5H", "KS", "8C", "2D"], bo: ["9H", "3C", "QD"]}, top="5S", turn=0,
    draw=["4C", "7D", "JH"], discard=["6S"])
check("not your turn", attempt(bo, "select play_eights_card(%s, '9H')", m) == "not your turn")
check("a card you don't have",
      attempt(ada, "select play_eights_card(%s, 'AS')", m) == "not in your hand")
check("a card that doesn't match",
      attempt(ada, "select play_eights_card(%s, '2D')", m) == "that card doesn't go")
check("an eight needs a suit",
      attempt(ada, "select play_eights_card(%s, '8C')", m) == "name a suit for the eight")
check("can't pass without drawing",
      attempt(ada, "select pass_eights_turn(%s)", m) == "draw a card first")

r = attempt(ada, "select play_eights_card(%s, '5H')", m)
st = match(m)[2]
check("matching the rank goes", isinstance(r, list) and sorted(r[0][0]) == sorted(["KS", "8C", "2D"]))
check("…the pile shows it and hearts follow", st["top"] == "5H" and st["suit"] == "H")
check("…and it's bo's turn", st["turn"] == 1 and st["counts"] == [3, 3])
check("…and the old top went under", deck(m)[1] == ["6S", "5S"])
check("the move is there for everyone", st["last"] == {"seat": 0, "kind": "play", "card": "5H", "suit": None})

r = attempt(bo, "select draw_eights_card(%s)", m)
st = match(m)[2]
check("drawing takes the top of the pile", "JH" in r[0][0] and st["counts"][1] == 4)
check("…once a turn", attempt(bo, "select draw_eights_card(%s)", m) == "you already drew")
check("…it's still bo's go", st["turn"] == 1 and st["drawn"] is True and st["draw"] == 2)
attempt(bo, "select pass_eights_turn(%s)", m)
check("bo passes: back to ada", match(m)[2]["turn"] == 0 and match(m)[2]["last"]["kind"] == "pass")

r = attempt(ada, "select play_eights_card(%s, '8C', 'S')", m)
st = match(m)[2]
check("an eight goes on anything and names the suit", st["top"] == "8C" and st["suit"] == "S")
check("…shown as the eight's suit", st["last"]["suit"] == "S")
check("bo's heart doesn't follow spades",
      attempt(bo, "select play_eights_card(%s, '9H')", m) == "that card doesn't go")

# The pile runs out: what was played is shuffled back in.
rig(m, turn=1, draw=[], discard=["2C", "3H"])
r = attempt(bo, "select draw_eights_card(%s)", m)
check("an empty pile is refilled from the played cards",
      any(c in r[0][0] for c in ("2C", "3H")) and deck(m)[1] == [])

# ── winning ───────────────────────────────────────────────────────────────
rig(m, hands={ada: ["KS"], bo: ["9H", "3C"]}, top="4S", turn=0)
attempt(ada, "select play_eights_card(%s, 'KS')", m)
status, winner, st, _, _ = match(m)
check("the last card wins", status == "completed" and winner == ada and st["winner"] == 0)
check("…and takes the pot", balance(ada) == start[ada] + 50 and balance(bo) == start[bo] - 50)
check("the game counts for events",
      attempt(bo, "select event_count_game('eights', %s)", m) != "not a finished game of yours")
check("nothing more can be played",
      attempt(bo, "select play_eights_card(%s, '3C')", m) == "match is not active")

# ── time running out ──────────────────────────────────────────────────────
harness.as_user(db, ada)
room = one("select create_eights_room(3, 0)")
attempt(bo, "select join_eights_room(%s)", room["code"])
attempt(cy, "select join_eights_room(%s)", room["code"])
m2 = str(attempt(ada, "select start_eights_room(%s)", room["id"])[0][0])
st = match(m2)[2]
check("three players get five each", st["counts"] == [5, 5, 5])
rig(m2, hands={ada: ["2C", "3C", "KS"]}, top="9H", suit="H", turn=0, draw=["4S", "5D"])


def go_quiet(mm, seconds=25):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("update eights_matches set updated_at = now() - make_interval(secs => %s)"
                  " where id = %s", (seconds, mm))


seq = match(m2)[2]["seq"]
check("not yet: time isn't up",
      attempt(bo, "select skip_eights_turn(%s, %s)", m2, seq)[0][0] is False)
go_quiet(m2, 45)
attempt(bo, "select skip_eights_turn(%s, %s)", m2, seq)
st, missed = match(m2)[2], match(m2)[3]
check("ada's time ran out: nothing went, so she drew one (it didn't go) and it's bo's go",
      st["counts"][0] == 4 and sorted(hand(m2, ada)) == ["2C", "3C", "5D", "KS"]
      and st["turn"] == 1, (st, hand(m2, ada)))
check("…shown as a time-out", st["last"]["kind"] == "timeout" and missed.get("0") == 1)
check("a late call for the same turn does nothing",
      attempt(cy, "select skip_eights_turn(%s, %s)", m2, seq)[0][0] is True and match(m2)[2]["turn"] == 1)

rig(m2, top="9D", suit="D", turn=0, draw=["4S", "6D"])
go_quiet(m2, 45)
attempt(bo, "select skip_eights_turn(%s, %s)", m2, match(m2)[2]["seq"])
st, missed = match(m2)[2], match(m2)[3]
check("away again: the diamond she holds goes for her",
      st["last"]["kind"] == "play" and st["last"]["card"] == "5D" and st["top"] == "5D"
      and sorted(hand(m2, ada)) == ["2C", "3C", "KS"] and st["turn"] == 1, st)
check("…and she's counted away twice", missed.get("0") == 2)

rig(m2, top="9H", suit="H", turn=0, draw=["4S", "6H"])
go_quiet(m2, 45)
attempt(bo, "select skip_eights_turn(%s, %s)", m2, match(m2)[2]["seq"])
st, missed = match(m2)[2], match(m2)[3]
check("a third time: nothing went, the card she drew did, so it's played",
      st["top"] == "6H" and sorted(hand(m2, ada)) == ["2C", "3C", "KS"] and st["turn"] == 1, st)
check("three in a row and ada's still in", st["left"] == [] and match(m2)[0] == "active"
      and missed.get("0") == 3, (st["left"], missed))

rig(m2, top="9C", suit="C", turn=0)
check("back, she plays her own card", attempt(ada, "select play_eights_card(%s, '2C')", m2) != "ok"
      and match(m2)[2]["top"] == "2C")
check("…and she's not away any more", match(m2)[3].get("0") is None)

attempt(cy, "select resign_eights_match(%s)", m2)
attempt(ada, "select resign_eights_match(%s)", m2)
status, winner, st, _, _ = match(m2)
check("ada and cy leave: bo wins", status == "completed" and winner == bo and st["winner"] == 1)

# ── quick match ───────────────────────────────────────────────────────────
r1 = attempt(cy, "select join_eights_matchmaking_queue(0, 2)")
check("the first in waits", r1[0][0] is None)
r2 = attempt(di, "select join_eights_matchmaking_queue(0, 2)")
m3 = r2[0][0]
check("the second fills the table", m3 is not None and match(str(m3))[0] == "active")
check("both are in it", set(match(str(m3))[4]) == {cy, di})
check("too big a table isn't quick match",
      "2 to 4" in str(attempt(cy, "select join_eights_matchmaking_queue(0, 5)")))

# ── chat ──────────────────────────────────────────────────────────────────
m3 = str(m3)
check("players chat", attempt(cy, "select send_eights_chat(%s, 'text', 'gl hf')", m3) != "")
check("others can't", attempt(ada, "select send_eights_chat(%s, 'text', 'hi')", m3)
      == "not a player in this match")
check("only chat kinds", attempt(cy, "select send_eights_chat(%s, 'reaction', 'war')", m3)
      == "invalid message kind")
check("players' voice notes have a folder",
      attempt(di, "select _is_ludo_voice_folder(%s)", m3)[0][0] is True)
check("others' don't", attempt(ada, "select _is_ludo_voice_folder(%s)", m3)[0][0] is False)

stats = attempt(cy, "select get_player_stats(%s)", bo)[0][0]
check("wins show on the player card", stats["eights_won"] == 1 and stats["eights_played"] == 2)

print()
print("FAILED: " + ", ".join(fails) if fails else "ALL PASS")
sys.exit(1 if fails else 0)
