-- Bigger coin gifts, kept safe. 1,000 a gift and 2,000 a day was no fun;
-- now, for accounts (never guests) a week old and up:
--
--   * A gift is 10 to 50,000 coins.
--   * A day: up to 100,000 sent once the account's 30 days old (10,000
--     before that), up to 20 gifts, and up to 200,000 received.
--   * And never more than half the coins they had that day
--     (daily_share): a stolen account, a scam or a slip of the thumb can't
--     empty a wallet at once. Generous players can still give it all, a
--     day at a time.
--   * To a friend of under 3 days (new_friend_days), at most 5,000 a day:
--     "add me and send me coins" scams, and a stolen account pouring its
--     coins into a friend it just made, get little.
--   * As before: coins bought in the last 14 days stay put (a refund
--     couldn't take them back from the friend), friends only, never a
--     house player, every gift in the ledger twice, and gift_settings
--     turns it all off at once.
--
-- The allowance says which rule is closest (cap_left, share_left, and
-- friend_left for a new friend), so the app can say why it stops where
-- it does. A gift can be taken back by the team (tool/sql/reverse_gift.sql):
-- reversed_at and reversed_coins record it.

alter table public.gift_settings
  add column young_days int not null default 30,
  add column daily_send_young int not null default 10000,
  add column daily_share int not null default 50
    check (daily_share between 1 and 100),
  add column new_friend_days int not null default 3,
  add column new_friend_daily int not null default 5000;

alter table public.gift_settings
  alter column max_gift set default 50000,
  alter column daily_send set default 100000,
  alter column daily_gifts set default 20,
  alter column daily_receive set default 200000;
update public.gift_settings
   set max_gift = 50000, daily_send = 100000, daily_gifts = 20, daily_receive = 200000;

alter table public.coin_gifts
  add column reversed_at timestamptz,
  add column reversed_coins int;

drop function public.send_coin_gift(uuid, int, uuid);
drop function public.coin_gift_allowance();
drop function public._gift_allowance(uuid);

/** What [p_me] can send now (to [p_to], if named): whether at all (and
 * why not), and how much, by each rule. */
create function public._gift_allowance(p_me uuid, p_to uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_s public.gift_settings;
  v_guest boolean;
  v_created timestamptz;
  v_balance bigint;
  v_held bigint;
  v_sent bigint;
  v_count int;
  v_today timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  v_young boolean;
  v_cap bigint;
  v_cap_left bigint;
  v_share_left bigint;
  v_friends_since timestamptz;
  v_to_today bigint;
  v_friend_left bigint;
  v_why text;
begin
  select * into v_s from public.gift_settings;
  select coalesce(is_anonymous, false) into v_guest from auth.users where id = p_me;
  select created_at, balance into v_created, v_balance from public.profiles where id = p_me;
  v_balance := coalesce(v_balance, 0);
  select coalesce(sum(coins - coins_taken_back), 0) into v_held
    from public.coin_purchases
    where user_id = p_me and revoked_at is null
      and created_at > now() - make_interval(days => v_s.purchase_hold_days);
  select coalesce(sum(coins), 0), count(*) into v_sent, v_count
    from public.coin_gifts where from_user = p_me and created_at >= v_today;

  v_young := v_created > now() - make_interval(days => v_s.young_days);
  v_cap := case when v_young then v_s.daily_send_young else v_s.daily_send end;
  v_cap_left := greatest(0, v_cap - v_sent);
  -- Half of what they had today: their balance now, plus what they've
  -- already sent today.
  v_share_left := greatest(0, floor((v_balance + v_sent) * v_s.daily_share / 100.0)::bigint - v_sent);

  if p_to is not null then
    select created_at into v_friends_since from public.friendships
     where user_low = least(p_me, p_to) and user_high = greatest(p_me, p_to);
    if v_friends_since > now() - make_interval(days => v_s.new_friend_days) then
      select coalesce(sum(coins), 0) into v_to_today
        from public.coin_gifts
       where from_user = p_me and to_user = p_to and created_at >= v_today;
      v_friend_left := greatest(0, v_s.new_friend_daily - v_to_today);
    end if;
  end if;

  v_why := case
    when not v_s.enabled then 'off'
    when coalesce(v_guest, true) then 'guest'
    when v_created > now() - make_interval(days => v_s.account_days) then 'new'
  end;

  return jsonb_build_object(
    'ok', v_why is null,
    'why', v_why,
    'ready_at', case when v_why = 'new'
                     then v_created + make_interval(days => v_s.account_days) end,
    'balance', v_balance,
    'giftable', greatest(0, v_balance - v_held),
    'held', least(v_held, v_balance),
    'hold_days', v_s.purchase_hold_days,
    'min', v_s.min_gift,
    'max', v_s.max_gift,
    'left_today', least(v_cap_left, v_share_left),
    'cap_left', v_cap_left,
    'daily_cap', v_cap,
    'young', v_young,
    'grown_at', case when v_young then v_created + make_interval(days => v_s.young_days) end,
    'share_left', v_share_left,
    'share', v_s.daily_share,
    'gifts_left', greatest(0, v_s.daily_gifts - v_count),
    'friend_left', v_friend_left,
    'friend_limit', v_s.new_friend_daily,
    'friend_ready_at', case when v_friend_left is not null
                            then v_friends_since + make_interval(days => v_s.new_friend_days) end
  );
end;
$$;

/** What the player can send now (to [p_to], if named: for the send sheet). */
create function public.coin_gift_allowance(p_to uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return public._gift_allowance(auth.uid(), p_to);
end;
$$;

/** Sends [p_coins] to friend [p_to]. [p_key], made once per gift by the
 * app, makes a retry harmless. Answers {ok, gift, coins, balance}, or
 * {ok: false, why} when a rule says no. */
create function public.send_coin_gift(p_to uuid, p_coins int, p_key uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_s public.gift_settings;
  v_allow jsonb;
  v_gift public.coin_gifts;
  v_received bigint;
  v_today timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  v_balance bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_to is null or p_coins is null or p_key is null then
    raise exception 'missing recipient, coins or key';
  end if;
  if p_to = v_me then return jsonb_build_object('ok', false, 'why', 'self'); end if;

  -- Both balances, locked in the same order whoever's sending: two
  -- friends gifting each other at once can't deadlock.
  perform 1 from public.profiles where id in (v_me, p_to) order by id for update;
  if not exists (select 1 from public.profiles where id = p_to) then
    return jsonb_build_object('ok', false, 'why', 'nobody');
  end if;

  -- Sent already (a retry): the same answer, nothing sent twice.
  select * into v_gift from public.coin_gifts where from_user = v_me and client_key = p_key;
  if found then
    select balance into v_balance from public.profiles where id = v_me;
    return jsonb_build_object('ok', true, 'gift', v_gift.id, 'coins', v_gift.coins,
                              'balance', v_balance, 'again', true);
  end if;

  if exists (select 1 from public.house_players where id = p_to) then
    return jsonb_build_object('ok', false, 'why', 'house');
  end if;
  if not exists (
    select 1 from public.friendships
    where user_low = least(v_me, p_to) and user_high = greatest(v_me, p_to)
  ) then
    return jsonb_build_object('ok', false, 'why', 'not_friends');
  end if;

  select * into v_s from public.gift_settings;
  v_allow := public._gift_allowance(v_me, p_to);
  if not (v_allow ->> 'ok')::boolean then
    return jsonb_build_object('ok', false, 'why', v_allow ->> 'why');
  end if;
  if p_coins < v_s.min_gift or p_coins > v_s.max_gift then
    return jsonb_build_object('ok', false, 'why', 'amount');
  end if;
  if p_coins > (v_allow ->> 'balance')::bigint then
    return jsonb_build_object('ok', false, 'why', 'balance');
  end if;
  if p_coins > (v_allow ->> 'giftable')::bigint then
    return jsonb_build_object('ok', false, 'why', 'held');
  end if;
  if (v_allow ->> 'gifts_left')::int <= 0 or p_coins > (v_allow ->> 'cap_left')::bigint then
    return jsonb_build_object('ok', false, 'why', 'daily_send');
  end if;
  if p_coins > (v_allow ->> 'share_left')::bigint then
    return jsonb_build_object('ok', false, 'why', 'share');
  end if;
  if v_allow ->> 'friend_left' is not null and p_coins > (v_allow ->> 'friend_left')::bigint then
    return jsonb_build_object('ok', false, 'why', 'new_friend');
  end if;
  select coalesce(sum(coins), 0) into v_received
    from public.coin_gifts where to_user = p_to and created_at >= v_today;
  if v_received + p_coins > v_s.daily_receive then
    return jsonb_build_object('ok', false, 'why', 'daily_receive');
  end if;

  insert into public.coin_gifts (from_user, to_user, coins, client_key)
    values (v_me, p_to, p_coins, p_key)
    returning * into v_gift;
  perform public._ledger_move(v_me, 'coin_gift', -p_coins, null,
                              jsonb_build_object('gift', v_gift.id, 'to', p_to));
  perform public._ledger_move(p_to, 'coin_gift', p_coins, null,
                              jsonb_build_object('gift', v_gift.id, 'from', v_me));
  insert into public.notifications (user_id, kind, actor_id, ref_id, data)
    values (p_to, 'coin_gift', v_me, v_gift.id, jsonb_build_object('coins', p_coins));

  select balance into v_balance from public.profiles where id = v_me;
  return jsonb_build_object('ok', true, 'gift', v_gift.id, 'coins', p_coins, 'balance', v_balance);
end;
$$;

revoke all on function public._gift_allowance(uuid, uuid) from public, anon, authenticated;
revoke all on function public.coin_gift_allowance(uuid) from public, anon;
revoke all on function public.send_coin_gift(uuid, int, uuid) from public, anon;
grant execute on function public.coin_gift_allowance(uuid) to authenticated;
grant execute on function public.send_coin_gift(uuid, int, uuid) to authenticated;
