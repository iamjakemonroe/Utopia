-- Fewer, clearer prices.
--
--   * Coin packs top out at $99.99: the $199.99 and $399.99 packs are gone.
--   * A world is rented for a week (or bought for good): no 3-day or
--     month rentals.
--   * A frame is worn for a week or a month: no 3-day wears.

delete from public.coin_packs
 where product_id in ('utopia.coins.treasury', 'utopia.coins.kingdom');

create or replace function public._world_rent_price(p_world_id text, p_days int)
returns bigint
language sql
immutable
as $$
  select case
    when p_days <> 7 or public._free_item(p_world_id) then null
    when p_world_id in (
      'utopia_dark', 'utopia_alien', 'utopia_tech', 'utopia_anime',
      'utopia_deep', 'utopia_doodle', 'utopia_dojo', 'utopia_zombie',
      'utopia_heaven', 'utopia_hell', 'utopia_music'
    ) then 6000
    when p_world_id ~ '^(ruby|ember|sunbeam|jade|lagoon|azure|sapphire|amethyst|blossom|rosegold|onyx|pearl)_(dawn|dusk|midnight)$'
      then 3000
  end;
$$;

create or replace function public.buy_aura(p_aura_id text, p_days int)
returns timestamptz -- when it now runs out
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_aura public.aura_catalog;
  v_price bigint;
  v_balance bigint;
  v_from timestamptz;
  v_expires timestamptz;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_aura from public.aura_catalog where id = p_aura_id;
  if v_aura is null then raise exception 'unknown aura'; end if;
  if v_aura.retired then raise exception 'that aura is no longer sold'; end if;

  v_price := case p_days
    when 7 then v_aura.price_7d
    when 30 then v_aura.price_30d
  end;
  if v_price is null then raise exception 'auras come for a week or a month'; end if;

  select balance into v_balance from public.profiles where id = v_me for update;
  if v_balance < v_price then raise exception 'insufficient balance'; end if;

  -- Still wearing time left? The new days go on the end.
  select greatest(expires_at, now()) into v_from
    from public.user_auras where user_id = v_me and aura_id = p_aura_id;
  v_expires := coalesce(v_from, now()) + make_interval(days => p_days);

  perform public._ledger_move(
    v_me,
    'aura_purchase',
    -v_price,
    null,
    jsonb_build_object('aura', p_aura_id, 'days', p_days)
  );

  insert into public.user_auras (user_id, aura_id, expires_at)
    values (v_me, p_aura_id, v_expires)
    on conflict (user_id, aura_id) do update set expires_at = excluded.expires_at;

  update public.profiles
    set equipped_aura = p_aura_id, aura_expires_at = v_expires, updated_at = now()
    where id = v_me;

  return v_expires;
end;
$$;

revoke all on function public.buy_aura(text, int) from public;
grant execute on function public.buy_aura(text, int) to authenticated;
