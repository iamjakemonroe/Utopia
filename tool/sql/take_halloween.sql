-- Testing: undoes give_halloween.sql, so the player can earn Halloween
-- again from the start. Put the player's email below, then Run.
do $$
declare
  v_email text := 'you@example.com';   -- <- the player's email
  v_user uuid;
begin
  select id into v_user from auth.users where lower(email) = lower(v_email);
  if v_user is null then
    raise exception 'No account with the email %', v_email;
  end if;
  delete from public.season_items where user_id = v_user and event_id = 'halloween_2026';
  delete from public.event_claims where user_id = v_user and event_id = 'halloween_2026';
  delete from public.event_progress where user_id = v_user and event_id = 'halloween_2026';
  delete from public.world_rentals where user_id = v_user and world_id = 'utopia_halloween';
  delete from public.user_auras where user_id = v_user and aura_id = 'jack';
  update public.profiles
     set equipped_theme = case when equipped_theme = 'utopia_halloween' then null else equipped_theme end,
         equipped_aura = case when equipped_aura = 'jack' then null else equipped_aura end
   where id = v_user;
  raise notice 'Halloween taken back';
end $$;
