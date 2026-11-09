-- A notification for every purchase, 2026-11-09.
--
-- The buyer hears about each payment that's credited, in Utopia's
-- notifications (live, like the rest): coins bought on the web from any app
-- (Utopia, Chip Rizz or Chip Study), a web subscription's first payment and
-- each renewal, and coins or Chip Maestro bought in the App Store or Google
-- Play (verify-purchase).
--
-- The notification is written by the same SQL that credits the payment, in
-- the same transaction, so it comes exactly once whichever of the webhook
-- and the return from checkout gets there first, and never for a payment
-- that isn't paid (those functions are only called for successful ones,
-- and a wrong amount or currency raises and writes nothing).
--
-- kind 'purchase', data:
--   app        'utopia', 'chip' or 'study': where it was bought (a web
--              subscription's app is its plan's: Chip Maestro is Utopia's)
--   product_id the coin pack or plan
--   title      for people: '20,000 coins', 'Chip Maestro', 'Chip Study Pro'
--   coins      a coin pack's coins (absent for a plan)
--   amount, currency  what was paid (absent for the App Store and Google
--              Play, which don't tell the server the price)
--   renewal    true for a subscription's later payments
--   period     a plan's 'weekly' or 'monthly'
--   platform   'ios' or 'android' for a store purchase
--   ref        the web checkout's reference
--
-- web_payments.app: the app a web coin checkout was started from,
-- web_checkout_start's new p_app (the web-pay function passes it).

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('friend_request', 'friend_accepted', 'game_invite',
                  'friend_birthday', 'birthday_wish', 'coin_gift',
                  'report_update', 'purchase'));

alter table public.web_payments
  add column app text not null default 'utopia' check (app in ('utopia', 'chip', 'study'));

/** Tells [p_user] about a purchase (see the top of this file). */
create function public._purchase_notify(p_user uuid, p_data jsonb)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (user_id, kind, data)
  select p_user, 'purchase', jsonb_strip_nulls(p_data)
   where exists (select 1 from public.profiles where id = p_user);
$$;

revoke all on function public._purchase_notify(uuid, jsonb) from public, anon, authenticated;

/** '20,000 coins'. */
create function public._coins_title(p_coins bigint)
returns text
language sql
immutable
as $$
  select to_char(p_coins, 'FM999,999,999,999') || ' coins';
$$;

revoke all on function public._coins_title(bigint) from public, anon, authenticated;

-- ── Coins: the App Store and Google Play ────────────────────────────────────

-- As in 20261014110000_real_coin_top_ups.sql, and a store purchase credited
-- now is notified (a web one is, by credit_web_payment, which knows the
-- price and the app).
create or replace function public.credit_coin_purchase(
  p_user_id uuid,
  p_platform text,
  p_transaction_id text,
  p_order_id text,
  p_product_id text,
  p_quantity int,
  p_environment text,
  p_purchased_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_coins bigint;
  v_id bigint;
  v_owner uuid;
  v_balance bigint;
begin
  select coins into v_coins from public.coin_packs where product_id = p_product_id;
  if v_coins is null then raise exception 'unknown coin pack'; end if;
  v_coins := v_coins * greatest(coalesce(p_quantity, 1), 1);

  insert into public.coin_purchases (
    user_id, platform, transaction_id, order_id, product_id, quantity,
    coins, environment, purchased_at
  )
  values (
    p_user_id, p_platform, p_transaction_id, p_order_id, p_product_id,
    greatest(coalesce(p_quantity, 1), 1), v_coins, p_environment, p_purchased_at
  )
  on conflict (platform, transaction_id) do nothing
  returning id into v_id;

  if v_id is null then
    select user_id into v_owner
      from public.coin_purchases
      where platform = p_platform and transaction_id = p_transaction_id;
    if v_owner is distinct from p_user_id then
      raise exception 'purchase belongs to another account';
    end if;
  else
    perform public._ledger_move(
      p_user_id,
      'purchase_credit',
      v_coins,
      null,
      jsonb_build_object('product_id', p_product_id, 'platform', p_platform, 'purchase', v_id)
    );
    if p_platform in ('ios', 'android') then
      perform public._purchase_notify(p_user_id, jsonb_build_object(
        'app', 'utopia',
        'product_id', p_product_id,
        'title', public._coins_title(v_coins),
        'coins', v_coins,
        'renewal', false,
        'platform', p_platform
      ));
    end if;
  end if;

  select balance into v_balance from public.profiles where id = p_user_id;
  return jsonb_build_object('credited', v_id is not null, 'coins', v_coins, 'balance', v_balance);
end;
$$;

-- ── Coins on the web ────────────────────────────────────────────────────────

drop function public.web_checkout_start(text, text);

/** Starts paying for [p_product]: the price (in [p_currency] when there is
 * one) and the reference the payment goes by. Accounts only. [p_app] is the
 * app it's bought in ('utopia', 'chip' or 'study'). */
create function public.web_checkout_start(p_product text, p_currency text default 'USD',
                                          p_app text default 'utopia')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_price record;
  v_ref text;
  v_name text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from auth.users where id = v_me and is_anonymous) then
    raise exception 'save your account first';
  end if;
  if p_product = 'utopia.coins.starter' and exists (
    select 1 from public.coin_purchases where user_id = v_me and product_id = p_product
  ) then
    raise exception 'starter pack already bought';
  end if;
  select * into v_price from public.web_coin_shop(p_currency) where product_id = p_product;
  if not found then raise exception 'unknown coin pack'; end if;

  v_ref := 'utopia-' || replace(gen_random_uuid()::text, '-', '');
  insert into public.web_payments (ref, user_id, product_id, coins, currency, amount, app)
  values (v_ref, v_me, p_product, v_price.coins, v_price.currency, v_price.amount,
          case when p_app in ('chip', 'study') then p_app else 'utopia' end);
  select coalesce(display_name, username) into v_name from public.profiles where id = v_me;
  return jsonb_build_object(
    'ref', v_ref,
    'amount', v_price.amount,
    'currency', v_price.currency,
    'coins', v_price.coins,
    'name', v_name
  );
end;
$$;

revoke all on function public.web_checkout_start(text, text, text) from public, anon;
grant execute on function public.web_checkout_start(text, text, text) to authenticated;

/** Flutterwave confirmed payment [p_provider_id] for checkout [p_ref]: the
 * pack's coins, once, if it was paid in full in the currency asked, and the
 * buyer is told. */
create or replace function public.credit_web_payment(
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
  v_payment public.web_payments;
  v_result jsonb;
begin
  select * into v_payment from public.web_payments where ref = p_ref for update;
  if not found then raise exception 'unknown payment'; end if;
  if upper(p_currency) <> v_payment.currency or p_amount < v_payment.amount then
    raise exception 'paid % %, expected % %', p_amount, p_currency, v_payment.amount, v_payment.currency;
  end if;
  v_result := public.credit_coin_purchase(
    v_payment.user_id, 'web', p_provider_id, p_ref, v_payment.product_id, 1,
    case when p_environment = 'sandbox' then 'sandbox' else 'production' end, now()
  );
  update public.web_payments
     set status = 'paid', provider_id = p_provider_id, paid_at = coalesce(paid_at, now())
   where ref = p_ref;
  if (v_result ->> 'credited')::boolean then
    perform public._purchase_notify(v_payment.user_id, jsonb_build_object(
      'app', v_payment.app,
      'product_id', v_payment.product_id,
      'title', public._coins_title(v_payment.coins),
      'coins', v_payment.coins,
      'amount', v_payment.amount,
      'currency', v_payment.currency,
      'renewal', false,
      'ref', p_ref
    ));
  end if;
  return v_result || jsonb_build_object('user_id', v_payment.user_id,
                                        'amount', v_payment.amount, 'currency', v_payment.currency);
end;
$$;

-- ── Web subscriptions: the first payment and each renewal ───────────────────

/** A payment for [p_sub], once: the period paid for starts now (or when the
 * last one ends, if that's later), a Maestro plan shows as Maestro, and the
 * member is told (a renewal when an earlier payment was credited). */
create or replace function public._web_subscription_paid(
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
  v_renewal boolean;
begin
  if upper(p_currency) <> p_sub.currency or p_amount < p_sub.amount then
    raise exception 'paid % %, expected % %', p_amount, p_currency, p_sub.amount, p_sub.currency;
  end if;
  v_renewal := exists (select 1 from public.web_subscription_charges where subscription_id = p_sub.id);
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
  perform public._purchase_notify(p_sub.user_id, jsonb_build_object(
    'app', case v_plan.product when 'rizz_pro' then 'chip' when 'study_pro' then 'study' else 'utopia' end,
    'product_id', p_sub.plan_id,
    'title', v_plan.title,
    'amount', p_sub.amount,
    'currency', p_sub.currency,
    'renewal', v_renewal,
    'period', v_plan.period,
    'ref', p_sub.ref
  ));
  return jsonb_build_object('user_id', p_sub.user_id, 'product', v_plan.product, 'until', v_end,
                            'amount', p_sub.amount, 'currency', p_sub.currency);
end;
$$;

-- ── Chip Maestro from the App Store and Google Play ─────────────────────────

/** The subscription [p_original] (for [p_user]) as the store says it is
 * now; the Maestro frame lasts as long. A store plan that starts (the
 * player had none, or it had run out) is notified; the web's are, by
 * _web_subscription_paid. Store renewals aren't: the store's expiry date
 * alone can't tell a paid renewal from a grace period. */
create or replace function public.maestro_record(
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
  v_was timestamptz;
begin
  select user_id into v_owner from public.maestro_subscriptions where original_id = p_original;
  if v_owner is not null and v_owner <> p_user then
    raise exception 'subscription belongs to another account';
  end if;
  select expires_at into v_was from public.maestro_subscriptions where user_id = p_user;

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

  if p_platform in ('ios', 'android') and p_expires > now() and (v_was is null or v_was <= now()) then
    perform public._purchase_notify(p_user, jsonb_build_object(
      'app', 'utopia',
      'product_id', p_product,
      'title', 'Chip Maestro',
      'renewal', false,
      'period', 'monthly',
      'platform', p_platform
    ));
  end if;

  return jsonb_build_object('active', p_expires > now(), 'until', p_expires);
end;
$$;
