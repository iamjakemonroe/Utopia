-- Dragon Coil: a Mythic aura. A dragon wound round the picture, breathing
-- fire; worn in the Dojo world, the world's own dragon flies free.

insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort) values
  ('dragon', 'mythic', 8000, 24000, 90000, 18)
on conflict (id) do nothing;
