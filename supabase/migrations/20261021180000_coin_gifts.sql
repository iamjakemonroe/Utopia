-- Coin gifts: a player sends some of their coins to a friend.
--
-- Coins are bought with real money, so a gift has to be safe:
--   * Only friends, never yourself or a house player.
--   * Only accounts (not guests, made by the dozen), at least
--     account_days old, so fresh accounts can't pass on their starting
--     coins.
--   * Coins bought in the last purchase_hold_days stay put: buy, gift,
--     then refund the purchase, and the refund could only take back
--     what's left (take_back_coin_purchase), so the friend would keep
--     coins nobody paid for.
--   * Limits: min_gift..max_gift a gift; daily_send coins and
--     daily_gifts gifts a day sent; daily_receive coins a day received
--     (many accounts can't pour coins into one). Days are UTC.
--   * Both balances move in one transaction, locked in the same order
--     whoever's sending; a retry with the same client_key sends nothing
--     twice; every gift is a coin_gifts row and two ledger entries.
--   * The friend hears about it (a coin_gift notification).
--   * gift_settings.enabled turns gifts off at once.

alter type public.ledger_entry_type add value if not exists 'coin_gift';

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('friend_request', 'friend_accepted', 'game_invite',
                  'friend_birthday', 'birthday_wish', 'coin_gift'));

create table public.gift_settings (
  id                 boolean primary key default true check (id),
  enabled            boolean not null default true,
  min_gift           int not null default 10,
  max_gift           int not null default 1000,
  daily_send         int not null default 2000,
  daily_gifts        int not null default 10,
  daily_receive      int not null default 5000,
  account_days       int not null default 7,
  purchase_hold_days int not null default 14
);
insert into public.gift_settings default values;
alter table public.gift_settings enable row level security;
revoke all on public.gift_settings from anon, authenticated;

create table public.coin_gifts (
  id         uuid primary key default gen_random_uuid(),
  from_user  uuid not null references public.profiles (id) on delete cascade,
  to_user    uuid not null references public.profiles (id) on delete cascade,
  coins      int not null check (coins > 0),
  client_key uuid not null,
  created_at timestamptz not null default now(),
  unique (from_user, client_key)
);
create index coin_gifts_from_idx on public.coin_gifts (from_user, created_at desc);
create index coin_gifts_to_idx on public.coin_gifts (to_user, created_at desc);
alter table public.coin_gifts enable row level security;
revoke insert, update, delete on public.coin_gifts from anon, authenticated;
create policy "see gifts you sent or got" on public.coin_gifts
  for select using (from_user = auth.uid() or to_user = auth.uid());

/** What [p_me] can send now: whether at all (and why not), and how much. */
create function public._gift_allowance(p_me uuid)
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
  v_why text;
begin
  select * into v_s from public.gift_settings;
  select coalesce(is_anonymous, false) into v_guest from auth.users where id = p_me;
  select created_at, balance into v_created, v_balance from public.profiles where id = p_me;
  select coalesce(sum(coins - coins_taken_back), 0) into v_held
    from public.coin_purchases
    where user_id = p_me and revoked_at is null
      and created_at > now() - make_interval(days => v_s.purchase_hold_days);
  select coalesce(sum(coins), 0), count(*) into v_sent, v_count
    from public.coin_gifts where from_user = p_me and created_at >= v_today;

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
    'balance', coalesce(v_balance, 0),
    'giftable', greatest(0, coalesce(v_balance, 0) - v_held),
    'held', least(v_held, coalesce(v_balance, 0)),
    'hold_days', v_s.purchase_hold_days,
    'min', v_s.min_gift,
    'max', v_s.max_gift,
    'left_today', greatest(0, v_s.daily_send - v_sent),
    'gifts_left', greatest(0, v_s.daily_gifts - v_count)
  );
end;
$$;

/** What the player can send now (for the send sheet). */
create function public.coin_gift_allowance()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return public._gift_allowance(auth.uid());
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
  v_allow := public._gift_allowance(v_me);
  if not (v_allow ->> 'ok')::boolean then
    return jsonb_build_object('ok', false, 'why', v_allow ->> 'why');
  end if;
  if p_coins < v_s.min_gift or p_coins > v_s.max_gift then
    return jsonb_build_object('ok', false, 'why', 'amount');
  end if;
  if (v_allow ->> 'gifts_left')::int <= 0 or p_coins > (v_allow ->> 'left_today')::bigint then
    return jsonb_build_object('ok', false, 'why', 'daily_send');
  end if;
  if p_coins > (v_allow ->> 'balance')::bigint then
    return jsonb_build_object('ok', false, 'why', 'balance');
  end if;
  if p_coins > (v_allow ->> 'giftable')::bigint then
    return jsonb_build_object('ok', false, 'why', 'held');
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

revoke all on function public._gift_allowance(uuid) from public, anon, authenticated;
revoke all on function public.coin_gift_allowance() from public, anon;
revoke all on function public.send_coin_gift(uuid, int, uuid) from public, anon;
grant execute on function public.coin_gift_allowance() to authenticated;
grant execute on function public.send_coin_gift(uuid, int, uuid) to authenticated;
