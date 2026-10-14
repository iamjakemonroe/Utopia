-- Real coin top-ups, checked with Apple and Google.
--
--   * coin_packs: the new ladder. About 10,000 coins per dollar (the rate
--     the store's coin prices were set at), with a bonus that grows with
--     the pack, plus a starter pack each player can buy once.
--   * coin_purchases: every top-up the App Store or Play Store confirmed,
--     one row per store transaction, so a payment is only ever paid out
--     once. Only the verify-purchase and store-notifications functions
--     write here (through the functions below, as the service role).
--   * credit_coin_purchase adds a confirmed pack's coins.
--     take_back_coin_purchase takes them back when the store refunds the
--     payment (as many as are left; the rest is recorded), and
--     return_coin_purchase gives them back if the refund is reversed.
--   * coin_shop_offers tells the app whether the starter pack is still on.
--
-- The old claim functions stay closed: they took the app's word for it.

alter type public.ledger_entry_type add value if not exists 'purchase_refund';

delete from public.coin_packs
  where product_id not in (
    'utopia.coins.starter', 'utopia.coins.pouch', 'utopia.coins.sack',
    'utopia.coins.chest', 'utopia.coins.vault', 'utopia.coins.mountain',
    'utopia.coins.hoard', 'utopia.coins.treasury', 'utopia.coins.kingdom'
  );

insert into public.coin_packs (product_id, coins, sort) values
  ('utopia.coins.starter', 20000, 0),      -- $0.99, once per player
  ('utopia.coins.pouch', 10000, 1),        -- $0.99
  ('utopia.coins.sack', 55000, 2),         -- $4.99, +10%
  ('utopia.coins.chest', 120000, 3),       -- $9.99, +20%
  ('utopia.coins.vault', 260000, 4),       -- $19.99, +30%
  ('utopia.coins.mountain', 750000, 5),    -- $49.99, +50%
  ('utopia.coins.hoard', 1600000, 6),      -- $99.99, +60%
  ('utopia.coins.treasury', 3500000, 7),   -- $199.99, +75%
  ('utopia.coins.kingdom', 8000000, 8)     -- $399.99, +100%
on conflict (product_id) do update set coins = excluded.coins, sort = excluded.sort;

create table public.coin_purchases (
  id               bigint generated always as identity primary key,
  user_id          uuid references public.profiles (id) on delete set null,
  platform         text not null check (platform in ('ios', 'android')),
  -- Apple's transaction id, or Google's purchase token.
  transaction_id   text not null,
  -- Google's order id (GPA....), or Apple's original transaction id.
  order_id         text,
  product_id       text not null,
  quantity         int not null default 1 check (quantity between 1 and 10),
  coins            bigint not null check (coins > 0),
  -- 'production', or 'sandbox' for Apple sandbox / TestFlight and Google
  -- license testers.
  environment      text not null default 'production'
                     check (environment in ('production', 'sandbox')),
  purchased_at     timestamptz,
  created_at       timestamptz not null default now(),
  revoked_at       timestamptz,
  coins_taken_back bigint not null default 0,
  unique (platform, transaction_id)
);

create index coin_purchases_by_player on public.coin_purchases (user_id, created_at desc);

alter table public.coin_purchases enable row level security;
revoke all on public.coin_purchases from anon, authenticated;

comment on table public.coin_purchases is 'Coin top-ups confirmed by the App Store Server API or the Play Developer API. Written only by the verify-purchase and store-notifications Edge Functions.';

-- Adds a confirmed pack's coins to [p_user_id]. Calling it again for the
-- same store transaction pays nothing more (the store redelivers
-- purchases until the app finishes them).
create function public.credit_coin_purchase(
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
  end if;

  select balance into v_balance from public.profiles where id = p_user_id;
  return jsonb_build_object('credited', v_id is not null, 'coins', v_coins, 'balance', v_balance);
end;
$$;

-- The store refunded a top-up: take its coins back, as many as are left.
create function public.take_back_coin_purchase(
  p_platform text,
  p_transaction_id text,
  p_revoked_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.coin_purchases;
  v_take bigint := 0;
begin
  select * into v_row
    from public.coin_purchases
    where platform = p_platform and transaction_id = p_transaction_id
    for update;
  if not found then return jsonb_build_object('found', false); end if;
  if v_row.revoked_at is not null then
    return jsonb_build_object('found', true, 'already', true);
  end if;

  if v_row.user_id is not null then
    select least(balance, v_row.coins) into v_take
      from public.profiles where id = v_row.user_id for update;
    v_take := coalesce(v_take, 0);
    if v_take > 0 then
      perform public._ledger_move(
        v_row.user_id,
        'purchase_refund',
        -v_take,
        null,
        jsonb_build_object('product_id', v_row.product_id, 'platform', p_platform, 'purchase', v_row.id)
      );
    end if;
  end if;

  update public.coin_purchases
    set revoked_at = coalesce(p_revoked_at, now()), coins_taken_back = v_take
    where id = v_row.id;
  return jsonb_build_object('found', true, 'taken_back', v_take, 'coins', v_row.coins);
end;
$$;

-- A refund was reversed: give back the coins that were taken.
create function public.return_coin_purchase(
  p_platform text,
  p_transaction_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.coin_purchases;
begin
  select * into v_row
    from public.coin_purchases
    where platform = p_platform and transaction_id = p_transaction_id
    for update;
  if not found or v_row.revoked_at is null then
    return jsonb_build_object('found', found, 'returned', 0);
  end if;

  if v_row.user_id is not null and v_row.coins_taken_back > 0 then
    perform public._ledger_move(
      v_row.user_id,
      'purchase_credit',
      v_row.coins_taken_back,
      null,
      jsonb_build_object('product_id', v_row.product_id, 'platform', p_platform, 'purchase', v_row.id, 'refund_reversed', true)
    );
  end if;

  update public.coin_purchases
    set revoked_at = null, coins_taken_back = 0
    where id = v_row.id;
  return jsonb_build_object('found', true, 'returned', v_row.coins_taken_back);
end;
$$;

revoke all on function public.credit_coin_purchase(uuid, text, text, text, text, int, text, timestamptz) from public, anon, authenticated;
revoke all on function public.take_back_coin_purchase(text, text, timestamptz) from public, anon, authenticated;
revoke all on function public.return_coin_purchase(text, text) from public, anon, authenticated;
grant execute on function public.credit_coin_purchase(uuid, text, text, text, text, int, text, timestamptz) to service_role;
grant execute on function public.take_back_coin_purchase(text, text, timestamptz) to service_role;
grant execute on function public.return_coin_purchase(text, text) to service_role;

-- What the coin shop can offer this player: the starter pack until
-- they've bought it.
create function public.coin_shop_offers()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'starter', not exists (
      select 1 from public.coin_purchases
      where user_id = auth.uid() and product_id = 'utopia.coins.starter'
    )
  );
$$;

revoke all on function public.coin_shop_offers() from public, anon;
grant execute on function public.coin_shop_offers() to authenticated;
