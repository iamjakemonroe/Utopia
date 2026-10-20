-- Other players' holograms. On the rankings, a player's card opens their
-- rank hologram too: their record, streaks, best win, rival and the rest,
-- as their own shows them. Each player chooses (Settings > Account > Show
-- my stats; on unless turned off) whether others can see theirs.
--
--   * profiles.show_stats, readable by everyone (so the app knows whether
--     to offer the hologram) and set by its player (set_show_stats).
--   * get_rank_insights takes whose (p_user, the player themselves when
--     left out); for someone who hides their stats it answers only
--     {hidden: true}.

alter table public.profiles
  add column show_stats boolean not null default true;

comment on column public.profiles.show_stats is 'Whether other players can open this player''s rank hologram (their stats).';

grant select (show_stats) on public.profiles to anon, authenticated;

create function public.set_show_stats(p_show boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.profiles
     set show_stats = coalesce(p_show, true), updated_at = now()
   where id = auth.uid();
end;
$$;

revoke all on function public.set_show_stats(boolean) from public, anon;
grant execute on function public.set_show_stats(boolean) to authenticated;

drop function public.get_rank_insights(text);

create function public.get_rank_insights(p_game text, p_user uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := coalesce(p_user, auth.uid());
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
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  -- Someone else's: only if they show their stats.
  if v_me <> auth.uid() and not coalesce(
    (select show_stats from public.profiles where id = v_me), false
  ) then
    return jsonb_build_object('game', p_game, 'hidden', true);
  end if;
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

revoke all on function public.get_rank_insights(text, uuid) from public, anon;
grant execute on function public.get_rank_insights(text, uuid) to authenticated;
