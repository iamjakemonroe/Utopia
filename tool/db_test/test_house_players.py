"""House players: matched when no one's free for a free game, playing and
reporting like anyone, rated, and never on a leaderboard."""
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
    harness.as_admin(db)
    rows = q(sql, *args)
    return rows[0][0] if rows else None


def raises(sql, *args):
    try:
        q(sql, *args)
        return None
    except Exception as e:
        return str(e).splitlines()[0]


houses = one("select count(*) from house_players")
check("eighty house players, each a profile with a frame and ratings", houses == 80
      and one("select count(*) from house_players h join profiles p on p.id = h.id "
              "where p.equipped_aura is not null and p.display_name is not null and p.avatar_kind is not null") == 80
      and one("select count(*) from player_ratings r join house_players h on h.id = r.user_id") == 160, houses)

me = harness.new_user(db, "me@example.com")
harness.as_user(db, me)
check("nobody to play: the queue waits", q("select join_board_queue('chess', 0, 10, 0)")[0][0] is None)
match = q("select house_match_start('chess', 10, 0)")[0][0]
row = one("select house_player, stake, status, %s in (player_white, player_black) from matches where id = %s", me, match)
check("a house player instead, for a free game", match is not None)
row = None
harness.as_admin(db)
house, stake, status, mine = q("select house_player, stake, status, %s in (player_white, player_black) from matches where id = %s", me, match)[0]
check("…a real match: active, free, theirs", house is not None and stake == 0 and status == "active" and mine)
check("…and they've left the queue", one("select count(*) from matchmaking_queue where user_id = %s", me) == 0)
check("the house player is one of the house's", one("select count(*) from house_players where id = %s", house) == 1)

rich = harness.new_user(db, "rich@example.com")
harness.as_user(db, rich)
q("select join_board_queue('chess', 500, 10, 0)")
check("never for coins", raises("select house_match_start('chess', 10, 0)") == "house games are free games")

waiting = harness.new_user(db, "waiting@example.com")
other = harness.new_user(db, "other@example.com")
harness.as_user(db, waiting)
q("select join_board_queue('checkers', 0, 5, 0)")
harness.as_user(db, other)
harness.as_admin(db)
q("insert into matchmaking_queue (user_id, game, stake, minutes, increment) values (%s, 'checkers', 0, 5, 0)", other)
harness.as_user(db, waiting)
paired = q("select house_match_start('checkers', 5, 0)")[0][0]
check("a real player who came along comes first",
      one("select house_player is null and %s in (player_white, player_black) from matches where id = %s", other, paired))

# The house player's turn, as the house-move function sees it.
state = one("select house_turn_state(%s, %s)", match, me)
white_house = state["house_white"]
check("the turn state says whose move it is", state["house_to_move"] == white_house and state["ply"] == 0)
check("…only for a player in the game",
      one("select house_turn_state(%s, %s)", match, other) is None)
if not white_house:
    # The player's move, as the board-move function saves it.
    harness.as_admin(db)
    one("select board_play_move(%s, %s, 0, 'e2', 'e4', null, 'e4', "
        "'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1', null, null)", match, me)
ply = one("select ply_count from matches where id = %s", match)
check("one think per move", one("select house_claim_turn(%s, %s)", match, ply) is True
      and one("select house_claim_turn(%s, %s)", match, ply) is False)
fen = "rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 1 1" if white_house else \
      "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2"
frm, to, san = ("g1", "f3", "Nf3") if white_house else ("e7", "e5", "e5")
check("a stale move is dropped", one("select house_play_move(%s, %s, %s, %s, null, %s, %s)", match, ply + 5, frm, to, san, fen) is False)
check("the house player's move goes in, as theirs",
      one("select house_play_move(%s, %s, %s, %s, null, %s, %s)", match, ply, frm, to, san, fen) is True
      and one("select player_id from match_moves where match_id = %s order by ply desc limit 1", match) == house
      and one("select ply_count from matches where id = %s", match) == ply + 1)
harness.as_user(db, me)
check("players can't move for the house", raises("select house_play_move(%s, 1, 'a', 'b', null, 'x', 'y')", match) is not None)

# At least a move each (a game of one move isn't rated, for anyone).
if white_house:
    harness.as_admin(db)
    one("select board_play_move(%s, %s, 1, 'e7', 'e5', null, 'e5', "
        "'rnbqkbnr/pppp1ppp/8/4p3/8/5N2/PPPPPPPP/RNBQKB1R w KQkq - 0 2', null, null)", match, me)

# The end: the house player's engine reads the server's board, so its word
# settles the game, and it's rated.
harness.as_admin(db)
before = one("select coalesce((select games from player_ratings where user_id = %s and game = 'chess'), 0)", me)
one("select house_report_result(%s, %s, 'checkmate')", match, "white" if not white_house else "black")
check("the house player's engine says how it ended: settled",
      one("select status from matches where id = %s", match) == "completed"
      and one("select winner_id from matches where id = %s", match) == me)
check("…and rated like any game", one("select games from player_ratings where user_id = %s and game = 'chess'", me) == before + 1)

# Leaderboards and cards (house players can be shown for a while, by a
# switch: off, they're never on it).
harness.as_admin(db)
q("update leaderboard_settings set show_house_players = false")
harness.as_user(db, me)
board = q("select get_leaderboard('chess')")[0][0]
check("house players never on the leaderboard (switch off)",
      all(one("select count(*) from house_players where id = %s", p["id"]) == 0 for p in board["top"]), board["top"][:2])
stats = one("select get_player_stats(%s)", house)
check("a house player's card reads like an established player's", stats["chess_played"] >= 30 and stats["chess_rating"] is not None)

sys.exit(1 if fails else 0)
