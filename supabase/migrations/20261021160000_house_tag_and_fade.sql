-- House players on the leaderboards, honestly: each row says whether
-- it's one of Utopia's house players (the app tags them "House"), and
-- they fill a game's board only until it has enough real players
-- (leaderboard_settings.house_until_players ranked, 50 to start), then
-- leave it by themselves. The switch still turns them off altogether:
--   update public.leaderboard_settings set show_house_players = false;

alter table public.leaderboard_settings
  add column house_until_players int not null default 50;

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
  v_settings public.leaderboard_settings;
  v_house boolean := false;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_game not in ('chess', 'checkers', 'doodle') then raise exception 'unknown game'; end if;

  -- House players while the game's board is still filling up.
  select * into v_settings from public.leaderboard_settings;
  if coalesce(v_settings.show_house_players, false) then
    v_house := (
      select count(*) from public.player_ratings r
      where r.game = p_game and r.games >= 5
        and not exists (select 1 from public.house_players h where h.id = r.user_id)
    ) < v_settings.house_until_players;
  end if;

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
           r.rating, r.games,
           exists (select 1 from public.house_players h where h.id = r.user_id) as house
    from public.player_ratings r
    join public.profiles p on p.id = r.user_id
    where r.game = p_game and r.games >= 5
      and (v_house or not exists (select 1 from public.house_players h where h.id = r.user_id))
      and (not p_friends or r.user_id = any (v_pool))
    order by r.rating desc, r.games desc, r.user_id
    limit 100
  ) t;

  select * into v_mine from public.player_ratings where user_id = v_me and game = p_game;
  if found and v_mine.games >= 5 then
    select 1 + count(*) into v_place
    from public.player_ratings r
    where r.game = p_game and r.games >= 5 and r.rating > v_mine.rating
      and (v_house or not exists (select 1 from public.house_players h where h.id = r.user_id))
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
