-- Gets one player ready to test sending coins (Send coins on a friend's
-- card):
--   * v_coins coins are added (0 adds none). They're an admin grant, not
--     a purchase, so they can be sent at once (coins bought in the last
--     14 days stay put);
--   * with v_friend set, the two are made friends (gifts only go to
--     friends), and any request between them is marked accepted;
--   * with v_pin set (4 digits, not 0000 or 1234-like), that's their gift
--     PIN; otherwise the app asks them to choose one before their first
--     gift.
-- Everything else about them stays as it is.
--
-- A guest can't be made ready: gifts are for accounts only (guests are
-- made by the dozen, so their starting coins can't be passed on). They
-- tap "Save your account" in the app and sign in with an email first.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the player's
-- username, user ID or email below (and their friend's, or leave it ''),
-- then Run. The result line says what they can send now. Reopen Send
-- coins in the app (or pull to refresh) to see it.
do $$
declare
  v_who text := 'their_username';  -- <- username, user ID or email
  v_friend text := '';             -- <- optional: who they'll send to
  v_coins int := 2000;             -- coins to add (0 for none)
  v_pin text := '';                -- <- optional: their gift PIN
  v_user uuid;
  v_to uuid;
  v_guest boolean;
  v_allow jsonb;
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
  if v_guest then
    raise exception '"%" is a guest. Gifts are for accounts only: they tap "Save your account" in the app first, then run this again.', v_who;
  end if;

  v_friend := trim(v_friend);
  if v_friend <> '' then
    if v_friend ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      v_to := v_friend::uuid;
    elsif v_friend ~ '^[^@\s]+@[^@\s]+$' then
      select id into v_to from auth.users where lower(email) = lower(v_friend);
    else
      select id into v_to from public.profiles where lower(username) = lower(ltrim(v_friend, '@'));
    end if;
    if v_to is null or not exists (select 1 from public.profiles where id = v_to) then
      raise exception 'No account matches friend "%"', v_friend;
    end if;
    if v_to = v_user then
      raise exception 'They can''t send coins to themselves: pick someone else as v_friend.';
    end if;
    if exists (select 1 from public.house_players where id = v_to) then
      raise exception '"%" is a house player: gifts never go to them.', v_friend;
    end if;
  end if;

  v_pin := trim(v_pin);
  if v_pin <> '' and public._gift_pin_problem(v_pin) is not null then
    raise exception 'v_pin "%" won''t do: 4 digits, and not all the same or a straight run (1234, 9876).', v_pin;
  end if;

  if v_coins > 0 then
    perform public._ledger_move(v_user, 'admin_adjustment', v_coins, null,
                                jsonb_build_object('reason', 'ready_for_gifts'));
  end if;

  if v_to is not null then
    insert into public.friendships (user_low, user_high)
      values (least(v_user, v_to), greatest(v_user, v_to))
      on conflict (user_low, user_high) do nothing;
    update public.friend_requests
       set status = 'accepted', responded_at = now()
     where status = 'pending'
       and ((from_user = v_user and to_user = v_to) or (from_user = v_to and to_user = v_user));
  end if;

  if v_pin <> '' then
    perform public._gift_pin_save(v_user, v_pin);
  end if;

  v_allow := public._gift_allowance(v_user);
  raise notice '% (%): % to send (balance %, % held from recent purchases)%; gift PIN %.',
    coalesce((select '@' || username from public.profiles where id = v_user), 'Player with no username'),
    v_user,
    case when (v_allow ->> 'ok')::boolean then 'ready, ' || (v_allow ->> 'giftable') || ' coins'
         else 'NOT ready (' || (v_allow ->> 'why') || ')' end,
    v_allow ->> 'balance', v_allow ->> 'held',
    case when v_to is not null
         then ', friends with ' || coalesce((select '@' || username from public.profiles where id = v_to), v_to::text)
         else '' end,
    case when (v_allow ->> 'pin_set')::boolean then 'set' else 'not set yet (the app asks for one)' end;
end $$;
