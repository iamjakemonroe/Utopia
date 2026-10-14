-- Welcome week: a new player's first seven days are on us. Every world that
-- is normally bought or rented, and the Angel Halo aura, are theirs free
-- for a week, so they can feel the whole of Utopia before spending a coin.
-- When the week ends those rentals simply run out, like any other rental,
-- and the player can rent or unlock the ones they loved.
--
--   * profiles.welcome_until: when the week ends (null until it starts).
--     Private, like every new profiles column.
--   * start_welcome_week(): starts the week the first time it's called and
--     says when it ends; after that it only reports. 'fresh' is true on the
--     call that started it, so the app knows to show the welcome.

alter table public.profiles add column welcome_until timestamptz;

create function public.start_welcome_week()
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

  -- Every paid world: the premium Utopia worlds and all 36 color worlds.
  insert into public.world_rentals (user_id, world_id, expires_at)
  select v_me, w, v_until
  from (
    select unnest(array[
      'utopia_calm', 'utopia_adventure', 'utopia_warm', 'utopia_alien',
      'utopia_tech', 'utopia_anime', 'utopia_deep', 'utopia_doodle',
      'utopia_dojo', 'utopia_zombie', 'utopia_heaven', 'utopia_hell'
    ]) as w
    union all
    select f || '_' || s
    from unnest(array[
      'ruby', 'ember', 'sunbeam', 'jade', 'lagoon', 'azure',
      'sapphire', 'amethyst', 'blossom', 'rosegold', 'onyx', 'pearl'
    ]) as f
    cross join unnest(array['dawn', 'dusk', 'midnight']) as s
  ) worlds
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
