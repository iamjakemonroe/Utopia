-- Gives one player (a test account) a Legend rating in chess or checkers
-- with the history to match, so every number on the rankings page and in
-- the hologram adds up: rating, best, games, wins, losses and draws, the
-- week's and month's moves, streaks, white and black, how they won and
-- lost, the fastest win, the usual clock, best win, rival and nemesis.
--
-- It plays it out: a climb from 1000 over v_days, against the house
-- players, game by game, rated the way the app rates a finished match
-- (K 40 for the first 20 games, then 20), until they pass v_target. The
-- games are real completed matches (no coins at stake), so their profile's
-- game history shows them too.
--
--   * Their rating history in that game is replaced by this one (it's for
--     test accounts: their real rated games there stop counting).
--   * The house players' ratings on the leaderboard aren't touched.
--   * Running it again gives the same history again (nothing doubles).
--   * They'll show on the leaderboard in that game, at the top.
--   * take_legend.sql takes it back.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the player's
-- username, user ID or email below, then Run. Reopen the rankings page.
do $$
declare
  v_who text := 'their_username';  -- <- username, user ID or email
  v_game text := 'chess';          -- chess or checkers
  v_target int := 1850;            -- the rating to pass (Legend is 1700 up)
  v_days int := 75;                -- how far back the climb starts
  v_user uuid;
  v_opp uuid[];
  v_opp_rating int[];
  v_opp_games int[];
  v_rival int;
  v_nemesis int;
  -- The games, as they're played out.
  v_pick int[] := '{}';
  v_score numeric[] := '{}';
  v_before int[] := '{}';
  v_after int[] := '{}';
  v_opp_after int[] := '{}';
  v_r int := 1000;
  v_n int := 0;
  v_k int;
  v_i int;
  v_o int;
  v_e numeric;
  v_s numeric;
  v_p numeric;
  v_finish text[] := '{L,W,W,W,W}';  -- once past the target
  v_extra int := 0;
  v_step interval;
  v_end timestamptz;
  v_ply int;
  v_result text;
  v_clock int;
  v_inc int;
  v_white boolean;
  v_id uuid;
  v_won int;
  v_lost int;
  v_drawn int;
begin
  if v_game not in ('chess', 'checkers') then
    raise exception 'v_game is chess or checkers (not "%")', v_game;
  end if;
  v_who := trim(v_who);
  if v_who ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_user := v_who::uuid;
  elsif v_who ~ '^[^@\s]+@[^@\s]+$' then
    select id into v_user from auth.users where lower(email) = lower(v_who);
  else
    select id into v_user from public.profiles where lower(username) = lower(ltrim(v_who, '@'));
  end if;
  perform 1 from auth.users where id = v_user;
  if not found then
    raise exception 'No account matches "%"', v_who;
  end if;
  if exists (select 1 from public.house_players where id = v_user) then
    raise exception '"%" is a house player', v_who;
  end if;

  -- The opponents: the house players, weakest to strongest. The rival is
  -- met most; the nemesis (the strongest) wins most against them.
  select array_agg(r.user_id order by r.rating), array_agg(r.rating order by r.rating),
         array_agg(r.games order by r.rating)
    into v_opp, v_opp_rating, v_opp_games
    from public.player_ratings r
    join public.house_players h on h.id = r.user_id
   where r.game = v_game;
  if coalesce(cardinality(v_opp), 0) < 5 then
    raise exception 'Not enough house players rated in % to play against', v_game;
  end if;
  v_nemesis := cardinality(v_opp);
  v_rival := cardinality(v_opp) - 2;
  -- Far above the strongest of them, the climb would take forever (each
  -- win's worth little): no more than 250 over.
  v_target := least(v_target, v_opp_rating[v_nemesis] + 250);

  -- The same climb every time it's run.
  perform setseed(0.37);
  loop
    v_n := v_n + 1;
    -- Who: the rival now and then; otherwise someone near their level
    -- (up to 300 below, 150 above), or the strongest few once they're
    -- past everyone.
    v_p := random();
    if v_p < 0.12 then
      v_o := v_rival;
    elsif v_p < 0.18 and v_n > 40 then
      v_o := v_nemesis;
    else
      select i into v_o from generate_subscripts(v_opp_rating, 1) i
       where v_opp_rating[i] between v_r - 300 and v_r + 150
       order by random() limit 1;
      if v_o is null then
        v_o := cardinality(v_opp) - floor(random() * 5)::int;
      end if;
    end if;
    v_e := 1 / (1 + power(10::numeric, (v_opp_rating[v_o] - v_r) / 400.0));
    if v_r >= v_target or v_extra > 0 or (v_n >= 400 and v_r >= 1730) then
      -- Past it: a loss, then four wins to finish on a streak.
      v_extra := v_extra + 1;
      v_s := case v_finish[v_extra] when 'W' then 1 else 0 end;
    else
      -- Better than the odds say: they're a Legend. More so against the
      -- rival (met most), far less against the nemesis (lost to most).
      v_p := least(0.93, v_e + 0.22)
             + case when v_o = v_rival then 0.05 when v_o = v_nemesis then -0.4 else 0 end;
      v_s := case when random() < 0.06 then 0.5
                  when random() < v_p then 1 else 0 end;
    end if;
    v_k := case when v_n <= 20 then 40 else 20 end;
    v_pick := v_pick || v_o;
    v_score := v_score || v_s;
    v_before := v_before || v_r;
    v_r := greatest(100, round(v_r + v_k * (v_s - v_e)));
    v_after := v_after || v_r;
    v_opp_after := v_opp_after || greatest(100, round(v_opp_rating[v_o]
      + (case when v_opp_games[v_o] < 20 then 40 else 20 end) * ((1 - v_s) - (1 - v_e))))::int;
    v_o := null;
    exit when v_extra >= cardinality(v_finish) or v_n >= 600;
  end loop;

  -- Out with the old: what this made before (its games and both sides'
  -- ratings in them; rating changes aren't tied to matches, since Guess My
  -- Doodle's games aren't matches), and their rating history.
  delete from public.rating_changes
   where match_id in (select md5('give_legend:' || v_user || ':' || v_game || ':' || g)::uuid
                        from generate_series(1, 600) g);
  delete from public.matches
   where id in (select md5('give_legend:' || v_user || ':' || v_game || ':' || g)::uuid
                  from generate_series(1, 600) g);
  delete from public.rating_changes where user_id = v_user and game = v_game;

  -- The games, spread over the days (each in its own slot, the last a
  -- few hours ago).
  v_step := (make_interval(days => v_days) - interval '3 hours') / v_n;
  for v_i in 1 .. v_n loop
    v_o := v_pick[v_i];
    v_s := v_score[v_i];
    v_end := now() - make_interval(days => v_days) + v_step * (v_i - 1 + 0.2 + 0.6 * random());
    v_white := random() < 0.5;
    v_result := case
      when v_s = 0.5 then case when v_game = 'chess' and random() < 0.2 then 'stalemate' else 'draw' end
      when v_game = 'checkers' then (array['win', 'win', 'win', 'resignation', 'resignation', 'timeout'])[1 + floor(random() * 6)::int]
      else (array['checkmate', 'checkmate', 'checkmate', 'resignation', 'resignation', 'timeout'])[1 + floor(random() * 6)::int]
    end;
    v_ply := case v_result
      when 'checkmate' then 22 + floor(random() * 70)::int
      when 'win' then 30 + floor(random() * 60)::int
      when 'resignation' then 36 + floor(random() * 60)::int
      when 'timeout' then 60 + floor(random() * 70)::int
      else 80 + floor(random() * 60)::int
    end;
    v_clock := (array[300000, 300000, 300000, 300000, 300000, 300000, 300000, 600000, 600000, 180000])[1 + floor(random() * 10)::int];
    v_inc := case v_clock when 300000 then 3000 when 180000 then 2000 else 0 end;
    v_id := md5('give_legend:' || v_user || ':' || v_game || ':' || v_i)::uuid;
    insert into public.matches (id, game, status, stake, commission_bps,
                                player_white, player_black, ply_count, winner_id, result,
                                created_at, started_at, ended_at,
                                clock_initial_ms, clock_increment_ms, house_player)
    values (v_id, v_game::public.game_kind, 'completed', 0, 0,
            case when v_white then v_user else v_opp[v_o] end,
            case when v_white then v_opp[v_o] else v_user end,
            v_ply,
            case v_s when 1 then v_user when 0 then v_opp[v_o] end,
            v_result,
            v_end - make_interval(secs => v_ply * 9), v_end - make_interval(secs => v_ply * 9), v_end,
            v_clock, v_inc, v_opp[v_o]);
    insert into public.rating_changes (match_id, user_id, game, before, after, created_at)
    values (v_id, v_user, v_game, v_before[v_i], v_after[v_i], v_end),
           (v_id, v_opp[v_o], v_game, v_opp_rating[v_o], v_opp_after[v_i], v_end);
  end loop;

  select count(*) filter (where s = 1), count(*) filter (where s = 0), count(*) filter (where s = 0.5)
    into v_won, v_lost, v_drawn
    from unnest(v_score) s;
  insert into public.player_ratings (user_id, game, rating, games, wins, losses, draws, best, updated_at)
  values (v_user, v_game, v_r, v_n, v_won, v_lost, v_drawn,
          (select max(a) from unnest(v_after) a), now())
  on conflict (user_id, game) do update
    set rating = excluded.rating, games = excluded.games, wins = excluded.wins,
        losses = excluded.losses, draws = excluded.draws, best = excluded.best,
        updated_at = excluded.updated_at;

  raise notice '% (%): % in % at % (best %): % games, % won, % lost, % drawn (% won)',
    coalesce((select '@' || username from public.profiles where id = v_user), 'Player with no username'),
    v_user,
    case when v_r >= 1700 then 'Legend' else 'NOT Legend' end, v_game, v_r,
    (select max(a) from unnest(v_after) a), v_n, v_won, v_lost, v_drawn,
    round(100.0 * v_won / v_n) || '%';
end $$;
