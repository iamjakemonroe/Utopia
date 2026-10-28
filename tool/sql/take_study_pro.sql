-- Takes back Chip Study Pro given with give_study_pro.sql, from the people
-- listed below. A paid subscription is left alone.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put usernames,
-- user IDs or emails in the list below, then Run.
do $$
declare
  v_people text[] := array['their_username'];  -- <- usernames, user IDs or emails
  v_who text;
  v_user uuid;
begin
  foreach v_who in array v_people loop
    v_who := trim(v_who);
    v_user := null;
    if v_who ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      v_user := v_who::uuid;
    elsif v_who ~ '^[^@\s]+@[^@\s]+$' then
      select id into v_user from auth.users where lower(email) = lower(v_who);
    else
      select id into v_user from public.profiles where lower(username) = lower(ltrim(v_who, '@'));
    end if;
    if v_user is null then
      raise exception 'No account matches "%"', v_who;
    end if;
    update public.web_subscriptions
       set status = 'ended', period_end = now(), updated_at = now()
     where ref = 'grant:study:' || v_user;
  end loop;
end $$;
