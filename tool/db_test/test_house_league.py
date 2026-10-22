"""The house league (20261022110000_house_league.sql): forty more house
players who play strongly, and games between house players run on the
server: one tick at a time, games started at a person's pace between free
house players, moves played when due through the ordinary move function,
results settled and rated like any game, and none of it open to players."""
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


def raises(sql, *args):
    try:
        one(sql, *args)
        return None
    except Exception as e:  # noqa: BLE001
        return str(e).splitlines()[0]


def as_service():
    harness.as_admin(db)
    with db.cursor() as c:
        c.execute("set role service_role")


harness.as_admin(db)

# ── the new forty ───────────────────────────────────────────────────────────
strong = one("select count(*) from house_players where strength >= 1400")
check("forty new house players, all playing strongly", strong == 40, strong)
check("each a profile with a name, an avatar, a frame and both ratings",
      one("select count(*) from house_players h join profiles p on p.id = h.id "
          "where h.strength is not null and p.display_name is not null "
          "and p.avatar_kind is not null and p.equipped_aura is not null "
          "and (select count(*) from player_ratings r where r.user_id = h.id) = 2") == 40)
check("established records: more won than lost",
      one("select bool_and(wins > losses) from player_ratings r "
          "join house_players h on h.id = r.user_id where h.strength is not null and r.game = 'chess'"))
weak = one("select h.id from house_players h join player_ratings r on r.user_id = h.id "
           "and r.game = 'chess' where h.strength is not null order by r.rating limit 1")
rating, strength = one("select array[r.rating, h.strength] from house_players h "
                       "join player_ratings r on r.user_id = h.id and r.game = 'chess' where h.id = %s", weak)
check("their engine plays at their strength even when their rating is lower",
      one("select _house_strength(%s, 'chess')", weak) == max(rating, strength), (rating, strength))
old = one("select id from house_players where strength is null limit 1")
check("the first forty play at their own rating, as before",
      one("select _house_strength(%s, 'chess')", old)
      == one("select rating from player_ratings where user_id = %s and game = 'chess'", old))

as_service()
# ── starting games ──────────────────────────────────────────────────────────
match = one("select house_league_start()")
check("a league game starts", match is not None)
harness.as_admin(db)
white, black, stake, status, house = one(
    "select array[player_white::text, player_black::text, stake::text, status::text, house_player::text] "
    "from matches where id = %s", match)
check("between two house players, free, active",
      one("select count(*) from house_players where id in (%s, %s)", white, black) == 2
      and white != black and stake == "0" and status == "active", (white, black, stake, status))
check("marked a house game, so it never counts toward prizes", house is not None)
as_service()
check("not another within 90 seconds", one("select house_league_start()") is None)

harness.as_admin(db)
target = one("select _house_league_target()")
for _ in range(10):
    one("update house_league_state set last_start = 'epoch' returning 1")
    as_service()
    one("select house_league_start()")
    harness.as_admin(db)
going = one("select count(*) from house_league_games")
check("no more at once than the hour allows (1-4)", 1 <= going <= target <= 4, (going, target))
check("nobody in two games at once",
      one("select max(n) from (select p, count(*) n from matches m, "
          "lateral (values (m.player_white), (m.player_black)) v(p) "
          "where m.status = 'active' group by p) t") == 1)

# ── moves ───────────────────────────────────────────────────────────────────
as_service()
check("no move before it's due", one("select house_league_claim()") is None)
harness.as_admin(db)
one("update house_league_games set next_move_at = now() - interval '1 second' where match_id = %s returning 1", match)
as_service()
due = one("select house_league_claim()")
check("due: the position, and the side to move's strength and clock",
      due is not None and due["match"] == match and due["ply"] == 0
      and due["rating"] == one("select _house_strength(%s, game::text) from matches where id = %s", white, match)
      and due["ms_left"] > 0, due)
check("claimed: no other call gets the same move", one("select house_league_claim()") is None)
fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
played = one("select house_league_play(%s, 0, 'e2', 'e4', null, 'e4', %s, 7000)", match, fen)
harness.as_admin(db)
check("the move is played, as white's",
      played is True and one("select ply_count from matches where id = %s", match) == 1)
wait = one("select extract(epoch from next_move_at - now()) from house_league_games where match_id = %s", match)
check("the next one waits as long as a person might think", 5 < float(wait) <= 7.5, wait)
as_service()
check("a stale move is dropped",
      one("select house_league_play(%s, 0, 'e2', 'e4', null, 'e4', %s, 7000)", match, fen) is False)

# ── results ─────────────────────────────────────────────────────────────────
# A reply, so the game is long enough to be rated (two moves at least).
as_service()
one("select house_league_play(%s, 1, 'e7', 'e5', null, 'e5', %s, 3000)", match,
    "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2")
harness.as_admin(db)
before = one("select array[(select games from player_ratings where user_id = %s and game = 'chess'), "
             "(select games from player_ratings where user_id = %s and game = 'chess')]", white, black)
game = one("select game::text from matches where id = %s", match)
as_service()
one("select house_league_over(%s, 'white', 'checkmate')", match)
harness.as_admin(db)
check("the result is settled", one("select status::text from matches where id = %s", match) != "active")
check("and leaves the league", one("select count(*) from house_league_games where match_id = %s", match) == 0)
if game == "chess":
    after = one("select array[(select games from player_ratings where user_id = %s and game = 'chess'), "
                "(select games from player_ratings where user_id = %s and game = 'chess')]", white, black)
    check("both are rated, like any game", after == [before[0] + 1, before[1] + 1], (before, after))

other = one("select match_id from house_league_games limit 1")
if other:
    one("update matches set status = 'completed' where id = %s returning 1", other)
    as_service()
    check("a game that ended some other way is tidied away", one("select house_league_tidy()") >= 1)

# ── players ─────────────────────────────────────────────────────────────────
me = harness.new_user(db)
harness.as_user(db, me)
for fn in ["house_league_start()", "house_league_claim()",
           "house_league_over('00000000-0000-0000-0000-000000000000', null, 'draw')"]:
    check(f"players can't call {fn.split('(')[0]}", raises(f"select {fn}") is not None)

harness.as_admin(db)
check("the league is called four times every 15 seconds",
      one("select count(*) from cron.job where jobname = 'house-league' and schedule = '15 seconds' "
          "and command like '%%functions/v1/house-league%%' and command like '%%generate_series(1, 4)%%'") == 1)

print()
print("FAILED: " + ", ".join(fails) if fails else "All passed.")
sys.exit(1 if fails else 0)
