-- Chip Maestro: the monthly art plan, sold through the App Store and Play
-- Store as an auto-renewing subscription (utopia.maestro.monthly). Real
-- portraits cost real money to make, so they come with the plan instead of
-- coins: 30 a month for members, and one free for everyone to try.
--
--   * maestro_subscriptions: each member's subscription as the store last
--     confirmed it (written only by the verify-purchase and
--     store-notifications functions). One account per subscription.
--   * maestro_record / maestro_expire: those functions' way in (service
--     role only). Members also wear the Maestro frame (a not-for-sale
--     aura) while their plan lasts.
--   * chip_portrait_pay / chip_portrait_offer: no coins any more: members
--     use their monthly allowance, everyone else their one free portrait.
--   * coloring_pages.premium: a famous person's real portrait is drawn once
--     and shared with every member who asks for them (it costs nothing the
--     second time), but it never shows up in the free library.
--   * chip_take: members get more of Chip's own drawings and colorings a
--     day.
--   * my_maestro: the app's view of the player's plan.

create table public.maestro_subscriptions (
  user_id     uuid primary key references public.profiles (id) on delete cascade,
  platform    text not null check (platform in ('ios', 'android')),
  product_id  text not null,
  -- Apple's original transaction id, or Google's purchase token.
  original_id text not null unique,
  expires_at  timestamptz not null,
  auto_renew  boolean not null default true,
  environment text not null default 'production'
                check (environment in ('production', 'sandbox')),
  started_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.maestro_subscriptions enable row level security;
revoke all on public.maestro_subscriptions from anon, authenticated;

-- The Maestro frame: worn by members, never sold.
insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort, retired)
values ('maestro', 'legendary', 1, 1, 1, 99, true)
on conflict (id) do update set retired = true;

/** The subscription [p_original] (for [p_user]) as the store says it is
 * now; the Maestro frame lasts as long. */
create function public.maestro_record(
  p_user uuid,
  p_platform text,
  p_product text,
  p_original text,
  p_expires timestamptz,
  p_auto_renew boolean,
  p_environment text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select user_id into v_owner from public.maestro_subscriptions where original_id = p_original;
  if v_owner is not null and v_owner <> p_user then
    raise exception 'subscription belongs to another account';
  end if;

  insert into public.maestro_subscriptions as m (
    user_id, platform, product_id, original_id, expires_at, auto_renew, environment
  )
  values (p_user, p_platform, p_product, p_original, p_expires, p_auto_renew, p_environment)
  on conflict (user_id) do update set
    platform = excluded.platform,
    product_id = excluded.product_id,
    original_id = excluded.original_id,
    expires_at = excluded.expires_at,
    auto_renew = excluded.auto_renew,
    environment = excluded.environment,
    updated_at = now();

  insert into public.user_auras (user_id, aura_id, expires_at)
    values (p_user, 'maestro', p_expires)
    on conflict (user_id, aura_id) do update set expires_at = excluded.expires_at;
  update public.profiles set aura_expires_at = p_expires, updated_at = now()
    where id = p_user and equipped_aura = 'maestro';

  return jsonb_build_object('active', p_expires > now(), 'until', p_expires);
end;
$$;

/** Ends subscription [p_original] at [p_at] (refunded or revoked). */
create function public.maestro_expire(p_original text, p_at timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_until timestamptz;
begin
  update public.maestro_subscriptions
    set expires_at = least(expires_at, p_at), auto_renew = false, updated_at = now()
    where original_id = p_original
    returning user_id, expires_at into v_user, v_until;
  if v_user is null then return; end if;
  update public.user_auras set expires_at = v_until
    where user_id = v_user and aura_id = 'maestro';
  update public.profiles set aura_expires_at = v_until, updated_at = now()
    where id = v_user and equipped_aura = 'maestro';
end;
$$;

/** When [p_user]'s plan runs out, if it's still going. */
create function public._maestro_until(p_user uuid)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select expires_at from public.maestro_subscriptions
    where user_id = p_user and expires_at > now();
$$;

alter table public.chip_portraits add column kind text not null default 'free'
  check (kind in ('free', 'coins', 'maestro'));
update public.chip_portraits set kind = 'coins' where coins > 0;

/** Portraits [p_user] has used this month of their plan. */
create function public._maestro_used(p_user uuid, p_until timestamptz)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int from public.chip_portraits
    where user_id = p_user and kind = 'maestro' and not refunded
      and created_at >= p_until - interval '1 month';
$$;

drop function public.chip_portrait_pay(uuid);

-- Takes one of [p_user]'s portraits: from their plan's monthly 30, or
-- their one free one. Raises 'needs maestro', 'maestro limit' or
-- 'portrait limit' (a day's worth). Returns {id, kind, left}.
create function public.chip_portrait_pay(p_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  v_until timestamptz;
  v_used int;
  v_kind text;
  v_id bigint;
begin
  perform 1 from public.profiles where id = p_user for update;

  if (select count(*) from public.chip_portraits
        where user_id = p_user and not refunded and created_at >= v_today) >= 10
     or (select count(*) from public.chip_portraits
        where not refunded and created_at >= v_today) >= 500 then
    raise exception 'portrait limit';
  end if;

  v_until := public._maestro_until(p_user);
  if v_until is not null then
    v_used := public._maestro_used(p_user, v_until);
    if v_used >= 30 then raise exception 'maestro limit'; end if;
    v_kind := 'maestro';
  elsif not exists (
    select 1 from public.chip_portraits where user_id = p_user and not refunded
  ) then
    v_kind := 'free';
  else
    raise exception 'needs maestro';
  end if;

  insert into public.chip_portraits (user_id, coins, kind) values (p_user, 0, v_kind)
    returning id into v_id;
  return jsonb_build_object(
    'id', v_id,
    'kind', v_kind,
    'left', case when v_kind = 'maestro' then 29 - v_used else 0 end
  );
end;
$$;

drop function public.chip_portrait_offer(uuid);

-- What a portrait means for [p_user] right now: {state: 'maestro' (with
-- left this month) | 'free' (their one free one) | 'locked', left}.
create function public.chip_portrait_offer(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_until timestamptz := public._maestro_until(p_user);
begin
  if v_until is not null then
    return jsonb_build_object(
      'state', 'maestro',
      'left', greatest(0, 30 - public._maestro_used(p_user, v_until))
    );
  end if;
  return jsonb_build_object(
    'state',
    case when exists (
      select 1 from public.chip_portraits where user_id = p_user and not refunded
    ) then 'locked' else 'free' end,
    'left', 0
  );
end;
$$;

revoke all on function public.chip_portrait_pay(uuid) from public, anon, authenticated;
revoke all on function public.chip_portrait_offer(uuid) from public, anon, authenticated;
revoke all on function public.maestro_record(uuid, text, text, text, timestamptz, boolean, text) from public, anon, authenticated;
revoke all on function public.maestro_expire(text, timestamptz) from public, anon, authenticated;
revoke all on function public._maestro_until(uuid) from public, anon, authenticated;
revoke all on function public._maestro_used(uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.chip_portrait_pay(uuid) to service_role;
grant execute on function public.chip_portrait_offer(uuid) to service_role;
grant execute on function public.maestro_record(uuid, text, text, text, timestamptz, boolean, text) to service_role;
grant execute on function public.maestro_expire(text, timestamptz) to service_role;

-- The player's plan: {active, until, auto_renew, left (portraits this
-- month), free (their free portrait is still there)}.
create function public.my_maestro()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_sub public.maestro_subscriptions;
  v_offer jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_sub from public.maestro_subscriptions where user_id = v_me;
  v_offer := public.chip_portrait_offer(v_me);
  return jsonb_build_object(
    'active', v_sub.expires_at is not null and v_sub.expires_at > now(),
    'until', v_sub.expires_at,
    'auto_renew', coalesce(v_sub.auto_renew, false),
    'left', (v_offer ->> 'left')::int,
    'free', v_offer ->> 'state' = 'free'
  );
end;
$$;

revoke all on function public.my_maestro() from public, anon;
grant execute on function public.my_maestro() to authenticated;

-- Famous people's real portraits: shared between members, kept out of the
-- free library.
alter table public.coloring_pages add column premium boolean not null default false;

drop policy "the library, your own pictures, and ones you asked for" on public.coloring_pages;

create policy "the library, your own pictures, and ones you asked for"
  on public.coloring_pages for select to authenticated
  using (
    (owner is null and status = 'ready' and not premium)
    or owner = auth.uid()
    or exists (
      select 1 from public.coloring_asks a
      where a.page_id = coloring_pages.id and a.user_id = auth.uid()
    )
  );

-- A shared portrait's line art (coloring-art/shared/<page id>.png) is for
-- whoever has asked for that page.
create policy "players read shared portraits they asked for"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'coloring-art'
    and (storage.foldername(name))[1] = 'shared'
    and exists (
      select 1 from public.coloring_asks a
      where a.user_id = auth.uid()
        and a.page_id::text = split_part(storage.filename(name), '.', 1)
    )
  );

-- Members get more of Chip's own drawings (10 a day) and colorings (100).
create or replace function public.chip_take(p_kind text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_member boolean;
  v_used int;
  v_everyone int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('chat', 'vibe', 'draw', 'paint') then
    raise exception 'unknown kind';
  end if;
  v_member := public._maestro_until(v_me) is not null;

  insert into public.chip_usage (user_id, day) values (v_me, v_today)
    on conflict (user_id, day) do nothing;

  if p_kind = 'chat' then
    update public.chip_usage set chats = chats + 1
      where user_id = v_me and day = v_today and chats < 40
      returning chats into v_used;
  elsif p_kind = 'vibe' then
    update public.chip_usage set vibes = vibes + 1
      where user_id = v_me and day = v_today and vibes < 150
      returning vibes into v_used;
  elsif p_kind = 'draw' then
    select coalesce(sum(draws), 0) into v_everyone
      from public.chip_usage where day = v_today;
    if v_everyone >= 300 then return false; end if;
    update public.chip_usage set draws = draws + 1
      where user_id = v_me and day = v_today
        and draws < case when v_member then 10 else 4 end
      returning draws into v_used;
  else
    select coalesce(sum(paints), 0) into v_everyone
      from public.chip_usage where day = v_today;
    if v_everyone >= 3000 then return false; end if;
    update public.chip_usage set paints = paints + 1
      where user_id = v_me and day = v_today
        and paints < case when v_member then 100 else 20 end
      returning paints into v_used;
  end if;

  return v_used is not null;
end;
$$;

revoke all on function public.chip_take(text) from public;
grant execute on function public.chip_take(text) to authenticated;
