-- Testing: undoes give_winter.sql, so the player can earn Winter again
-- from the start. Put the player's user ID below, then Run.
do $$
declare
  v_user uuid := '00000000-0000-0000-0000-000000000000';  -- <- the player's user ID
begin
  perform 1 from auth.users where id = v_user;
  if not found then
    raise exception 'No account with the ID %', v_user;
  end if;
  delete from public.season_items where user_id = v_user and event_id = 'winter_2026';
  delete from public.event_claims where user_id = v_user and event_id = 'winter_2026';
  delete from public.event_progress where user_id = v_user and event_id = 'winter_2026';
  delete from public.world_rentals where user_id = v_user and world_id = 'utopia_winter';
  delete from public.user_auras where user_id = v_user and aura_id = 'snow_globe';
  update public.profiles
     -- Back to a free world: a player always has one on.
     set equipped_theme = case when equipped_theme = 'utopia_winter' then 'utopia_calm' else equipped_theme end,
         equipped_aura = case when equipped_aura = 'snow_globe' then null else equipped_aura end,
         aura_expires_at = case when equipped_aura = 'snow_globe' then null else aura_expires_at end
   where id = v_user;
  raise notice 'Winter taken back';
end $$;
