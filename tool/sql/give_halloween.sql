-- Testing: gives one player everything Halloween 2026 offers, as if they'd
-- finished 15 games over 5 days: Jack's Lantern (frame) and the Utopia
-- Halloween world. Uses the same award the game does, so it's theirs for
-- good and in their hands until the event ends (2 Nov).
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the player's
-- email on the line below, then Run. Reopen the app afterwards.
-- (A guest account has no email: use its username instead, see below.)
do $$
declare
  v_email text := 'you@example.com';   -- <- the player's email
  v_user uuid;
  v_event public.events;
  v_given text[];
begin
  select id into v_user from auth.users where lower(email) = lower(v_email);
  -- For a guest: select id into v_user from public.profiles where username = 'their_username';
  if v_user is null then
    raise exception 'No account with the email %', v_email;
  end if;

  select * into v_event from public.events where id = 'halloween_2026';
  if v_event.id is null then
    raise exception 'The Halloween 2026 event is missing';
  end if;

  insert into public.event_progress (user_id, event_id, games, days, last_day)
  values (v_user, v_event.id, 15, 5, (now() at time zone 'utc')::date)
  on conflict (user_id, event_id) do update
    set games = greatest(event_progress.games, 15),
        days = greatest(event_progress.days, 5);

  v_given := public._event_award(v_user, v_event);
  raise notice 'Given: %', coalesce(nullif(array_to_string(v_given, ', '), ''), 'nothing new (they had it all)');
end $$;
