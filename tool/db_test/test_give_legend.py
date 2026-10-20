"""tool/sql/give_legend.sql and take_legend.sql: a test account made a
Legend with a history where every number adds up (the hologram's record,
its games one by one, its white and black, how they were won), the same
every run, the house players' ratings untouched; and taken back."""
import pathlib
import sys

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


def run(script, who, game="chess"):
    harness.as_admin(db)
    sql = (SQL / script).read_text().replace("'their_username'", "'" + who + "'")
    sql = sql.replace("v_game text := 'chess'", f"v_game text := '{game}'")
    with db.cursor() as c:
        c.execute(sql)


def insights(user, game="chess"):
    harness.as_user(db, user)
    return one("select get_rank_insights(%s)", game)


def adds_up(name, i):
    check(f"{name}: Legend", i["rating"] >= 1700 and i["best"] >= i["rating"], (i["rating"], i["best"]))
    check(f"{name}: games = wins + losses + draws",
          i["games"] == i["wins"] + i["losses"] + i["draws"], i)
    check(f"{name}: won under 100%, and well", 0.6 < i["wins"] / i["games"] < 1, i["wins"] / i["games"])
    check(f"{name}: white and black games add up",
          i["white"]["games"] + i["black"]["games"] == i["games"]
          and i["white"]["wins"] + i["black"]["wins"] == i["wins"], (i["white"], i["black"]))
    check(f"{name}: how they won adds up", sum(i["wins_by"].values()) == i["wins"], i["wins_by"])
    check(f"{name}: how they lost adds up", sum(i["losses_by"].values()) == i["losses"], i["losses_by"])
    check(f"{name}: ends on a win streak", i["streak_kind"] == "W" and i["streak"] >= 4, i["streak"])
    check(f"{name}: a best win, a rival and a nemesis (two people)",
          i.get("best_win") and i.get("rival") and i.get("nemesis")
          and i["rival"]["id"] != i["nemesis"]["id"], [i.get(k) for k in ("rival", "nemesis")])
    check(f"{name}: games this week and moves this month", i["games_week"] > 0 and i["month"] != 0, i)
    # First of the real ranked players (only them here: top 100%).
    check(f"{name}: ranked first among the players",
          i.get("top_percent") == -(-100 // i["ranked"]), (i.get("top_percent"), i.get("ranked")))


me = harness.new_user(db, "legend@example.com")
harness.as_admin(db)
houses = one("select jsonb_object_agg(user_id, rating) from player_ratings r "
             "join house_players h on h.id = r.user_id where r.game = 'chess'")

run("give_legend.sql", "legend@example.com")
first = insights(me)
adds_up("chess", first)
harness.as_admin(db)
check("its rating is the last game's", one(
    "select after from rating_changes where user_id = %s and game = 'chess' order by created_at desc limit 1", me)
    == first["rating"])
check("every game is a completed, unstaked match with a house player", one(
    "select count(*) from matches where %s in (player_white, player_black) and status = 'completed' "
    "and stake = 0 and house_player is not null", me) == first["games"])
check("the house players' ratings aren't touched", one(
    "select jsonb_object_agg(user_id, rating) from player_ratings r "
    "join house_players h on h.id = r.user_id where r.game = 'chess'") == houses)

run("give_legend.sql", me)
again = insights(me)
check("run again: the same history, nothing doubled",
      (again["games"], again["rating"], again["wins"]) == (first["games"], first["rating"], first["wins"]),
      (again["games"], first["games"]))

run("give_legend.sql", me, "checkers")
adds_up("checkers", insights(me, "checkers"))

run("take_legend.sql", me)
harness.as_admin(db)
check("taken back: no chess rating, no made-up games, no ratings left in them",
      one("select count(*) from player_ratings where user_id = %s and game = 'chess'", me) == 0
      and one("select count(*) from matches where %s in (player_white, player_black) and game = 'chess'", me) == 0
      and one("select count(*) from rating_changes where game = 'chess' and match_id not in (select id from matches)") == 0)
check("…checkers kept", one("select rating from player_ratings where user_id = %s and game = 'checkers'", me) >= 1700)

try:
    run("give_legend.sql", "nobody@example.com")
    check("an unknown player is refused", False)
except Exception as e:
    db.rollback() if not db.autocommit else None
    check("an unknown player is refused", "No account matches" in str(e), e)

sys.exit(1 if fails else 0)
