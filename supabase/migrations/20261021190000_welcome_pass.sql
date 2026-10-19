-- The welcome pass (replaces the welcome week for new players): for their
-- first three days, everything in Utopia's store is theirs to use: every
-- world, every frame on sale, every chess set and piece set. Not Chip
-- Maestro, not coins, and not what's earned (event worlds and frames, the
-- Birthday world).
--
-- It's all lent, the way rentals are, until profiles.welcome_until:
--   * worlds, chess sets and piece sets: world_rentals rows (one table
--     for everything lent for a while; equip_item now takes a rental of
--     any kind);
--   * frames: user_auras rows that run out then.
-- When it ends, it goes back to normal: rentals and frames run out by
-- themselves, the app takes them back to a world of theirs, and a lent
-- set that's still on goes back to the classic one (settle_lent_sets,
-- every 15 minutes, and the app at once). Whatever they paid for stays:
-- coins they bought, anything bought with coins, Chip Maestro.
--
-- Started once, by start_welcome_week() (the app calls it on arriving
-- home), so only new players get it; those already past their welcome
-- week don't.

create or replace function public.equip_item(p_kind text, p_item_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not public._free_item(p_item_id)
     and not exists (
       select 1 from public.user_entitlements where user_id = v_me and item_id = p_item_id
     )
     and not exists (
       select 1 from public.world_rentals
       where user_id = v_me and world_id = p_item_id and expires_at > now()
     ) then
    raise exception 'you don''t own that yet';
  end if;

  case p_kind
    when 'theme' then update public.profiles set equipped_theme = p_item_id where id = v_me;
    when 'ludo_pieces' then update public.profiles set equipped_ludo_pieces = p_item_id where id = v_me;
    when 'chess_pieces' then update public.profiles set equipped_chess_pieces = p_item_id where id = v_me;
    else raise exception 'invalid item kind';
  end case;
end;
$$;

create or replace function public.start_welcome_week()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_until timestamptz;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select welcome_until into v_until from public.profiles where id = v_me for update;
  if not found then raise exception 'no profile'; end if;
  if v_until is not null then
    return jsonb_build_object('until', v_until, 'fresh', false);
  end if;

  v_until := now() + interval '3 days';
  update public.profiles set welcome_until = v_until where id = v_me;

  -- Everything the store sells: worlds, chess sets and piece sets.
  insert into public.world_rentals (user_id, world_id, expires_at)
  select distinct v_me, item, v_until
  from public.store_coin_prices, unnest(item_ids) as item
  where not public._free_item(item)
  on conflict (user_id, world_id)
    do update set expires_at = greatest(world_rentals.expires_at, excluded.expires_at);

  -- Every frame on sale.
  insert into public.user_auras (user_id, aura_id, expires_at)
  select v_me, id, v_until from public.aura_catalog where not retired
  on conflict (user_id, aura_id)
    do update set expires_at = greatest(user_auras.expires_at, excluded.expires_at);

  -- The Angel Halo, worn straight away unless they already wear a frame.
  update public.profiles
    set equipped_aura = 'halo', aura_expires_at = v_until, updated_at = now()
    where id = v_me
      and exists (select 1 from public.aura_catalog where id = 'halo')
      and (equipped_aura is null or aura_expires_at is null or aura_expires_at < now());

  return jsonb_build_object('until', v_until, 'fresh', true);
end;
$$;

/** Takes off lent chess and piece sets whose time ran out (back to the
 * classic ones). Returns how many were taken off. */
create function public.settle_lent_sets()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ludo int;
  v_chess int;
begin
  update public.profiles p
     set equipped_ludo_pieces = 'classic', updated_at = now()
   where not public._free_item(p.equipped_ludo_pieces)
     and not exists (select 1 from public.house_players h where h.id = p.id)
     and not exists (select 1 from public.user_entitlements e
                     where e.user_id = p.id and e.item_id = p.equipped_ludo_pieces)
     and not exists (select 1 from public.world_rentals r
                     where r.user_id = p.id and r.world_id = p.equipped_ludo_pieces
                       and r.expires_at > now());
  get diagnostics v_ludo = row_count;
  update public.profiles p
     set equipped_chess_pieces = 'classic', updated_at = now()
   where not public._free_item(p.equipped_chess_pieces)
     and not exists (select 1 from public.house_players h where h.id = p.id)
     and not exists (select 1 from public.user_entitlements e
                     where e.user_id = p.id and e.item_id = p.equipped_chess_pieces)
     and not exists (select 1 from public.world_rentals r
                     where r.user_id = p.id and r.world_id = p.equipped_chess_pieces
                       and r.expires_at > now());
  get diagnostics v_chess = row_count;
  return v_ludo + v_chess;
end;
$$;

revoke all on function public.settle_lent_sets() from public, anon, authenticated;

select cron.schedule(
  'settle-lent-sets',
  '*/15 * * * *',
  $$select public.settle_lent_sets()$$
);
