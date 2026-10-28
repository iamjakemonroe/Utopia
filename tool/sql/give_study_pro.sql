-- Gives Chip Study Pro, free, to the people listed below for v_years:
--   * Chip's best model (with its daily fair use), and Fast on top;
--   * web research for sources;
--   * 20 MB uploads and 30 readings a day.
-- A grant has no monthly cap on the best model, only the daily one, so
-- keep it to people you'd give it to anyway. Running it again sets the end
-- to v_years from now (never sooner than it was). A paid subscription is
-- left alone. take_study_pro.sql takes it back.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put usernames,
-- user IDs or emails in the list below, then Run. The table at the end
-- shows everyone with a grant, and until when. Reload Chip Study to see Pro.
do $$
declare
  v_people text[] := array['their_username'];  -- <- usernames, user IDs or emails
  v_years int := 10;                            -- how long it lasts
  v_who text;
  v_user uuid;
  v_email text;
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
    select email into v_email from auth.users where id = v_user;
    if v_user is null or not found or not exists (select 1 from public.profiles where id = v_user) then
      raise exception 'No account matches "%"', v_who;
    end if;

    insert into public.web_subscriptions (user_id, plan_id, currency, amount, ref, email, status, period_end)
    values (v_user, 'study.pro.monthly', 'USD', 0, 'grant:study:' || v_user, coalesce(v_email, ''),
            'active', now() + make_interval(years => v_years))
    on conflict (ref) do update
      set status = 'active',
          period_end = greatest(public.web_subscriptions.period_end, excluded.period_end),
          updated_at = now();
  end loop;
end $$;

select p.username, p.display_name, s.user_id, s.period_end as pro_until
  from public.web_subscriptions s
  join public.profiles p on p.id = s.user_id
 where s.ref like 'grant:study:%' and s.status = 'active'
 order by s.period_end desc;
