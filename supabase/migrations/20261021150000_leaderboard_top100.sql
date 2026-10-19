-- Leaderboards show the top 100 (were 50): it's competitive, and players
-- below the podium want to see where they stand.
--
-- For now, house players can show on them too, so the boards can be seen
-- full (leaderboard_settings.show_house_players, on for now; they never
-- count for prizes either way). Take them off with:
--   update public.leaderboard_settings set show_house_players = false;

create table public.leaderboard_settings (
  id boolean primary key default true check (id),
  show_house_players boolean not null default false
);
insert into public.leaderboard_settings (show_house_players) values (true);
alter table public.leaderboard_settings enable row level security;
revoke all on public.leaderboard_settings from anon, authenticated;

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
  v_house boolean := coalesce(
    (select show_house_players from public.leaderboard_settings), false
  );
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
