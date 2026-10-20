-- A note with a gift: "Happy birthday!", "for the rematch".
--
--   * Optional, up to 140 characters, kept with the gift (coin_gifts.note)
--     and shown to the friend in their notification of it.
--   * Cleaned on the way in (_gift_note): no invisible or control
--     characters, runs of spaces and new lines become one space, trimmed;
--     nothing left is no note. Gifts only go between friends, so like
--     friends' game chat it isn't word-filtered.
--   * send_coin_gift takes it as p_note (default null), so an app that
--     doesn't send one yet works as before.

alter table public.coin_gifts
  add column note text check (note is null or char_length(note) between 1 and 140);

/** [p] as a gift's note: cleaned, or null if there's nothing to it. */
create function public._gift_note(p text)
returns text
language sql
immutable
as $fn$
  select nullif(
    btrim(regexp_replace(
      regexp_replace(
        coalesce(p, ''),
        '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]',
        '', 'g'),
      '\s+', ' ', 'g')),
    '');
$fn$;

revoke all on function public._gift_note(text) from public, anon, authenticated;

drop function public.send_coin_gift(uuid, int, uuid, text);

create function public.send_coin_gift(
  p_to uuid, p_coins int, p_key uuid, p_pin text, p_note text default null
)
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
  v_note text := public._gift_note(p_note);
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_to is null or p_coins is null or p_key is null then
    raise exception 'missing recipient, coins or key';
  end if;
  if p_to = v_me then return jsonb_build_object('ok', false, 'why', 'self'); end if;
  -- Before the PIN: a note that's too long doesn't cost a try.
  if char_length(v_note) > 140 then
    return jsonb_build_object('ok', false, 'why', 'note_long');
  end if;

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
                              'note', v_gift.note, 'balance', v_balance, 'again', true);
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

  insert into public.coin_gifts (from_user, to_user, coins, client_key, note)
    values (v_me, p_to, p_coins, p_key, v_note)
    returning * into v_gift;
  perform public._ledger_move(v_me, 'coin_gift', -p_coins, null,
                              jsonb_build_object('gift', v_gift.id, 'to', p_to));
  perform public._ledger_move(p_to, 'coin_gift', p_coins, null,
                              jsonb_build_object('gift', v_gift.id, 'from', v_me));
  insert into public.notifications (user_id, kind, actor_id, ref_id, data)
    values (p_to, 'coin_gift', v_me, v_gift.id,
            jsonb_strip_nulls(jsonb_build_object('coins', p_coins, 'note', v_note)));

  select balance into v_balance from public.profiles where id = v_me;
  return jsonb_build_object('ok', true, 'gift', v_gift.id, 'coins', p_coins,
                            'note', v_note, 'balance', v_balance);
end;
$$;

revoke all on function public.send_coin_gift(uuid, int, uuid, text, text) from public, anon;
grant execute on function public.send_coin_gift(uuid, int, uuid, text, text) to authenticated;
