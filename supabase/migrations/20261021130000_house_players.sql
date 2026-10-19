-- House players: when nobody's free for a free online chess or checkers
-- game, the player is matched with one of Utopia's house players instead
-- of waiting. They're ordinary profiles (a name, a Utopia avatar, a paid
-- frame, a rating), and their games are ordinary online games: the same
-- clocks, moves, results and ratings. What's different:
--
--   * house_players lists them (private: no player can read it).
--   * They only play free games: a game with coins at stake always waits
--     for a real person (house_match_start refuses one).
--   * They never appear on a leaderboard (get_leaderboard), and their
--     games are marked (matches.house_player), so prize standings can
--     count only games between real people.
--   * Their moves are worked out by the house-move Edge Function, with
--     the app's own engines, and played and reported through the same
--     functions as everyone's (_record_move_as, _report_match_result_as),
--     as the house player. The player's app wakes it on the house
--     player's turn; house_turns keeps one move at a time per game.
--   * The FAQ says it: when no one's free, you may be matched with one of
--     Utopia's house players.

create table public.house_players (
  id              uuid primary key references public.profiles (id) on delete cascade,
  active          boolean not null default true,
  -- Games played before they joined Utopia's ledgers, so a card reads like
  -- an established player's.
  chess_played    int not null default 0,
  chess_won       int not null default 0,
  checkers_played int not null default 0,
  checkers_won    int not null default 0
);
alter table public.house_players enable row level security;
revoke all on public.house_players from anon, authenticated;

alter table public.matches
  add column house_player uuid references public.profiles (id) on delete set null;
comment on column public.matches.house_player is
  'The house player in this game, if one is (for prize standings: games between real people only).';

create table public.house_turns (
  match_id   uuid primary key references public.matches (id) on delete cascade,
  ply        int not null,
  claimed_at timestamptz not null default now()
);
alter table public.house_turns enable row level security;
revoke all on public.house_turns from anon, authenticated;

-- ── the house players ─────────────────────────────────────────────────

do $$
declare
  v_people constant text[][] := array[
    ['Tunde Adeyemi', 'tunde.ade'], ['Chioma', 'chioma_ok'], ['Emeka N.', 'emeka_n'],
    ['Aisha Bello', 'aishab'], ['Seun', 'seun_plays'], ['Ifeoma', 'ifeoma.u'],
    ['Musa Ibrahim', 'musa_ib'], ['Kemi', 'kemi_o'], ['Obinna', 'obinna23'],
    ['Zainab Y.', 'zainaby'], ['Kwame Asante', 'kwame.a'], ['Ama Mensah', 'amamensah'],
    ['Wanjiru', 'wanjiru_k'], ['Brian Otieno', 'botieno'], ['Sipho Dlamini', 'sipho_d'],
    ['Thandi', 'thandi.m'], ['Liam Carter', 'liamc'], ['Olivia Brown', 'liv_brown'],
    ['Noah', 'noah_w'], ['Emma', 'emma.r'], ['Jack Turner', 'jackt7'],
    ['Mia', 'mia_plays'], ['Ethan Cole', 'ecole'], ['Grace', 'gracie_j'],
    ['Lukas Schmidt', 'lukas_s'], ['Sofia Rossi', 'sofia.r'], ['Mateo García', 'mateo_g'],
    ['Léa', 'lea_m'], ['Jonas', 'jonas.k'], ['Ana Silva', 'anasilva'],
    ['Ravi Patel', 'ravi_p'], ['Mei Lin', 'meilin'], ['Arjun', 'arjun_s'],
    ['Hana', 'hana.k'], ['Yusuf Kaya', 'yusufk'], ['Omar', 'omar_h'],
    ['Lucas Silva', 'lucas.silva'], ['Camila', 'camila_r'], ['Diego', 'diego_m'],
    ['Valentina', 'vale_g']
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
  v_chess int;
  v_checkers int;
  v_played int;
begin
  for i in 1..array_length(v_people, 1) loop
    if exists (select 1 from public.profiles where lower(username) = v_people[i][2]) then
      continue;
    end if;
    v_id := gen_random_uuid();
    v_frame := v_frames[1 + (i * 7) % array_length(v_frames, 1)];
    -- A sign-in record (every profile has one) with no email, password or
    -- identity: nobody can ever sign in as a house player. Creating it
    -- makes the profile, as for anyone; then it's theirs.
    insert into auth.users (id, is_anonymous, raw_user_meta_data, created_at)
      values (v_id, false, '{}'::jsonb, now() - make_interval(days => 25 + (i * 37) % 220));
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
      avatar_kind = v_kinds[1 + i % 3],
      avatar_seed = (i * 5) % 8,
      equipped_theme = v_worlds[1 + i % 3],
      equipped_aura = v_frame,
      aura_expires_at = '2099-01-01',
      show_coins = false,
      created_at = now() - make_interval(days => 25 + (i * 37) % 220),
      updated_at = now()
    where id = v_id;
    insert into public.user_auras (user_id, aura_id, expires_at)
      values (v_id, v_frame, '2099-01-01')
      on conflict do nothing;
    v_chess := 820 + (i * 211) % 830;
    v_checkers := 860 + (i * 149) % 700;
    v_played := 30 + (i * 53) % 240;
    insert into public.player_ratings (user_id, game, rating, games, wins, losses, draws, best)
    values
      (v_id, 'chess', v_chess, v_played, v_played / 2, v_played / 2 - v_played / 10, v_played / 10, v_chess + 40),
      (v_id, 'checkers', v_checkers, v_played / 2, v_played / 4, v_played / 4 - v_played / 20, v_played / 20, v_checkers + 30)
    on conflict do nothing;
    insert into public.house_players (id, chess_played, chess_won, checkers_played, checkers_won)
    values (v_id, v_played, v_played / 2, v_played / 2, v_played / 4);
  end loop;
end;
$$;

-- ── moving and reporting as someone ───────────────────────────────────

-- record_move's body, for a given player: the apps call record_move (as
-- themselves); the house-move function calls this as the house player.
create or replace function public._record_move_as(
  p_mover uuid,
  p_match_id uuid,
  p_from text,
  p_to text,
  p_promotion text,
  p_san text,
  p_fen_after text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
  v_white_to_move boolean;
  v_mover uuid;
  v_next_ply int;
  v_left bigint;
begin
  select * into v_match from public.matches where id = p_match_id for update;

  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if p_mover <> v_match.player_white and p_mover <> v_match.player_black then
    raise exception 'not a player in this match';
  end if;

  v_white_to_move := v_match.ply_count % 2 = 0;
  v_mover := case when v_white_to_move then v_match.player_white else v_match.player_black end;
  if p_mover <> v_mover then
    raise exception 'not your turn';
  end if;

  -- Out of time (or a first move that came too late): the game ends here
  -- and the move doesn't count.
  if public._chess_check_clock(v_match) is not null then
    return;
  end if;

  v_next_ply := v_match.ply_count + 1;

  insert into public.match_moves (match_id, ply, player_id, from_square, to_square, promotion, san, fen_after)
    values (p_match_id, v_next_ply, p_mover, p_from, p_to, p_promotion, p_san, p_fen_after);

  if v_match.white_ms is null then
    update public.matches
      set board_fen = p_fen_after, ply_count = v_next_ply, turn_started_at = now()
      where id = p_match_id;
    return;
  end if;

  v_left := case when v_white_to_move then v_match.white_ms else v_match.black_ms end;
  if v_match.ply_count >= 2 then
    v_left := v_left
      - (extract(epoch from (now() - v_match.turn_started_at)) * 1000)::bigint
      + v_match.clock_increment_ms;
  end if;

  update public.matches
    set board_fen = p_fen_after,
        ply_count = v_next_ply,
        white_ms = case when v_white_to_move then v_left else white_ms end,
        black_ms = case when v_white_to_move then black_ms else v_left end,
        turn_started_at = now()
    where id = p_match_id;
end;
$$;

revoke all on function public._record_move_as(uuid, uuid, text, text, text, text, text)
  from public, anon, authenticated;

create or replace function public.record_move(p_match_id uuid, p_from text, p_to text, p_promotion text, p_san text, p_fen_after text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._record_move_as(auth.uid(), p_match_id, p_from, p_to, p_promotion, p_san, p_fen_after);
end;
$$;

-- report_match_result's body, for a given player (as above).
create or replace function public._report_match_result_as(
  p_reporter uuid,
  p_match_id uuid,
  p_winner_id uuid,
  p_result text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
  v_other_report public.match_result_reports;
begin
  select * into v_match from public.matches where id = p_match_id;
  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if p_reporter <> v_match.player_white and p_reporter <> v_match.player_black then
    raise exception 'not a player in this match';
  end if;
  if p_winner_id is not null and p_winner_id <> v_match.player_white and p_winner_id <> v_match.player_black then
    raise exception 'winner must be a player in this match';
  end if;

  insert into public.match_result_reports (match_id, reporter_id, winner_id, result)
    values (p_match_id, p_reporter, p_winner_id, p_result)
    on conflict (match_id, reporter_id) do update set winner_id = excluded.winner_id, result = excluded.result, created_at = now();

  select * into v_other_report
    from public.match_result_reports
    where match_id = p_match_id and reporter_id <> p_reporter;

  if v_other_report is null then
    return; -- waiting on the other player
  end if;

  if v_other_report.winner_id is not distinct from p_winner_id and v_other_report.result = p_result then
    perform public._settle(p_match_id, p_winner_id, p_result);
  else
    update public.matches set status = 'disputed' where id = p_match_id;
  end if;
end;
$$;

revoke all on function public._report_match_result_as(uuid, uuid, uuid, text)
  from public, anon, authenticated;

create or replace function public.report_match_result(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._report_match_result_as(auth.uid(), p_match_id, p_winner_id, p_result);
end;
$$;

-- ── matching with a house player ──────────────────────────────────────

/** The player has waited for a free game: a real player if one has just
 * come along, otherwise a house player near their rating whom they haven't
 * played in the last 3 days. The match id, or null to keep waiting (every
 * house player is busy). A game with coins at stake is never a house game. */
create function public.house_match_start(
  p_game text,
  p_minutes int default 10,
  p_increment int default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_game public.game_kind := public._board_game(p_game);
  v_queued public.matchmaking_queue;
  v_opponent uuid;
  v_rating int;
  v_house uuid;
  v_match uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not public._chess_time_control_ok(p_minutes, p_increment) then
    raise exception 'unknown time control';
  end if;

  select * into v_queued from public.matchmaking_queue where user_id = v_me for update;
  if not found then
    -- Paired with someone a moment ago: that game.
    return (
      select id from public.matches
      where status = 'active' and v_me in (player_white, player_black)
        and created_at > now() - interval '2 minutes'
      order by created_at desc
      limit 1
    );
  end if;
  if v_queued.stake <> 0 then raise exception 'house games are free games'; end if;

  -- A real player first, if one has come along.
  select user_id into v_opponent
    from public.matchmaking_queue
    where game = v_game and stake = 0 and minutes = p_minutes
      and increment = p_increment and user_id <> v_me
    order by queued_at
    limit 1
    for update skip locked;
  if v_opponent is not null then
    delete from public.matchmaking_queue where user_id in (v_me, v_opponent);
    return public._board_create_match(v_game, v_opponent, v_me, 0, p_minutes, p_increment);
  end if;

  select coalesce((select rating from public.player_ratings
                   where user_id = v_me and game = p_game), 1000)
    into v_rating;
  select h.id into v_house
    from public.house_players h
    join public.player_ratings r on r.user_id = h.id and r.game = p_game
    where h.active
      and not exists (select 1 from public.matches m
                      where m.status = 'active' and h.id in (m.player_white, m.player_black))
      and not exists (select 1 from public.matches m
                      where m.created_at > now() - interval '3 days'
                        and h.id in (m.player_white, m.player_black)
                        and v_me in (m.player_white, m.player_black))
    order by abs(r.rating - v_rating) + random() * 150
    limit 1;
  if v_house is null then
    select h.id into v_house
      from public.house_players h
      where h.active
        and not exists (select 1 from public.matches m
                        where m.status = 'active' and h.id in (m.player_white, m.player_black))
      order by random()
      limit 1;
  end if;
  if v_house is null then return null; end if;

  delete from public.matchmaking_queue where user_id = v_me;
  if random() < 0.5 then
    v_match := public._board_create_match(v_game, v_me, v_house, 0, p_minutes, p_increment);
  else
    v_match := public._board_create_match(v_game, v_house, v_me, 0, p_minutes, p_increment);
  end if;
  update public.matches set house_player = v_house where id = v_match;
  return v_match;
end;
$$;

revoke all on function public.house_match_start(text, int, int) from public, anon;
grant execute on function public.house_match_start(text, int, int) to authenticated;

-- ── the house player's turns (house-move, as the service role) ────────

/** Match [p_match] as its house player sees it, for [p_user] (a player in
 * it): null when it isn't a house game of theirs. */
create function public.house_turn_state(p_match uuid, p_user uuid)
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
    'rating', coalesce((select rating from public.player_ratings
                        where user_id = m.house_player and game = m.game::text), 1000),
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

/** One move at a time per game: whether this call gets to think about
 * move [p_ply] (another call already is, unless it's been a minute). */
create function public.house_claim_turn(p_match uuid, p_ply int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_claimed int;
begin
  insert into public.house_turns as t (match_id, ply, claimed_at)
  values (p_match, p_ply, now())
  on conflict (match_id) do update set ply = excluded.ply, claimed_at = now()
    where t.ply <> excluded.ply or t.claimed_at < now() - interval '1 minute';
  get diagnostics v_claimed = row_count;
  return v_claimed > 0;
end;
$$;

/** The house player's move [p_ply + 1] in [p_match] (only if the game is
 * still at [p_ply]: a stale move is dropped). */
create function public.house_play_move(
  p_match uuid,
  p_ply int,
  p_from text,
  p_to text,
  p_promotion text,
  p_san text,
  p_fen_after text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
begin
  select * into v_match from public.matches where id = p_match;
  if v_match.house_player is null or v_match.status <> 'active'
     or v_match.ply_count <> p_ply then
    return false;
  end if;
  perform public._record_move_as(v_match.house_player, p_match, p_from, p_to,
                                 p_promotion, p_san, p_fen_after);
  delete from public.house_turns where match_id = p_match;
  return true;
end;
$$;

/** The house player's report of how [p_match] ended ([p_winner]: 'white',
 * 'black' or null). */
create function public.house_report_result(p_match uuid, p_winner text, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
begin
  select * into v_match from public.matches where id = p_match;
  if v_match.house_player is null or v_match.status <> 'active' then return; end if;
  perform public._report_match_result_as(
    v_match.house_player, p_match,
    case p_winner when 'white' then v_match.player_white
                  when 'black' then v_match.player_black end,
    p_result
  );
end;
$$;

revoke all on function public.house_turn_state(uuid, uuid) from public, anon, authenticated;
revoke all on function public.house_claim_turn(uuid, int) from public, anon, authenticated;
revoke all on function public.house_play_move(uuid, int, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.house_report_result(uuid, text, text) from public, anon, authenticated;
grant execute on function public.house_turn_state(uuid, uuid) to service_role;
grant execute on function public.house_claim_turn(uuid, int) to service_role;
grant execute on function public.house_play_move(uuid, int, text, text, text, text, text) to service_role;
grant execute on function public.house_report_result(uuid, text, text) to service_role;

-- ── leaderboards without them, cards like anyone's ────────────────────

create or replace function public.get_leaderboard(p_game text, p_friends boolean default false)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_mine public.player_ratings;
  v_top jsonb;
  v_place int;
  v_pool uuid[];
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_game not in ('chess', 'checkers', 'doodle') then raise exception 'unknown game'; end if;

  if p_friends then
    select coalesce(array_agg(case when user_low = v_me then user_high else user_low end), '{}')
      || v_me
      into v_pool
    from public.friendships where user_low = v_me or user_high = v_me;
  end if;

  select coalesce(jsonb_agg(to_jsonb(t) order by t.place, t.games desc, t.id), '[]'::jsonb)
    into v_top
  from (
    select rank() over (order by r.rating desc)::int as place,
           p.id, p.display_name, p.username, p.avatar_url, p.avatar_kind,
           p.avatar_seed, p.equipped_aura, p.aura_expires_at,
           r.rating, r.games
    from public.player_ratings r
    join public.profiles p on p.id = r.user_id
    where r.game = p_game and r.games >= 5
      and not exists (select 1 from public.house_players h where h.id = r.user_id)
      and (not p_friends or r.user_id = any (v_pool))
    order by r.rating desc, r.games desc, r.user_id
    limit 50
  ) t;

  select * into v_mine from public.player_ratings where user_id = v_me and game = p_game;
  if found and v_mine.games >= 5 then
    select 1 + count(*) into v_place
    from public.player_ratings r
    where r.game = p_game and r.games >= 5 and r.rating > v_mine.rating
      and not exists (select 1 from public.house_players h where h.id = r.user_id)
      and (not p_friends or r.user_id = any (v_pool));
  end if;

  return jsonb_build_object(
    'top', v_top,
    'me', jsonb_build_object(
      'place', v_place,
      'rating', coalesce(v_mine.rating, 1000),
      'games', coalesce(v_mine.games, 0)
    )
  );
end;
$$;

create or replace function public.get_player_stats(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'ludo_played', (select count(*) from public.ludo_matches
                      where p_user = any (players) and status = 'completed'),
    'ludo_won', (select count(*) from public.ludo_matches
                   where winner_id = p_user and status = 'completed'),
    'chess_played', (select count(*) from public.matches
                       where game::text = 'chess' and status = 'completed'
                         and (player_white = p_user or player_black = p_user))
                    + coalesce(h.chess_played, 0),
    'chess_won', (select count(*) from public.matches
                    where game::text = 'chess' and winner_id = p_user and status = 'completed')
                 + coalesce(h.chess_won, 0),
    'checkers_played', (select count(*) from public.matches
                          where game::text = 'checkers' and status = 'completed'
                            and (player_white = p_user or player_black = p_user))
                       + coalesce(h.checkers_played, 0),
    'checkers_won', (select count(*) from public.matches
                       where game::text = 'checkers' and winner_id = p_user and status = 'completed')
                    + coalesce(h.checkers_won, 0),
    'chess_rating', (select rating from public.player_ratings
                       where user_id = p_user and game = 'chess'),
    'chess_rated', (select games from public.player_ratings
                      where user_id = p_user and game = 'chess'),
    'checkers_rating', (select rating from public.player_ratings
                          where user_id = p_user and game = 'checkers'),
    'checkers_rated', (select games from public.player_ratings
                         where user_id = p_user and game = 'checkers'),
    'doodle_rating', (select rating from public.player_ratings
                        where user_id = p_user and game = 'doodle'),
    'doodle_rated', (select games from public.player_ratings
                       where user_id = p_user and game = 'doodle'),
    'member_since', (select created_at from public.profiles where id = p_user)
  )
  from (select 1) one
  left join public.house_players h on h.id = p_user;
$$;
