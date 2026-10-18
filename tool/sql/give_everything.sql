-- Gives one player everything Utopia sells, guest or not:
--   * every world, piece set and chess set, theirs for good;
--   * every frame on sale, and Maestro, for v_days;
--   * whatever a live event gives (Halloween's world and Jack's Lantern),
--     until the event ends;
--   * v_coins coins (added again each time this is run).
-- What they have on stays as it is. Running it again only adds what's
-- missing (and the coins). A real Maestro subscription is left alone.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the player's
-- username, user ID or email on the line below, then Run. The result
-- line says who got what. Then close the app fully and open it again.
do $$
declare
  v_who text := 'their_username';  -- <- username, user ID or email
  v_days int := 365;               -- how long the frames and Maestro last
  v_coins bigint := 100000;        -- coins to add (0 for none)
  v_user uuid;
  v_guest boolean;
  v_until timestamptz;
  v_event public.events;
  v_items int;
  v_frames int;
  v_maestro text := 'Maestro';
  v_events text[] := '{}';
begin
  v_who := trim(v_who);
  if v_who ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_user := v_who::uuid;
  elsif v_who ~ '^[^@\s]+@[^@\s]+$' then
    select id into v_user from auth.users where lower(email) = lower(v_who);
  else
    select id into v_user from public.profiles where lower(username) = lower(ltrim(v_who, '@'));
  end if;
  select coalesce(is_anonymous, false) into v_guest from auth.users where id = v_user;
  if not found then
    raise exception 'No account matches "%"', v_who;
  end if;
  v_until := now() + make_interval(days => v_days);

  -- Worlds, piece sets and chess sets: everything in the shop, for good.
  insert into public.user_entitlements (user_id, item_id, source)
  select distinct v_user, item, 'grant'
  from public.store_coin_prices, unnest(item_ids) as item
  on conflict (user_id, item_id) do nothing;
  get diagnostics v_items = row_count;

  -- Every frame on sale, for v_days (or longer, if theirs lasts longer).
  insert into public.user_auras (user_id, aura_id, expires_at)
  select v_user, id, v_until from public.aura_catalog where not retired
  on conflict (user_id, aura_id)
    do update set expires_at = greatest(user_auras.expires_at, excluded.expires_at);
  get diagnostics v_frames = row_count;

  -- Maestro, the way a store purchase records it (with its frame), marked
  -- as a grant so it's never taken for a real subscription.
  if exists (select 1 from public.maestro_subscriptions
             where user_id = v_user and original_id not like 'grant:%'
               and expires_at > now()) then
    v_maestro := 'Maestro (already subscribed, left alone)';
  else
    perform public.maestro_record(
      v_user, 'ios', 'utopia.maestro.monthly', 'grant:' || v_user,
      greatest(v_until, coalesce(public._maestro_until(v_user), v_until)),
      false, 'sandbox'
    );
  end if;

  -- A live event's world and frame, as if they'd played it through.
  for v_event in
    select e.* from public.events e
    where now() >= e.starts_at and now() < e.ends_at
      and exists (select 1 from public.event_rewards r
                  where r.event_id = e.id and r.kind in ('aura', 'world'))
  loop
    insert into public.event_progress (user_id, event_id, games, days, last_day)
    select v_user, v_event.id, max(r.games), max(r.days), (now() at time zone 'utc')::date
    from public.event_rewards r where r.event_id = v_event.id
    on conflict (user_id, event_id) do update
      set games = greatest(event_progress.games, excluded.games),
          days = greatest(event_progress.days, excluded.days);
    perform public._event_award(v_user, v_event);
    v_events := v_events || v_event.title;
  end loop;

  -- The frame they have on lasts as long as their copy of it now does.
  update public.profiles p
     set aura_expires_at = a.expires_at, updated_at = now()
    from public.user_auras a
   where p.id = v_user and a.user_id = v_user and a.aura_id = p.equipped_aura
     and a.expires_at > coalesce(p.aura_expires_at, '-infinity');

  if v_coins > 0 then
    perform public._ledger_move(v_user, 'admin_adjustment', v_coins, null,
                                jsonb_build_object('reason', 'give_everything'));
  end if;

  raise notice '% % (%): % new shop items, % frames until %, %, % coins%',
    case when v_guest then 'Guest' else 'Player' end,
    coalesce((select '@' || username from public.profiles where id = v_user), 'with no username'),
    v_user, v_items, v_frames, v_until::date, v_maestro, v_coins,
    case when cardinality(v_events) > 0
         then ', and ' || array_to_string(v_events, ', ') || '''s items' else '' end;
end $$;
