-- Coins bought on the web, through Flutterwave: cards from anywhere, Apple
-- Pay and Google Pay, bank transfer, USSD and mobile money. Each player pays
-- in their own currency when a price is set for it (naira to start), in US
-- dollars otherwise (which any card in the world can pay).
--
--   * web_coin_prices: each pack's price per currency. Add a currency, or
--     change a price, in the SQL editor:
--       insert into web_coin_prices values ('utopia.coins.pouch', 'GHS', 15)
--         on conflict (product_id, currency) do update set amount = excluded.amount;
--   * web_payments: every checkout started, so a payment is matched to the
--     player, pack and price it was for (pending until it's paid).
--   * web_checkout_start: as the player (accounts only: a guest's progress
--     lives in their browser and could be lost with paid coins in it).
--   * credit_web_payment: as the web-pay functions, once Flutterwave
--     confirms the payment: the pack's coins, exactly once
--     (credit_coin_purchase, platform 'web').
--   * Refunds and chargebacks: as for the stores, in the SQL editor:
--       select take_back_coin_purchase('web', '<Flutterwave transaction id>', now());

alter table public.coin_purchases drop constraint coin_purchases_platform_check;
alter table public.coin_purchases add constraint coin_purchases_platform_check
  check (platform in ('ios', 'android', 'web'));

create table public.web_coin_prices (
  product_id text not null references public.coin_packs (product_id) on delete cascade,
  currency   text not null check (currency ~ '^[A-Z]{3}$'),
  amount     numeric(12, 2) not null check (amount > 0),
  primary key (product_id, currency)
);
alter table public.web_coin_prices enable row level security;
revoke all on public.web_coin_prices from anon, authenticated;

-- The phone stores' dollar prices, and naira at about 1,500 to the dollar
-- (round numbers; change them as the rate moves).
insert into public.web_coin_prices (product_id, currency, amount) values
  ('utopia.coins.starter', 'USD', 0.99),
  ('utopia.coins.pouch', 'USD', 0.99),
  ('utopia.coins.sack', 'USD', 4.99),
  ('utopia.coins.chest', 'USD', 9.99),
  ('utopia.coins.vault', 'USD', 19.99),
  ('utopia.coins.mountain', 'USD', 49.99),
  ('utopia.coins.hoard', 'USD', 99.99),
  ('utopia.coins.starter', 'NGN', 1500),
  ('utopia.coins.pouch', 'NGN', 1500),
  ('utopia.coins.sack', 'NGN', 7500),
  ('utopia.coins.chest', 'NGN', 15000),
  ('utopia.coins.vault', 'NGN', 30000),
  ('utopia.coins.mountain', 'NGN', 75000),
  ('utopia.coins.hoard', 'NGN', 150000);

create table public.web_payments (
  ref         text primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  product_id  text not null references public.coin_packs (product_id),
  coins       bigint not null,
  currency    text not null,
  amount      numeric(12, 2) not null,
  provider    text not null default 'flutterwave',
  provider_id text,
  status      text not null default 'pending' check (status in ('pending', 'paid')),
  created_at  timestamptz not null default now(),
  paid_at     timestamptz
);
create index web_payments_by_player on public.web_payments (user_id, created_at desc);
alter table public.web_payments enable row level security;
revoke all on public.web_payments from anon, authenticated;

/** Each pack's price in [p_currency] (US dollars where it has none). */
create function public.web_coin_shop(p_currency text default 'USD')
returns table (product_id text, currency text, amount numeric, coins bigint)
language sql
stable
security definer
set search_path = public
as $$
  select p.product_id, coalesce(local.currency, usd.currency), coalesce(local.amount, usd.amount), p.coins
  from public.coin_packs p
  join public.web_coin_prices usd on usd.product_id = p.product_id and usd.currency = 'USD'
  left join public.web_coin_prices local
    on local.product_id = p.product_id and local.currency = upper(coalesce(p_currency, 'USD'))
  order by p.sort;
$$;

revoke all on function public.web_coin_shop(text) from public, anon;
grant execute on function public.web_coin_shop(text) to authenticated;

/** Starts paying for [p_product]: the price (in [p_currency] when there is
 * one) and the reference the payment goes by. Accounts only. */
create function public.web_checkout_start(p_product text, p_currency text default 'USD')
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
  insert into public.web_payments (ref, user_id, product_id, coins, currency, amount)
  values (v_ref, v_me, p_product, v_price.coins, v_price.currency, v_price.amount);
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

revoke all on function public.web_checkout_start(text, text) from public, anon;
grant execute on function public.web_checkout_start(text, text) to authenticated;

/** Flutterwave confirmed payment [p_provider_id] for checkout [p_ref]: the
 * pack's coins, once, if it was paid in full in the currency asked. */
create function public.credit_web_payment(
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
  return v_result || jsonb_build_object('user_id', v_payment.user_id);
end;
$$;

revoke all on function public.credit_web_payment(text, text, numeric, text, text) from public, anon, authenticated;
grant execute on function public.credit_web_payment(text, text, numeric, text, text) to service_role;
