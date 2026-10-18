-- Birthdays, and events whose items are earned by playing.
--
--   * Birthdays: the day and month only (never the year, so no one's age
--     is kept), in a table only the player can read. set_birthday sets it;
--     it can be corrected for a day, then it's locked. On their birthday,
--     start_birthday gives them the Birthday world and the Birthday frame
--     until their own midnight. Neither is ever sold, rented or listed.
--   * Events (Halloween first): their items are earned free by playing
--     while the event is on, kept for good, and usable whenever their
--     season comes round again. event_visit counts the days a player comes
--     by (and hands back what they've earned once the season returns);
--     event_count_game counts a finished game.
--   * Halloween leaves the store: Utopia Halloween and Jack's Lantern are
--     earned in the Halloween event instead of bought.

-- ── Birthdays ────────────────────────────────────────────────────────────

create table public.user_birthdays (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  month   smallint not null check (month between 1 and 12),
  day     smallint not null check (day between 1 and 31),
  -- When it was first set: it can be corrected for a day after that.
  set_at  timestamptz not null default now(),
  check (day <= case month when 2 then 29 when 4 then 30 when 6 then 30
                           when 9 then 30 when 11 then 30 else 31 end)
);

comment on table public.user_birthdays is 'Day and month of each player''s birthday (no year). Private: only its owner can read it.';

alter table public.user_birthdays enable row level security;
revoke insert, update, delete on public.user_birthdays from authenticated, anon;
create policy "see your own birthday" on public.user_birthdays
  for select using (user_id = auth.uid());

create function public.set_birthday(p_month int, p_day int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_set timestamptz;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_month is null or p_day is null or p_month not between 1 and 12
     or p_day < 1 or p_day > extract(day from (make_date(2000, p_month, 1)
       + interval '1 month' - interval '1 day')) then
    raise exception 'not a real date';
  end if;
  select set_at into v_set from public.user_birthdays where user_id = v_me;
  if v_set is not null and v_set < now() - interval '1 day' then
    raise exception 'birthday locked';
  end if;
  insert into public.user_birthdays (user_id, month, day)
    values (v_me, p_month, p_day)
    on conflict (user_id) do update set month = excluded.month, day = excluded.day;
end;
$$;

revoke all on function public.set_birthday(int, int) from public;
grant execute on function public.set_birthday(int, int) to authenticated;

/** When [p_month]/[p_day] ends everywhere (midnight at UTC-12), if it's that
 * date anywhere on Earth right now (UTC-12 to UTC+14); null otherwise.
 * 29 February is celebrated on the 28th in other years. */
create function public._birthday_ends(p_month int, p_day int)
returns timestamptz
language sql
stable
set search_path = public
as $$
  select max((d + 1)::timestamp at time zone 'utc' + interval '12 hours')
  from generate_series(
    ((now() at time zone 'utc') - interval '12 hours')::date,
    ((now() at time zone 'utc') + interval '14 hours')::date,
    interval '1 day'
  ) as g(day)
  cross join lateral (select g.day::date as d) as x
  where (extract(month from d) = p_month and extract(day from d) = p_day)
     or (p_month = 2 and p_day = 29
         and extract(month from d) = 2 and extract(day from d) = 28
         and extract(day from (make_date(extract(year from d)::int, 3, 1) - 1)) = 28);
$$;

/** On the player's birthday: the Birthday world and frame, put on, until
 * [p_until] (their midnight, from the app), never past the end of that
 * date everywhere. Anything else: {birthday: false}. */
create function public.start_birthday(p_until timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_bday public.user_birthdays;
  v_ends timestamptz;
  v_until timestamptz;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_bday from public.user_birthdays where user_id = v_me;
  if not found then return jsonb_build_object('birthday', false); end if;
  v_ends := public._birthday_ends(v_bday.month, v_bday.day);
  if v_ends is null then return jsonb_build_object('birthday', false); end if;

  v_until := least(greatest(coalesce(p_until, v_ends), now() + interval '1 hour'), v_ends);

  insert into public.world_rentals (user_id, world_id, expires_at)
    values (v_me, 'utopia_birthday', v_until)
    on conflict (user_id, world_id)
      do update set expires_at = greatest(world_rentals.expires_at, excluded.expires_at);
  insert into public.user_auras (user_id, aura_id, expires_at)
    values (v_me, 'birthday', v_until)
    on conflict (user_id, aura_id)
      do update set expires_at = greatest(user_auras.expires_at, excluded.expires_at);
  update public.profiles
    set equipped_theme = 'utopia_birthday', equipped_aura = 'birthday',
        aura_expires_at = (select expires_at from public.user_auras
                           where user_id = v_me and aura_id = 'birthday'),
        updated_at = now()
    where id = v_me;

  return jsonb_build_object(
    'birthday', true,
    'until', (select expires_at from public.world_rentals
              where user_id = v_me and world_id = 'utopia_birthday')
  );
end;
$$;

revoke all on function public.start_birthday(timestamptz) from public;
grant execute on function public.start_birthday(timestamptz) to authenticated;

-- The Birthday frame: never sold (retired), only given on the day.
insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort, retired)
values ('birthday', 'legendary', 5000, 15000, 60000, 40, true)
on conflict (id) do update set retired = true;

-- ── Events ───────────────────────────────────────────────────────────────

create table public.events (
  id        text primary key,           -- one per year: 'halloween_2026'
  season    text not null,              -- what comes round again: 'halloween'
  title     text not null,
  starts_at timestamptz not null,
  ends_at   timestamptz not null,
  check (ends_at > starts_at)
);

comment on table public.events is 'Seasonal events. Items earned in one are the player''s for good, usable whenever an event of the same season is on.';

create table public.event_rewards (
  event_id text not null references public.events (id) on delete cascade,
  item_id  text not null,
  kind     text not null check (kind in ('world', 'aura')),
  -- What earns it: games finished during the event, and different days
  -- they came by.
  games    int not null default 0 check (games >= 0),
  days     int not null default 0 check (days >= 0),
  sort     int not null default 0,
  primary key (event_id, item_id)
);

create table public.event_progress (
  user_id         uuid not null references public.profiles (id) on delete cascade,
  event_id        text not null references public.events (id) on delete cascade,
  games           int not null default 0,
  days            int not null default 0,
  last_day        date,
  -- Offline games are taken on trust, so they're limited: these track it.
  offline_day     date,
  offline_today   int not null default 0,
  last_offline_at timestamptz,
  primary key (user_id, event_id)
);

-- Online games already counted for a player (each counts once).
create table public.event_counted (
  user_id  uuid not null references public.profiles (id) on delete cascade,
  match_id uuid not null,
  primary key (user_id, match_id)
);

create table public.season_items (
  user_id   uuid not null references public.profiles (id) on delete cascade,
  item_id   text not null,
  kind      text not null check (kind in ('world', 'aura')),
  season    text not null,
  event_id  text not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

comment on table public.season_items is 'Event items a player has earned: theirs for good, usable while an event of their season is on.';

alter table public.events enable row level security;
alter table public.event_rewards enable row level security;
alter table public.event_progress enable row level security;
alter table public.event_counted enable row level security;
alter table public.season_items enable row level security;
revoke insert, update, delete on public.events, public.event_rewards,
  public.event_progress, public.event_counted, public.season_items
  from authenticated, anon;
create policy "anyone sees events" on public.events for select using (true);
create policy "anyone sees event rewards" on public.event_rewards for select using (true);
create policy "see your own progress" on public.event_progress
  for select using (user_id = auth.uid());
create policy "see your own counted games" on public.event_counted
  for select using (user_id = auth.uid());
create policy "see your own season items" on public.season_items
  for select using (user_id = auth.uid());

/** Puts a season item in [p_user]'s hands until [p_until]: a world as a
 * rental, a frame as a wear. */
create function public._season_grant(p_user uuid, p_item text, p_kind text, p_until timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind = 'world' then
    insert into public.world_rentals (user_id, world_id, expires_at)
      values (p_user, p_item, p_until)
      on conflict (user_id, world_id)
        do update set expires_at = greatest(world_rentals.expires_at, excluded.expires_at);
  else
    insert into public.user_auras (user_id, aura_id, expires_at)
      values (p_user, p_item, p_until)
      on conflict (user_id, aura_id)
        do update set expires_at = greatest(user_auras.expires_at, excluded.expires_at);
  end if;
end;
$$;

revoke all on function public._season_grant(uuid, text, text, timestamptz) from public, anon, authenticated;

/** Whatever [p_user] has now earned in [p_event] and doesn't have yet: theirs,
 * and in their hands until the event ends. Returns the new item ids. */
create function public._event_award(p_user uuid, p_event public.events)
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_progress public.event_progress;
  v_reward public.event_rewards;
  v_new text[] := '{}';
begin
  select * into v_progress from public.event_progress
    where user_id = p_user and event_id = p_event.id;
  if not found then return v_new; end if;
  for v_reward in
    select r.* from public.event_rewards r
    where r.event_id = p_event.id
      and r.games <= v_progress.games
      and r.days <= v_progress.days
      and not exists (select 1 from public.season_items s
                      where s.user_id = p_user and s.item_id = r.item_id)
    order by r.sort
  loop
    insert into public.season_items (user_id, item_id, kind, season, event_id)
      values (p_user, v_reward.item_id, v_reward.kind, p_event.season, p_event.id);
    perform public._season_grant(p_user, v_reward.item_id, v_reward.kind, p_event.ends_at);
    v_new := v_new || v_reward.item_id;
  end loop;
  return v_new;
end;
$$;

revoke all on function public._event_award(uuid, public.events) from public, anon, authenticated;

/** The app's view: every event on now, with its rewards (and which the
 * player has), their progress, and [p_new]: items just earned. */
create function public._event_state(p_user uuid, p_new text[], p_counted boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'counted', p_counted,
    'earned_now', to_jsonb(coalesce(p_new, '{}')),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id,
        'season', e.season,
        'title', e.title,
        'starts_at', e.starts_at,
        'ends_at', e.ends_at,
        'games', coalesce(p.games, 0),
        'days', coalesce(p.days, 0),
        'rewards', coalesce((
          select jsonb_agg(jsonb_build_object(
            'item_id', r.item_id,
            'kind', r.kind,
            'games', r.games,
            'days', r.days,
            'earned', exists (select 1 from public.season_items s
                              where s.user_id = p_user and s.item_id = r.item_id)
          ) order by r.sort)
          from public.event_rewards r where r.event_id = e.id
        ), '[]'::jsonb)
      ) order by e.starts_at)
      from public.events e
      left join public.event_progress p on p.event_id = e.id and p.user_id = p_user
      where now() between e.starts_at and e.ends_at
    ), '[]'::jsonb)
  );
$$;

revoke all on function public._event_state(uuid, text[], boolean) from public, anon, authenticated;

/** The player opened the app: counts today for every event on now, hands
 * back their season items for this season, and awards anything now due. */
create function public.event_visit()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_event public.events;
  v_item public.season_items;
  v_new text[] := '{}';
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  for v_event in
    select * from public.events where now() between starts_at and ends_at
  loop
    insert into public.event_progress (user_id, event_id, days, last_day)
      values (v_me, v_event.id, 1, v_today)
      on conflict (user_id, event_id) do update set
        days = event_progress.days
          + case when event_progress.last_day is distinct from v_today then 1 else 0 end,
        last_day = v_today;
    for v_item in
      select * from public.season_items where user_id = v_me and season = v_event.season
    loop
      perform public._season_grant(v_me, v_item.item_id, v_item.kind, v_event.ends_at);
    end loop;
    v_new := v_new || public._event_award(v_me, v_event);
  end loop;
  return public._event_state(v_me, v_new, false);
end;
$$;

revoke all on function public.event_visit() from public;
grant execute on function public.event_visit() to authenticated;

/** A game the player just finished, for every event on now. An online one
 * ([p_match]) must be finished and theirs, and counts once. An offline one
 * is taken on trust, so at most one a minute and 10 a day count. */
create function public.event_count_game(p_game text, p_match uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_event public.events;
  v_new text[] := '{}';
  v_ok boolean;
  v_offline boolean := p_match is null;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_game not in ('chess', 'checkers', 'ludo', 'doodle') then
    raise exception 'unknown game';
  end if;
  if not exists (select 1 from public.events where now() between starts_at and ends_at) then
    return public._event_state(v_me, v_new, false);
  end if;

  if not v_offline then
    v_ok := case p_game
      when 'ludo' then exists (
        select 1 from public.ludo_matches
        where id = p_match and status = 'completed' and v_me = any (players))
      when 'doodle' then exists (
        select 1 from public.doodle_games g
        join public.doodle_players p on p.game_id = g.id
        where g.id = p_match and g.status in ('over', 'closed')
          and p.user_id = v_me and p.left_at is null)
      else exists (
        select 1 from public.matches
        where id = p_match and status = 'completed'
          and v_me in (player_white, player_black))
    end;
    if not v_ok then raise exception 'not a finished game of yours'; end if;
    insert into public.event_counted (user_id, match_id) values (v_me, p_match)
      on conflict do nothing;
    if not found then return public._event_state(v_me, v_new, false); end if;
  elsif exists (
    select 1 from public.event_progress p
    join public.events e on e.id = p.event_id
    where p.user_id = v_me and now() between e.starts_at and e.ends_at
      and (p.last_offline_at > now() - interval '1 minute'
           or (p.offline_day = v_today and p.offline_today >= 10))
  ) then
    return public._event_state(v_me, v_new, false);
  end if;

  for v_event in
    select * from public.events where now() between starts_at and ends_at
  loop
    insert into public.event_progress (
      user_id, event_id, games, days, last_day, offline_day, offline_today, last_offline_at
    )
    values (
      v_me, v_event.id, 1, 1, v_today,
      case when v_offline then v_today end,
      case when v_offline then 1 else 0 end,
      case when v_offline then now() end
    )
    on conflict (user_id, event_id) do update set
      games = event_progress.games + 1,
      days = event_progress.days
        + case when event_progress.last_day is distinct from v_today then 1 else 0 end,
      last_day = v_today,
      offline_today = case
        when not v_offline then event_progress.offline_today
        when event_progress.offline_day is distinct from v_today then 1
        else event_progress.offline_today + 1 end,
      offline_day = case when v_offline then v_today else event_progress.offline_day end,
      last_offline_at = case when v_offline then now() else event_progress.last_offline_at end;
    v_new := v_new || public._event_award(v_me, v_event);
  end loop;
  return public._event_state(v_me, v_new, true);
end;
$$;

revoke all on function public.event_count_game(text, uuid) from public;
grant execute on function public.event_count_game(text, uuid) to authenticated;

-- ── Halloween 2026 ───────────────────────────────────────────────────────

insert into public.events (id, season, title, starts_at, ends_at)
values ('halloween_2026', 'halloween', 'Halloween',
        '2026-10-15 00:00+00', '2026-11-02 12:00+00');

-- Jack's Lantern for 10 games; the world for 15 games over 5 different days
-- (so it's a few visits, not one long sitting).
insert into public.event_rewards (event_id, item_id, kind, games, days, sort)
values
  ('halloween_2026', 'jack', 'aura', 10, 0, 1),
  ('halloween_2026', 'utopia_halloween', 'world', 15, 5, 2);

-- Off the shelves: no longer bought, rented, packed or given in the
-- welcome week.
update public.aura_catalog set retired = true where id = 'jack';
delete from public.store_coin_prices where product_id = 'utopia.theme.utopia_halloween';
update public.store_coin_prices
   set item_ids = array_remove(item_ids, 'utopia_halloween')
 where product_id = 'utopia.themes.all';

-- Anyone who bought them before: they become their season items.
insert into public.season_items (user_id, item_id, kind, season, event_id)
select user_id, 'utopia_halloween', 'world', 'halloween', 'halloween_2026'
from public.user_entitlements where item_id = 'utopia_halloween'
on conflict do nothing;
delete from public.user_entitlements where item_id = 'utopia_halloween';
insert into public.season_items (user_id, item_id, kind, season, event_id)
select user_id, 'jack', 'aura', 'halloween', 'halloween_2026'
from public.user_auras where aura_id = 'jack'
on conflict do nothing;

create or replace function public._world_rent_price(p_world_id text, p_days int)
returns bigint
language sql
immutable
as $$
  select case
    when public._free_item(p_world_id) then null
    when p_world_id in (
      'utopia_dark', 'utopia_alien', 'utopia_tech', 'utopia_anime',
      'utopia_deep', 'utopia_doodle', 'utopia_dojo', 'utopia_zombie',
      'utopia_heaven', 'utopia_hell', 'utopia_music'
    ) then case p_days when 3 then 2500 when 7 then 6000 when 30 then 20000 end
    when p_world_id ~ '^(ruby|ember|sunbeam|jade|lagoon|azure|sapphire|amethyst|blossom|rosegold|onyx|pearl)_(dawn|dusk|midnight)$'
      then case p_days when 3 then 1200 when 7 then 3000 when 30 then 10000 end
  end;
$$;

create or replace function public.start_welcome_week()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_until timestamptz;
  v_started boolean;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select welcome_until into v_until from public.profiles where id = v_me for update;
  if not found then raise exception 'no profile'; end if;
  if v_until is not null then
    return jsonb_build_object('until', v_until, 'fresh', false);
  end if;

  v_until := now() + interval '7 days';
  update public.profiles set welcome_until = v_until where id = v_me;

  -- Every paid world: the premium Utopia worlds and the color worlds
  -- (event worlds are earned in their event, not given here).
  insert into public.world_rentals (user_id, world_id, expires_at)
  select v_me, w, v_until
  from (
    select unnest(array[
      'utopia_dark', 'utopia_alien', 'utopia_tech', 'utopia_anime',
      'utopia_deep', 'utopia_doodle', 'utopia_dojo', 'utopia_zombie',
      'utopia_heaven', 'utopia_hell', 'utopia_music'
    ]) as w
    union all
    select f || '_' || s
    from unnest(array[
      'ruby', 'ember', 'sunbeam', 'jade', 'lagoon', 'azure',
      'sapphire', 'amethyst', 'blossom', 'rosegold', 'onyx', 'pearl'
    ]) as f
    cross join unnest(array['dawn', 'dusk', 'midnight']) as s
  ) worlds
  where not public._free_item(w)
  on conflict (user_id, world_id)
    do update set expires_at = greatest(world_rentals.expires_at, excluded.expires_at);

  -- The Angel Halo, worn straight away unless they already wear an aura.
  insert into public.user_auras (user_id, aura_id, expires_at)
  values (v_me, 'halo', v_until)
  on conflict (user_id, aura_id)
    do update set expires_at = greatest(user_auras.expires_at, excluded.expires_at);

  update public.profiles
    set equipped_aura = 'halo', aura_expires_at = v_until, updated_at = now()
    where id = v_me
      and (equipped_aura is null or aura_expires_at is null or aura_expires_at < now());

  v_started := true;
  return jsonb_build_object('until', v_until, 'fresh', v_started);
end;
$$;

revoke all on function public.start_welcome_week() from public;
grant execute on function public.start_welcome_week() to authenticated;
