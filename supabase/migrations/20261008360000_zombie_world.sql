-- Utopia Zombie, the graveyard world: a premium world like the others,
-- bought with coins (30,000) or rented, and part of the every-world pack.

create or replace function public._world_rent_price(p_world_id text, p_days int)
returns bigint
language sql
immutable
as $$
  select case
    when public._free_item(p_world_id) then null
    when p_world_id in (
      'utopia_calm', 'utopia_adventure', 'utopia_warm',
      'utopia_alien', 'utopia_tech', 'utopia_anime', 'utopia_deep',
      'utopia_doodle', 'utopia_dojo', 'utopia_zombie'
    ) then case p_days when 3 then 2500 when 7 then 6000 when 30 then 20000 end
    when p_world_id ~ '^(ruby|ember|sunbeam|jade|lagoon|azure|sapphire|amethyst|blossom|rosegold|onyx|pearl)_(dawn|dusk|midnight)$'
      then case p_days when 3 then 1200 when 7 then 3000 when 30 then 10000 end
  end;
$$;

insert into public.store_coin_prices (product_id, item_ids, coins, sort)
values ('utopia.theme.utopia_zombie', array['utopia_zombie'], 30000, 9)
on conflict (product_id) do update
  set item_ids = excluded.item_ids, coins = excluded.coins;

update public.store_coin_prices
   set item_ids = array_append(item_ids, 'utopia_zombie')
 where product_id = 'utopia.themes.all'
   and not ('utopia_zombie' = any (item_ids));
