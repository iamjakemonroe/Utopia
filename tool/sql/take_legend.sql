-- Takes back give_legend.sql: the games it made go (and their ratings
-- with them), and the player's rating in that game is worked out again
-- from whatever rated games are left (none: it's gone, back to 1000).
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the player's
-- username, user ID or email below, then Run.
do $$
declare
  v_who text := 'their_username';  -- <- username, user ID or email
  v_game text := 'chess';          -- chess or checkers
  v_user uuid;
  v_gone int;
  v_left int;
begin
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

  -- Both sides' ratings in them (not tied to matches), then the games.
  delete from public.rating_changes
   where match_id in (select md5('give_legend:' || v_user || ':' || v_game || ':' || g)::uuid
                        from generate_series(1, 600) g);
  delete from public.matches
   where id in (select md5('give_legend:' || v_user || ':' || v_game || ':' || g)::uuid
                  from generate_series(1, 600) g);
  get diagnostics v_gone = row_count;

  select count(*) into v_left from public.rating_changes where user_id = v_user and game = v_game;
  if v_left = 0 then
    delete from public.player_ratings where user_id = v_user and game = v_game;
  else
    update public.player_ratings r
       set rating = (select after from public.rating_changes
                      where user_id = v_user and game = v_game order by created_at desc limit 1),
           best = greatest(1000, (select max(after) from public.rating_changes
                                   where user_id = v_user and game = v_game)),
           games = h.games, wins = h.wins, losses = h.losses, draws = h.draws,
           updated_at = now()
      from (select count(*) as games,
                   count(*) filter (where outcome = 'W') as wins,
                   count(*) filter (where outcome = 'L') as losses,
                   count(*) filter (where outcome = 'D') as draws
              from public._rated_matches(v_user, v_game)) h
     where r.user_id = v_user and r.game = v_game;
  end if;

  raise notice '% (%): % made-up games gone; % rated games left in %',
    coalesce((select '@' || username from public.profiles where id = v_user), 'Player with no username'),
    v_user, v_gone, v_left, v_game;
end $$;
