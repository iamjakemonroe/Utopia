-- New worlds, new frames, and a new set of free worlds.
--
--   * Utopia Music and Utopia Halloween: premium worlds like the others,
--     bought with coins (30,000) or rented, part of the every-world pack
--     and the welcome week. Each has a set with a frame worn in it (Encore
--     in Music, Jack's Lantern in Halloween), shown only in the app.
--   * The free worlds are now Utopia Calm, Utopia Warm and Utopia
--     Adventure (with Noir and Azure Dusk, which stay free). Every new
--     player, guest or registered, starts in one of the three at random.
--   * Utopia Dark (shown as Utopia Twilight) becomes a premium world.
--     Everyone who has an account now keeps it for good.

-- Everyone here today keeps Twilight.
insert into public.user_entitlements (user_id, item_id, source)
select id, 'utopia_dark', 'grant' from public.profiles
on conflict (user_id, item_id) do nothing;

create or replace function public._free_item(p_item_id text)
returns boolean
language sql
immutable
as $$
  select p_item_id in (
    'utopia_calm', 'utopia_warm', 'utopia_adventure',
    'azure_dusk', 'noir', 'classic', 'bubble'
  );
$$;

-- New players land in one of the three free worlds, at random.
alter table public.profiles
  alter column equipped_theme
  set default ((array['utopia_calm', 'utopia_warm', 'utopia_adventure'])[1 + floor(random() * 3)::int]);

create or replace function public._world_rent_price(p_world_id text, p_days int)
returns bigint
language sql
immutable
as $$
  select case
    when public._free_item(p_world_id) then null
    when p_world_id in (
      'utopia_dark', 'utopia_alien', 'utopia_tech', 'utopia_anime',
      'utopia_deep', 'utopia_doodle', 'utopia_dojo', 'utopia_zombie',
      'utopia_heaven', 'utopia_hell', 'utopia_music', 'utopia_halloween'
    ) then case p_days when 3 then 2500 when 7 then 6000 when 30 then 20000 end
    when p_world_id ~ '^(ruby|ember|sunbeam|jade|lagoon|azure|sapphire|amethyst|blossom|rosegold|onyx|pearl)_(dawn|dusk|midnight)$'
      then case p_days when 3 then 1200 when 7 then 3000 when 30 then 10000 end
  end;
$$;

-- The free worlds aren't sold any more; Twilight and the new two are.
delete from public.store_coin_prices
 where product_id in (
   'utopia.theme.utopia_calm',
   'utopia.theme.utopia_warm',
   'utopia.theme.utopia_adventure'
 );

insert into public.store_coin_prices (product_id, item_ids, coins, sort)
values
  ('utopia.theme.utopia_dark', array['utopia_dark'], 30000, 0),
  ('utopia.theme.utopia_music', array['utopia_music'], 30000, 12),
  ('utopia.theme.utopia_halloween', array['utopia_halloween'], 30000, 13)
on conflict (product_id) do update
  set item_ids = excluded.item_ids, coins = excluded.coins;

update public.store_coin_prices
   set item_ids = array_append(item_ids, 'utopia_music')
 where product_id = 'utopia.themes.all'
   and not ('utopia_music' = any (item_ids));

update public.store_coin_prices
   set item_ids = array_append(item_ids, 'utopia_halloween')
 where product_id = 'utopia.themes.all'
   and not ('utopia_halloween' = any (item_ids));

-- The new sets' frames.
insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort) values
  ('music', 'legendary', 5000, 15000, 60000, 30),
  ('jack',  'legendary', 5000, 15000, 60000, 31)
on conflict (id) do nothing;

-- The welcome week now covers Twilight and the new worlds (and not the
-- worlds that are free anyway).
create or replace function public.start_welcome_week()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_until timestamptz;
  v_started boolean;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select welcome_until into v_until from public.profiles where id = v_me for update;
  if not found then raise exception 'no profile'; end if;
  if v_until is not null then
    return jsonb_build_object('until', v_until, 'fresh', false);
  end if;

  v_until := now() + interval '7 days';
  update public.profiles set welcome_until = v_until where id = v_me;

  -- Every paid world: the premium Utopia worlds and the color worlds.
  insert into public.world_rentals (user_id, world_id, expires_at)
  select v_me, w, v_until
  from (
    select unnest(array[
      'utopia_dark', 'utopia_alien', 'utopia_tech', 'utopia_anime',
      'utopia_deep', 'utopia_doodle', 'utopia_dojo', 'utopia_zombie',
      'utopia_heaven', 'utopia_hell', 'utopia_music', 'utopia_halloween'
    ]) as w
    union all
    select f || '_' || s
    from unnest(array[
      'ruby', 'ember', 'sunbeam', 'jade', 'lagoon', 'azure',
      'sapphire', 'amethyst', 'blossom', 'rosegold', 'onyx', 'pearl'
    ]) as f
    cross join unnest(array['dawn', 'dusk', 'midnight']) as s
  ) worlds
  where not public._free_item(w)
  on conflict (user_id, world_id)
    do update set expires_at = greatest(world_rentals.expires_at, excluded.expires_at);

  -- The Angel Halo, worn straight away unless they already wear an aura.
  insert into public.user_auras (user_id, aura_id, expires_at)
  values (v_me, 'halo', v_until)
  on conflict (user_id, aura_id)
    do update set expires_at = greatest(user_auras.expires_at, excluded.expires_at);

  update public.profiles
    set equipped_aura = 'halo', aura_expires_at = v_until, updated_at = now()
    where id = v_me
      and (equipped_aura is null or aura_expires_at is null or aura_expires_at < now());

  v_started := true;
  return jsonb_build_object('until', v_until, 'fresh', v_started);
end;
$$;

revoke all on function public.start_welcome_week() from public;
grant execute on function public.start_welcome_week() to authenticated;
