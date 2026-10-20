-- Gets one player ready to test sending coins (Send coins on a friend's
-- card), as an older account would be:
--   * their account is dated back past the new-account wait (7 days,
--     gift_settings.account_days), so it counts as an old one;
--   * v_coins coins are added (0 adds none). They're an admin grant, not
--     a purchase, so they can be sent at once (coins bought in the last
--     14 days stay put);
--   * with v_friend set, the two are made friends (gifts only go to
--     friends), and any request between them is marked accepted.
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
--
-- Joined dates only feed the "new players" count on the analytics page;
-- the line also says the old one, if it's ever wanted back.
do $$
declare
  v_who text := 'their_username';  -- <- username, user ID or email
  v_friend text := '';             -- <- optional: who they'll send to
  v_coins int := 2000;             -- coins to add (0 for none)
  v_user uuid;
  v_to uuid;
  v_guest boolean;
  v_days int;
  v_joined timestamptz;
  v_allow jsonb;
begin
  select account_days into v_days from public.gift_settings;

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

  -- Old enough: dated back a day past the wait (never moved forward).
  select created_at into v_joined from public.profiles where id = v_user;
  update public.profiles
     set created_at = least(created_at, now() - make_interval(days => v_days + 1))
   where id = v_user;

  if v_coins > 0 then
    perform public._ledger_move(v_user, 'admin_adjustment', v_coins, null,
                                jsonb_build_object('reason', 'ready_for_gifts'));
  end if;

  if v_to is not null then
    insert into public.friendships (user_low, user_high)
      values (least(v_user, v_to), greatest(v_user, v_to))
      on conflict do nothing;
    update public.friend_requests
       set status = 'accepted', responded_at = now()
     where status = 'pending'
       and ((from_user = v_user and to_user = v_to) or (from_user = v_to and to_user = v_user));
  end if;

  v_allow := public._gift_allowance(v_user);
  raise notice '% (%): % to send now (balance %, % held from recent purchases), % a gift, % left today%. Joined date was %.',
    coalesce((select '@' || username from public.profiles where id = v_user), 'Player with no username'),
    v_user,
    case when (v_allow ->> 'ok')::boolean then 'ready, ' || (v_allow ->> 'giftable') || ' coins'
         else 'NOT ready (' || (v_allow ->> 'why') || ')' end,
    v_allow ->> 'balance', v_allow ->> 'held',
    (v_allow ->> 'min') || '-' || (v_allow ->> 'max'),
    v_allow ->> 'left_today',
    case when v_to is not null
         then ', friends with ' || coalesce((select '@' || username from public.profiles where id = v_to), v_to::text)
         else '' end,
    v_joined;
end $$;
