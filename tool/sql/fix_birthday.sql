-- Corrects a player's birthday when they report it's wrong. The app lets
-- a player change it for a day after setting it, then locks it (so it
-- can't be moved around for more parties) and tells them to report a bug
-- if it's wrong. Day and month only, never the year. It stays locked
-- after: only another correction here changes it again. Their party comes
-- on the new day.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the player's
-- username, user ID or email and the right month and day below, then Run.
-- The result line says what it was and what it is now. Then mark their
-- report fixed (tool/reports.sh mark <id> fixed "note"), which tells them.
do $$
declare
  v_who text := 'their_username';  -- <- username, user ID or email
  v_month int := 12;               -- the right month (1-12)
  v_day int := 21;                 -- the right day
  v_user uuid;
  v_was text;
begin
  v_who := trim(v_who);
  if v_who ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_user := v_who::uuid;
  elsif v_who ~ '^[^@\s]+@[^@\s]+$' then
    select id into v_user from auth.users where lower(email) = lower(v_who);
  else
    select id into v_user from public.profiles where lower(username) = lower(ltrim(v_who, '@'));
  end if;
  if v_user is null or not exists (select 1 from public.profiles where id = v_user) then
    raise exception 'No account matches "%"', v_who;
  end if;
  if v_month not between 1 and 12 or v_day < 1 or v_day > extract(day from
       (make_date(2000, v_month, 1) + interval '1 month' - interval '1 day')) then
    raise exception '%/% is not a real date', v_day, v_month;
  end if;

  select to_char(make_date(2000, month, day), 'FMDD Month') into v_was
    from public.user_birthdays where user_id = v_user;
  insert into public.user_birthdays (user_id, month, day, set_at)
    values (v_user, v_month, v_day, now() - interval '2 days')
    on conflict (user_id) do update
      set month = excluded.month, day = excluded.day,
          set_at = least(public.user_birthdays.set_at, now() - interval '2 days');

  raise notice '% (%): birthday was %, now % (locked)',
    coalesce((select '@' || username from public.profiles where id = v_user), 'Player with no username'),
    v_user, coalesce(trim(v_was), 'not set'),
    trim(to_char(make_date(2000, v_month, v_day), 'FMDD Month'));
end $$;
