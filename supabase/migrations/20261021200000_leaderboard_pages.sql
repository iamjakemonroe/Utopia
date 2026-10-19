-- Leaderboards a page at a time: the board opens on its first 25 and
-- loads the next as the player scrolls down, up to the top 100, instead
-- of all 100 at once. get_leaderboard takes p_offset and p_limit (25 a
-- page, at most 100) and says whether there's more ('more'). Called the
-- old way (without them), it's the first page.

drop function public.get_leaderboard(text, boolean);

create function public.get_leaderboard(
  p_game text,
  p_friends boolean default false,
  p_offset int default 0,
  p_limit int default 25
)
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
  v_total int;
  v_place int;
  v_pool uuid[];
  v_settings public.leaderboard_settings;
  v_house boolean := false;
  v_offset int := greatest(coalesce(p_offset, 0), 0);
  v_limit int := least(greatest(coalesce(p_limit, 25), 1), 100);
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_game not in ('chess', 'checkers', 'doodle') then raise exception 'unknown game'; end if;
  -- The board is the top 100: nothing past it.
  v_limit := greatest(least(v_limit, 100 - v_offset), 0);

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

  with ranked as (
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
  ),
  page as (
    select * from ranked
    order by place, games desc, id
    offset v_offset limit v_limit
  )
  select (select count(*) from ranked),
         coalesce((select jsonb_agg(to_jsonb(t) order by t.place, t.games desc, t.id) from page t),
                  '[]'::jsonb)
    into v_total, v_top;

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
    'more', v_offset + jsonb_array_length(v_top) < least(v_total, 100),
    'me', jsonb_build_object(
      'place', v_place,
      'rating', coalesce(v_mine.rating, 1000),
      'games', coalesce(v_mine.games, 0)
    )
  );
end;
$$;

revoke all on function public.get_leaderboard(text, boolean, int, int) from public, anon;
grant execute on function public.get_leaderboard(text, boolean, int, int) to authenticated;
