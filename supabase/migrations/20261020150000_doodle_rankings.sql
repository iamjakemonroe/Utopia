-- Rankings for Guess My Doodle.
--
--   * When a public game is played to the end (every round), each player
--     still there is rated against every other by final score: Elo over
--     every pair, so beating stronger players earns more. Same K as chess
--     and checkers (40 for the first 20 games, then 20), never below 100.
--   * A win is finishing first (sharing first counts, as long as someone
--     scored); anything else is a loss.
--   * Only public games: a private room of friends could hand each other
--     points. A public room's next game (it restarts) is rated on its own.
--   * The same board and tiers: get_leaderboard('doodle'), and
--     get_player_stats carries doodle_rating.
--   * rating_changes now holds doodle games too, so its match id no longer
--     points at matches.

alter table public.player_ratings drop constraint player_ratings_game_check;
alter table public.player_ratings add constraint player_ratings_game_check
  check (game in ('chess', 'checkers', 'doodle'));

alter table public.rating_changes drop constraint rating_changes_match_id_fkey;
comment on column public.rating_changes.match_id is 'The rated game: a match (chess, checkers), or for doodle, md5(doodle game id || '':'' || its turn) as a uuid (a public room plays many games).';

/** Rates a doodle game as it ends (see the header). */
create function public._rate_doodle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game_key uuid := md5(new.id::text || ':' || new.turn)::uuid;
  v_n int;
  v_top int;
  v_me record;
  v_other record;
  v_expect numeric;
  v_score numeric;
  v_new int;
begin
  if not new.is_public or new.round < new.rounds then return null; end if;
  select count(*), max(score) into v_n, v_top from public.doodle_players
    where game_id = new.id and left_at is null;
  if v_n < 2 then return null; end if;

  insert into public.player_ratings (user_id, game)
    select user_id, 'doodle' from public.doodle_players
    where game_id = new.id and left_at is null
    on conflict do nothing;
  perform 1 from public.player_ratings
    where game = 'doodle' and user_id in (
      select user_id from public.doodle_players where game_id = new.id and left_at is null)
    order by user_id for update;

  -- Everyone's new rating from the ratings before this game.
  create temp table _doodle_rated (user_id uuid primary key, before int, after int, won boolean)
    on commit drop;
  for v_me in
    select dp.user_id, dp.score, r.rating, r.games
    from public.doodle_players dp
    join public.player_ratings r on r.user_id = dp.user_id and r.game = 'doodle'
    where dp.game_id = new.id and dp.left_at is null
  loop
    v_expect := 0;
    v_score := 0;
    for v_other in
      select dp.score, r.rating
      from public.doodle_players dp
      join public.player_ratings r on r.user_id = dp.user_id and r.game = 'doodle'
      where dp.game_id = new.id and dp.left_at is null and dp.user_id <> v_me.user_id
    loop
      v_expect := v_expect + 1 / (1 + power(10::numeric, (v_other.rating - v_me.rating) / 400.0));
      v_score := v_score + case when v_me.score > v_other.score then 1
                                when v_me.score = v_other.score then 0.5 else 0 end;
    end loop;
    v_new := greatest(100, round(v_me.rating
      + (case when v_me.games < 20 then 40 else 20 end) * (v_score - v_expect) / (v_n - 1)));
    insert into _doodle_rated values (v_me.user_id, v_me.rating, v_new, v_top > 0 and v_me.score = v_top);
  end loop;

  update public.player_ratings r
     set rating = d.after, games = r.games + 1, best = greatest(r.best, d.after),
         wins = r.wins + d.won::int,
         losses = r.losses + (not d.won)::int,
         updated_at = now()
    from _doodle_rated d
   where r.user_id = d.user_id and r.game = 'doodle';
  insert into public.rating_changes (match_id, user_id, game, before, after)
    select v_game_key, user_id, 'doodle', before, after from _doodle_rated
    on conflict do nothing;
  drop table _doodle_rated;
  return null;
end;
$$;

revoke all on function public._rate_doodle() from public, anon, authenticated;

create trigger doodle_games_rate
  after update of status on public.doodle_games
  for each row
  when (new.status = 'over' and old.status is distinct from 'over')
  execute function public._rate_doodle();

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
      and (not p_friends or r.user_id = any (v_pool))
    order by r.rating desc, r.games desc, r.user_id
    limit 50
  ) t;

  select * into v_mine from public.player_ratings where user_id = v_me and game = p_game;
  if found and v_mine.games >= 5 then
    select 1 + count(*) into v_place
    from public.player_ratings r
    where r.game = p_game and r.games >= 5 and r.rating > v_mine.rating
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
                         and (player_white = p_user or player_black = p_user)),
    'chess_won', (select count(*) from public.matches
                    where game::text = 'chess' and winner_id = p_user and status = 'completed'),
    'checkers_played', (select count(*) from public.matches
                          where game::text = 'checkers' and status = 'completed'
                            and (player_white = p_user or player_black = p_user)),
    'checkers_won', (select count(*) from public.matches
                       where game::text = 'checkers' and winner_id = p_user and status = 'completed'),
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
  );
$$;

