-- Noir: a pure black-and-white world, free for everyone.

create or replace function public._free_item(p_item_id text)
returns boolean
language sql
immutable
as $$
  select p_item_id in ('utopia_dark', 'azure_dusk', 'noir', 'classic', 'bubble');
$$;
