-- Takes back coin gifts: one by its ID, or every gift a player sent in
-- the last v_hours (a stolen account, a scam, a mistake). For each, the
-- coins go back from the friend to the sender, as many as the friend
-- still has (they may have spent some: the line says how many came back).
-- Each is in the ledger both ways and marked on the gift (reversed_at,
-- reversed_coins); a gift is never taken back twice.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the gift's
-- ID in v_gift, or the sender's username, user ID or email in v_from
-- (and how far back in v_hours), then Run.
do $$
declare
  v_gift uuid := null;              -- <- one gift's ID, or
  v_from text := 'their_username';  -- <- everything this player sent
  v_hours int := 24;                --    in the last this many hours
  v_sender uuid;
  v_g public.coin_gifts;
  v_back int;
  v_gifts int := 0;
  v_sent bigint := 0;
  v_returned bigint := 0;
begin
  if v_gift is null then
    v_from := trim(v_from);
    if v_from ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      v_sender := v_from::uuid;
    elsif v_from ~ '^[^@\s]+@[^@\s]+$' then
      select id into v_sender from auth.users where lower(email) = lower(v_from);
    else
      select id into v_sender from public.profiles where lower(username) = lower(ltrim(v_from, '@'));
    end if;
    if v_sender is null or not exists (select 1 from public.profiles where id = v_sender) then
      raise exception 'No account matches "%"', v_from;
    end if;
  end if;

  for v_g in
    select * from public.coin_gifts
     where reversed_at is null
       and (case when v_gift is not null then id = v_gift
                 else from_user = v_sender and created_at > now() - make_interval(hours => v_hours) end)
     order by created_at
     for update
  loop
    -- Both balances, in the same order the gifts lock them.
    perform 1 from public.profiles where id in (v_g.from_user, v_g.to_user) order by id for update;
    select least(v_g.coins, greatest(balance, 0))::int into v_back from public.profiles where id = v_g.to_user;
    if v_back > 0 then
      perform public._ledger_move(v_g.to_user, 'coin_gift', -v_back, null,
                                  jsonb_build_object('gift', v_g.id, 'reversed', true, 'to', v_g.from_user));
      perform public._ledger_move(v_g.from_user, 'coin_gift', v_back, null,
                                  jsonb_build_object('gift', v_g.id, 'reversed', true, 'from', v_g.to_user));
    end if;
    update public.coin_gifts set reversed_at = now(), reversed_coins = v_back where id = v_g.id;
    v_gifts := v_gifts + 1;
    v_sent := v_sent + v_g.coins;
    v_returned := v_returned + v_back;
  end loop;

  if v_gifts = 0 then
    raise notice 'No gifts to take back (none match, or they were taken back already).';
  else
    raise notice '% gift(s) taken back: % coins had been sent, % came back to the sender.',
      v_gifts, v_sent, v_returned;
  end if;
end $$;
