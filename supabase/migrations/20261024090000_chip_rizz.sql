-- Chip Rizz (chip.kaivon.app): Chip as a texting wingman, on the same
-- Kaivon account, coins and Chip Maestro membership as Utopia.
--
--   * rizz_ages: each user's date of birth, given once in Chip Rizz (Utopia
--     keeps birthdays without the year). Chip Rizz is for 16 and over and
--     its Bold tone for 18 and over. A date can be corrected for a day
--     after it's first given, like a birthday.
--   * rizz_people: the people someone texts, with what they've told Chip
--     about each and what Chip learned from a chat they shared (the chat
--     itself is never kept). Only their owner sees them; at most 100 each.
--   * Two new kinds of Chip call in chip_allow: 'rizz' (a set of replies)
--     and 'learn' (reading a shared chat), with allowances by tier like the
--     others. An account out of replies can pay coins for more, as it can
--     for chats; chip_refund gives back a paid call that failed.
--   * rizz_me(): what the app shows (age, tier, what's left today, coins).
--   * A guest who signs in to an existing account takes their people and
--     date of birth along (guest_transfer_finish, before the guest retires).
--   * Deleting an account (anonymize_account) deletes both.

alter table public.chip_usage
  add column if not exists rizzes int not null default 0,
  add column if not exists learns int not null default 0;

-- ── Dates of birth ──────────────────────────────────────────────────────

create table public.rizz_ages (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  born    date not null check (born >= date '1900-01-01'),
  -- When it was first given: it can be corrected for a day after that.
  set_at  timestamptz not null default now()
);

comment on table public.rizz_ages is 'Date of birth given in Chip Rizz, for its age limits. Private: only its owner can read it.';

alter table public.rizz_ages enable row level security;
revoke all on public.rizz_ages from anon, authenticated;
grant select on public.rizz_ages to authenticated;
create policy "see your own date of birth" on public.rizz_ages
  for select to authenticated using (user_id = auth.uid());

/** Whole years from [p_born] to today (UTC). */
create function public._age_on(p_born date)
returns int
language sql
stable
as $$
  select extract(year from age((now() at time zone 'utc')::date, p_born))::int;
$$;

/** Gives the signed-in user's date of birth: once, then only within a day
 * of first giving it. Returns their age. */
create function public.rizz_set_born(p_born date)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_set_at timestamptz;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_born is null or p_born < date '1900-01-01'
     or p_born > (now() at time zone 'utc')::date then
    raise exception 'invalid date of birth';
  end if;
  select set_at into v_set_at from public.rizz_ages where user_id = v_me for update;
  if v_set_at is not null and v_set_at < now() - interval '1 day' then
    raise exception 'date of birth already set';
  end if;
  insert into public.rizz_ages (user_id, born) values (v_me, p_born)
    on conflict (user_id) do update set born = excluded.born;
  return public._age_on(p_born);
end;
$$;

revoke all on function public.rizz_set_born(date) from public, anon;
grant execute on function public.rizz_set_born(date) to authenticated;

-- ── People ──────────────────────────────────────────────────────────────

create table public.rizz_people (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid()
             references public.profiles (id) on delete cascade,
  name       text not null check (char_length(btrim(name)) between 1 and 40),
  emoji      text check (emoji is null or char_length(emoji) <= 16),
  -- What the user tells Chip: how they know them, what they're hoping for.
  about      text not null default '' check (char_length(about) <= 1000),
  -- What Chip took from a shared chat (the user can edit or clear it).
  memory     text not null default '' check (char_length(memory) <= 4000),
  learned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.rizz_people is 'The people a Chip Rizz user texts, and what Chip knows about each. Private to their owner.';

create index rizz_people_by_user on public.rizz_people (user_id, updated_at desc);

alter table public.rizz_people enable row level security;
revoke all on public.rizz_people from anon, authenticated;
grant select, delete on public.rizz_people to authenticated;
grant insert (name, emoji, about) on public.rizz_people to authenticated;
grant update (name, emoji, about, memory) on public.rizz_people to authenticated;
create policy "your own people" on public.rizz_people
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create function public._rizz_people_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform pg_advisory_xact_lock(hashtext('rizz_people:' || new.user_id::text));
    if (select count(*) from public.rizz_people where user_id = new.user_id) >= 100 then
      raise exception 'too many people';
    end if;
  else
    new.updated_at := now();
  end if;
  new.name := btrim(new.name);
  return new;
end;
$$;

revoke all on function public._rizz_people_guard() from public, anon, authenticated;

create trigger rizz_people_guard
  before insert or update on public.rizz_people
  for each row execute function public._rizz_people_guard();

-- ── Allowances ──────────────────────────────────────────────────────────

/** Who's asking, for Chip: 'maestro', 'guest' or 'free'. */
create function public._chip_tier(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public._maestro_until(p_user) is not null then 'maestro'
    when exists (select 1 from auth.users where id = p_user and is_anonymous) then 'guest'
    else 'free' end;
$$;

revoke all on function public._chip_tier(uuid) from public, anon, authenticated;

create or replace function public._chip_limit(p_kind text, p_tier text)
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
    when 'rizz' then case p_tier when 'guest' then 5 when 'free' then 15 else 300 end
    when 'learn' then case p_tier when 'guest' then 1 when 'free' then 3 else 30 end
  end;
$$;

create or replace function public._chip_count(p_user uuid, p_day date, p_kind text, p_device text)
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
    paints = paints + (p_kind = 'paint')::int,
    rizzes = rizzes + (p_kind = 'rizz')::int,
    learns = learns + (p_kind = 'learn')::int
   where user_id = p_user and day = p_day;
  if p_device is not null then
    update public.chip_device_usage set used = used + 1
     where device = p_device and day = p_day and kind = p_kind;
  end if;
end;
$$;

/** Takes one of today's [p_kind] for the player, if they have one left.
 * {ok, tier, paid, why, price}: why is 'guest' (a guest who's out, or the
 * guests' share of the budget is), 'limit' (an account that's out), 'busy'
 * (the day's budget is spent) or 'coins' (paying, without enough). An
 * account that's out of chats or replies can pass [p_pay] to pay coins for
 * one. */
create or replace function public.chip_allow(
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
  if p_kind not in ('chat', 'vibe', 'draw', 'paint', 'doodle', 'rizz', 'learn') then
    raise exception 'unknown kind';
  end if;
  select * into v_settings from public.chip_settings;
  v_tier := public._chip_tier(v_me);
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
                     when 'draw' then draws when 'doodle' then doodles
                     when 'rizz' then rizzes when 'learn' then learns else paints end
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
  if p_kind not in ('chat', 'rizz') then
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
  perform public._ledger_move(v_me, 'chip_chat', -v_settings.chat_coins, null,
                              jsonb_build_object('kind', p_kind));
  perform public._chip_count(v_me, v_today, p_kind, null);
  return jsonb_build_object('ok', true, 'tier', v_tier, 'paid', true,
                            'price', v_settings.chat_coins);
end;
$$;

/** Gives back a paid [p_kind] call that failed: its coins and its count. */
create function public.chip_refund(p_user uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind not in ('chat', 'rizz') then raise exception 'unknown kind'; end if;
  perform public._ledger_move(p_user, 'chip_chat',
                              (select chat_coins from public.chip_settings), null,
                              jsonb_build_object('refund', true, 'kind', p_kind));
  update public.chip_usage set
    chats = case when p_kind = 'chat' then greatest(chats - 1, 0) else chats end,
    rizzes = case when p_kind = 'rizz' then greatest(rizzes - 1, 0) else rizzes end
   where user_id = p_user and day = (now() at time zone 'utc')::date;
end;
$$;

revoke all on function public.chip_refund(uuid, text) from public, anon, authenticated;
grant execute on function public.chip_refund(uuid, text) to service_role;

/** What Chip Rizz shows the signed-in user: {guest, tier, age, born,
 * born_fixable, rizz_left, learn_left, coins, price}. [p_device]: a guest's
 * device key, whose allowance is shared by every guest on it. */
create function public.rizz_me(p_device text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_tier text;
  v_ages public.rizz_ages;
  v_rizzes int := 0;
  v_learns int := 0;
  v_device_rizzes int := 0;
  v_device_learns int := 0;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  v_tier := public._chip_tier(v_me);
  select * into v_ages from public.rizz_ages where user_id = v_me;
  select coalesce(rizzes, 0), coalesce(learns, 0) into v_rizzes, v_learns
    from public.chip_usage where user_id = v_me and day = v_today;
  if v_tier = 'guest' and p_device ~ '^[A-Za-z0-9_-]{16,64}$' then
    select coalesce(max(used) filter (where kind = 'rizz'), 0),
           coalesce(max(used) filter (where kind = 'learn'), 0)
      into v_device_rizzes, v_device_learns
      from public.chip_device_usage where device = p_device and day = v_today;
  end if;
  return jsonb_build_object(
    'guest', v_tier = 'guest',
    'tier', v_tier,
    'born', v_ages.born,
    'age', case when v_ages.born is null then null else public._age_on(v_ages.born) end,
    'born_fixable', v_ages.set_at is null or v_ages.set_at >= now() - interval '1 day',
    'rizz_left', greatest(public._chip_limit('rizz', v_tier) - greatest(coalesce(v_rizzes, 0), v_device_rizzes), 0),
    'learn_left', greatest(public._chip_limit('learn', v_tier) - greatest(coalesce(v_learns, 0), v_device_learns), 0),
    'coins', (select balance from public.profiles where id = v_me),
    'price', (select chat_coins from public.chip_settings)
  );
end;
$$;

revoke all on function public.rizz_me(text) from public, anon;
grant execute on function public.rizz_me(text) to authenticated;

-- ── A guest signing in to an account ────────────────────────────────────

/** A guest's people move to the account they signed in to, and their date
 * of birth if the account hasn't given one. */
create function public._rizz_take_guest(p_from uuid, p_to uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.rizz_people set user_id = p_to where user_id = p_from;
  insert into public.rizz_ages (user_id, born, set_at)
    select p_to, born, set_at from public.rizz_ages where user_id = p_from
    on conflict (user_id) do nothing;
  delete from public.rizz_ages where user_id = p_from;
end;
$$;

revoke all on function public._rizz_take_guest(uuid, uuid) from public, anon, authenticated;

-- As before, with Chip Rizz's things taken along before the guest retires.
create or replace function public.guest_transfer_finish(p_ticket uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_ticket public.guest_transfers;
  v_result jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from auth.users where id = v_me and is_anonymous) then
    raise exception 'sign in first';
  end if;
  select * into v_ticket from public.guest_transfers where ticket = p_ticket for update;
  -- Used, a week old, the guest that became this account (nothing to
  -- move: it's all here already), or a guest already moved somewhere.
  if not found or v_ticket.done_at is not null
     or v_ticket.created_at < now() - interval '7 days'
     or v_ticket.guest_id = v_me
     or exists (select 1 from public.guest_transfers
                where guest_id = v_ticket.guest_id and done_by is not null) then
    return jsonb_build_object('moved', false);
  end if;
  -- The guest must still be a guest (not since saved to an email of its own).
  if not exists (select 1 from auth.users where id = v_ticket.guest_id and is_anonymous) then
    update public.guest_transfers set done_at = now() where ticket = p_ticket;
    return jsonb_build_object('moved', false);
  end if;
  -- Chip Rizz first: retiring the guest clears its own.
  perform public._rizz_take_guest(v_ticket.guest_id, v_me);
  v_result := public._merge_guest(v_ticket.guest_id, v_me);
  update public.guest_transfers set done_at = now(), done_by = v_me where ticket = p_ticket;
  return v_result;
end;
$$;

-- ── Deleting an account ─────────────────────────────────────────────────

-- As before, and Chip Rizz's people and date of birth go too.
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
  delete from public.player_ratings where user_id = p_user;
  delete from public.rating_changes where user_id = p_user;
  delete from public.chip_doodle_seen where user_id = p_user;
  delete from public.rizz_people where user_id = p_user;
  delete from public.rizz_ages where user_id = p_user;
end;
$$;
