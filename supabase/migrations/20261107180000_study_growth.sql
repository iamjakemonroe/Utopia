-- Chip Study's next round, 2026-11-07:
--   * invite a friend: you both get a week of Pro once they've really used it;
--   * campus reps: a named link with sign-ups counted, for Kaivon to see;
--   * an age rule: 18 or over, or under 18 with a parent or guardian's
--     agreement; schools with under-18 students confirm parental consent;
--   * course tutors: a lecturer describes their course and how much help
--     Chip may give, and students who link an assignment to the class get
--     that version of Chip;
--   * what a class is stuck on: anonymous themes from the questions asked in
--     a class's assignments, only for 5 or more students, no quotes, no names.

-- ── Invite a friend, and campus reps ────────────────────────────────────

create table public.study_referral_codes (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  code       text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  rep_name   text check (rep_name is null or char_length(btrim(rep_name)) between 1 and 120),
  rep_since  timestamptz,
  created_at timestamptz not null default now()
);

create table public.study_referrals (
  user_id     uuid primary key references public.profiles (id) on delete cascade,
  referrer    uuid not null references public.profiles (id) on delete cascade,
  code        text not null,
  created_at  timestamptz not null default now(),
  -- When both got their week: once the new person had asked Chip 3 times.
  rewarded_at timestamptz,
  check (user_id <> referrer)
);
create index study_referrals_referrer on public.study_referrals (referrer);

alter table public.study_referral_codes enable row level security;
alter table public.study_referrals enable row level security;

create function public._study_new_referral_code()
returns text language plpgsql volatile set search_path = public as $$
declare
  v_letters constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
begin
  loop
    v_code := '';
    for i in 1..8 loop
      v_code := v_code || substr(v_letters, 1 + floor(random() * length(v_letters))::int, 1);
    end loop;
    exit when not exists (select 1 from public.study_referral_codes where code = v_code);
  end loop;
  return v_code;
end;
$$;

/** [p_user]'s code, made the first time. */
create function public._study_referral_code(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_code text := (select code from public.study_referral_codes where user_id = p_user);
begin
  if v_code is null then
    insert into public.study_referral_codes (user_id, code) values (p_user, public._study_new_referral_code())
    on conflict (user_id) do nothing;
    v_code := (select code from public.study_referral_codes where user_id = p_user);
  end if;
  return v_code;
end;
$$;

/** A week of Chip Study Pro for [p_user], after any Pro they already have. */
create function public._study_give_week(p_user uuid, p_ref text)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.web_subscriptions (user_id, plan_id, currency, amount, ref, email, status, period_end)
  values (p_user, 'study.pro.monthly', 'USD', 0, p_ref,
          coalesce((select email from auth.users where id = p_user), ''), 'active',
          greatest(coalesce(public._web_plan_until(p_user, 'study_pro'), now()), now()) + interval '7 days')
  on conflict (ref) do nothing;
end;
$$;

/** Weeks a referrer can earn in a year. */
create function public._study_referral_cap()
returns int language sql immutable as $$ select 12 $$;

/** Gives the weeks now due for referrals [p_user] is part of: once the new
 * person has asked Chip 3 times, both get a week (the referrer up to the
 * yearly cap; the new person always). */
create function public._study_settle_referrals(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  r public.study_referrals;
begin
  for r in
    select * from public.study_referrals
     where rewarded_at is null and (user_id = p_user or referrer = p_user)
       and (select coalesce(sum(asks), 0) from public.study_usage u where u.user_id = study_referrals.user_id) >= 3
     for update
  loop
    perform public._study_give_week(r.user_id, 'referral:study:joined:' || r.user_id);
    if (select count(*) from public.study_referrals
         where referrer = r.referrer and rewarded_at > now() - interval '365 days') < public._study_referral_cap() then
      perform public._study_give_week(r.referrer, 'referral:study:invited:' || r.user_id);
    end if;
    update public.study_referrals set rewarded_at = now() where user_id = r.user_id;
  end loop;
end;
$$;

revoke all on function public._study_new_referral_code(), public._study_referral_code(uuid),
  public._study_give_week(uuid, text), public._study_referral_cap(), public._study_settle_referrals(uuid)
  from public, anon, authenticated;

/** Your invite code and how it's going (and settles any weeks now due). */
create function public.study_my_referral()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._study_need_account();
  v_code text;
begin
  perform public._study_settle_referrals(v_me);
  v_code := public._study_referral_code(v_me);
  return jsonb_build_object(
    'code', v_code,
    'rep', (select rep_name from public.study_referral_codes where user_id = v_me),
    'invited', (select count(*) from public.study_referrals where referrer = v_me),
    'active', (select count(*) from public.study_referrals where referrer = v_me and rewarded_at is not null),
    'weeks_this_year', (select count(*) from public.study_referrals
                         where referrer = v_me and rewarded_at > now() - interval '365 days'),
    'cap', public._study_referral_cap(),
    'referred_by', (select coalesce(nullif(p.display_name, ''), p.username, 'a friend')
                      from public.study_referrals r join public.profiles p on p.id = r.referrer
                     where r.user_id = v_me),
    'my_week', (select case when r.rewarded_at is not null then 'given' else 'waiting' end
                  from public.study_referrals r where r.user_id = v_me),
    'weeks', (select coalesce(jsonb_agg(jsonb_build_object('week', w.start, 'joined', w.n) order by w.start), '[]'::jsonb)
                from (select (current_date - 6 - 7 * g)::date as start,
                             (select count(*) from public.study_referrals r
                               where r.referrer = v_me
                                 and r.created_at::date between (current_date - 6 - 7 * g) and (current_date - 7 * g)) as n
                        from generate_series(0, 7) g) w));
end;
$$;

/** A new account says who brought them, within its first 14 days. */
create function public.study_referral_redeem(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._study_need_account();
  v_owner uuid := (select user_id from public.study_referral_codes where code = upper(btrim(coalesce(p_code, ''))));
begin
  if v_owner is null then raise exception 'no such code'; end if;
  if v_owner = v_me then raise exception 'your own code'; end if;
  if exists (select 1 from public.study_referrals where user_id = v_me) then raise exception 'already referred'; end if;
  if (select created_at from auth.users where id = v_me) < now() - interval '14 days' then raise exception 'too late'; end if;
  insert into public.study_referrals (user_id, referrer, code) values (v_me, v_owner, upper(btrim(p_code)));
  perform public._study_settle_referrals(v_me);
  return jsonb_build_object('referrer', (select coalesce(nullif(display_name, ''), username, 'a friend')
                                           from public.profiles where id = v_owner));
end;
$$;

/** Kaivon's view of campus reps: sign-ups and how many really used it. */
create function public.study_staff_reps()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public._study_is_staff(auth.uid()) then raise exception 'not allowed'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'user_id', c.user_id, 'name', c.rep_name, 'code', c.code, 'since', c.rep_since,
      'email', (select email from auth.users where id = c.user_id),
      'signups', (select count(*) from public.study_referrals r where r.referrer = c.user_id),
      'signups_7d', (select count(*) from public.study_referrals r where r.referrer = c.user_id
                      and r.created_at > now() - interval '7 days'),
      'signups_30d', (select count(*) from public.study_referrals r where r.referrer = c.user_id
                       and r.created_at > now() - interval '30 days'),
      'active', (select count(*) from public.study_referrals r where r.referrer = c.user_id and r.rewarded_at is not null))
      order by c.rep_since desc)
      from public.study_referral_codes c where c.rep_name is not null), '[]'::jsonb);
end;
$$;

/** Makes someone a campus rep (by email, username or ID), or stops it (null name). */
create function public.study_staff_set_rep(p_who text, p_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_who text := btrim(coalesce(p_who, ''));
  v_user uuid;
begin
  if not public._study_is_staff(auth.uid()) then raise exception 'not allowed'; end if;
  if v_who ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_user := v_who::uuid;
  elsif position('@' in v_who) > 0 then
    select id into v_user from auth.users where lower(email) = lower(v_who);
  else
    select id into v_user from public.profiles where lower(username) = lower(ltrim(v_who, '@'));
  end if;
  if v_user is null or not exists (select 1 from public.profiles where id = v_user) then
    raise exception 'no such account';
  end if;
  perform public._study_referral_code(v_user);
  update public.study_referral_codes
     set rep_name = nullif(btrim(coalesce(p_name, '')), ''),
         rep_since = case when nullif(btrim(coalesce(p_name, '')), '') is null then null else coalesce(rep_since, now()) end
   where user_id = v_user;
  return jsonb_build_object('user_id', v_user, 'code', (select code from public.study_referral_codes where user_id = v_user));
end;
$$;

-- ── The age rule ────────────────────────────────────────────────────────

create table public.study_age (
  user_id     uuid primary key references public.profiles (id) on delete cascade,
  answer      text not null check (answer in ('adult', 'guardian')),
  answered_at timestamptz not null default now()
);
alter table public.study_age enable row level security;

create function public.study_age_get()
returns text language sql stable security definer set search_path = public as $$
  select answer from public.study_age where user_id = auth.uid();
$$;

/** 'adult': 18 or over. 'guardian': under 18, with a parent or guardian's
 * agreement. Under 13 can't use Chip Study, so there's no answer for it. */
create function public.study_age_confirm(p_answer text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_answer not in ('adult', 'guardian') then raise exception 'bad answer'; end if;
  insert into public.study_age (user_id, answer) values (auth.uid(), p_answer)
  on conflict (user_id) do update set answer = excluded.answer, answered_at = now();
end;
$$;

alter table public.study_institutions
  add column minors_consent boolean not null default false;

-- Registering now says whether students under 18 will join, and a school
-- (where they will) confirms it has parents' consent.
drop function public.study_institution_register(text, text, text, text, text, text, text, int);
create function public.study_institution_register(
  p_name text, p_country text, p_kind text, p_website text default '',
  p_email_domain text default '', p_contact_name text default '', p_contact_role text default '',
  p_students_estimate int default null, p_minors_consent boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._study_need_account();
  v_id uuid;
begin
  if p_kind = 'school' and not coalesce(p_minors_consent, false) then raise exception 'parental consent needed'; end if;
  if (select count(*) from public.study_institutions where created_by = v_me and status = 'pending') >= 3 then
    raise exception 'too many waiting';
  end if;
  insert into public.study_institutions (name, country, kind, website, domain_requested, contact_name,
                                          contact_role, students_estimate, minors_consent, created_by)
  values (btrim(p_name), upper(btrim(p_country)), p_kind, btrim(coalesce(p_website, '')),
          lower(btrim(coalesce(p_email_domain, ''))), btrim(coalesce(p_contact_name, '')),
          btrim(coalesce(p_contact_role, '')), p_students_estimate, coalesce(p_minors_consent, false), v_me)
  returning id into v_id;
  insert into public.study_institution_members (institution_id, user_id, role, added_by)
  values (v_id, v_me, 'admin', v_me);
  return v_id;
end;
$$;

-- ── Course tutors ───────────────────────────────────────────────────────

alter table public.study_classes
  add column course_brief text not null default '' check (char_length(course_brief) <= 6000),
  add column help_level   text not null default 'guide' check (help_level in ('guide', 'explain', 'hints')),
  add column tutor_notes  text not null default '' check (char_length(tutor_notes) <= 3000);

alter table public.study_assignments
  add column class_id uuid references public.study_classes (id) on delete set null;
create index study_assignments_class on public.study_assignments (class_id) where class_id is not null;

/** Whether [p_user] runs class [p_class]: an admin of its institution or one of its teachers. */
create function public._study_runs_class(p_class uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public._study_inst_role((select institution_id from public.study_classes where id = p_class), p_user) = 'admin', false)
      or exists (select 1 from public.study_class_members where class_id = p_class and user_id = p_user and role = 'teacher');
$$;
revoke all on function public._study_runs_class(uuid, uuid) from public, anon, authenticated;

create function public.study_class_tutor_set(p_class uuid, p_course_brief text, p_help_level text, p_tutor_notes text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public._study_runs_class(p_class, auth.uid()) then raise exception 'not allowed'; end if;
  update public.study_classes
     set course_brief = btrim(coalesce(p_course_brief, '')),
         help_level = coalesce(p_help_level, help_level),
         tutor_notes = btrim(coalesce(p_tutor_notes, ''))
   where id = p_class;
end;
$$;

/** A class's course tutor, for whoever runs it or studies in it. */
create function public.study_class_tutor_get(p_class uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not (public._study_runs_class(p_class, auth.uid())
          or exists (select 1 from public.study_class_members where class_id = p_class and user_id = auth.uid())) then
    raise exception 'not allowed';
  end if;
  return (select jsonb_build_object('id', c.id, 'name', c.name, 'institution', i.name,
                                    'course_brief', c.course_brief, 'help_level', c.help_level, 'tutor_notes', c.tutor_notes)
            from public.study_classes c join public.study_institutions i on i.id = c.institution_id where c.id = p_class);
end;
$$;

/** The classes you study in, to link an assignment to. */
create function public.study_my_classes()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'institution', i.name,
                                               'help_level', c.help_level) order by i.name, c.name), '[]'::jsonb)
    from public.study_class_members m
    join public.study_classes c on c.id = m.class_id
    join public.study_institutions i on i.id = c.institution_id
   where m.user_id = auth.uid() and m.role = 'student' and not c.archived and public._study_inst_active(i.id);
$$;

/** Links your assignment to a class you study in, or unlinks it (null). */
create function public.study_assignment_set_class(p_assignment uuid, p_class uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.study_assignments where id = p_assignment and user_id = auth.uid()) then
    raise exception 'not allowed';
  end if;
  if p_class is not null and not exists (select 1 from public.study_class_members
                                          where class_id = p_class and user_id = auth.uid() and role = 'student') then
    raise exception 'not allowed';
  end if;
  update public.study_assignments set class_id = p_class where id = p_assignment;
end;
$$;

/** The course tutor for one of your assignments, for Chip (chip-study
 * function): only while you're a student in the class and it's active. */
create function public.study_assignment_tutor(p_assignment uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('class', c.name, 'institution', i.name, 'course_brief', c.course_brief,
                            'help_level', c.help_level, 'tutor_notes', c.tutor_notes)
    from public.study_assignments a
    join public.study_classes c on c.id = a.class_id
    join public.study_institutions i on i.id = c.institution_id
   where a.id = p_assignment and a.user_id = auth.uid() and not c.archived
     and public._study_inst_active(i.id)
     and exists (select 1 from public.study_class_members m
                  where m.class_id = c.id and m.user_id = auth.uid() and m.role = 'student');
$$;

-- ── What a class is stuck on ────────────────────────────────────────────

create table public.study_class_themes (
  class_id     uuid primary key references public.study_classes (id) on delete cascade,
  generated_at timestamptz not null default now(),
  students     int not null,
  questions    int not null,
  themes       jsonb not null default '[]'::jsonb
);
alter table public.study_class_themes enable row level security;

create function public._study_theme_min_students()
returns int language sql immutable as $$ select 5 $$;

/** The last 14 days of questions asked to Chip in a class's assignments, by
 * students still in it, without names: for the chip-study function to
 * turn into anonymous themes. Only for whoever runs the class, and only
 * when 5 or more students asked. */
create function public.study_class_theme_source(p_class uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_students int;
begin
  if not public._study_runs_class(p_class, auth.uid()) then raise exception 'not allowed'; end if;
  select count(distinct q.user_id) into v_students
    from public.study_messages q join public.study_assignments a on a.id = q.assignment_id
   where a.class_id = p_class and q.role = 'user' and q.created_at > now() - interval '14 days'
     and exists (select 1 from public.study_class_members m
                  where m.class_id = p_class and m.user_id = q.user_id and m.role = 'student');
  if v_students < public._study_theme_min_students() then
    return jsonb_build_object('students', v_students, 'enough', false, 'questions', '[]'::jsonb);
  end if;
  return jsonb_build_object('students', v_students, 'enough', true,
    'questions', (select coalesce(jsonb_agg(t.content), '[]'::jsonb) from (
        select left(q.content, 300) as content
          from public.study_messages q join public.study_assignments a on a.id = q.assignment_id
         where a.class_id = p_class and q.role = 'user' and q.created_at > now() - interval '14 days'
           and exists (select 1 from public.study_class_members m
                        where m.class_id = p_class and m.user_id = q.user_id and m.role = 'student')
         order by random() limit 400) t));
end;
$$;

create function public.study_class_themes_get(p_class uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public._study_runs_class(p_class, auth.uid()) then raise exception 'not allowed'; end if;
  return (select jsonb_build_object('generated_at', generated_at, 'students', students,
                                    'questions', questions, 'themes', themes)
            from public.study_class_themes where class_id = p_class);
end;
$$;

-- ── Grants ──────────────────────────────────────────────────────────────

revoke all on function
  public.study_my_referral(), public.study_referral_redeem(text), public.study_staff_reps(),
  public.study_staff_set_rep(text, text), public.study_age_get(), public.study_age_confirm(text),
  public.study_institution_register(text, text, text, text, text, text, text, int, boolean),
  public.study_class_tutor_set(uuid, text, text, text), public.study_class_tutor_get(uuid),
  public.study_my_classes(), public.study_assignment_set_class(uuid, uuid), public.study_assignment_tutor(uuid),
  public.study_class_theme_source(uuid), public.study_class_themes_get(uuid)
  from public, anon;
revoke all on function public._study_theme_min_students() from public, anon, authenticated;

grant execute on function
  public.study_my_referral(), public.study_referral_redeem(text), public.study_staff_reps(),
  public.study_staff_set_rep(text, text), public.study_age_get(), public.study_age_confirm(text),
  public.study_institution_register(text, text, text, text, text, text, text, int, boolean),
  public.study_class_tutor_set(uuid, text, text, text), public.study_class_tutor_get(uuid),
  public.study_my_classes(), public.study_assignment_set_class(uuid, uuid), public.study_assignment_tutor(uuid),
  public.study_class_theme_source(uuid), public.study_class_themes_get(uuid)
  to authenticated;
