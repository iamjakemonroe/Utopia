-- Utopia Doodle, the ink-on-paper world, can be rented with coins like
-- the other premium worlds.

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
      'utopia_doodle'
    ) then case p_days when 3 then 2500 when 7 then 6000 when 30 then 20000 end
    when p_world_id ~ '^(ruby|ember|sunbeam|jade|lagoon|azure|sapphire|amethyst|blossom|rosegold|onyx|pearl)_(dawn|dusk|midnight)$'
      then case p_days when 3 then 1200 when 7 then 3000 when 30 then 10000 end
  end;
$$;
