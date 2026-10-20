-- The Winter event: 13 December to 2 January.
--
--   * Earned by playing while it's on, like Halloween: the Snow Globe frame
--     for 10 games, and Utopia Winter (a snowy night by a frozen lake,
--     Santa's sleigh across the moon) for 15 games over 5 different days.
--     Theirs for good, usable whenever Winter comes round again.
--   * Neither is ever sold: the Snow Globe is in the frame catalog (so it
--     can be worn) but retired, so it's never bought, rented or given in
--     the welcome week; the world isn't in the store at all.

insert into public.events (id, season, title, starts_at, ends_at)
values ('winter_2026', 'winter', 'Winter',
        '2026-12-13 00:00+00', '2027-01-03 12:00+00');

insert into public.event_rewards (event_id, item_id, kind, games, days, sort)
values
  ('winter_2026', 'snow_globe', 'aura', 10, 0, 1),
  ('winter_2026', 'utopia_winter', 'world', 15, 5, 2);

insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort, retired)
values ('snow_globe', 'legendary', 5000, 15000, 60000, 32, true);
