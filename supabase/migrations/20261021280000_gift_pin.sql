-- Coin gifts with a PIN, and without the limits.
--
-- Every gift now takes the sender's 4-digit gift PIN, checked here. The
-- daily caps, the per-gift most, the account's age and the new-friend
-- limit are gone. What stays:
--
--   * Friends only, never a guest or a house player.
--   * Coins bought in the last 14 days stay put: a refund couldn't take
--     them back from the friend (a PIN doesn't stop that).
--   * gift_settings.enabled turns gifts off at once.
--
-- The PIN is kept only as a bcrypt hash, in a table no one can read but
-- these functions. Five wrong tries lock gifts for 15 minutes. A player
-- who's forgotten it proves they own the account's email with a code
-- (the app has them sign in with one again) and sets a new one: there's
-- no default PIN for anyone to guess.

create extension if not exists pgcrypto with schema extensions;

create table public.gift_pins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  pin_hash text not null,
  tries int not null default 0,
  locked_until timestamptz,
  set_at timestamptz not null default now()
);
alter table public.gift_pins enable row level security;
revoke all on public.gift_pins from anon, authenticated;

alter table public.gift_settings
  add column pin_tries int not null default 5,
  add column pin_lock_minutes int not null default 15,
  add column pin_reset_minutes int not null default 10;
update public.gift_settings set min_gift = 1;

drop function public.send_coin_gift(uuid, int, uuid);
drop function public.coin_gift_allowance(uuid);
drop function public._gift_allowance(uuid, uuid);

/** Four digits, and not one anyone would guess first: all the same
 * (0000) or a straight run (1234, 9876). */
create function public._gift_pin_problem(p_pin text)
returns text
language sql
immutable
as $$
  select case
    when p_pin is null or p_pin !~ '^[0-9]{4}$' then 'format'
    when p_pin ~ '^([0-9])\1{3}$' then 'weak'
    when position(p_pin in '0123456789') > 0
      or position(p_pin in '9876543210') > 0 then 'weak'
  end;
$$;

/** Checks [p_pin] against [p_me]'s, counting wrong tries (and locking
 * after too many). Null when it's right; otherwise {ok: false, why}:
 * 'no_pin', 'locked' (until locked_until) or 'wrong_pin' (tries_left). */
create function public._gift_pin_check(p_me uuid, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_s public.gift_settings;
  v_pin public.gift_pins;
  v_tries int;
begin
  select * into v_s from public.gift_settings;
  select * into v_pin from public.gift_pins where user_id = p_me for update;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'no_pin');
  end if;
  if v_pin.locked_until > now() then
    return jsonb_build_object('ok', false, 'why', 'locked',
                              'locked_until', v_pin.locked_until);
  end if;
  if p_pin is null or extensions.crypt(p_pin, v_pin.pin_hash) <> v_pin.pin_hash then
    v_tries := v_pin.tries + 1;
    if v_tries >= v_s.pin_tries then
      update public.gift_pins
         set tries = 0,
             locked_until = now() + make_interval(mins => v_s.pin_lock_minutes)
       where user_id = p_me
       returning * into v_pin;
      return jsonb_build_object('ok', false, 'why', 'locked',
                                'locked_until', v_pin.locked_until);
    end if;
    update public.gift_pins set tries = v_tries where user_id = p_me;
    return jsonb_build_object('ok', false, 'why', 'wrong_pin',
                              'tries_left', v_s.pin_tries - v_tries);
  end if;
  if v_pin.tries <> 0 or v_pin.locked_until is not null then
    update public.gift_pins set tries = 0, locked_until = null where user_id = p_me;
  end if;
  return null;
end;
$$;

/** Saves [p_pin] (already checked) as [p_me]'s gift PIN. */
create function public._gift_pin_save(p_me uuid, p_pin text)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.gift_pins (user_id, pin_hash)
    values (p_me, extensions.crypt(p_pin, extensions.gen_salt('bf', 8)))
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, tries = 0, locked_until = null,
        set_at = now();
$$;

/** Whether the player has a gift PIN, and whether it's locked. */
create function public.gift_pin_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_pin public.gift_pins;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_pin from public.gift_pins where user_id = auth.uid();
  return jsonb_build_object(
    'set', found,
    'set_at', v_pin.set_at,
    'locked_until', case when v_pin.locked_until > now() then v_pin.locked_until end
  );
end;
$$;

/** Sets the player's gift PIN to [p_pin], or changes it: then [p_current]
 * must be the one they have (a wrong one counts as a wrong try). Answers
 * {ok} or {ok: false, why}: 'guest', 'format', 'weak', or what checking
 * the current one said. */
create function public.set_gift_pin(p_pin text, p_current text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_problem text;
  v_check jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if coalesce((select is_anonymous from auth.users where id = v_me), true) then
    return jsonb_build_object('ok', false, 'why', 'guest');
  end if;
  v_problem := public._gift_pin_problem(p_pin);
  if v_problem is not null then
    return jsonb_build_object('ok', false, 'why', v_problem);
  end if;
  if exists (select 1 from public.gift_pins where user_id = v_me) then
    v_check := public._gift_pin_check(v_me, p_current);
    if v_check is not null then return v_check; end if;
  end if;
  perform public._gift_pin_save(v_me, p_pin);
  return jsonb_build_object('ok', true);
end;
$$;

/** A new gift PIN, for a player who's forgotten theirs: allowed only in
 * a session they proved with a code from their email in the last few
 * minutes (pin_reset_minutes). Answers {ok}, or {ok: false, why}: 'guest',
 * 'format', 'weak' or 'verify' (prove the email first). */
create function public.reset_gift_pin(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_s public.gift_settings;
  v_problem text;
  v_amr jsonb := auth.jwt() -> 'amr';
  v_proved boolean;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if coalesce((select is_anonymous from auth.users where id = v_me), true) then
    return jsonb_build_object('ok', false, 'why', 'guest');
  end if;
  v_problem := public._gift_pin_problem(p_pin);
  if v_problem is not null then
    return jsonb_build_object('ok', false, 'why', v_problem);
  end if;
  select * into v_s from public.gift_settings;
  -- How this session was signed in, and when: a code or a link from the
  -- account's email, just now.
  select exists (
    select 1
      from jsonb_array_elements(
             case when jsonb_typeof(v_amr) = 'array' then v_amr else '[]' end
           ) a
     where jsonb_typeof(a) = 'object'
       and a ->> 'method' in ('otp', 'magiclink', 'email/signup', 'recovery',
                              'invite', 'email_change')
       and (a ->> 'timestamp') ~ '^[0-9]+(\.[0-9]+)?$'
       and (a ->> 'timestamp')::numeric
           >= extract(epoch from now()) - v_s.pin_reset_minutes * 60
  ) into v_proved;
  if not v_proved then
    return jsonb_build_object('ok', false, 'why', 'verify');
  end if;
  perform public._gift_pin_save(v_me, p_pin);
  return jsonb_build_object('ok', true);
end;
$$;

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
  v_balance bigint;
  v_held bigint;
  v_pin public.gift_pins;
  v_why text;
begin
  select * into v_s from public.gift_settings;
  select coalesce(is_anonymous, false) into v_guest from auth.users where id = p_me;
  select balance into v_balance from public.profiles where id = p_me;
  v_balance := coalesce(v_balance, 0);
  select coalesce(sum(coins - coins_taken_back), 0) into v_held
    from public.coin_purchases
    where user_id = p_me and revoked_at is null
      and created_at > now() - make_interval(days => v_s.purchase_hold_days);
  select * into v_pin from public.gift_pins where user_id = p_me;

  v_why := case
    when not v_s.enabled then 'off'
    when coalesce(v_guest, true) then 'guest'
  end;

  return jsonb_build_object(
    'ok', v_why is null,
    'why', v_why,
    'balance', v_balance,
    'giftable', greatest(0, v_balance - v_held),
    'held', least(v_held, v_balance),
    'hold_days', v_s.purchase_hold_days,
    'min', v_s.min_gift,
    'pin_set', v_pin.user_id is not null,
    'pin_locked_until', case when v_pin.locked_until > now() then v_pin.locked_until end
  );
end;
$$;

/** What the player can send now ([p_to] is kept for older apps). */
create function public.coin_gift_allowance(p_to uuid default null)
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

/** Sends [p_coins] to friend [p_to], with the sender's gift [p_pin].
 * [p_key], made once per gift by the app, makes a retry harmless. Answers
 * {ok, gift, coins, balance}, or {ok: false, why} when something says no
 * ('wrong_pin' with tries_left, 'locked' with locked_until, 'no_pin',
 * 'not_friends', 'held', 'balance', ...). */
create function public.send_coin_gift(p_to uuid, p_coins int, p_key uuid, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_allow jsonb;
  v_pin jsonb;
  v_gift public.coin_gifts;
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
  v_allow := public._gift_allowance(v_me);
  if not (v_allow ->> 'ok')::boolean then
    return jsonb_build_object('ok', false, 'why', v_allow ->> 'why');
  end if;

  v_pin := public._gift_pin_check(v_me, p_pin);
  if v_pin is not null then return v_pin; end if;

  if p_coins < (v_allow ->> 'min')::int then
    return jsonb_build_object('ok', false, 'why', 'amount');
  end if;
  if p_coins > (v_allow ->> 'balance')::bigint then
    return jsonb_build_object('ok', false, 'why', 'balance');
  end if;
  if p_coins > (v_allow ->> 'giftable')::bigint then
    return jsonb_build_object('ok', false, 'why', 'held');
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

revoke all on function public._gift_pin_problem(text) from public, anon, authenticated;
revoke all on function public._gift_pin_check(uuid, text) from public, anon, authenticated;
revoke all on function public._gift_pin_save(uuid, text) from public, anon, authenticated;
revoke all on function public._gift_allowance(uuid) from public, anon, authenticated;
revoke all on function public.gift_pin_status() from public, anon;
revoke all on function public.set_gift_pin(text, text) from public, anon;
revoke all on function public.reset_gift_pin(text) from public, anon;
revoke all on function public.coin_gift_allowance(uuid) from public, anon;
revoke all on function public.send_coin_gift(uuid, int, uuid, text) from public, anon;
grant execute on function public.gift_pin_status() to authenticated;
grant execute on function public.set_gift_pin(text, text) to authenticated;
grant execute on function public.reset_gift_pin(text) to authenticated;
grant execute on function public.coin_gift_allowance(uuid) to authenticated;
grant execute on function public.send_coin_gift(uuid, int, uuid, text) to authenticated;
