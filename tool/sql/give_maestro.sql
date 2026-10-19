-- Gives one player Chip at full, guest or not: Chip Maestro for v_days,
-- and nothing else. As a member, Chip:
--   * chats on Opus (the smartest model), with web search;
--   * draws and paints on Opus;
--   * allows 200 chats, 10 drawings, 12 doodles and 100 colorings a day,
--     and 30 portraits a month;
--   * never waits on the day's free budget.
-- They also wear the Maestro frame while it lasts. Running it again sets
-- the end to v_days from now (never sooner than it was). A real Maestro
-- subscription is left alone. take_maestro.sql takes it back.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the player's
-- username, user ID or email on the line below, then Run. The result
-- line says who got it, and until when. Their next message to Chip is on
-- Opus (no need to reopen the app; reopen it to see the Maestro badge).
do $$
declare
  v_who text := 'their_username';  -- <- username, user ID or email
  v_days int := 30;                -- how long it lasts
  v_user uuid;
  v_guest boolean;
  v_until timestamptz;
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

  if exists (select 1 from public.maestro_subscriptions
             where user_id = v_user and original_id not like 'grant:%'
               and expires_at > now()) then
    raise notice '% already subscribes to Maestro (until %): Chip is already at full.',
      v_user, (select expires_at::date from public.maestro_subscriptions where user_id = v_user);
    return;
  end if;

  -- The way a store purchase records it (with its frame), marked as a
  -- grant so it's never taken for a real subscription.
  v_until := greatest(now() + make_interval(days => v_days),
                      coalesce(public._maestro_until(v_user), now()));
  perform public.maestro_record(
    v_user, 'ios', 'utopia.maestro.monthly', 'grant:' || v_user,
    v_until, false, 'sandbox'
  );

  raise notice '% % (%): Chip Maestro until %',
    case when v_guest then 'Guest' else 'Player' end,
    coalesce((select '@' || username from public.profiles where id = v_user), 'with no username'),
    v_user, v_until::date;
end $$;
