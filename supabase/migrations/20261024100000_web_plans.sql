-- Subscriptions on the web, through Flutterwave payment plans (a card,
-- charged again each period until cancelled), and Chip priced to pay for
-- itself.
--
--   * web_plans / web_plan_prices: what's sold and for how much, in US
--     dollars (Flutterwave converts for cards in other currencies). The
--     coin packs' naira prices go too: everything on the web is in dollars.
--     Change a price in the SQL editor; the Flutterwave plan for it is made
--     by the web-pay function the first time someone pays that price
--     (web_plan_prices.flw_plan_id), so a new price gets a new plan.
--       - Chip Maestro (utopia.maestro.monthly): Utopia's art plan, the same
--         membership as through the App Store or Google Play (a 'web' row in
--         maestro_subscriptions), so every Maestro perk just works.
--       - Chip Rizz Pro (rizz.pro.weekly, rizz.pro.monthly): Smart Chip (the
--         stronger model) on every set of replies, up to 40 sets a day and
--         reply_cap a period, and learn_cap chats read a period.
--   * web_subscriptions: each subscription, from checkout (pending) to
--     active, cancelled (paid up until period_end) or ended; and
--     web_subscription_charges: every payment, credited once.
--   * The functions' ways in (service role): credit_web_subscription (first
--     payment, by checkout reference), renew_web_subscription (each renewal,
--     by Flutterwave plan and email), end_web_subscription (cancelled).
--   * Chip Rizz's tiers: guest, free and pro (_rizz_tier; Chip Maestro is
--     Utopia's plan and doesn't change Chip Rizz). Guests and free accounts
--     get a few sets a day from the fast model; Pro and paid-for sets get the
--     stronger one (chip-rizz decides the model).
--   * Chip Maestro's daily fair use, lower where the smartest model made a
--     heavy member cost more than the plan: 60 chats, 6 drawings and 40
--     colorings a day.
--
-- Prices and periods, e.g.:
--   update web_plan_prices set amount = 12.99 where plan_id = 'rizz.pro.monthly' and currency = 'USD';
--   (also set flw_plan_id = null on that row, so a plan at the new price is made)

alter table public.chip_costs drop constraint chip_costs_tier_check;
alter table public.chip_costs add constraint chip_costs_tier_check
  check (tier in ('guest', 'free', 'maestro', 'pro'));

alter table public.maestro_subscriptions drop constraint maestro_subscriptions_platform_check;
alter table public.maestro_subscriptions add constraint maestro_subscriptions_platform_check
  check (platform in ('ios', 'android', 'web'));

-- ── Plans ───────────────────────────────────────────────────────────────

create table public.web_plans (
  id         text primary key,
  product    text not null check (product in ('maestro', 'rizz_pro')),
  title      text not null,
  period     text not null check (period in ('weekly', 'monthly')),
  days       int not null check (days > 0),
  -- Chip Rizz Pro's fair use per period (null: no cap).
  reply_cap  int check (reply_cap > 0),
  learn_cap  int check (learn_cap > 0),
  sort       int not null default 0
);

insert into public.web_plans (id, product, title, period, days, reply_cap, learn_cap, sort) values
  ('utopia.maestro.monthly', 'maestro', 'Chip Maestro', 'monthly', 30, null, null, 1),
  ('rizz.pro.weekly', 'rizz_pro', 'Chip Rizz Pro (weekly)', 'weekly', 7, 150, 10, 2),
  ('rizz.pro.monthly', 'rizz_pro', 'Chip Rizz Pro (monthly)', 'monthly', 30, 600, 30, 3);

create table public.web_plan_prices (
  plan_id     text not null references public.web_plans (id) on delete cascade,
  currency    text not null check (currency ~ '^[A-Z]{3}$'),
  amount      numeric(12, 2) not null check (amount > 0),
  -- Flutterwave's payment plan for this price (made on first use).
  flw_plan_id text,
  primary key (plan_id, currency)
);

-- What a heavy user can cost (the most a period allows, at today's model
-- prices) stays under each price after Flutterwave's fees; a typical one
-- costs a fraction. See docs/PRICING.md.
insert into public.web_plan_prices (plan_id, currency, amount) values
  ('utopia.maestro.monthly', 'USD', 7.99),
  ('rizz.pro.weekly', 'USD', 3.99),
  ('rizz.pro.monthly', 'USD', 9.99);

-- Dollars only on the web, coins included.
delete from public.web_coin_prices where currency <> 'USD';

alter table public.web_plans enable row level security;
alter table public.web_plan_prices enable row level security;
revoke all on public.web_plans, public.web_plan_prices from anon, authenticated;

-- ── Subscriptions ───────────────────────────────────────────────────────

create table public.web_subscriptions (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.profiles (id) on delete cascade,
  plan_id             text not null references public.web_plans (id),
  currency            text not null,
  amount              numeric(12, 2) not null,
  -- The first checkout's reference; Flutterwave ties the subscription to
  -- the email it was paid with.
  ref                 text not null unique,
  email               text not null,
  flw_plan_id         text,
  status              text not null default 'pending'
                      check (status in ('pending', 'active', 'cancelled', 'ended')),
  period_end          timestamptz,
  environment         text not null default 'production' check (environment in ('production', 'sandbox')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index web_subscriptions_by_user on public.web_subscriptions (user_id, created_at desc);
create index web_subscriptions_by_plan_email on public.web_subscriptions (flw_plan_id, lower(email));

create table public.web_subscription_charges (
  provider_id     text primary key,
  subscription_id uuid not null references public.web_subscriptions (id) on delete cascade,
  amount          numeric(12, 2) not null,
  currency        text not null,
  created_at      timestamptz not null default now()
);

alter table public.web_subscriptions enable row level security;
alter table public.web_subscription_charges enable row level security;
revoke all on public.web_subscriptions, public.web_subscription_charges from anon, authenticated;

/** Whether [p_user] has [p_product] now: the end of what they've paid for. */
create function public._web_plan_until(p_user uuid, p_product text)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select max(s.period_end)
    from public.web_subscriptions s
    join public.web_plans p on p.id = s.plan_id
   where s.user_id = p_user and p.product = p_product
     and s.status in ('active', 'cancelled') and s.period_end > now();
$$;

revoke all on function public._web_plan_until(uuid, text) from public, anon, authenticated;

/** The plans for sale, priced in [p_currency] (dollars where a plan has no
 * price in it), with whether the player already has each. */
create function public.web_plan_shop(p_currency text default 'USD')
returns table (plan_id text, product text, title text, period text, currency text, amount numeric,
               reply_cap int, learn_cap int, until timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.product, p.title, p.period,
         coalesce(local.currency, usd.currency), coalesce(local.amount, usd.amount),
         p.reply_cap, p.learn_cap,
         case p.product
           when 'maestro' then public._maestro_until(auth.uid())
           else public._web_plan_until(auth.uid(), p.product) end
    from public.web_plans p
    join public.web_plan_prices usd on usd.plan_id = p.id and usd.currency = 'USD'
    left join public.web_plan_prices local
      on local.plan_id = p.id and local.currency = upper(coalesce(p_currency, 'USD'))
   order by p.sort;
$$;

revoke all on function public.web_plan_shop(text) from public, anon;
grant execute on function public.web_plan_shop(text) to authenticated;

/** Starts subscribing to [p_plan] (accounts only, and not while already a
 * member of it): the checkout's reference, price and Flutterwave plan (null
 * until the web-pay function has made it, see web_plan_flw). */
create function public.web_subscribe_start(p_plan text, p_currency text default 'USD')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_plan public.web_plans;
  v_price public.web_plan_prices;
  v_email text;
  v_name text;
  v_ref text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select email into v_email from auth.users where id = v_me and not coalesce(is_anonymous, false);
  if v_email is null then raise exception 'save your account first'; end if;
  select * into v_plan from public.web_plans where id = p_plan;
  if not found then raise exception 'unknown plan'; end if;
  if (v_plan.product = 'maestro' and public._maestro_until(v_me) is not null)
     or (v_plan.product <> 'maestro' and public._web_plan_until(v_me, v_plan.product) is not null) then
    raise exception 'already a member';
  end if;
  select * into v_price from public.web_plan_prices
   where plan_id = p_plan and currency = upper(coalesce(p_currency, 'USD'));
  if not found then
    select * into v_price from public.web_plan_prices where plan_id = p_plan and currency = 'USD';
  end if;

  v_ref := 'kaivon-sub-' || replace(gen_random_uuid()::text, '-', '');
  insert into public.web_subscriptions (user_id, plan_id, currency, amount, ref, email, flw_plan_id)
  values (v_me, p_plan, v_price.currency, v_price.amount, v_ref, v_email, v_price.flw_plan_id);
  select coalesce(display_name, username) into v_name from public.profiles where id = v_me;
  return jsonb_build_object(
    'ref', v_ref,
    'plan', p_plan,
    'product', v_plan.product,
    'title', v_plan.title,
    'period', v_plan.period,
    'amount', v_price.amount,
    'currency', v_price.currency,
    'flw_plan_id', v_price.flw_plan_id,
    'email', v_email,
    'name', v_name
  );
end;
$$;

revoke all on function public.web_subscribe_start(text, text) from public, anon;
grant execute on function public.web_subscribe_start(text, text) to authenticated;

/** The web-pay function made Flutterwave's plan for a price: kept for every
 * later checkout at that price, and on the checkout [p_ref] waiting for it. */
create function public.web_plan_flw(p_plan text, p_currency text, p_flw_plan_id text, p_ref text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.web_plan_prices set flw_plan_id = p_flw_plan_id
   where plan_id = p_plan and currency = p_currency and flw_plan_id is null;
  update public.web_subscriptions set flw_plan_id = p_flw_plan_id, updated_at = now()
   where ref = p_ref and flw_plan_id is null;
$$;

revoke all on function public.web_plan_flw(text, text, text, text) from public, anon, authenticated;
grant execute on function public.web_plan_flw(text, text, text, text) to service_role;

/** A payment for [p_sub], once: the period paid for starts now (or when the
 * last one ends, if that's later), and a Maestro plan shows as Maestro. */
create function public._web_subscription_paid(
  p_sub public.web_subscriptions,
  p_provider_id text,
  p_amount numeric,
  p_currency text,
  p_environment text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan public.web_plans;
  v_end timestamptz;
begin
  if upper(p_currency) <> p_sub.currency or p_amount < p_sub.amount then
    raise exception 'paid % %, expected % %', p_amount, p_currency, p_sub.amount, p_sub.currency;
  end if;
  insert into public.web_subscription_charges (provider_id, subscription_id, amount, currency)
    values (p_provider_id, p_sub.id, p_amount, upper(p_currency))
    on conflict (provider_id) do nothing;
  if not found then
    return jsonb_build_object('user_id', p_sub.user_id, 'until', p_sub.period_end, 'again', true);
  end if;
  select * into v_plan from public.web_plans where id = p_sub.plan_id;
  -- A day's grace for the next charge to go through.
  v_end := greatest(coalesce(p_sub.period_end, now()), now()) + make_interval(days => v_plan.days + 1);
  update public.web_subscriptions
     set status = 'active', period_end = v_end,
         environment = case when p_environment = 'sandbox' then 'sandbox' else 'production' end,
         updated_at = now()
   where id = p_sub.id;
  if v_plan.product = 'maestro' then
    perform public.maestro_record(p_sub.user_id, 'web', p_sub.plan_id, 'web:' || p_sub.ref, v_end, true,
                                  case when p_environment = 'sandbox' then 'sandbox' else 'production' end);
  end if;
  return jsonb_build_object('user_id', p_sub.user_id, 'product', v_plan.product, 'until', v_end);
end;
$$;

revoke all on function public._web_subscription_paid(public.web_subscriptions, text, numeric, text, text)
  from public, anon, authenticated;

/** Flutterwave confirmed the first payment [p_provider_id] for checkout
 * [p_ref]. */
create function public.credit_web_subscription(
  p_ref text,
  p_provider_id text,
  p_amount numeric,
  p_currency text,
  p_environment text default 'production'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.web_subscriptions;
begin
  select * into v_sub from public.web_subscriptions where ref = p_ref for update;
  if not found then raise exception 'unknown subscription'; end if;
  return public._web_subscription_paid(v_sub, p_provider_id, p_amount, p_currency, p_environment);
end;
$$;

/** A renewal: Flutterwave charged [p_email] again on plan [p_flw_plan_id]. */
create function public.renew_web_subscription(
  p_flw_plan_id text,
  p_email text,
  p_provider_id text,
  p_amount numeric,
  p_currency text,
  p_environment text default 'production'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.web_subscriptions;
begin
  select * into v_sub from public.web_subscriptions
   where flw_plan_id = p_flw_plan_id and lower(email) = lower(p_email) and status <> 'pending'
   order by created_at desc limit 1 for update;
  if not found then raise exception 'unknown subscription'; end if;
  return public._web_subscription_paid(v_sub, p_provider_id, p_amount, p_currency, p_environment);
end;
$$;

/** Cancelled (by the member, or after failed renewals): paid-up time is
 * kept, nothing more is charged. */
create function public.end_web_subscription(p_flw_plan_id text, p_email text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.web_subscriptions;
begin
  update public.web_subscriptions
     set status = case when period_end > now() then 'cancelled' else 'ended' end, updated_at = now()
   where id = (select id from public.web_subscriptions
                where flw_plan_id = p_flw_plan_id and lower(email) = lower(p_email)
                  and status in ('active', 'cancelled')
                order by created_at desc limit 1)
  returning * into v_sub;
  if v_sub.id is null then return jsonb_build_object('ended', false); end if;
  if v_sub.plan_id = 'utopia.maestro.monthly' then
    update public.maestro_subscriptions set auto_renew = false, updated_at = now()
     where original_id = 'web:' || v_sub.ref;
  end if;
  return jsonb_build_object('ended', true, 'user_id', v_sub.user_id, 'until', v_sub.period_end);
end;
$$;

revoke all on function public.credit_web_subscription(text, text, numeric, text, text) from public, anon, authenticated;
revoke all on function public.renew_web_subscription(text, text, text, numeric, text, text) from public, anon, authenticated;
revoke all on function public.end_web_subscription(text, text) from public, anon, authenticated;
grant execute on function public.credit_web_subscription(text, text, numeric, text, text) to service_role;
grant execute on function public.renew_web_subscription(text, text, text, numeric, text, text) to service_role;
grant execute on function public.end_web_subscription(text, text) to service_role;

/** The player's web subscription to [p_product] that can be cancelled: what
 * the web-pay function needs to cancel it with Flutterwave. */
create function public.web_subscription_mine(p_product text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object('flw_plan_id', s.flw_plan_id, 'email', s.email, 'until', s.period_end,
                            'status', s.status, 'plan', s.plan_id)
    from public.web_subscriptions s
    join public.web_plans p on p.id = s.plan_id
   where s.user_id = auth.uid() and p.product = p_product and s.status in ('active', 'cancelled')
   order by s.created_at desc limit 1;
$$;

revoke all on function public.web_subscription_mine(text) from public, anon;
grant execute on function public.web_subscription_mine(text) to authenticated;

-- ── Chip Rizz's tiers and fair use ──────────────────────────────────────

/** Who's asking, for Chip Rizz: 'pro', 'guest' or 'free'. */
create function public._rizz_tier(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public._web_plan_until(p_user, 'rizz_pro') is not null then 'pro'
    when exists (select 1 from auth.users where id = p_user and is_anonymous) then 'guest'
    else 'free' end;
$$;

revoke all on function public._rizz_tier(uuid) from public, anon, authenticated;

create or replace function public._chip_limit(p_kind text, p_tier text)
returns int
language sql
immutable
as $$
  select case p_kind
    when 'chat' then case p_tier when 'guest' then 10 when 'free' then 20 else 60 end
    when 'vibe' then case p_tier when 'guest' then 50 else 150 end
    when 'draw' then case p_tier when 'guest' then 1 when 'free' then 4 else 6 end
    when 'doodle' then case p_tier when 'guest' then 3 when 'free' then 6 else 12 end
    when 'paint' then case p_tier when 'guest' then 5 when 'free' then 20 else 40 end
    when 'rizz' then case p_tier when 'guest' then 3 when 'free' then 5 else 40 end
    when 'learn' then case p_tier when 'guest' then 1 when 'free' then 1 else 3 end
  end;
$$;

/** How many [p_kind] a Chip Rizz Pro member has had this period, and the
 * period's cap: {used, cap}. */
create function public._rizz_period(p_user uuid, p_kind text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with plan as (
    select s.period_end, p.days, case p_kind when 'rizz' then p.reply_cap else p.learn_cap end as cap
      from public.web_subscriptions s join public.web_plans p on p.id = s.plan_id
     where s.user_id = p_user and p.product = 'rizz_pro'
       and s.status in ('active', 'cancelled') and s.period_end > now()
     order by s.period_end desc limit 1
  )
  select jsonb_build_object(
    'cap', plan.cap,
    'used', coalesce((select sum(case p_kind when 'rizz' then u.rizzes else u.learns end)
                        from public.chip_usage u
                       where u.user_id = p_user
                         and u.day > ((plan.period_end - make_interval(days => plan.days + 1)) at time zone 'utc')::date), 0))
  from plan;
$$;

revoke all on function public._rizz_period(uuid, text) from public, anon, authenticated;

/** As before, with Chip Rizz's own tiers (and a Pro member's cap a period)
 * for 'rizz' and 'learn'. */
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
  v_price int;
  v_period jsonb;
  v_over boolean := false;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('chat', 'vibe', 'draw', 'paint', 'doodle', 'rizz', 'learn') then
    raise exception 'unknown kind';
  end if;
  select * into v_settings from public.chip_settings;
  v_price := case when p_kind = 'rizz' then v_settings.rizz_coins else v_settings.chat_coins end;
  v_tier := case when p_kind in ('rizz', 'learn') then public._rizz_tier(v_me) else public._chip_tier(v_me) end;
  v_limit := public._chip_limit(p_kind, v_tier);
  if v_tier = 'guest' and p_device ~ '^[A-Za-z0-9_-]{16,64}$' then
    v_device := p_device;
  end if;
  if v_tier = 'pro' then
    v_period := public._rizz_period(v_me, p_kind);
    v_over := (v_period ->> 'cap') is not null and (v_period ->> 'used')::int >= (v_period ->> 'cap')::int;
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

  -- The day's budget, for everyone who isn't paying.
  if v_tier not in ('maestro', 'pro') then
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

  if not v_busy and not v_over and v_used < v_limit and v_device_used < v_limit then
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
                              'price', v_price);
  end if;
  select balance into v_balance from public.profiles where id = v_me for update;
  if coalesce(v_balance, 0) < v_price then
    return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'coins', 'price', v_price);
  end if;
  perform public._ledger_move(v_me, 'chip_chat', -v_price, null,
                              jsonb_build_object('kind', p_kind));
  perform public._chip_count(v_me, v_today, p_kind, null);
  return jsonb_build_object('ok', true, 'tier', v_tier, 'paid', true, 'price', v_price);
end;
$$;

/** As before, with Chip Rizz Pro: {guest, tier, pro_until, ..., rizz_left,
 * learn_left (today's, and within a Pro member's period), coins, price}. */
create or replace function public.rizz_me(p_device text default null)
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
  v_rizz_left int;
  v_learn_left int;
  v_period jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  v_tier := public._rizz_tier(v_me);
  select * into v_ages from public.rizz_ages where user_id = v_me;
  select coalesce(rizzes, 0), coalesce(learns, 0) into v_rizzes, v_learns
    from public.chip_usage where user_id = v_me and day = v_today;
  if v_tier = 'guest' and p_device ~ '^[A-Za-z0-9_-]{16,64}$' then
    select coalesce(max(used) filter (where kind = 'rizz'), 0),
           coalesce(max(used) filter (where kind = 'learn'), 0)
      into v_device_rizzes, v_device_learns
      from public.chip_device_usage where device = p_device and day = v_today;
  end if;
  v_rizz_left := greatest(public._chip_limit('rizz', v_tier) - greatest(coalesce(v_rizzes, 0), v_device_rizzes), 0);
  v_learn_left := greatest(public._chip_limit('learn', v_tier) - greatest(coalesce(v_learns, 0), v_device_learns), 0);
  if v_tier = 'pro' then
    v_period := public._rizz_period(v_me, 'rizz');
    v_rizz_left := least(v_rizz_left, greatest((v_period ->> 'cap')::int - (v_period ->> 'used')::int, 0));
    v_period := public._rizz_period(v_me, 'learn');
    v_learn_left := least(v_learn_left, greatest((v_period ->> 'cap')::int - (v_period ->> 'used')::int, 0));
  end if;
  return jsonb_build_object(
    'guest', v_tier = 'guest',
    'tier', v_tier,
    'pro_until', public._web_plan_until(v_me, 'rizz_pro'),
    'born', v_ages.born,
    'age', case when v_ages.born is null then null else public._age_on(v_ages.born) end,
    'born_fixable', v_ages.set_at is null or v_ages.set_at >= now() - interval '1 day',
    'rizz_left', v_rizz_left,
    'learn_left', v_learn_left,
    'coins', (select balance from public.profiles where id = v_me),
    'price', (select rizz_coins from public.chip_settings)
  );
end;
$$;
