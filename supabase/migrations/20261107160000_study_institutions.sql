-- Chip Study for institutions, 2026-11-07.
--
-- A school, college or university registers, Kaivon checks it's real and
-- approves it, and its admins and teachers bring their students in: by
-- invite link, by class code, or (once Kaivon has confirmed the school's
-- email domain) by signing in with a school email. Students in an active
-- institution get Chip Study Pro, a pilot first and paid seats after.
--
-- What staff see, decided by the user: who's active, study time, practice
-- scores, Chip use and each assignment's AI-use record (the action and
-- its summary). Never chats, notes, documents, or the prompt and output
-- text kept in the AI-use log. Students are told this when they join.
--
-- Roles: an institution's admins run everything; teachers run their own
-- classes and see only those students. Kaivon staff (study_staff) review
-- institutions. All of it goes through the functions below: the tables
-- have row-level security on and no policies, so nothing is read directly.

-- ── Tables ──────────────────────────────────────────────────────────────

create table public.study_staff (
  user_id  uuid primary key references public.profiles (id) on delete cascade,
  added_at timestamptz not null default now()
);

create table public.study_institutions (
  id                uuid primary key default gen_random_uuid(),
  name              text not null check (char_length(btrim(name)) between 2 and 160),
  country           text not null check (country ~ '^[A-Z]{2}$'),
  kind              text not null check (kind in ('university', 'college', 'school', 'other')),
  website           text not null default '' check (char_length(website) <= 300),
  -- Asked for at sign-up; only Kaivon sets email_domain, at review, since
  -- anyone with that domain can then join and take a seat.
  domain_requested  text not null default '' check (char_length(domain_requested) <= 120),
  email_domain      text check (email_domain is null
                      or (email_domain = lower(email_domain) and email_domain ~ '^[a-z0-9.-]+\.[a-z]{2,}$')),
  contact_name      text not null default '' check (char_length(contact_name) <= 120),
  contact_role      text not null default '' check (char_length(contact_role) <= 120),
  students_estimate int check (students_estimate between 1 and 2000000),
  status            text not null default 'pending'
                      check (status in ('pending', 'approved', 'rejected', 'suspended')),
  plan              text not null default 'pilot' check (plan in ('pilot', 'paid')),
  seats             int not null default 0 check (seats >= 0),
  pilot_ends        date,
  paid_until        date,
  review_note       text not null default '' check (char_length(review_note) <= 1000),
  reviewed_by       uuid references public.profiles (id) on delete set null,
  reviewed_at       timestamptz,
  created_by        uuid references public.profiles (id) on delete set null,
  created_at        timestamptz not null default now()
);
-- One approved institution per email domain.
create unique index study_institutions_domain
  on public.study_institutions (email_domain) where email_domain is not null and status = 'approved';

create table public.study_institution_members (
  institution_id uuid not null references public.study_institutions (id) on delete cascade,
  user_id        uuid not null references public.profiles (id) on delete cascade,
  role           text not null check (role in ('admin', 'teacher', 'student')),
  joined_at      timestamptz not null default now(),
  added_by       uuid references public.profiles (id) on delete set null,
  primary key (institution_id, user_id)
);
create index study_institution_members_user on public.study_institution_members (user_id);

create table public.study_classes (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.study_institutions (id) on delete cascade,
  name           text not null check (char_length(btrim(name)) between 1 and 120),
  code           text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  archived       boolean not null default false,
  created_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now()
);
create index study_classes_institution on public.study_classes (institution_id);

create table public.study_class_members (
  class_id  uuid not null references public.study_classes (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  role      text not null check (role in ('teacher', 'student')),
  joined_at timestamptz not null default now(),
  primary key (class_id, user_id)
);
create index study_class_members_user on public.study_class_members (user_id);

create table public.study_institution_invites (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.study_institutions (id) on delete cascade,
  email          text not null check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  role           text not null check (role in ('admin', 'teacher', 'student')),
  class_id       uuid references public.study_classes (id) on delete set null,
  token          text not null unique,
  invited_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now(),
  expires_at     timestamptz not null default now() + interval '30 days',
  accepted_at    timestamptz,
  accepted_by    uuid references public.profiles (id) on delete set null,
  revoked        boolean not null default false
);
create index study_institution_invites_inst on public.study_institution_invites (institution_id);

alter table public.study_staff enable row level security;
alter table public.study_institutions enable row level security;
alter table public.study_institution_members enable row level security;
alter table public.study_classes enable row level security;
alter table public.study_class_members enable row level security;
alter table public.study_institution_invites enable row level security;

-- ── Helpers (not callable by users) ─────────────────────────────────────

create function public._study_is_staff(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.study_staff where user_id = p_user);
$$;

/** Approved, and inside its pilot or paid period. */
create function public._study_inst_active(p_inst uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.study_institutions i
     where i.id = p_inst and i.status = 'approved'
       and case i.plan
             when 'paid' then i.paid_until is null or i.paid_until >= current_date
             else i.pilot_ends is null or i.pilot_ends >= current_date end);
$$;

create function public._study_inst_role(p_inst uuid, p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select role from public.study_institution_members where institution_id = p_inst and user_id = p_user;
$$;

/** Whether [p_user] gets Pro through an active institution. */
create function public._study_institution_pro(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.study_institution_members m
                  where m.user_id = p_user and public._study_inst_active(m.institution_id));
$$;

/** The students [p_viewer] may see in [p_inst]: all of them for an admin,
 * those in their classes for a teacher, nobody otherwise. */
create function public._study_visible_students(p_inst uuid, p_viewer uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select m.user_id from public.study_institution_members m
   where m.institution_id = p_inst and m.role = 'student'
     and (public._study_inst_role(p_inst, p_viewer) = 'admin'
          or (public._study_inst_role(p_inst, p_viewer) = 'teacher'
              and exists (select 1 from public.study_class_members s
                            join public.study_class_members t on t.class_id = s.class_id
                            join public.study_classes c on c.id = s.class_id
                           where s.user_id = m.user_id and s.role = 'student'
                             and t.user_id = p_viewer and t.role = 'teacher'
                             and c.institution_id = p_inst and not c.archived)));
$$;

create function public._study_students_count(p_inst uuid)
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from public.study_institution_members where institution_id = p_inst and role = 'student';
$$;

create function public._study_new_token()
returns text language sql volatile as $$
  select replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
$$;

create function public._study_new_class_code()
returns text language plpgsql volatile set search_path = public as $$
declare
  v_letters constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
begin
  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_letters, 1 + floor(random() * length(v_letters))::int, 1);
    end loop;
    exit when not exists (select 1 from public.study_classes where code = v_code);
  end loop;
  return v_code;
end;
$$;

create function public._study_me_email()
returns text language sql stable security definer set search_path = public as $$
  select lower(email) from auth.users where id = auth.uid();
$$;

/** Signed in with a saved (not guest) account, or an error. */
create function public._study_need_account()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from auth.users where id = v_me and coalesce(is_anonymous, false)) then
    raise exception 'save your account first';
  end if;
  return v_me;
end;
$$;

/** Adds [p_user] as a student, if there's a seat. */
create function public._study_add_student(p_inst uuid, p_user uuid, p_by uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_role text := public._study_inst_role(p_inst, p_user);
begin
  if v_role is not null then return; end if;
  if not public._study_inst_active(p_inst) then raise exception 'institution not active'; end if;
  perform 1 from public.study_institutions where id = p_inst for update;
  if public._study_students_count(p_inst) >= (select seats from public.study_institutions where id = p_inst) then
    raise exception 'no seats left';
  end if;
  insert into public.study_institution_members (institution_id, user_id, role, added_by)
  values (p_inst, p_user, 'student', p_by);
end;
$$;

revoke all on function public._study_is_staff(uuid), public._study_inst_active(uuid),
  public._study_inst_role(uuid, uuid), public._study_institution_pro(uuid),
  public._study_visible_students(uuid, uuid), public._study_students_count(uuid),
  public._study_new_token(), public._study_new_class_code(), public._study_me_email(),
  public._study_need_account(), public._study_add_student(uuid, uuid, uuid)
  from public, anon, authenticated;

-- ── Pro through an institution ──────────────────────────────────────────

create or replace function public._study_tier(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public._web_plan_until(p_user, 'study_pro') is not null then 'pro'
    when public._study_institution_pro(p_user) then 'pro'
    when exists (select 1 from auth.users where id = p_user and coalesce(is_anonymous, false)) then 'guest'
    else 'free' end;
$$;
revoke all on function public._study_tier(uuid) from public, anon, authenticated;

-- ── Signing up and seeing your institutions ─────────────────────────────

create function public.study_institution_register(
  p_name text, p_country text, p_kind text, p_website text default '',
  p_email_domain text default '', p_contact_name text default '', p_contact_role text default '',
  p_students_estimate int default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._study_need_account();
  v_id uuid;
begin
  if (select count(*) from public.study_institutions where created_by = v_me and status = 'pending') >= 3 then
    raise exception 'too many waiting';
  end if;
  insert into public.study_institutions (name, country, kind, website, domain_requested,
                                          contact_name, contact_role, students_estimate, created_by)
  values (btrim(p_name), upper(btrim(p_country)), p_kind, btrim(coalesce(p_website, '')),
          lower(btrim(coalesce(p_email_domain, ''))), btrim(coalesce(p_contact_name, '')),
          btrim(coalesce(p_contact_role, '')), p_students_estimate, v_me)
  returning id into v_id;
  insert into public.study_institution_members (institution_id, user_id, role, added_by)
  values (v_id, v_me, 'admin', v_me);
  return v_id;
end;
$$;

/** The institutions you're in, and any whose email domain you share. */
create function public.study_my_institutions()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_domain text := split_part(coalesce(public._study_me_email(), ''), '@', 2);
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  return jsonb_build_object(
    'mine', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'name', i.name, 'kind', i.kind, 'country', i.country, 'status', i.status,
        'role', m.role, 'plan', i.plan, 'active', public._study_inst_active(i.id),
        'seats', i.seats, 'students', public._study_students_count(i.id),
        'pilot_ends', i.pilot_ends, 'paid_until', i.paid_until, 'joined_at', m.joined_at)
        order by m.joined_at)
        from public.study_institution_members m join public.study_institutions i on i.id = m.institution_id
       where m.user_id = v_me), '[]'::jsonb),
    'suggested', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'name', i.name, 'kind', i.kind, 'country', i.country))
        from public.study_institutions i
       where v_domain <> '' and i.email_domain = v_domain and public._study_inst_active(i.id)
         and not exists (select 1 from public.study_institution_members m
                          where m.institution_id = i.id and m.user_id = v_me)), '[]'::jsonb));
end;
$$;

-- ── An institution's dashboard ──────────────────────────────────────────

create function public.study_institution_overview(p_inst uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_role text := public._study_inst_role(p_inst, auth.uid());
  v_students uuid[];
  v_week date := current_date - 6;
begin
  if coalesce(v_role, '') not in ('admin', 'teacher') then raise exception 'not allowed'; end if;
  v_students := array(select public._study_visible_students(p_inst, v_me));
  return jsonb_build_object(
    'role', v_role,
    'institution', (select jsonb_build_object(
        'id', i.id, 'name', i.name, 'kind', i.kind, 'country', i.country, 'website', i.website,
        'status', i.status, 'plan', i.plan, 'active', public._study_inst_active(i.id),
        'seats', i.seats, 'pilot_ends', i.pilot_ends, 'paid_until', i.paid_until,
        'email_domain', i.email_domain, 'domain_requested', i.domain_requested,
        'contact_name', i.contact_name, 'contact_role', i.contact_role,
        'review_note', i.review_note, 'created_at', i.created_at)
        from public.study_institutions i where i.id = p_inst),
    'counts', jsonb_build_object(
        'students', public._study_students_count(p_inst),
        'visible_students', coalesce(array_length(v_students, 1), 0),
        'teachers', (select count(*) from public.study_institution_members where institution_id = p_inst and role = 'teacher'),
        'admins', (select count(*) from public.study_institution_members where institution_id = p_inst and role = 'admin'),
        'classes', (select count(*) from public.study_classes where institution_id = p_inst and not archived),
        'invites_open', (select count(*) from public.study_institution_invites
                          where institution_id = p_inst and accepted_at is null and not revoked and expires_at > now())),
    'week', jsonb_build_object(
        'active_students', (select count(distinct u) from (
            select user_id u from public.study_focus where user_id = any(v_students) and started_at::date >= v_week
            union select user_id from public.study_practice where user_id = any(v_students) and at::date >= v_week
            union select user_id from public.study_usage where user_id = any(v_students) and day >= v_week and asks > 0
          ) a),
        'focus_minutes', (select coalesce(sum(minutes), 0) from public.study_focus
                           where user_id = any(v_students) and started_at::date >= v_week),
        'practice_sessions', (select count(*) from public.study_practice where user_id = any(v_students) and at::date >= v_week),
        'practice_score', (select round(100.0 * sum(correct) / nullif(sum(total), 0)) from public.study_practice
                            where user_id = any(v_students) and at::date >= v_week),
        'chip_asks', (select coalesce(sum(asks), 0) from public.study_usage where user_id = any(v_students) and day >= v_week),
        'ai_records', (select count(*) from public.study_ai_log where user_id = any(v_students) and at::date >= v_week)),
    'weeks', (select coalesce(jsonb_agg(jsonb_build_object(
          'week', w.start,
          'active', (select count(distinct u) from (
              select user_id u from public.study_focus where user_id = any(v_students) and started_at::date between w.start and w.start + 6
              union select user_id from public.study_practice where user_id = any(v_students) and at::date between w.start and w.start + 6
              union select user_id from public.study_usage where user_id = any(v_students) and day between w.start and w.start + 6 and asks > 0
            ) a),
          'minutes', (select coalesce(sum(minutes), 0) from public.study_focus
                       where user_id = any(v_students) and started_at::date between w.start and w.start + 6))
          order by w.start), '[]'::jsonb)
        from (select (current_date - 6 - 7 * g)::date as start from generate_series(0, 7) g) w));
end;
$$;

create function public.study_institution_students(p_inst uuid, p_class uuid default null)
returns table (user_id uuid, name text, email text, role text, classes text[], joined_at timestamptz,
               last_active timestamptz, minutes_30d int, practice_score_30d int, asks_30d int,
               assignments int, ai_records int)
language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_role text := public._study_inst_role(p_inst, auth.uid());
  v_from date := current_date - 29;
begin
  if coalesce(v_role, '') not in ('admin', 'teacher') then raise exception 'not allowed'; end if;
  return query
  select m.user_id,
         coalesce(nullif(p.display_name, ''), p.username, split_part(au.email, '@', 1))::text,
         au.email::text,
         m.role,
         array(select c.name from public.study_class_members cm join public.study_classes c on c.id = cm.class_id
                where cm.user_id = m.user_id and c.institution_id = p_inst and not c.archived order by c.name),
         m.joined_at,
         greatest((select max(started_at) from public.study_focus f where f.user_id = m.user_id),
                  (select max(at) from public.study_practice pr where pr.user_id = m.user_id),
                  (select max(day)::timestamptz from public.study_usage su where su.user_id = m.user_id and su.asks > 0),
                  (select max(at) from public.study_ai_log l where l.user_id = m.user_id)),
         (select coalesce(sum(minutes), 0)::int from public.study_focus f where f.user_id = m.user_id and f.started_at::date >= v_from),
         (select round(100.0 * sum(correct) / nullif(sum(total), 0))::int from public.study_practice pr
           where pr.user_id = m.user_id and pr.at::date >= v_from),
         (select coalesce(sum(asks), 0)::int from public.study_usage su where su.user_id = m.user_id and su.day >= v_from),
         (select count(*)::int from public.study_assignments a where a.user_id = m.user_id),
         (select count(*)::int from public.study_ai_log l where l.user_id = m.user_id)
    from public.study_institution_members m
    join public.profiles p on p.id = m.user_id
    join auth.users au on au.id = m.user_id
   where m.institution_id = p_inst
     and (v_role = 'admin' or m.user_id in (select public._study_visible_students(p_inst, v_me)))
     and (p_class is null or exists (select 1 from public.study_class_members cm
                                      where cm.class_id = p_class and cm.user_id = m.user_id))
   order by m.role, 2;
end;
$$;

/** One student, for their admin or teacher: their assignments with study
 * time, practice and the AI-use record. Never chats, notes or documents,
 * and never the prompt or output text in the AI-use log. */
create function public.study_institution_student(p_inst uuid, p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
begin
  if p_user not in (select public._study_visible_students(p_inst, v_me)) then raise exception 'not allowed'; end if;
  return jsonb_build_object(
    'student', (select jsonb_build_object(
        'user_id', m.user_id,
        'name', coalesce(nullif(p.display_name, ''), p.username, split_part(au.email, '@', 1)),
        'email', au.email, 'joined_at', m.joined_at)
        from public.study_institution_members m join public.profiles p on p.id = m.user_id
        join auth.users au on au.id = m.user_id
       where m.institution_id = p_inst and m.user_id = p_user),
    'assignments', coalesce((select jsonb_agg(x order by x->>'updated' desc) from (
        select jsonb_build_object(
          'id', a.id, 'title', a.title, 'course', a.course, 'kind', a.kind, 'status', a.status,
          'due_at', a.due_at, 'words', a.words, 'updated', a.updated_at,
          'focus_minutes', (select coalesce(sum(minutes), 0) from public.study_focus f where f.assignment_id = a.id),
          'practice', (select jsonb_build_object('sessions', count(*),
                                                 'score', round(100.0 * sum(correct) / nullif(sum(total), 0)))
                         from public.study_practice pr where pr.assignment_id = a.id),
          'ai_use', coalesce((select jsonb_agg(jsonb_build_object(
                                'action', l.action, 'summary', l.summary, 'words', l.words, 'at', l.at)
                                order by l.at)
                                from public.study_ai_log l where l.assignment_id = a.id), '[]'::jsonb)) x
          from public.study_assignments a where a.user_id = p_user
         order by a.updated_at desc limit 60) t), '[]'::jsonb));
end;
$$;

-- ── Bringing people in ──────────────────────────────────────────────────

/** Invite links for [p_emails]. Admins invite anyone; teachers invite
 * students into a class of theirs. Students only once the institution is
 * active. Answers each email's link token (an open invite is reused). */
create function public.study_institution_invite(p_inst uuid, p_emails text[], p_role text, p_class uuid default null)
returns table (email text, token text, status text)
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_role text := public._study_inst_role(p_inst, auth.uid());
  v_email text;
  v_token text;
begin
  if p_role not in ('admin', 'teacher', 'student') then raise exception 'bad role'; end if;
  if v_role = 'teacher' then
    if p_role <> 'student' or p_class is null or not exists (
         select 1 from public.study_class_members where class_id = p_class and user_id = v_me and role = 'teacher') then
      raise exception 'not allowed';
    end if;
  elsif v_role is distinct from 'admin' then
    raise exception 'not allowed';
  end if;
  if (select si.status from public.study_institutions si where si.id = p_inst) in ('rejected', 'suspended') then
    raise exception 'institution not active';
  end if;
  if p_role = 'student' and not public._study_inst_active(p_inst) then raise exception 'institution not active'; end if;
  if p_class is not null and not exists (select 1 from public.study_classes sc where sc.id = p_class and sc.institution_id = p_inst) then
    raise exception 'not allowed';
  end if;
  if coalesce(array_length(p_emails, 1), 0) > 500 then raise exception 'too many'; end if;
  foreach v_email in array coalesce(p_emails, '{}') loop
    v_email := lower(btrim(v_email));
    continue when v_email = '';
    if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
      email := v_email; token := null; status := 'invalid'; return next; continue;
    end if;
    if exists (select 1 from public.study_institution_members m join auth.users au on au.id = m.user_id
                where m.institution_id = p_inst and lower(au.email) = v_email) then
      email := v_email; token := null; status := 'member'; return next; continue;
    end if;
    select i.token into v_token from public.study_institution_invites i
     where i.institution_id = p_inst and i.email = v_email and i.role = p_role
       and i.class_id is not distinct from p_class and i.accepted_at is null and not i.revoked and i.expires_at > now()
     limit 1;
    if v_token is null then
      v_token := public._study_new_token();
      insert into public.study_institution_invites (institution_id, email, role, class_id, token, invited_by)
      values (p_inst, v_email, p_role, p_class, v_token, v_me);
    end if;
    email := v_email; token := v_token; status := 'invited'; return next;
  end loop;
end;
$$;

create function public.study_invite_revoke(p_token text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_inv public.study_institution_invites;
begin
  select * into v_inv from public.study_institution_invites where token = p_token;
  if v_inv.id is null or public._study_inst_role(v_inv.institution_id, auth.uid()) is distinct from 'admin' then
    raise exception 'not allowed';
  end if;
  update public.study_institution_invites set revoked = true where id = v_inv.id;
end;
$$;

/** What an invite link is for, before accepting it. */
create function public.study_invite_peek(p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_inv public.study_institution_invites;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_inv from public.study_institution_invites where token = p_token;
  if v_inv.id is null then return jsonb_build_object('status', 'unknown'); end if;
  return jsonb_build_object(
    'status', case when v_inv.revoked then 'revoked' when v_inv.accepted_at is not null then 'used'
                   when v_inv.expires_at <= now() then 'expired' else 'open' end,
    'institution', (select name from public.study_institutions where id = v_inv.institution_id),
    'role', v_inv.role,
    'class', (select name from public.study_classes where id = v_inv.class_id),
    'email_matches', v_inv.email = public._study_me_email());
end;
$$;

create function public.study_invite_accept(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._study_need_account();
  v_inv public.study_institution_invites;
  v_role text;
begin
  select * into v_inv from public.study_institution_invites where token = p_token for update;
  if v_inv.id is null or v_inv.revoked or v_inv.accepted_at is not null or v_inv.expires_at <= now() then
    raise exception 'invite not open';
  end if;
  if v_inv.email <> public._study_me_email() then raise exception 'invite is for another email'; end if;
  v_role := public._study_inst_role(v_inv.institution_id, v_me);
  if v_inv.role = 'student' then
    if v_role is not null and v_role <> 'student' then raise exception 'already staff'; end if;
    perform public._study_add_student(v_inv.institution_id, v_me, v_inv.invited_by);
  elsif v_role is null then
    insert into public.study_institution_members (institution_id, user_id, role, added_by)
    values (v_inv.institution_id, v_me, v_inv.role, v_inv.invited_by);
  elsif v_role = 'student' or (v_role = 'teacher' and v_inv.role = 'admin') then
    update public.study_institution_members set role = v_inv.role
     where institution_id = v_inv.institution_id and user_id = v_me;
    if v_inv.role in ('teacher', 'admin') then
      delete from public.study_class_members cm using public.study_classes c
       where c.id = cm.class_id and c.institution_id = v_inv.institution_id and cm.user_id = v_me and cm.role = 'student';
    end if;
  end if;
  if v_inv.class_id is not null then
    insert into public.study_class_members (class_id, user_id, role)
    values (v_inv.class_id, v_me, case when v_inv.role = 'student' then 'student' else 'teacher' end)
    on conflict (class_id, user_id) do nothing;
  end if;
  update public.study_institution_invites set accepted_at = now(), accepted_by = v_me where id = v_inv.id;
  return jsonb_build_object('institution_id', v_inv.institution_id,
                            'name', (select name from public.study_institutions where id = v_inv.institution_id),
                            'role', public._study_inst_role(v_inv.institution_id, v_me));
end;
$$;

/** Joins as a student by school email, once Kaivon has confirmed the domain. */
create function public.study_institution_join_by_email(p_inst uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._study_need_account();
  v_domain text := split_part(coalesce(public._study_me_email(), ''), '@', 2);
begin
  if v_domain = '' or not exists (select 1 from public.study_institutions
                                   where id = p_inst and email_domain = v_domain) then
    raise exception 'not allowed';
  end if;
  perform public._study_add_student(p_inst, v_me, v_me);
  return jsonb_build_object('institution_id', p_inst, 'name', (select name from public.study_institutions where id = p_inst));
end;
$$;

-- ── Classes ─────────────────────────────────────────────────────────────

create function public.study_class_create(p_inst uuid, p_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_role text := public._study_inst_role(p_inst, auth.uid());
  v_class public.study_classes;
begin
  if coalesce(v_role, '') not in ('admin', 'teacher') then raise exception 'not allowed'; end if;
  if (select status from public.study_institutions where id = p_inst) in ('rejected', 'suspended') then
    raise exception 'institution not active';
  end if;
  if (select count(*) from public.study_classes where institution_id = p_inst) >= 2000 then raise exception 'too many'; end if;
  insert into public.study_classes (institution_id, name, code, created_by)
  values (p_inst, btrim(p_name), public._study_new_class_code(), v_me)
  returning * into v_class;
  if v_role = 'teacher' then
    insert into public.study_class_members (class_id, user_id, role) values (v_class.id, v_me, 'teacher');
  end if;
  return jsonb_build_object('id', v_class.id, 'name', v_class.name, 'code', v_class.code);
end;
$$;

create function public.study_classes_list(p_inst uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_role text := public._study_inst_role(p_inst, auth.uid());
begin
  if coalesce(v_role, '') not in ('admin', 'teacher') then raise exception 'not allowed'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', c.name, 'code', c.code, 'archived', c.archived, 'created_at', c.created_at,
      'teachers', coalesce((select jsonb_agg(jsonb_build_object('user_id', p.id,
                     'name', coalesce(nullif(p.display_name, ''), p.username, 'Teacher')))
                     from public.study_class_members cm join public.profiles p on p.id = cm.user_id
                    where cm.class_id = c.id and cm.role = 'teacher'), '[]'::jsonb),
      'students', (select count(*) from public.study_class_members cm where cm.class_id = c.id and cm.role = 'student'))
      order by c.archived, c.name)
      from public.study_classes c
     where c.institution_id = p_inst
       and (v_role = 'admin' or exists (select 1 from public.study_class_members t
                                         where t.class_id = c.id and t.user_id = v_me and t.role = 'teacher'))), '[]'::jsonb);
end;
$$;

create function public.study_class_update(p_class uuid, p_name text default null, p_archived boolean default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_inst uuid := (select institution_id from public.study_classes where id = p_class);
begin
  if not (coalesce(public._study_inst_role(v_inst, auth.uid()) = 'admin', false)
          or exists (select 1 from public.study_class_members where class_id = p_class
                      and user_id = auth.uid() and role = 'teacher')) then
    raise exception 'not allowed';
  end if;
  update public.study_classes
     set name = coalesce(nullif(btrim(p_name), ''), name), archived = coalesce(p_archived, archived)
   where id = p_class;
end;
$$;

/** Adds [p_user] to a class as [p_role], or takes them out (null). */
create function public.study_class_member_set(p_class uuid, p_user uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_inst uuid := (select institution_id from public.study_classes where id = p_class);
  v_admin boolean := coalesce(public._study_inst_role(v_inst, auth.uid()) = 'admin', false);
  v_their_role text := public._study_inst_role(v_inst, p_user);
begin
  if not (v_admin or exists (select 1 from public.study_class_members where class_id = p_class
                              and user_id = auth.uid() and role = 'teacher')) then
    raise exception 'not allowed';
  end if;
  if v_their_role is null then raise exception 'not a member'; end if;
  if p_role is null then
    delete from public.study_class_members where class_id = p_class and user_id = p_user;
    return;
  end if;
  if p_role = 'teacher' and (not v_admin or v_their_role = 'student') then raise exception 'not allowed'; end if;
  if p_role = 'student' and v_their_role <> 'student' then raise exception 'not allowed'; end if;
  insert into public.study_class_members (class_id, user_id, role) values (p_class, p_user, p_role)
  on conflict (class_id, user_id) do update set role = excluded.role;
end;
$$;

/** Joins a class (and its institution, as a student) with its code. */
create function public.study_class_join(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._study_need_account();
  v_class public.study_classes;
  v_role text;
begin
  select * into v_class from public.study_classes where code = upper(btrim(p_code)) and not archived;
  if v_class.id is null then raise exception 'no such class'; end if;
  v_role := public._study_inst_role(v_class.institution_id, v_me);
  if v_role is not null and v_role <> 'student' then raise exception 'already staff'; end if;
  perform public._study_add_student(v_class.institution_id, v_me, v_me);
  insert into public.study_class_members (class_id, user_id, role) values (v_class.id, v_me, 'student')
  on conflict (class_id, user_id) do nothing;
  return jsonb_build_object('institution_id', v_class.institution_id, 'class', v_class.name,
                            'name', (select name from public.study_institutions where id = v_class.institution_id));
end;
$$;

-- ── Running the institution ─────────────────────────────────────────────

create function public.study_institution_update(
  p_inst uuid, p_name text default null, p_website text default null,
  p_contact_name text default null, p_contact_role text default null, p_domain_requested text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if public._study_inst_role(p_inst, auth.uid()) is distinct from 'admin' then raise exception 'not allowed'; end if;
  update public.study_institutions set
    name = coalesce(nullif(btrim(p_name), ''), name),
    website = coalesce(btrim(p_website), website),
    contact_name = coalesce(btrim(p_contact_name), contact_name),
    contact_role = coalesce(btrim(p_contact_role), contact_role),
    domain_requested = coalesce(lower(btrim(p_domain_requested)), domain_requested)
   where id = p_inst;
end;
$$;

/** Changes a member's role, or removes them from the institution (null). */
create function public.study_institution_member_set(p_inst uuid, p_user uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_their_role text := public._study_inst_role(p_inst, p_user);
begin
  if public._study_inst_role(p_inst, auth.uid()) is distinct from 'admin' then raise exception 'not allowed'; end if;
  if v_their_role is null then raise exception 'not a member'; end if;
  if v_their_role = 'admin' and coalesce(p_role, '') <> 'admin'
     and (select count(*) from public.study_institution_members where institution_id = p_inst and role = 'admin') <= 1 then
    raise exception 'last admin';
  end if;
  if p_role is null then
    delete from public.study_class_members cm using public.study_classes c
     where c.id = cm.class_id and c.institution_id = p_inst and cm.user_id = p_user;
    delete from public.study_institution_members where institution_id = p_inst and user_id = p_user;
    return;
  end if;
  if p_role not in ('admin', 'teacher', 'student') then raise exception 'bad role'; end if;
  if p_role = 'student' and v_their_role <> 'student' then
    if public._study_students_count(p_inst) >= (select seats from public.study_institutions where id = p_inst) then
      raise exception 'no seats left';
    end if;
  end if;
  update public.study_institution_members set role = p_role where institution_id = p_inst and user_id = p_user;
  update public.study_class_members cm set role = case when p_role = 'student' then 'student' else 'teacher' end
    from public.study_classes c where c.id = cm.class_id and c.institution_id = p_inst and cm.user_id = p_user;
end;
$$;

create function public.study_institution_leave(p_inst uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
begin
  if public._study_inst_role(p_inst, v_me) is null then raise exception 'not a member'; end if;
  if public._study_inst_role(p_inst, v_me) = 'admin'
     and (select count(*) from public.study_institution_members where institution_id = p_inst and role = 'admin') <= 1 then
    raise exception 'last admin';
  end if;
  delete from public.study_class_members cm using public.study_classes c
   where c.id = cm.class_id and c.institution_id = p_inst and cm.user_id = v_me;
  delete from public.study_institution_members where institution_id = p_inst and user_id = v_me;
end;
$$;

-- ── Kaivon's review ─────────────────────────────────────────────────────

create function public.study_staff_institutions(p_status text default 'pending')
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public._study_is_staff(auth.uid()) then raise exception 'not allowed'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', i.id, 'name', i.name, 'kind', i.kind, 'country', i.country, 'website', i.website,
      'domain_requested', i.domain_requested, 'email_domain', i.email_domain,
      'contact_name', i.contact_name, 'contact_role', i.contact_role,
      'contact_email', (select email from auth.users where id = i.created_by),
      'students_estimate', i.students_estimate, 'status', i.status, 'plan', i.plan, 'seats', i.seats,
      'students', public._study_students_count(i.id), 'pilot_ends', i.pilot_ends, 'paid_until', i.paid_until,
      'review_note', i.review_note, 'created_at', i.created_at, 'reviewed_at', i.reviewed_at)
      order by i.created_at desc)
      from public.study_institutions i
     where p_status = 'all' or i.status = p_status), '[]'::jsonb);
end;
$$;

/** Kaivon's decision on an institution: approve (with seats, pilot length
 * and, if checked, its email domain), reject, suspend, or move to paid. */
create function public.study_staff_review(
  p_inst uuid, p_status text, p_seats int default null, p_pilot_days int default null,
  p_email_domain text default null, p_note text default null, p_plan text default null, p_paid_until date default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_domain text := nullif(lower(btrim(coalesce(p_email_domain, ''))), '');
begin
  if not public._study_is_staff(auth.uid()) then raise exception 'not allowed'; end if;
  if p_status not in ('approved', 'rejected', 'suspended', 'pending') then raise exception 'bad status'; end if;
  if v_domain in ('gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com', 'icloud.com', 'live.com', 'aol.com',
                  'proton.me', 'protonmail.com', 'ymail.com', 'mail.com', 'gmx.com') then
    raise exception 'public email domain';
  end if;
  update public.study_institutions set
    status = p_status,
    seats = coalesce(p_seats, case when p_status = 'approved' and seats = 0 then 50 else seats end),
    pilot_ends = case when p_pilot_days is not null then current_date + p_pilot_days
                      when p_status = 'approved' and pilot_ends is null then current_date + 90
                      else pilot_ends end,
    email_domain = coalesce(v_domain, email_domain),
    plan = coalesce(p_plan, plan),
    paid_until = coalesce(p_paid_until, paid_until),
    review_note = coalesce(p_note, review_note),
    reviewed_by = auth.uid(),
    reviewed_at = now()
   where id = p_inst;
  if not found then raise exception 'no such institution'; end if;
end;
$$;

-- ── Grants ──────────────────────────────────────────────────────────────

revoke all on function
  public.study_institution_register(text, text, text, text, text, text, text, int),
  public.study_my_institutions(),
  public.study_institution_overview(uuid),
  public.study_institution_students(uuid, uuid),
  public.study_institution_student(uuid, uuid),
  public.study_institution_invite(uuid, text[], text, uuid),
  public.study_invite_revoke(text),
  public.study_invite_peek(text),
  public.study_invite_accept(text),
  public.study_institution_join_by_email(uuid),
  public.study_class_create(uuid, text),
  public.study_classes_list(uuid),
  public.study_class_update(uuid, text, boolean),
  public.study_class_member_set(uuid, uuid, text),
  public.study_class_join(text),
  public.study_institution_update(uuid, text, text, text, text, text),
  public.study_institution_member_set(uuid, uuid, text),
  public.study_institution_leave(uuid),
  public.study_staff_institutions(text),
  public.study_staff_review(uuid, text, int, int, text, text, text, date)
  from public, anon;

grant execute on function
  public.study_institution_register(text, text, text, text, text, text, text, int),
  public.study_my_institutions(),
  public.study_institution_overview(uuid),
  public.study_institution_students(uuid, uuid),
  public.study_institution_student(uuid, uuid),
  public.study_institution_invite(uuid, text[], text, uuid),
  public.study_invite_revoke(text),
  public.study_invite_peek(text),
  public.study_invite_accept(text),
  public.study_institution_join_by_email(uuid),
  public.study_class_create(uuid, text),
  public.study_classes_list(uuid),
  public.study_class_update(uuid, text, boolean),
  public.study_class_member_set(uuid, uuid, text),
  public.study_class_join(text),
  public.study_institution_update(uuid, text, text, text, text, text),
  public.study_institution_member_set(uuid, uuid, text),
  public.study_institution_leave(uuid),
  public.study_staff_institutions(text),
  public.study_staff_review(uuid, text, int, int, text, text, text, date)
  to authenticated;
