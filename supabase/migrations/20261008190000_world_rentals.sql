-- Worlds for coins.
--
-- Besides unlocking a world for good in the app store, a player can rent
-- one with coins for 3 days, a week or a month, the same way auras work.
-- Renting again while it is still active adds the days on the end.
--
--   * The premium Utopia worlds and the color worlds can be rented; free
--     worlds cannot be (they are free already).
--   * Prices live here, never in the app.
--   * equip_item now accepts a world with an active rental.

alter type public.ledger_entry_type add value if not exists 'world_rental';

create table public.world_rentals (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  world_id   text not null,
  expires_at timestamptz not null,
  primary key (user_id, world_id)
);

alter table public.world_rentals enable row level security;
revoke insert, update, delete on public.world_rentals from authenticated, anon;
create policy "see your own world rentals" on public.world_rentals
  for select using (user_id = auth.uid());

-- What a rental costs, or null if that world cannot be rented.
create function public._world_rent_price(p_world_id text, p_days int)
returns bigint
language sql
immutable
as $$
  select case
    when public._free_item(p_world_id) then null
    when p_world_id in (
      'utopia_calm', 'utopia_adventure', 'utopia_warm',
      'utopia_alien', 'utopia_tech', 'utopia_anime', 'utopia_deep'
    ) then case p_days when 3 then 2500 when 7 then 6000 when 30 then 20000 end
    when p_world_id ~ '^(ruby|ember|sunbeam|jade|lagoon|azure|sapphire|amethyst|blossom|rosegold|onyx|pearl)_(dawn|dusk|midnight)$'
      then case p_days when 3 then 1200 when 7 then 3000 when 30 then 10000 end
  end;
$$;

create function public.rent_world(p_world_id text, p_days int)
returns timestamptz -- when it now runs out
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_price bigint := public._world_rent_price(p_world_id, p_days);
  v_balance bigint;
  v_from timestamptz;
  v_expires timestamptz;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if v_price is null then raise exception 'that world can''t be rented for that long'; end if;

  select balance into v_balance from public.profiles where id = v_me for update;
  if v_balance < v_price then raise exception 'insufficient balance'; end if;

  select greatest(expires_at, now()) into v_from
    from public.world_rentals where user_id = v_me and world_id = p_world_id;
  v_expires := coalesce(v_from, now()) + make_interval(days => p_days);

  perform public._ledger_move(
    v_me, 'world_rental', -v_price, null,
    jsonb_build_object('world', p_world_id, 'days', p_days)
  );

  insert into public.world_rentals (user_id, world_id, expires_at)
    values (v_me, p_world_id, v_expires)
    on conflict (user_id, world_id) do update set expires_at = excluded.expires_at;

  update public.profiles set equipped_theme = p_world_id, updated_at = now() where id = v_me;
  return v_expires;
end;
$$;

revoke all on function public.rent_world(text, int) from public;
grant execute on function public.rent_world(text, int) to authenticated;

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
     and not (
       p_kind = 'theme' and exists (
         select 1 from public.world_rentals
         where user_id = v_me and world_id = p_item_id and expires_at > now()
       )
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
