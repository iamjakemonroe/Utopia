-- House players play each other: 40 more of them, and a league that has
-- house players play real chess and checkers games against one another on
-- the server, at a person's pace, so the boards move and every rating on
-- them is earned in real games.
--
--   * The new 40 are made like the first 40 (20261021130000_house_players)
--     and play strongly: house_players.strength is the rating their engine
--     plays at whatever their own rating does (hard, for all of them).
--   * The house-league Edge Function runs the league. pg_cron calls it
--     (through pg_net) four times every 15 seconds. Each call may start a
--     game (house_league_start: one in 90 seconds at most), then claims
--     one game whose move is due (house_league_claim) and plays it with
--     the app's own engines (brain.js) through the same move and result
--     functions as every game (house_league_play, house_league_over). A
--     move thinks for about as much CPU as one call may use, hence one a
--     call. A game moves only when its move is due, so calling more often
--     can't speed anything up.
--   * A league game is an ordinary free game between two house players:
--     matches.house_player is set, so (as for every house game) it never
--     counts toward prize standings.
--   * Pace: one to four league games at a time across the house (more in
--     the evening, Lagos time), each house player in at most one at a time
--     and preferring whoever has played least today: a few games a day
--     each, like an ordinary player.

alter table public.house_players add column strength int;
comment on column public.house_players.strength is
  'The rating the house player''s engine plays at, whatever their own rating (null: their own).';

-- Their engine's strength: their own rating, or [strength] when that's set.
create or replace function public._house_strength(p_player uuid, p_game text)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    coalesce((select rating from public.player_ratings
              where user_id = p_player and game = p_game), 1000),
    coalesce((select strength from public.house_players where id = p_player), 0)
  )
$$;
revoke all on function public._house_strength(uuid, text) from public, anon, authenticated;

-- The house player's turn in a game with a real player plays at their
-- strength too.
create or replace function public.house_turn_state(p_match uuid, p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'status', m.status,
    'game', m.game,
    'position', m.board_fen,
    'ply', m.ply_count,
    'house', m.house_player,
    'house_white', m.player_white = m.house_player,
    'house_to_move', (m.ply_count % 2 = 0) = (m.player_white = m.house_player),
    'rating', public._house_strength(m.house_player, m.game::text),
    'ms_left', case
      when m.white_ms is null then 0
      else greatest(0,
        (case when m.player_white = m.house_player then m.white_ms else m.black_ms end)
        - case when m.ply_count >= 2
            then (extract(epoch from (now() - m.turn_started_at)) * 1000)::bigint
            else 0 end)
    end
  )
  from public.matches m
  where m.id = p_match and m.house_player is not null
    and p_user in (m.player_white, m.player_black);
$$;

-- ── the new forty ───────────────────────────────────────────────────────

do $$
declare
  v_people constant text[][] := array[
    ['Chinedu Eze', 'chinedu.e'], ['Adaeze', 'adaeze_n'], ['Tolu Ajayi', 'tolu_aj'],
    ['Ngozi O.', 'ngozi.o'], ['Babajide', 'jide_b'], ['Funmi', 'funmi_a'],
    ['Ikenna Obi', 'ikenna_o'], ['Halima', 'halima.s'], ['Sani Garba', 'sanig'],
    ['Efe', 'efe_plays'], ['Damilola K.', 'dami_k'], ['Kelechi', 'kelechi.n'],
    ['Amaka', 'amaka_u'], ['Segun O.', 'segun_o7'], ['Rukayat', 'rukky_b'],
    ['Oghenekaro', 'karo_g'], ['Yemi Alade', 'yemi_al'], ['Uche', 'uche.okoro'],
    ['Kofi Boateng', 'kofi_b'], ['Akosua', 'akosua.m'], ['Yaw', 'yaw_owusu'],
    ['Achieng', 'achieng_o'], ['Kamau', 'kamau.j'], ['Lerato', 'lerato_m'],
    ['Bongani', 'bongani_z'], ['Fatima Z.', 'fatimaz'], ['Sarah K.', 'sarahk_'],
    ['Daniel Reyes', 'dreyes'], ['Priya', 'priya.n'], ['Chen Wei', 'chenwei'],
    ['Aiden', 'aiden_m'], ['Isabella', 'bella_r'], ['Marco', 'marco.b'],
    ['Elif', 'elif_y'], ['Hiroshi', 'hiro_t'], ['Nadia', 'nadia.k'],
    ['Tom Hughes', 'tomh'], ['Joy', 'joy_e'], ['Abdul', 'abdul_r'],
    ['Precious', 'precious.i']
  ];
  v_frames constant text[] := array[
    'bubbles', 'sakura', 'frost', 'sunburst', 'prism', 'cosmic', 'flame', 'storm',
    'hearts', 'fireflies', 'starlight', 'autumn', 'neon', 'tidal', 'galaxy',
    'storm_blue', 'storm_gold', 'storm_pink', 'fury', 'supernova', 'frostfire',
    'zombie', 'dragon', 'music'
  ];
  v_kinds constant text[] := array['human', 'animal', 'plant'];
  v_worlds constant text[] := array['utopia_calm', 'utopia_warm', 'utopia_adventure'];
  v_id uuid;
  v_frame text;
  v_days int;
  v_chess int;
  v_checkers int;
  v_played int;
  v_won int;
begin
  for i in 1..array_length(v_people, 1) loop
    if exists (select 1 from public.profiles where lower(username) = v_people[i][2]) then
      continue;
    end if;
    v_id := gen_random_uuid();
    v_frame := v_frames[1 + (i * 11) % array_length(v_frames, 1)];
    v_days := 12 + (i * 29) % 190;
    -- As for the first forty: a sign-in record nobody can sign in with.
    insert into auth.users (id, is_anonymous, raw_user_meta_data, created_at)
      values (v_id, false, '{}'::jsonb, now() - make_interval(days => v_days));
    begin
      execute 'update auth.users set aud = $2, role = $2 where id = $1'
        using v_id, 'authenticated';
    exception when undefined_column then null;
    end;
    insert into public.profiles (id) values (v_id) on conflict (id) do nothing;
    update public.profiles set
      display_name = v_people[i][1],
      username = v_people[i][2],
      avatar_url = null,
      avatar_kind = v_kinds[1 + (i + 1) % 3],
      avatar_seed = (i * 3) % 8,
      equipped_theme = v_worlds[1 + (i + 2) % 3],
      equipped_aura = v_frame,
      aura_expires_at = '2099-01-01',
      show_coins = false,
      created_at = now() - make_interval(days => v_days),
      updated_at = now()
    where id = v_id;
    insert into public.user_auras (user_id, aura_id, expires_at)
      values (v_id, v_frame, '2099-01-01')
      on conflict do nothing;
    -- Strong, established players: more won than lost.
    v_chess := 1180 + (i * 173) % 640;
    v_checkers := 1120 + (i * 131) % 580;
    v_played := 40 + (i * 67) % 380;
    v_won := v_played * (52 + (i * 7) % 9) / 100;
    insert into public.player_ratings (user_id, game, rating, games, wins, losses, draws, best)
    values
      (v_id, 'chess', v_chess, v_played, v_won, v_played - v_won - v_played / 12, v_played / 12, v_chess + 35 + i % 40),
      (v_id, 'checkers', v_checkers, v_played / 2, v_won / 2, v_played / 2 - v_won / 2 - v_played / 30, v_played / 30, v_checkers + 25 + i % 30)
    on conflict do nothing;
    insert into public.house_players (id, chess_played, chess_won, checkers_played, checkers_won, strength)
    values (v_id, v_played, v_won, v_played / 2, v_won / 2, 1400 + (i * 37) % 360);
  end loop;
end;
$$;

-- ── the league ──────────────────────────────────────────────────────────

-- Games between house players being played, and when the next move's due.
create table public.house_league_games (
  match_id uuid primary key references public.matches (id) on delete cascade,
  next_move_at timestamptz not null default now()
);
alter table public.house_league_games enable row level security;
revoke all on public.house_league_games from anon, authenticated;

create table public.house_league_state (
  id boolean primary key default true check (id),
  last_start timestamptz not null default 'epoch'
);
insert into public.house_league_state default values;
alter table public.house_league_state enable row level security;
revoke all on public.house_league_state from anon, authenticated;

-- How many league games may be going at [p_at]: one to four, most in the
-- evening (Lagos, UTC+1), fewest before dawn.
create function public._house_league_target(p_at timestamptz default now())
returns int
language sql
immutable
as $$
  select case
    when extract(hour from p_at at time zone 'Africa/Lagos') between 2 and 6 then 1
    when extract(hour from p_at at time zone 'Africa/Lagos') between 7 and 15 then 2
    when extract(hour from p_at at time zone 'Africa/Lagos') between 16 and 18 then 3
    else 4
  end
$$;

-- House players free to start a game of [p_game] (in no active game, with
-- anyone): their rating at it, and how many games they've begun today.
create function public._house_free(p_game text)
returns table (id uuid, rating int, today bigint)
language sql
stable
security definer
set search_path = public
as $$
  select h.id,
         coalesce(r.rating, 1000),
         (select count(*) from matches m
           where (m.player_white = h.id or m.player_black = h.id)
             and m.created_at > now() - interval '1 day')
  from house_players h
  left join player_ratings r on r.user_id = h.id and r.game = p_game
  where h.active
    and not exists (select 1 from matches m
                    where m.status = 'active'
                      and (m.player_white = h.id or m.player_black = h.id));
$$;
revoke all on function public._house_free(text) from public, anon, authenticated;

-- Starts a league game if the house is playing fewer than it would now
-- (and none started in the last 90 seconds): two free house players near
-- each other's rating, those with fewest games today first. Returns the
-- match, or null.
create function public.house_league_start()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game text := case when random() < 0.6 then 'chess' else 'checkers' end;
  v_controls constant int[][] := array[[15, 10], [20, 10], [15, 5]];
  v_k int := 1 + floor(random() * 3)::int;
  v_white uuid;
  v_black uuid;
  v_rating int;
  v_match uuid;
begin
  if (select count(*) from house_league_games) >= _house_league_target() then return null; end if;
  -- One start in 90 seconds, however many calls arrive at once.
  update house_league_state set last_start = now()
    where last_start <= now() - interval '90 seconds';
  if not found then return null; end if;

  select f.id, f.rating into v_white, v_rating
    from _house_free(v_game) f order by f.today, random() limit 1;
  if v_white is null then return null; end if;
  select f.id into v_black from _house_free(v_game) f
    where f.id <> v_white
    order by abs(f.rating - v_rating) + random() * 200, f.today
    limit 1;
  if v_black is null then return null; end if;
  if random() < 0.5 then
    select v_black, v_white into v_white, v_black;
  end if;

  v_match := _board_create_match(v_game::game_kind, v_white, v_black, 0,
                                 v_controls[v_k][1], v_controls[v_k][2]);
  update matches set house_player = v_white where id = v_match;
  insert into house_league_games (match_id, next_move_at)
    values (v_match, now() + make_interval(secs => 3 + random() * 10));
  return v_match;
end;
$$;

-- Claims one league game whose move is due (none other call gets it; it
-- comes round again in a minute if this one never plays it), with what the
-- engine needs: the position, and the side to move's strength and clock.
-- Null when none is due.
create function public.house_league_claim()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_match matches;
  v_mover uuid;
begin
  select g.match_id into v_id from house_league_games g
    where g.next_move_at <= now()
    order by g.next_move_at
    limit 1
    for update skip locked;
  if v_id is null then return null; end if;
  update house_league_games set next_move_at = now() + interval '1 minute'
    where match_id = v_id;
  select * into v_match from matches where id = v_id;
  v_mover := case when v_match.ply_count % 2 = 0 then v_match.player_white
                  else v_match.player_black end;
  return jsonb_build_object(
    'match', v_match.id,
    'game', v_match.game,
    'position', v_match.board_fen,
    'ply', v_match.ply_count,
    'rating', _house_strength(v_mover, v_match.game::text),
    'ms_left', case
      when v_match.white_ms is null then 0
      else greatest(0,
        (case when v_match.ply_count % 2 = 0 then v_match.white_ms else v_match.black_ms end)
        - case when v_match.ply_count >= 2
            then (extract(epoch from (now() - v_match.turn_started_at)) * 1000)::bigint
            else 0 end)
    end
  );
end;
$$;

-- Plays the side to move's move in a league game (from position [p_ply]),
-- and when the next one's due: after [p_think_ms], as long as a person
-- might take. False if the game has moved on or isn't a league game.
create function public.house_league_play(
  p_match uuid,
  p_ply int,
  p_from text,
  p_to text,
  p_promotion text,
  p_san text,
  p_fen_after text,
  p_think_ms int
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match matches;
begin
  select * into v_match from matches where id = p_match for update;
  if v_match is null or v_match.status <> 'active' or v_match.ply_count <> p_ply
     or not exists (select 1 from house_league_games where match_id = p_match) then
    return false;
  end if;
  perform _record_move_as(
    case when p_ply % 2 = 0 then v_match.player_white else v_match.player_black end,
    p_match, p_from, p_to, p_promotion, p_san, p_fen_after);
  update house_league_games
    set next_move_at = now() + make_interval(secs => greatest(p_think_ms, 1000) / 1000.0)
    where match_id = p_match;
  return true;
end;
$$;

-- How a league game ended, as the engine sees it ([p_winner]: 'white',
-- 'black' or null): settled and rated like any game.
create function public.house_league_over(p_match uuid, p_winner text, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match matches;
begin
  select * into v_match from matches where id = p_match for update;
  delete from house_league_games where match_id = p_match;
  if v_match is null or v_match.status <> 'active' then return; end if;
  perform _settle(
    p_match,
    case p_winner when 'white' then v_match.player_white
                  when 'black' then v_match.player_black end,
    p_result
  );
end;
$$;

-- A league game that ended some other way (a clock, a sweep) leaves the
-- league.
create function public.house_league_tidy()
returns int
language sql
security definer
set search_path = public
as $$
  with gone as (
    delete from house_league_games g
    using matches m
    where m.id = g.match_id and m.status <> 'active'
    returning 1
  )
  select count(*)::int from gone;
$$;

revoke all on function public._house_league_target(timestamptz) from public, anon, authenticated;
revoke all on function public.house_league_start() from public, anon, authenticated;
revoke all on function public.house_league_claim() from public, anon, authenticated;
revoke all on function public.house_league_play(uuid, int, text, text, text, text, text, int) from public, anon, authenticated;
revoke all on function public.house_league_over(uuid, text, text) from public, anon, authenticated;
revoke all on function public.house_league_tidy() from public, anon, authenticated;
grant execute on function public.house_league_start() to service_role;
grant execute on function public.house_league_claim() to service_role;
grant execute on function public.house_league_play(uuid, int, text, text, text, text, text, int) to service_role;
grant execute on function public.house_league_over(uuid, text, text) to service_role;
grant execute on function public.house_league_tidy() to service_role;

-- Four calls every 15 seconds to the league function. It takes no key: all
-- it can do is play the league's moves when they're due.
create extension if not exists pg_net;
select cron.schedule(
  'house-league',
  '15 seconds',
  $$select net.http_post(
      url := 'https://atrgasakfnmixhictynh.supabase.co/functions/v1/house-league',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := '{}'::jsonb
    ) from generate_series(1, 4)$$
);
