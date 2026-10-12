-- Two bigger coin packs for players who want to go all in.
--   Hoard:     80,000 coins (about $49.99, +60% over the base rate)
--   Treasury: 175,000 coins (about $99.99, +75% over the base rate)

insert into public.coin_packs (product_id, coins, sort) values
  ('utopia.coins.hoard', 80000, 6),
  ('utopia.coins.treasury', 175000, 7)
on conflict (product_id) do update set coins = excluded.coins, sort = excluded.sort;
