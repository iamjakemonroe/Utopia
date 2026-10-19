-- A player's insights in a ranked game, for the hologram on the rankings
-- page: everything worth knowing from the games they've played, in one
-- call (only their own games are read).
--
--   * Record: rating, best and when they first reached it, games, wins,
--     losses, draws; the week's and month's rating moves, games this
--     week, the biggest climb and drop in one game; where they sit among
--     the real ranked players (top N%); their streak now and their best.
--   * Chess and checkers, from the rated matches: as white and as black,
--     how they win and how they lose, the average game length and their
--     fastest win, their usual clock, the average rating they play, their
--     best win (the highest rated player beaten), their rival (played the
--     most) and their nemesis (lost to the most).
--   * Guess My Doodle: a win is finishing first; its streak is games won
--     in a row.

/** [p_user]'s rated matches in [p_game] (chess or checkers), oldest first. */
create function public._rated_matches(p_user uuid, p_game text)
returns table (
  match_id   uuid,
  white      boolean,
  opponent   uuid,
  outcome    text,
  result     text,
  ply        int,
  clock      text,
  opp_rating int,
  ended      timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select m.id,
         m.player_white = p_user,
         case when m.player_white = p_user then m.player_black else m.player_white end,
         case when m.winner_id = p_user then 'W' when m.winner_id is null then 'D' else 'L' end,
         m.result,
         m.ply_count,
         (m.clock_initial_ms / 60000)::text || '+' || (m.clock_increment_ms / 1000)::text,
         oc.before,
         coalesce(m.ended_at, rc.created_at)
  from public.matches m
  join public.rating_changes rc on rc.match_id = m.id and rc.user_id = p_user
  left join public.rating_changes oc on oc.match_id = m.id and oc.user_id <> p_user
  where m.game::text = p_game and m.status = 'completed'
  order by coalesce(m.ended_at, rc.created_at);
$$;

/** How [p_user] appears in the insights. */
create function public._insight_person(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id, 'display_name', p.display_name, 'username', p.username,
    'avatar_url', p.avatar_url, 'avatar_kind', p.avatar_kind,
    'avatar_seed', p.avatar_seed,
    'house', exists (select 1 from public.house_players h where h.id = p.id)
  )
  from public.profiles p where p.id = p_user;
$$;

create function public.get_rank_insights(p_game text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_r public.player_ratings;
  v_out jsonb;
  v_part jsonb;
  v_ranked int;
  v_above int;
  v_run int := 0;
  v_run_kind text;
  v_best int := 0;
  v_win_run int := 0;
  v_outcome record;
  v_pick record;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_game not in ('chess', 'checkers', 'doodle') then raise exception 'unknown game'; end if;
  select * into v_r from public.player_ratings where user_id = v_me and game = p_game;

  v_out := jsonb_build_object(
    'game', p_game,
    'rating', coalesce(v_r.rating, 1000),
    'best', coalesce(v_r.best, 1000),
    'games', coalesce(v_r.games, 0),
    'wins', coalesce(v_r.wins, 0),
    'losses', coalesce(v_r.losses, 0),
    'draws', coalesce(v_r.draws, 0)
  );

  -- How the rating has moved.
  select jsonb_build_object(
      'week', coalesce(sum(after - before) filter (where created_at > now() - interval '7 days'), 0),
      'month', coalesce(sum(after - before) filter (where created_at > now() - interval '30 days'), 0),
      'games_week', count(*) filter (where created_at > now() - interval '7 days'),
      'biggest_gain', coalesce(max(after - before), 0),
      'biggest_drop', coalesce(min(after - before), 0),
      'peak_at', min(created_at) filter (where after = v_r.best),
      'since', min(created_at)
    )
    into v_part
    from public.rating_changes where user_id = v_me and game = p_game;
  v_out := v_out || v_part;

  -- Among the real ranked players.
  if coalesce(v_r.games, 0) >= 5 then
    select count(*), count(*) filter (where r.rating > v_r.rating)
      into v_ranked, v_above
      from public.player_ratings r
     where r.game = p_game and r.games >= 5
       and not exists (select 1 from public.house_players h where h.id = r.user_id);
    v_out := v_out || jsonb_build_object(
      'ranked', v_ranked,
      'top_percent', greatest(1, ceil(100.0 * (v_above + 1) / greatest(v_ranked, 1)))::int
    );
  end if;

  -- Streaks: games won in a row (doodle: finishing first, told by the
  -- rating going up), now and at best.
  for v_outcome in
    select o from (
      select case when after > before then 'W' else 'L' end as o, created_at as at
        from public.rating_changes
       where user_id = v_me and game = p_game and p_game = 'doodle'
      union all
      select outcome, ended from public._rated_matches(v_me, p_game) where p_game <> 'doodle'
    ) x order by at
  loop
    if v_outcome.o = v_run_kind then
      v_run := v_run + 1;
    else
      v_run_kind := v_outcome.o;
      v_run := 1;
    end if;
    if v_outcome.o = 'W' then
      v_win_run := v_win_run + 1;
      v_best := greatest(v_best, v_win_run);
    else
      v_win_run := 0;
    end if;
  end loop;
  v_out := v_out || jsonb_build_object(
    'streak', v_run, 'streak_kind', v_run_kind, 'best_streak', v_best
  );

  if p_game = 'doodle' then
    return v_out;
  end if;

  -- Chess and checkers, from the matches themselves.
  select jsonb_build_object(
      'white', jsonb_build_object('games', count(*) filter (where white),
                                  'wins', count(*) filter (where white and outcome = 'W')),
      'black', jsonb_build_object('games', count(*) filter (where not white),
                                  'wins', count(*) filter (where not white and outcome = 'W')),
      'avg_moves', round(avg(ply) / 2.0),
      'fastest_win', ceil(min(ply) filter (where outcome = 'W') / 2.0),
      'avg_opponent', round(avg(opp_rating)),
      'clock', mode() within group (order by clock)
    )
    into v_part
    from public._rated_matches(v_me, p_game);
  v_out := v_out || v_part;

  select coalesce(jsonb_object_agg(result, n), '{}'::jsonb) into v_part
    from (select coalesce(result, 'other') as result, count(*) n
            from public._rated_matches(v_me, p_game) where outcome = 'W' group by 1) w;
  v_out := v_out || jsonb_build_object('wins_by', v_part);
  select coalesce(jsonb_object_agg(result, n), '{}'::jsonb) into v_part
    from (select coalesce(result, 'other') as result, count(*) n
            from public._rated_matches(v_me, p_game) where outcome = 'L' group by 1) l;
  v_out := v_out || jsonb_build_object('losses_by', v_part);

  -- The best win: the highest rated player beaten.
  select opponent, opp_rating into v_pick
    from public._rated_matches(v_me, p_game)
   where outcome = 'W' and opp_rating is not null
   order by opp_rating desc, ended desc limit 1;
  if found then
    v_out := v_out || jsonb_build_object(
      'best_win', public._insight_person(v_pick.opponent) || jsonb_build_object('rating', v_pick.opp_rating)
    );
  end if;

  -- The rival: played the most (twice at least).
  select opponent, count(*) as g,
         count(*) filter (where outcome = 'W') as w,
         count(*) filter (where outcome = 'L') as l
    into v_pick
    from public._rated_matches(v_me, p_game)
   group by opponent having count(*) >= 2
   order by count(*) desc, max(ended) desc limit 1;
  if found then
    v_out := v_out || jsonb_build_object(
      'rival', public._insight_person(v_pick.opponent)
               || jsonb_build_object('games', v_pick.g, 'wins', v_pick.w, 'losses', v_pick.l)
    );
  end if;

  -- The nemesis: lost to the most (twice at least).
  select opponent, count(*) filter (where outcome = 'L') as l
    into v_pick
    from public._rated_matches(v_me, p_game)
   group by opponent having count(*) filter (where outcome = 'L') >= 2
   order by count(*) filter (where outcome = 'L') desc, max(ended) desc limit 1;
  if found then
    v_out := v_out || jsonb_build_object(
      'nemesis', public._insight_person(v_pick.opponent) || jsonb_build_object('losses', v_pick.l)
    );
  end if;

  return v_out;
end;
$$;

revoke all on function public._rated_matches(uuid, text) from public, anon, authenticated;
revoke all on function public._insight_person(uuid) from public, anon, authenticated;
revoke all on function public.get_rank_insights(text) from public, anon;
grant execute on function public.get_rank_insights(text) to authenticated;
