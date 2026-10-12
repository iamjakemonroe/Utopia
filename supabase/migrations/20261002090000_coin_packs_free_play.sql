-- Coin packs (in-app purchases) and free play.
--
--   * _ledger_move ignores zero amounts, so 0-coin ("for fun") games work
--     everywhere: chess matchmaking and invites, Ludo rooms and quick match.
--   * coin_packs maps each store product to the coins it grants; the app
--     never says how many coins to add. claim_coin_purchase credits a pack
--     once per store transaction.
--
-- Like claim_purchase (cosmetics), purchases are trusted until server-side
-- receipt verification is added; every receipt is kept in purchase_receipts
-- so it can be verified retroactively.

create or replace function public._ledger_move(p_user_id uuid, p_type public.ledger_entry_type, p_amount bigint, p_match_id uuid, p_metadata jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_balance bigint;
begin
  if p_amount = 0 then
    return;
  end if;

  update public.profiles
    set balance = balance + p_amount, updated_at = now()
    where id = p_user_id
    returning balance into v_new_balance;

  insert into public.ledger_entries (user_id, entry_type, amount, balance_after, match_id, metadata)
    values (p_user_id, p_type, p_amount, v_new_balance, p_match_id, p_metadata);
end;
$$;

revoke all on function public._ledger_move(uuid, public.ledger_entry_type, bigint, uuid, jsonb) from public;

create table public.coin_packs (
  product_id text primary key,
  coins      bigint not null check (coins > 0),
  sort       int not null default 0
);

alter table public.coin_packs enable row level security;
revoke insert, update, delete on public.coin_packs from authenticated, anon;
create policy "anyone can read coin packs" on public.coin_packs for select using (true);

insert into public.coin_packs (product_id, coins, sort) values
  ('utopia.coins.pouch', 1000, 1),
  ('utopia.coins.sack', 3300, 2),
  ('utopia.coins.chest', 6000, 3),
  ('utopia.coins.vault', 13000, 4),
  ('utopia.coins.mountain', 30000, 5);

create function public.claim_coin_purchase(
  p_platform text,
  p_product_id text,
  p_transaction_id text,
  p_verification text
)
returns bigint -- the player's balance afterwards
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_coins bigint;
  v_receipt uuid;
  v_balance bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select coins into v_coins from public.coin_packs where product_id = p_product_id;
  if v_coins is null then raise exception 'unknown coin pack'; end if;

  insert into public.purchase_receipts (user_id, platform, product_id, transaction_id, verification)
    values (v_me, p_platform, p_product_id, p_transaction_id, p_verification)
    on conflict (platform, transaction_id) do nothing
    returning id into v_receipt;

  -- Already credited (a restore, or the store redelivering): no double pay.
  if v_receipt is not null then
    perform public._ledger_move(
      v_me,
      'purchase_credit',
      v_coins,
      null,
      jsonb_build_object('product_id', p_product_id, 'transaction_id', p_transaction_id)
    );
  end if;

  select balance into v_balance from public.profiles where id = v_me;
  return v_balance;
end;
$$;

revoke all on function public.claim_coin_purchase(text, text, text, text) from public;
grant execute on function public.claim_coin_purchase(text, text, text, text) to authenticated;
