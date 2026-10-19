-- Takes back Chip Maestro given with give_maestro.sql (or
-- give_everything.sql): Chip goes back to the free models and limits now,
-- and the Maestro frame comes off. A real, paid subscription is never
-- touched.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the player's
-- username, user ID or email on the line below, then Run.
do $$
declare
  v_who text := 'their_username';  -- <- username, user ID or email
  v_user uuid;
begin
  v_who := trim(v_who);
  if v_who ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_user := v_who::uuid;
  elsif v_who ~ '^[^@\s]+@[^@\s]+$' then
    select id into v_user from auth.users where lower(email) = lower(v_who);
  else
    select id into v_user from public.profiles where lower(username) = lower(ltrim(v_who, '@'));
  end if;
  if v_user is null or not exists (select 1 from auth.users where id = v_user) then
    raise exception 'No account matches "%"', v_who;
  end if;

  if not exists (select 1 from public.maestro_subscriptions
                 where user_id = v_user and original_id like 'grant:%'
                   and expires_at > now()) then
    raise notice '% has no Maestro that was given (a paid one stays).', v_user;
    return;
  end if;
  perform public.maestro_expire('grant:' || v_user, now());
  raise notice '%: Chip Maestro taken back.', v_user;
end $$;
