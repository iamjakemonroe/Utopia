-- Two legendary auras: Zombie Bite (toxic fire and chomping jaws) and
-- Demon (horns, crimson smoke and a long tail), the Angel Halo's opposite.

insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort) values
  ('zombie', 'legendary', 5000, 15000, 60000, 28),
  ('demon',  'legendary', 5000, 15000, 60000, 29)
on conflict (id) do nothing;
