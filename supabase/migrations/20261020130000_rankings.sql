-- Rankings: a skill rating for online chess and checkers.
--
--   * Everyone starts at 1000 in each game. When an online game finishes
--     (both players moved; not called off or disputed), both ratings move
--     by Elo: beating a stronger player gains more, losing to a weaker one
--     costs more. New players move faster for their first 20 games (K 40,
--     then 20). Never below 100.
--   * The same two players count at most 3 rated games a day (in each game)
--     against each other, so friends can't push each other up the board.
--   * get_leaderboard: the top 50 in a game, everyone or friends only, and
--     where the player stands. Players are ranked after 5 rated games.
--   * get_player_stats adds each game's rating; rating_changes keeps each
--     match's change, so the result card can show "+12".
--   * Deleting an account deletes its ratings.

create table public.player_ratings (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  game       text not null check (game in ('chess', 'checkers')),
  rating     int not null default 1000,
  games      int not null default 0,
  wins       int not null default 0,
  losses     int not null default 0,
  draws      int not null default 0,
  best       int not null default 1000,
  updated_at timestamptz not null default now(),
  primary key (user_id, game)
);

create index player_ratings_board_idx on public.player_ratings (game, rating desc);

comment on table public.player_ratings is 'Each player''s Elo rating per board game. Written only by _rate_match when a match completes.';

alter table public.player_ratings enable row level security;
revoke insert, update, delete on public.player_ratings from anon, authenticated;
create policy "ratings are public" on public.player_ratings
  for select to authenticated using (true);

create table public.rating_changes (
  match_id   uuid not null references public.matches (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  game       text not null,
  before     int not null,
  after      int not null,
  created_at timestamptz not null default now(),
  primary key (match_id, user_id)
);

create index rating_changes_user_idx on public.rating_changes (user_id, created_at desc);

alter table public.rating_changes enable row level security;
revoke insert, update, delete on public.rating_changes from anon, authenticated;
create policy "select own rating changes" on public.rating_changes
  for select to authenticated using (user_id = auth.uid());

/** Rates a match as it completes (see the header). */
create function public._rate_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game text := new.game::text;
  v_w public.player_ratings;
  v_b public.player_ratings;
  v_score numeric;   -- white's: 1, 0.5 or 0
  v_expect numeric;  -- white's expected score
  v_new_w int;
  v_new_b int;
begin
  if v_game not in ('chess', 'checkers') or new.player_black is null
     or new.player_white = new.player_black
     or coalesce(new.result, '') in ('aborted', 'disputed') or new.ply_count < 2 then
    return null;
  end if;
  if (select count(*) from public.rating_changes c
        join public.matches m on m.id = c.match_id
      where c.user_id = new.player_white and c.game = v_game
        and new.player_black in (m.player_white, m.player_black)
        and c.created_at > now() - interval '1 day') >= 3 then
    return null;
  end if;

  insert into public.player_ratings (user_id, game)
    values (new.player_white, v_game), (new.player_black, v_game)
    on conflict do nothing;
  -- Lock both in a fixed order, so two games finishing at once can't
  -- deadlock.
  perform 1 from public.player_ratings
    where game = v_game and user_id in (new.player_white, new.player_black)
    order by user_id for update;
  select * into v_w from public.player_ratings where user_id = new.player_white and game = v_game;
  select * into v_b from public.player_ratings where user_id = new.player_black and game = v_game;

  v_score := case when new.winner_id is null then 0.5
                  when new.winner_id = new.player_white then 1 else 0 end;
  v_expect := 1 / (1 + power(10::numeric, (v_b.rating - v_w.rating) / 400.0));
  v_new_w := greatest(100, round(v_w.rating
    + (case when v_w.games < 20 then 40 else 20 end) * (v_score - v_expect)));
  v_new_b := greatest(100, round(v_b.rating
    + (case when v_b.games < 20 then 40 else 20 end) * (v_expect - v_score)));

  update public.player_ratings
     set rating = v_new_w, games = games + 1, best = greatest(best, v_new_w),
         wins = wins + (v_score = 1)::int, losses = losses + (v_score = 0)::int,
         draws = draws + (v_score = 0.5)::int, updated_at = now()
   where user_id = new.player_white and game = v_game;
  update public.player_ratings
     set rating = v_new_b, games = games + 1, best = greatest(best, v_new_b),
         wins = wins + (v_score = 0)::int, losses = losses + (v_score = 1)::int,
         draws = draws + (v_score = 0.5)::int, updated_at = now()
   where user_id = new.player_black and game = v_game;

  insert into public.rating_changes (match_id, user_id, game, before, after)
    values (new.id, new.player_white, v_game, v_w.rating, v_new_w),
           (new.id, new.player_black, v_game, v_b.rating, v_new_b)
    on conflict do nothing;
  return null;
end;
$$;

revoke all on function public._rate_match() from public, anon, authenticated;

create trigger matches_rate
  after update of status on public.matches
  for each row
  when (new.status = 'completed' and old.status is distinct from 'completed')
  execute function public._rate_match();

/**
 * The [p_game] board: the top 50 (everyone, or the player and their
 * friends), and the player's own place, rating and rated games.
 */
create function public.get_leaderboard(p_game text, p_friends boolean default false)
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
  if p_game not in ('chess', 'checkers') then raise exception 'unknown game'; end if;

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

revoke all on function public.get_leaderboard(text, boolean) from public;
grant execute on function public.get_leaderboard(text, boolean) to authenticated;

-- Stats as before, with each game's rating (null until they've played a
-- rated game).
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
    'member_since', (select created_at from public.profiles where id = p_user)
  );
$$;

-- Account deletion as before, and the ratings go too.
create or replace function public.anonymize_account(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set display_name = 'Deleted player',
         username = null,
         avatar_url = null,
         avatar_kind = null,
         avatar_seed = null,
         equipped_aura = null,
         aura_expires_at = null,
         show_coins = false,
         updated_at = now()
   where id = p_user;

  delete from public.friendships where user_low = p_user or user_high = p_user;
  delete from public.friend_requests where from_user = p_user or to_user = p_user;
  delete from public.match_invites
   where (from_user = p_user or to_user = p_user) and match_id is null;
  delete from public.matchmaking_queue where user_id = p_user;
  delete from public.ludo_matchmaking_queue where user_id = p_user;
  delete from public.ludo_room_members where user_id = p_user;
  delete from public.chess_presence where user_id = p_user;
  delete from public.chess_chat_messages where sender_id = p_user;
  delete from public.ludo_chat_messages where sender_id = p_user;
  delete from public.notifications where user_id = p_user or actor_id = p_user;
  delete from public.chip_usage where user_id = p_user;
  update public.bug_reports set user_id = null, contact = null where user_id = p_user;
  -- Everything personal that came later.
  delete from public.chip_memories where user_id = p_user;
  delete from public.user_birthdays where user_id = p_user;
  delete from public.app_events where user_id = p_user;
  delete from public.doodle_messages where sender_id = p_user;
  delete from public.doodle_guesses where user_id = p_user;
  delete from public.coloring_asks where user_id = p_user;
  delete from public.player_ratings where user_id = p_user;
  delete from public.rating_changes where user_id = p_user;
end;
$$;

revoke all on function public.anonymize_account(uuid) from public, anon, authenticated;
grant execute on function public.anonymize_account(uuid) to service_role;
