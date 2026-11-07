-- Makes the people listed below Kaivon staff in Chip Study: they see
-- "Kaivon review" in the app, where institutions that registered wait to
-- be approved (with their seats, pilot length and school email domain),
-- rejected, suspended or moved to paid.
--
-- Run in the Supabase dashboard: SQL Editor > New query. Put the email you
-- sign in to Chip Study with (or a username or user ID) in the list below,
-- then Run. The table at the end shows everyone who's staff. To take it
-- away: delete from public.study_staff where user_id = '<their id>';
do $$
declare
  v_people text[] := array['you@example.com'];  -- <- emails, usernames or user IDs
  v_who text;
  v_user uuid;
begin
  foreach v_who in array v_people loop
    v_who := trim(v_who);
    v_user := null;
    if v_who ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      v_user := v_who::uuid;
    elsif position('@' in v_who) > 0 then
      select id into v_user from auth.users where lower(email) = lower(v_who);
    else
      select id into v_user from public.profiles where lower(username) = lower(v_who);
    end if;
    if v_user is null or not exists (select 1 from public.profiles where id = v_user) then
      raise notice 'No account for %, skipped', v_who;
      continue;
    end if;
    insert into public.study_staff (user_id) values (v_user) on conflict (user_id) do nothing;
    raise notice '% is Kaivon staff', v_who;
  end loop;
end $$;

select s.user_id, u.email, s.added_at
  from public.study_staff s join auth.users u on u.id = s.user_id
 order by s.added_at;
