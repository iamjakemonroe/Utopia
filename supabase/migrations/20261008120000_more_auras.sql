-- Ten more auras, priced like the others in their tier.

insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort) values
  ('hearts',    'common',    3000,  9000, 35000,  9),
  ('fireflies', 'common',    3000,  9000, 35000, 10),
  ('starlight', 'common',    3000,  9000, 35000, 11),
  ('autumn',    'common',    3000,  9000, 35000, 12),
  ('neon',      'rare',      4000, 12000, 45000, 13),
  ('tidal',     'rare',      4000, 12000, 45000, 14),
  ('halo',      'rare',      4000, 12000, 45000, 15),
  ('phoenix',   'legendary', 5000, 15000, 60000, 16),
  ('galaxy',    'legendary', 5000, 15000, 60000, 17),
  ('shadow',    'legendary', 5000, 15000, 60000, 18)
on conflict (id) do nothing;
