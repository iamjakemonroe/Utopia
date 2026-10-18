-- Our own analytics, and deleting an account forgets everything personal.
--
--   * app_events: what players do (the app opening, the screens they go
--     to, games finished, purchases, rewards, chats with Chip...), sent in
--     batches through log_events. No player can read it, not even their
--     own; it's for the team, through the views below, in the dashboard's
--     SQL editor. At most 3,000 a day each.
--   * analytics_daily: active players, new players, games, purchases and
--     Chip chats per day. analytics_retention: of the players who joined
--     each day, how many came back the next day, a week later, a month
--     later.
--   * anonymize_account also forgets Chip's notes, the birthday, the
--     analytics, Guess My Doodle chats and guesses, and what they asked
--     Chip to draw (the edge function removes their voice notes' files).

create table public.app_events (
  id      bigint generated always as identity primary key,
  user_id uuid references public.profiles (id) on delete cascade,
  name    text not null check (name ~ '^[a-z][a-z_]{1,39}$'),
  props   jsonb not null default '{}'::jsonb,
  at      timestamptz not null default now()
);

comment on table public.app_events is 'What players do in the app, for the team (see analytics_daily and analytics_retention). Never readable by players.';

create index app_events_by_name on public.app_events (name, at);
create index app_events_by_user on public.app_events (user_id, at);

alter table public.app_events enable row level security;
revoke all on public.app_events from anon, authenticated;

/** A batch of the player's events: [{name, props, at}], up to 100. */
create function public.log_events(p_events jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then return; end if;
  if jsonb_typeof(p_events) <> 'array' or jsonb_array_length(p_events) > 100 then
    raise exception 'bad batch';
  end if;
  if (select count(*) from public.app_events
      where user_id = v_me and at > now() - interval '1 day') >= 3000 then
    return;
  end if;
  insert into public.app_events (user_id, name, props, at)
  select
    v_me,
    e->>'name',
    case when jsonb_typeof(e->'props') = 'object' then e->'props' else '{}'::jsonb end,
    -- When it happened on the phone (it may have waited a while), but never
    -- in the future or more than a day back.
    least(now(), greatest(now() - interval '1 day',
      coalesce((e->>'at')::timestamptz, now())))
  from jsonb_array_elements(p_events) e
  where coalesce(e->>'name', '') ~ '^[a-z][a-z_]{1,39}$'
    and pg_column_size(coalesce(e->'props', '{}'::jsonb)) <= 2000;
end;
$$;

revoke all on function public.log_events(jsonb) from public;
grant execute on function public.log_events(jsonb) to authenticated;

create view public.analytics_daily with (security_invoker = true) as
with days as (
  select at::date as day,
    count(distinct user_id) filter (where name = 'app_open') as active_players,
    count(*) filter (where name = 'game_finished') as games,
    count(*) filter (where name = 'coin_purchase') as coin_purchases,
    count(*) filter (where name = 'store_purchase') as store_purchases,
    count(distinct user_id) filter (where name = 'chip_message') as chatted_with_chip,
    count(*) filter (where name = 'invite_shared') as invites_shared
  from public.app_events
  group by 1
)
select d.day,
  (select count(*) from public.profiles p where p.created_at::date = d.day) as new_players,
  d.active_players, d.games, d.coin_purchases, d.store_purchases,
  d.chatted_with_chip, d.invites_shared
from days d
order by d.day desc;

create view public.analytics_retention with (security_invoker = true) as
with active as (
  select distinct user_id, at::date as day from public.app_events where name = 'app_open'
)
select p.created_at::date as joined,
  count(*) as players,
  round(100.0 * count(*) filter (where exists (
    select 1 from active a where a.user_id = p.id and a.day = p.created_at::date + 1
  )) / count(*), 1) as day_1_pct,
  round(100.0 * count(*) filter (where exists (
    select 1 from active a where a.user_id = p.id and a.day = p.created_at::date + 7
  )) / count(*), 1) as day_7_pct,
  round(100.0 * count(*) filter (where exists (
    select 1 from active a where a.user_id = p.id and a.day = p.created_at::date + 30
  )) / count(*), 1) as day_30_pct
from public.profiles p
group by 1
order by 1 desc;

revoke all on public.analytics_daily, public.analytics_retention from anon, authenticated;

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
end;
$$;

revoke all on function public.anonymize_account(uuid) from public, anon, authenticated;
grant execute on function public.anonymize_account(uuid) to service_role;
