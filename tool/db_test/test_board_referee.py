"""Online chess and checkers moves checked by the server
(20261022090000_board_referee.sql): moves are saved only through the
referee (board_play_move, for the board-move function), a move that ends
the game settles it, and players no longer send boards or results."""
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


def row(match):
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("select status::text, ply_count, board_fen, winner_id::text, result"
                  " from matches where id = %s", (match,))
        return c.fetchone()


ada, bo = (harness.new_user(db, f"{n}@example.com") for n in ("ada", "bo"))
harness.as_admin(db)
match = str(one("select public._board_create_match('chess', %s, %s, 0, 10, 0)", ada, bo))
white = one("select player_white::text from matches where id = %s", match)
black = bo if white == ada else ada
E4 = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"


def play(mover, ply, frm, to, san, fen, winner=None, result=None):
    harness.as_admin(db)
    try:
        return one("select public.board_play_move(%s, %s, %s, %s, %s, null, %s, %s, %s, %s)",
                   match, mover, ply, frm, to, san, fen, winner, result)
    except Exception as e:
        db.rollback() if not db.autocommit else None
        return str(e).split("\n")[0]


check("the referee's move is saved", play(white, 0, "e2", "e4", "e4", E4) is True)
check("…the board is the referee's", row(match)[1:3] == (1, E4), row(match))
check("a move on a board that's moved on isn't",
      play(black, 0, "e7", "e5", "e5", "x") == "out of sync")
check("nor one by the player not on turn",
      play(white, 1, "d2", "d4", "d4", "x") == "not your turn")

check("players can't save a board themselves any more",
      "checked by the server" in str(attempt(black, "select record_move(%s, 'e7', 'e5', null, 'e5', 'x')", match)))
check("…nor say how a game ended",
      "decides how games end" in str(attempt(black, "select report_match_result(%s, %s, 'checkmate')", match, black)))
check("…nor call the referee's own saving",
      "permission denied" in str(attempt(black, "select board_play_move(%s, %s, 1, 'e7', 'e5', null, 'e5', 'x', null, null)", match, black)))

check("a move that ends the game settles it",
      play(black, 1, "d8", "h4", "Qh4#", "mate", "black", "checkmate") is True)
status, ply, _, winner, result = row(match)
check("…for the one who gave mate", status == "completed" and winner == black and result == "checkmate",
      row(match))

# A house player's engine reads the server's board: its word ends the game.
house = harness.new_user(db, "house@example.com")
harness.as_admin(db)
match = str(one("select public._board_create_match('checkers', %s, %s, 0, 10, 0)", ada, house))
with db.cursor() as c:
    c.execute("update matches set house_player = %s where id = %s", (house, match))
    c.execute("select public.house_report_result(%s, 'white', 'win')", (match,))
status, _, _, winner, result = row(match)
w = one("select player_white::text from matches where id = %s", match)
check("a house player's report of the end settles the game", status == "completed" and winner == w,
      row(match))

sys.exit(1 if fails else 0)
