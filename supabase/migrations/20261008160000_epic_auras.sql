-- Epic: a tier above legendary, for the wildest auras. The first one is
-- Crimson Fury.

alter table public.aura_catalog
  drop constraint aura_catalog_tier_check,
  add constraint aura_catalog_tier_check
    check (tier in ('common', 'rare', 'legendary', 'epic'));

insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort) values
  ('fury', 'epic', 8000, 24000, 90000, 19)
on conflict (id) do nothing;
