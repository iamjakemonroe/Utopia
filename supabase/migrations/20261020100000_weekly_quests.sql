-- Weekly quests: every week, coins for playing.
--
--   * Events can now give coins (event_rewards.kind 'coins', amount in
--     event_rewards.coins), paid into the ledger as 'quest_reward'.
--   * Each week (Monday to Monday, UTC) has its own event, 'weekly_<year>_
--     <week>', made the first time anyone comes by that week: play 5 games
--     for 1,500 coins, play 12 for 4,000 more, and come by on 3 different
--     days for 2,000. Every game counts, like in seasonal events.
--   * event_claims: every reward each player has had, per event (so a
--     week's coins are paid once; a seasonal item, once ever, as before).

alter type public.ledger_entry_type add value if not exists 'quest_reward';

alter table public.event_rewards drop constraint event_rewards_kind_check;
alter table public.event_rewards
  add constraint event_rewards_kind_check check (kind in ('world', 'aura', 'coins')),
  add column coins bigint not null default 0 check (coins >= 0);

create table public.event_claims (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  event_id   text not null references public.events (id) on delete cascade,
  item_id    text not null,
  claimed_at timestamptz not null default now(),
  primary key (user_id, event_id, item_id)
);

alter table public.event_claims enable row level security;
revoke insert, update, delete on public.event_claims from authenticated, anon;
create policy "see your own claims" on public.event_claims
  for select using (user_id = auth.uid());

-- What anyone has earned in the Halloween event so far counts as claimed.
insert into public.event_claims (user_id, event_id, item_id)
select s.user_id, s.event_id, s.item_id from public.season_items s
on conflict do nothing;

/** This week's quests, made the first time they're needed. */
create function public._ensure_weekly()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start timestamptz := date_trunc('week', now() at time zone 'utc') at time zone 'utc';
  v_id text := 'weekly_' || to_char(now() at time zone 'utc', 'IYYY_IW');
begin
  insert into public.events (id, season, title, starts_at, ends_at)
    values (v_id, 'weekly', 'This week', v_start, v_start + interval '7 days')
    on conflict (id) do nothing;
  if found then
    insert into public.event_rewards (event_id, item_id, kind, games, days, coins, sort)
    values
      (v_id, 'games_5', 'coins', 5, 0, 1500, 1),
      (v_id, 'games_12', 'coins', 12, 0, 4000, 2),
      (v_id, 'days_3', 'coins', 0, 3, 2000, 3);
  end if;
end;
$$;

revoke all on function public._ensure_weekly() from public, anon, authenticated;

/** Whether [p_user] has had [p_reward]: a seasonal item, ever (it's theirs
 * for good); coins, in this event. */
create function public._reward_had(p_user uuid, p_reward public.event_rewards)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case p_reward.kind
    when 'coins' then exists (
      select 1 from public.event_claims c
      where c.user_id = p_user and c.event_id = p_reward.event_id
        and c.item_id = p_reward.item_id)
    else exists (
      select 1 from public.season_items s
      where s.user_id = p_user and s.item_id = p_reward.item_id)
  end;
$$;

revoke all on function public._reward_had(uuid, public.event_rewards) from public, anon, authenticated;

create or replace function public._event_award(p_user uuid, p_event public.events)
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
    order by r.sort
  loop
    continue when public._reward_had(p_user, v_reward);
    insert into public.event_claims (user_id, event_id, item_id)
      values (p_user, p_event.id, v_reward.item_id)
      on conflict do nothing;
    if v_reward.kind = 'coins' then
      perform public._ledger_move(
        p_user,
        'quest_reward',
        v_reward.coins,
        null,
        jsonb_build_object('event', p_event.id, 'quest', v_reward.item_id)
      );
    else
      insert into public.season_items (user_id, item_id, kind, season, event_id)
        values (p_user, v_reward.item_id, v_reward.kind, p_event.season, p_event.id);
      perform public._season_grant(p_user, v_reward.item_id, v_reward.kind, p_event.ends_at);
    end if;
    v_new := v_new || v_reward.item_id;
  end loop;
  return v_new;
end;
$$;

create or replace function public._event_state(p_user uuid, p_new text[], p_counted boolean)
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
            'coins', r.coins,
            'earned', public._reward_had(p_user, r)
          ) order by r.sort)
          from public.event_rewards r where r.event_id = e.id
        ), '[]'::jsonb)
      -- Seasonal events first, then the week's quests.
      ) order by (e.season = 'weekly'), e.starts_at)
      from public.events e
      left join public.event_progress p on p.event_id = e.id and p.user_id = p_user
      where now() between e.starts_at and e.ends_at
    ), '[]'::jsonb)
  );
$$;

-- Both ways in make sure this week's quests exist first.
create or replace function public.event_visit()
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
  perform public._ensure_weekly();
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

create or replace function public.event_count_game(p_game text, p_match uuid default null)
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
  perform public._ensure_weekly();

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
