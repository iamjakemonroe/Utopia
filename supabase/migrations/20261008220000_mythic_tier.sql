-- The tier above legendary is now called Mythic (it was Epic, which read
-- as lower than legendary). Same auras, same prices.

alter table public.aura_catalog drop constraint aura_catalog_tier_check;

update public.aura_catalog set tier = 'mythic' where tier = 'epic';

alter table public.aura_catalog
  add constraint aura_catalog_tier_check
    check (tier in ('common', 'rare', 'legendary', 'mythic'));
