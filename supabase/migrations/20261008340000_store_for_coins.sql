-- The store for coins (first release): worlds, colour families and piece
-- sets are bought with coins, the price and contents set here on the
-- server and checked on every purchase. Real-money top-ups come later,
-- with receipts verified by the stores.
--
-- Until then, the old claim functions are closed: they took the app's word
-- for what was paid for, which would let anyone grant themselves coins or
-- items.

revoke execute on function public.claim_purchase(text, text, text, text, text[]) from authenticated;
revoke execute on function public.claim_coin_purchase(text, text, text, text) from authenticated;

alter type public.ledger_entry_type add value if not exists 'store_purchase';

alter table public.user_entitlements drop constraint user_entitlements_source_check;
alter table public.user_entitlements
  add constraint user_entitlements_source_check check (source in ('purchase', 'grant', 'coins'));

create table public.store_coin_prices (
  product_id text primary key,
  item_ids   text[] not null check (cardinality(item_ids) between 1 and 64),
  coins      bigint not null check (coins > 0),
  sort       int not null default 0
);

alter table public.store_coin_prices enable row level security;
revoke insert, update, delete on public.store_coin_prices from authenticated, anon;
create policy "anyone can read store prices" on public.store_coin_prices for select using (true);

-- 10,000 coins for each dollar of the store price the app shows today (a
-- premium world is 30,000 for keeps, against 20,000 to rent it a month).
insert into public.store_coin_prices (product_id, item_ids, coins, sort) values
  ('utopia.theme.utopia_calm', array['utopia_calm'], 30000, 0),
  ('utopia.theme.utopia_adventure', array['utopia_adventure'], 30000, 1),
  ('utopia.theme.utopia_warm', array['utopia_warm'], 30000, 2),
  ('utopia.theme.utopia_alien', array['utopia_alien'], 30000, 3),
  ('utopia.theme.utopia_tech', array['utopia_tech'], 30000, 4),
  ('utopia.theme.utopia_anime', array['utopia_anime'], 30000, 5),
  ('utopia.theme.utopia_deep', array['utopia_deep'], 30000, 6),
  ('utopia.theme.utopia_doodle', array['utopia_doodle'], 30000, 7),
  ('utopia.theme.utopia_dojo', array['utopia_dojo'], 30000, 8),
  ('utopia.themes.ruby', array['ruby_dawn', 'ruby_dusk', 'ruby_midnight'], 20000, 9),
  ('utopia.themes.ember', array['ember_dawn', 'ember_dusk', 'ember_midnight'], 20000, 10),
  ('utopia.themes.sunbeam', array['sunbeam_dawn', 'sunbeam_dusk', 'sunbeam_midnight'], 20000, 11),
  ('utopia.themes.jade', array['jade_dawn', 'jade_dusk', 'jade_midnight'], 20000, 12),
  ('utopia.themes.lagoon', array['lagoon_dawn', 'lagoon_dusk', 'lagoon_midnight'], 20000, 13),
  ('utopia.themes.azure', array['azure_dawn', 'azure_dusk', 'azure_midnight'], 20000, 14),
  ('utopia.themes.sapphire', array['sapphire_dawn', 'sapphire_dusk', 'sapphire_midnight'], 20000, 15),
  ('utopia.themes.amethyst', array['amethyst_dawn', 'amethyst_dusk', 'amethyst_midnight'], 20000, 16),
  ('utopia.themes.blossom', array['blossom_dawn', 'blossom_dusk', 'blossom_midnight'], 20000, 17),
  ('utopia.themes.rosegold', array['rosegold_dawn', 'rosegold_dusk', 'rosegold_midnight'], 20000, 18),
  ('utopia.themes.onyx', array['onyx_dawn', 'onyx_dusk', 'onyx_midnight'], 20000, 19),
  ('utopia.themes.pearl', array['pearl_dawn', 'pearl_dusk', 'pearl_midnight'], 20000, 20),
  ('utopia.themes.all', array['utopia_dark', 'noir', 'utopia_calm', 'utopia_adventure', 'utopia_warm', 'utopia_alien', 'utopia_tech', 'utopia_anime', 'utopia_deep', 'utopia_doodle', 'utopia_dojo', 'ruby_dawn', 'ruby_dusk', 'ruby_midnight', 'ember_dawn', 'ember_dusk', 'ember_midnight', 'sunbeam_dawn', 'sunbeam_dusk', 'sunbeam_midnight', 'jade_dawn', 'jade_dusk', 'jade_midnight', 'lagoon_dawn', 'lagoon_dusk', 'lagoon_midnight', 'azure_dawn', 'azure_dusk', 'azure_midnight', 'sapphire_dawn', 'sapphire_dusk', 'sapphire_midnight', 'amethyst_dawn', 'amethyst_dusk', 'amethyst_midnight', 'blossom_dawn', 'blossom_dusk', 'blossom_midnight', 'rosegold_dawn', 'rosegold_dusk', 'rosegold_midnight', 'onyx_dawn', 'onyx_dusk', 'onyx_midnight', 'pearl_dawn', 'pearl_dusk', 'pearl_midnight'], 100000, 21),
  ('utopia.pieces.jelly', array['jelly'], 40000, 22),
  ('utopia.pieces.crystal', array['crystal'], 40000, 23),
  ('utopia.pieces.candy', array['candy'], 40000, 24),
  ('utopia.pieces.cosmic', array['cosmic'], 50000, 25),
  ('utopia.pieces.royal', array['royal'], 50000, 26),
  ('utopia.chess.buddies', array['chess_buddies'], 40000, 27),
  ('utopia.chess.monsters', array['chess_monsters'], 50000, 28),
  ('utopia.chess.robots', array['chess_robots'], 50000, 29),
  ('utopia.chess.crystal', array['chess_crystal'], 40000, 30),
  ('utopia.chess.royal', array['chess_royal'], 50000, 31),
  ('utopia.chess.neon', array['chess_neon'], 40000, 32),
  ('utopia.chess.candy', array['chess_candy'], 40000, 33);

-- Buys [p_product_id] with coins: takes the price, then unlocks every item
-- in it. Owning all of it already costs nothing.
create function public.buy_with_coins(p_product_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_product public.store_coin_prices;
  v_balance bigint;
  v_item text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_product from public.store_coin_prices where product_id = p_product_id;
  if v_product is null then raise exception 'unknown product'; end if;

  if not exists (
    select 1 from unnest(v_product.item_ids) as i(item)
     where not exists (
       select 1 from public.user_entitlements e
        where e.user_id = v_me and e.item_id = i.item
     )
  ) then
    return;
  end if;

  select balance into v_balance from public.profiles where id = v_me for update;
  if v_balance < v_product.coins then raise exception 'insufficient balance'; end if;

  perform public._ledger_move(
    v_me,
    'store_purchase',
    -v_product.coins,
    null,
    jsonb_build_object('product', p_product_id)
  );

  foreach v_item in array v_product.item_ids loop
    insert into public.user_entitlements (user_id, item_id, source, product_id)
      values (v_me, v_item, 'coins', p_product_id)
      on conflict (user_id, item_id) do nothing;
  end loop;
end;
$$;

revoke all on function public.buy_with_coins(text) from public;
grant execute on function public.buy_with_coins(text) to authenticated;
