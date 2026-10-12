-- More auras: the storm in five more colors (legendary, like Violet Storm),
-- and three more epics.

insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort) values
  ('storm_white', 'legendary', 5000, 15000, 60000, 20),
  ('storm_blue',  'legendary', 5000, 15000, 60000, 21),
  ('storm_green', 'legendary', 5000, 15000, 60000, 22),
  ('storm_gold',  'legendary', 5000, 15000, 60000, 23),
  ('storm_pink',  'legendary', 5000, 15000, 60000, 24),
  ('supernova',   'epic',      8000, 24000, 90000, 25),
  ('blackhole',   'epic',      8000, 24000, 90000, 26),
  ('frostfire',   'epic',      8000, 24000, 90000, 27)
on conflict (id) do nothing;
