-- No house cut: the winner takes the whole pot.
--
-- Coins can be bought, and a cut taken from a pot that players pay into
-- reads as a house edge, which the App Store and Play Store review as
-- gambling. commission_bps stays, at 0, so settlement (which skips a zero
-- cut) needs no change.
--
--   * New chess, checkers and Ludo games: no cut.
--   * Games still waiting or being played pay out in full too.

alter table public.matches alter column commission_bps set default 0;
alter table public.ludo_matches alter column commission_bps set default 0;

update public.matches set commission_bps = 0
  where status in ('pending', 'active') and commission_bps <> 0;
update public.ludo_matches set commission_bps = 0
  where status in ('pending', 'active') and commission_bps <> 0;

comment on column public.matches.commission_bps is
  'Platform cut of the pot in basis points. 0: the winner takes the whole pot.';
comment on column public.ludo_matches.commission_bps is
  'Platform cut of the pot in basis points. 0: the winner takes the whole pot.';
