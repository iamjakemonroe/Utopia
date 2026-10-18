-- Testing: gives one player everything Halloween 2026 offers, as if they'd
-- finished 15 games over 5 days: Jack's Lantern (frame) and the Utopia
-- Halloween world, and puts both on. Uses the same award the game does,
-- so they're theirs until the event ends (2 Nov). Guests too.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the player's
-- user ID on the line below, then Run. Reopen the app afterwards.
-- The ID is in Authentication > Users (guests show as Anonymous), or the
-- id column of the profiles table. Undo with take_halloween.sql.
do $$
declare
  v_user uuid := '00000000-0000-0000-0000-000000000000';  -- <- the player's user ID
  v_put_on boolean := true;  -- false: just give them, don't put them on
  v_guest boolean;
  v_event public.events;
  v_given text[];
begin
  select coalesce(is_anonymous, false) into v_guest from auth.users where id = v_user;
  if not found then
    raise exception 'No account with the ID %', v_user;
  end if;

  select * into v_event from public.events where id = 'halloween_2026';
  if v_event.id is null then
    raise exception 'The Halloween 2026 event is missing';
  end if;
  if now() >= v_event.ends_at then
    raise exception 'Halloween ended on %', v_event.ends_at;
  end if;

  insert into public.event_progress (user_id, event_id, games, days, last_day)
  values (v_user, v_event.id, 15, 5, (now() at time zone 'utc')::date)
  on conflict (user_id, event_id) do update
    set games = greatest(event_progress.games, 15),
        days = greatest(event_progress.days, 5);

  v_given := public._event_award(v_user, v_event);

  if v_put_on then
    update public.profiles
       set equipped_theme = 'utopia_halloween',
           equipped_aura = 'jack',
           aura_expires_at = (select expires_at from public.user_auras
                              where user_id = v_user and aura_id = 'jack'),
           updated_at = now()
     where id = v_user;
  end if;

  raise notice '% %: given %; %',
    case when v_guest then 'Guest' else 'Player' end,
    v_user,
    coalesce(nullif(array_to_string(v_given, ', '), ''), 'nothing new (they had it all)'),
    case when v_put_on then 'world and frame put on' else 'not put on' end;
end $$;
