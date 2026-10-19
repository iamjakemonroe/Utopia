-- What Chip costs, and a guard on it that real players never notice.
--
--   * Allowances per day (UTC) by who's asking: a guest, a free account or
--     a Chip Maestro member (_chip_limit). chip_allow checks and takes one;
--     chip_take (what the edge function called before) wraps it.
--   * Guests made on one device share one guest allowance: the app keeps a
--     random key on the device (chip_device_usage), so signing out and
--     starting a new guest gives nothing new.
--   * A daily budget, in dollars, for everyone who isn't a member
--     (chip_settings), against what Chip actually cost today (chip_costs,
--     written by the edge function after every call). Guests get a share of
--     it. Past it, guests are asked to save their account and accounts can
--     pay coins to keep chatting; members never notice.
--   * More chats for coins once the day's are used: accounts only (a
--     guest's coins are the free ones every player starts with). One that
--     fails is refunded (chip_refund_chat).
--   * chip_spend: what Chip cost each day, for the dashboard.
--
-- Change the budget in the SQL editor, e.g.
--   update chip_settings set daily_free_usd = 40;

alter type public.ledger_entry_type add value if not exists 'chip_chat';

create table public.chip_settings (
  id             boolean primary key default true check (id),
  daily_free_usd numeric(10, 2) not null default 20 check (daily_free_usd >= 0),
  guest_share    numeric(3, 2) not null default 0.30 check (guest_share between 0 and 1),
  chat_coins     int not null default 20 check (chat_coins > 0)
);
insert into public.chip_settings default values;
alter table public.chip_settings enable row level security;
revoke all on public.chip_settings from anon, authenticated;

create table public.chip_costs (
  day                date not null,
  feature            text not null,
  model              text not null,
  tier               text not null check (tier in ('guest', 'free', 'maestro')),
  calls              int not null default 0,
  input_tokens       bigint not null default 0,
  output_tokens      bigint not null default 0,
  cache_read_tokens  bigint not null default 0,
  cache_write_tokens bigint not null default 0,
  searches           int not null default 0,
  usd                numeric(12, 5) not null default 0,
  primary key (day, feature, model, tier)
);
alter table public.chip_costs enable row level security;
revoke all on public.chip_costs from anon, authenticated;

create table public.chip_device_usage (
  device text not null,
  day    date not null,
  kind   text not null,
  used   int not null default 0,
  primary key (device, day, kind)
);
alter table public.chip_device_usage enable row level security;
revoke all on public.chip_device_usage from anon, authenticated;

create view public.chip_spend with (security_invoker = true) as
select day,
       round(sum(usd), 2) as usd,
       round(coalesce(sum(usd) filter (where tier = 'maestro'), 0), 2) as maestro_usd,
       round(coalesce(sum(usd) filter (where tier = 'free'), 0), 2) as free_usd,
       round(coalesce(sum(usd) filter (where tier = 'guest'), 0), 2) as guest_usd,
       sum(calls) as calls
from public.chip_costs
group by day
order by day desc;
revoke all on public.chip_spend from anon, authenticated;

/** A day's allowance of [p_kind] for a [p_tier] player. */
create function public._chip_limit(p_kind text, p_tier text)
returns int
language sql
immutable
as $$
  select case p_kind
    when 'chat' then case p_tier when 'guest' then 10 when 'free' then 20 else 200 end
    when 'vibe' then case p_tier when 'guest' then 50 else 150 end
    when 'draw' then case p_tier when 'guest' then 1 when 'free' then 4 else 10 end
    when 'doodle' then case p_tier when 'guest' then 3 when 'free' then 6 else 12 end
    when 'paint' then case p_tier when 'guest' then 5 when 'free' then 20 else 100 end
  end;
$$;

create function public._chip_count(p_user uuid, p_day date, p_kind text, p_device text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chip_usage set
    chats = chats + (p_kind = 'chat')::int,
    vibes = vibes + (p_kind = 'vibe')::int,
    draws = draws + (p_kind = 'draw')::int,
    doodles = doodles + (p_kind = 'doodle')::int,
    paints = paints + (p_kind = 'paint')::int
   where user_id = p_user and day = p_day;
  if p_device is not null then
    update public.chip_device_usage set used = used + 1
     where device = p_device and day = p_day and kind = p_kind;
  end if;
end;
$$;

revoke all on function public._chip_count(uuid, date, text, text) from public, anon, authenticated;

/** Takes one of today's [p_kind] for the player, if they have one left.
 * {ok, tier, paid, why, price}: why is 'guest' (a guest who's out, or the
 * guests' share of the budget is), 'limit' (an account that's out), 'busy'
 * (the day's budget is spent) or 'coins' (paying, without enough). An
 * account that's out of chats can pass [p_pay] to pay coins for one. */
create function public.chip_allow(
  p_kind text,
  p_device text default null,
  p_pay boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_settings public.chip_settings;
  v_tier text;
  v_limit int;
  v_used int;
  v_device text;
  v_device_used int := 0;
  v_cap int;
  v_everyone int;
  v_spent numeric := 0;
  v_guest_spent numeric := 0;
  v_busy boolean := false;
  v_balance bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('chat', 'vibe', 'draw', 'paint', 'doodle') then
    raise exception 'unknown kind';
  end if;
  select * into v_settings from public.chip_settings;
  v_tier := case
    when public._maestro_until(v_me) is not null then 'maestro'
    when exists (select 1 from auth.users where id = v_me and is_anonymous) then 'guest'
    else 'free' end;
  v_limit := public._chip_limit(p_kind, v_tier);
  if v_tier = 'guest' and p_device ~ '^[A-Za-z0-9_-]{16,64}$' then
    v_device := p_device;
  end if;

  -- Everyone's drawings, doodles and colorings today.
  v_cap := case p_kind when 'draw' then 300 when 'doodle' then 300 when 'paint' then 3000 end;
  if v_cap is not null then
    select coalesce(sum(case p_kind when 'draw' then draws when 'doodle' then doodles else paints end), 0)
      into v_everyone from public.chip_usage where day = v_today;
    if v_everyone >= v_cap then
      return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'busy');
    end if;
  end if;

  -- The day's budget, for everyone who isn't a member.
  if v_tier <> 'maestro' then
    select coalesce(sum(usd) filter (where tier in ('guest', 'free')), 0),
           coalesce(sum(usd) filter (where tier = 'guest'), 0)
      into v_spent, v_guest_spent
      from public.chip_costs where day = v_today;
    v_busy := v_spent >= v_settings.daily_free_usd
      or (v_tier = 'guest' and v_guest_spent >= v_settings.daily_free_usd * v_settings.guest_share);
  end if;

  insert into public.chip_usage (user_id, day) values (v_me, v_today)
    on conflict (user_id, day) do nothing;
  select case p_kind when 'chat' then chats when 'vibe' then vibes
                     when 'draw' then draws when 'doodle' then doodles else paints end
    into v_used
    from public.chip_usage where user_id = v_me and day = v_today for update;
  if v_device is not null then
    insert into public.chip_device_usage (device, day, kind) values (v_device, v_today, p_kind)
      on conflict (device, day, kind) do nothing;
    select used into v_device_used from public.chip_device_usage
     where device = v_device and day = v_today and kind = p_kind for update;
  end if;

  if not v_busy and v_used < v_limit and v_device_used < v_limit then
    perform public._chip_count(v_me, v_today, p_kind, v_device);
    return jsonb_build_object('ok', true, 'tier', v_tier, 'paid', false);
  end if;

  if v_tier = 'guest' then
    return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'guest');
  end if;
  if p_kind <> 'chat' then
    return jsonb_build_object('ok', false, 'tier', v_tier,
                              'why', case when v_busy then 'busy' else 'limit' end);
  end if;
  if not p_pay then
    return jsonb_build_object('ok', false, 'tier', v_tier,
                              'why', case when v_busy then 'busy' else 'limit' end,
                              'price', v_settings.chat_coins);
  end if;
  select balance into v_balance from public.profiles where id = v_me for update;
  if coalesce(v_balance, 0) < v_settings.chat_coins then
    return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'coins',
                              'price', v_settings.chat_coins);
  end if;
  perform public._ledger_move(v_me, 'chip_chat', -v_settings.chat_coins, null, '{}'::jsonb);
  perform public._chip_count(v_me, v_today, p_kind, null);
  return jsonb_build_object('ok', true, 'tier', v_tier, 'paid', true,
                            'price', v_settings.chat_coins);
end;
$$;

revoke all on function public.chip_allow(text, text, boolean) from public, anon;
grant execute on function public.chip_allow(text, text, boolean) to authenticated;

-- What the edge function called before: the same check, yes or no.
create or replace function public.chip_take(p_kind text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select (public.chip_allow(p_kind) ->> 'ok')::boolean;
$$;

/** A chat paid for with coins that Chip couldn't answer: the coins back. */
create function public.chip_refund_chat(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._ledger_move(p_user, 'chip_chat',
                              (select chat_coins from public.chip_settings), null,
                              jsonb_build_object('refund', true));
  update public.chip_usage set chats = greatest(chats - 1, 0)
   where user_id = p_user and day = (now() at time zone 'utc')::date;
end;
$$;

revoke all on function public.chip_refund_chat(uuid) from public, anon, authenticated;
grant execute on function public.chip_refund_chat(uuid) to service_role;

/** One call to a model: its tokens and what it cost, added to the day. */
create function public.chip_log_cost(
  p_feature text,
  p_model text,
  p_tier text,
  p_input bigint,
  p_output bigint,
  p_cache_read bigint,
  p_cache_write bigint,
  p_searches int,
  p_usd numeric
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.chip_costs as c (
    day, feature, model, tier, calls, input_tokens, output_tokens,
    cache_read_tokens, cache_write_tokens, searches, usd
  )
  values (
    (now() at time zone 'utc')::date, p_feature, p_model,
    case when p_tier in ('guest', 'free', 'maestro') then p_tier else 'free' end,
    1, p_input, p_output, p_cache_read, p_cache_write, p_searches, p_usd
  )
  on conflict (day, feature, model, tier) do update set
    calls = c.calls + 1,
    input_tokens = c.input_tokens + excluded.input_tokens,
    output_tokens = c.output_tokens + excluded.output_tokens,
    cache_read_tokens = c.cache_read_tokens + excluded.cache_read_tokens,
    cache_write_tokens = c.cache_write_tokens + excluded.cache_write_tokens,
    searches = c.searches + excluded.searches,
    usd = c.usd + excluded.usd;
$$;

revoke all on function public.chip_log_cost(text, text, text, bigint, bigint, bigint, bigint, int, numeric)
  from public, anon, authenticated;
grant execute on function public.chip_log_cost(text, text, text, bigint, bigint, bigint, bigint, int, numeric)
  to service_role;
