-- Chip Study inside Moodle, Canvas, Blackboard and Brightspace (LTI 1.3),
-- 2026-11-07.
--
-- An institution's admin registers its learning platform once (issuer,
-- client ID, deployment, and the platform's sign-in and key addresses).
-- Then a lecturer adds Chip Study to a course: when someone clicks it, the
-- study-lti function checks the platform's signed launch, signs them in to
-- Chip Study with their school email, and puts them in a class for that
-- course (as a teacher for instructors, a student for learners). Students
-- see the institution's privacy terms on their first visit.
--
-- Who gets signed in: a platform is registered by the institution's own
-- admin, so its word on an email address is only taken for the email domain
-- Kaivon staff confirmed belongs to that institution (or its subdomains).
-- Anyone else (another domain, or no email shared) signs in to Chip Study
-- themselves once, which links their platform account to their Chip Study
-- account; after that, launches sign them straight in.

create table public.study_lti_platforms (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.study_institutions (id) on delete cascade,
  name           text not null default '' check (char_length(name) <= 120),
  issuer         text not null check (issuer ~ '^https://'),
  client_id      text not null check (char_length(client_id) between 1 and 200),
  deployment_id  text not null check (char_length(deployment_id) between 1 and 200),
  auth_url       text not null check (auth_url ~ '^https://'),
  jwks_url       text not null check (jwks_url ~ '^https://'),
  created_at     timestamptz not null default now(),
  unique (issuer, client_id, deployment_id)
);

-- One sign-in attempt's state and nonce, kept a few minutes.
create table public.study_lti_states (
  state       text primary key,
  nonce       text not null,
  platform_id uuid not null references public.study_lti_platforms (id) on delete cascade,
  created_at  timestamptz not null default now()
);

-- Which Chip Study class a platform's course became.
create table public.study_lti_contexts (
  platform_id uuid not null references public.study_lti_platforms (id) on delete cascade,
  context_id  text not null check (char_length(context_id) <= 255),
  class_id    uuid not null references public.study_classes (id) on delete cascade,
  primary key (platform_id, context_id)
);

-- A platform's user (its "sub") linked to a Chip Study account.
create table public.study_lti_users (
  platform_id uuid not null references public.study_lti_platforms (id) on delete cascade,
  sub         text not null check (char_length(sub) between 1 and 255),
  user_id     uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (platform_id, sub)
);
create index study_lti_users_user on public.study_lti_users (user_id);

-- A launch waiting for the person to sign in to Chip Study and link it,
-- kept an hour.
create table public.study_lti_pending (
  token         text primary key,
  platform_id   uuid not null references public.study_lti_platforms (id) on delete cascade,
  sub           text not null,
  email         text,
  teacher       boolean not null default false,
  context_id    text,
  context_title text,
  created_at    timestamptz not null default now()
);

-- Whether a member has seen what their institution can see: joining by a
-- link or code shows it first; joining from a learning platform shows it on
-- the first visit.
alter table public.study_institution_members add column consented_at timestamptz;
update public.study_institution_members set consented_at = joined_at where consented_at is null;
-- New members joining by link or code have seen the terms; a platform launch clears this.
alter table public.study_institution_members alter column consented_at set default now();

alter table public.study_lti_platforms enable row level security;
alter table public.study_lti_states enable row level security;
alter table public.study_lti_contexts enable row level security;
alter table public.study_lti_users enable row level security;
alter table public.study_lti_pending enable row level security;

/** Registers (or updates) an institution's learning platform: its admins or Kaivon staff. */
create function public.study_lti_platform_set(
  p_inst uuid, p_name text, p_issuer text, p_client_id text, p_deployment_id text, p_auth_url text, p_jwks_url text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if public._study_inst_role(p_inst, auth.uid()) is distinct from 'admin' and not public._study_is_staff(auth.uid()) then
    raise exception 'not allowed';
  end if;
  if not public._study_inst_active(p_inst) then raise exception 'institution not active'; end if;
  insert into public.study_lti_platforms (institution_id, name, issuer, client_id, deployment_id, auth_url, jwks_url)
  values (p_inst, btrim(coalesce(p_name, '')), rtrim(btrim(p_issuer), '/'), btrim(p_client_id), btrim(p_deployment_id),
          btrim(p_auth_url), btrim(p_jwks_url))
  on conflict (issuer, client_id, deployment_id) do update
    set name = excluded.name, auth_url = excluded.auth_url, jwks_url = excluded.jwks_url
    where public.study_lti_platforms.institution_id = p_inst
  returning id into v_id;
  if v_id is null then raise exception 'registered to another institution'; end if;
  return v_id;
end;
$$;

create function public.study_lti_platforms(p_inst uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if public._study_inst_role(p_inst, auth.uid()) is distinct from 'admin' and not public._study_is_staff(auth.uid()) then
    raise exception 'not allowed';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'issuer', issuer, 'client_id', client_id,
      'deployment_id', deployment_id, 'auth_url', auth_url, 'jwks_url', jwks_url, 'created_at', created_at,
      'courses', (select count(*) from public.study_lti_contexts c where c.platform_id = p.id)) order by created_at)
      from public.study_lti_platforms p where institution_id = p_inst), '[]'::jsonb);
end;
$$;

create function public.study_lti_platform_remove(p_platform uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_inst uuid := (select institution_id from public.study_lti_platforms where id = p_platform);
begin
  if public._study_inst_role(v_inst, auth.uid()) is distinct from 'admin' and not public._study_is_staff(auth.uid()) then
    raise exception 'not allowed';
  end if;
  delete from public.study_lti_platforms where id = p_platform;
end;
$$;

/** For the study-lti function (service role): enrols a launched person in
 * the institution and the course's class, making the class the first time. */
create function public.study_lti_enrol(
  p_platform uuid, p_user uuid, p_teacher boolean, p_context_id text, p_context_title text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_inst uuid := (select institution_id from public.study_lti_platforms where id = p_platform);
  v_role text;
  v_class uuid;
begin
  if v_inst is null then raise exception 'no such platform'; end if;
  if not public._study_inst_active(v_inst) then raise exception 'institution not active'; end if;
  v_role := public._study_inst_role(v_inst, p_user);
  if v_role is null then
    if p_teacher then
      insert into public.study_institution_members (institution_id, user_id, role) values (v_inst, p_user, 'teacher');
    else
      perform public._study_add_student(v_inst, p_user, null);
      update public.study_institution_members set consented_at = null where institution_id = v_inst and user_id = p_user;
    end if;
    v_role := public._study_inst_role(v_inst, p_user);
  end if;
  if coalesce(p_context_id, '') <> '' then
    select class_id into v_class from public.study_lti_contexts where platform_id = p_platform and context_id = p_context_id;
    if v_class is null then
      insert into public.study_classes (institution_id, name, code)
      values (v_inst, left(coalesce(nullif(btrim(p_context_title), ''), 'Course'), 120), public._study_new_class_code())
      returning id into v_class;
      insert into public.study_lti_contexts (platform_id, context_id, class_id) values (p_platform, p_context_id, v_class);
    end if;
    insert into public.study_class_members (class_id, user_id, role)
    values (v_class, p_user, case when v_role = 'student' then 'student' else 'teacher' end)
    on conflict (class_id, user_id) do nothing;
  end if;
  return jsonb_build_object('institution_id', v_inst, 'role', v_role, 'class_id', v_class);
end;
$$;

/** Institutions whose privacy terms the caller hasn't seen yet (joined from a learning platform). */
create function public.study_consent_pending()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'name', i.name)), '[]'::jsonb)
    from public.study_institution_members m join public.study_institutions i on i.id = m.institution_id
   where m.user_id = auth.uid() and m.consented_at is null;
$$;

create function public.study_consent_accept(p_inst uuid)
returns void language sql security definer set search_path = public as $$
  update public.study_institution_members set consented_at = now()
   where institution_id = p_inst and user_id = auth.uid() and consented_at is null;
$$;

/** For the study-lti function: whether the platform's institution confirmed
 * this email's domain (or a parent of it), so the platform's word on it holds. */
create function public.study_lti_trusts_email(p_platform uuid, p_email text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select d is not null and (e = d or e like '%.' || d)
      from (select i.email_domain d, lower(split_part(btrim(coalesce(p_email, '')), '@', 2)) e
              from public.study_lti_platforms p join public.study_institutions i on i.id = p.institution_id
             where p.id = p_platform and public._study_inst_active(i.id)
               and btrim(coalesce(p_email, '')) ~ '^[^@\s]+@[^@\s]+$') x), false);
$$;

/** For the study-lti function: keeps a launch for the person to link once
 * they've signed in. Answers its one-time token. */
create function public.study_lti_pending_add(
  p_platform uuid, p_sub text, p_email text, p_teacher boolean, p_context_id text, p_context_title text)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_token text := public._study_new_token();
begin
  delete from public.study_lti_pending where created_at < now() - interval '1 hour';
  delete from public.study_lti_states where created_at < now() - interval '10 minutes';
  insert into public.study_lti_pending (token, platform_id, sub, email, teacher, context_id, context_title)
  values (v_token, p_platform, p_sub, nullif(lower(btrim(coalesce(p_email, ''))), ''), coalesce(p_teacher, false),
          nullif(p_context_id, ''), nullif(btrim(coalesce(p_context_title, '')), ''));
  return v_token;
end;
$$;

/** What a waiting launch is, for the page that asks the person to sign in:
 * the institution, the course, and the email the platform gave (if any). */
create function public.study_lti_pending_peek(p_token text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((
    select jsonb_build_object('found', true, 'institution', i.name, 'platform', p.name,
             'course', l.context_title, 'email', l.email, 'teacher', l.teacher)
      from public.study_lti_pending l
      join public.study_lti_platforms p on p.id = l.platform_id
      join public.study_institutions i on i.id = p.institution_id
     where l.token = p_token and l.created_at > now() - interval '1 hour'),
    jsonb_build_object('found', false));
$$;

/** The signed-in person links a waiting launch to their account, and joins
 * the institution and the course's class. */
create function public.study_lti_link(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_l public.study_lti_pending;
  v_owner uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_l from public.study_lti_pending where token = p_token and created_at > now() - interval '1 hour';
  if v_l.token is null then raise exception 'link expired'; end if;
  select user_id into v_owner from public.study_lti_users where platform_id = v_l.platform_id and sub = v_l.sub;
  if v_owner is not null and v_owner <> v_me then raise exception 'linked to another account'; end if;
  insert into public.study_lti_users (platform_id, sub, user_id) values (v_l.platform_id, v_l.sub, v_me)
  on conflict (platform_id, sub) do nothing;
  delete from public.study_lti_pending where token = p_token;
  return public.study_lti_enrol(v_l.platform_id, v_me, v_l.teacher, v_l.context_id, v_l.context_title);
end;
$$;

/** For the study-lti function: links a platform user whose email the
 * institution's domain vouches for. Refuses if the platform user is already
 * someone else. */
create function public.study_lti_bind(p_platform uuid, p_sub text, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
begin
  select user_id into v_owner from public.study_lti_users where platform_id = p_platform and sub = p_sub;
  if v_owner is not null and v_owner <> p_user then raise exception 'linked to another account'; end if;
  insert into public.study_lti_users (platform_id, sub, user_id) values (p_platform, p_sub, p_user)
  on conflict (platform_id, sub) do nothing;
end;
$$;

revoke all on function public.study_lti_platform_set(uuid, text, text, text, text, text, text),
  public.study_lti_platforms(uuid), public.study_lti_platform_remove(uuid),
  public.study_consent_pending(), public.study_consent_accept(uuid) from public, anon;
grant execute on function public.study_lti_platform_set(uuid, text, text, text, text, text, text),
  public.study_lti_platforms(uuid), public.study_lti_platform_remove(uuid),
  public.study_consent_pending(), public.study_consent_accept(uuid) to authenticated;
revoke all on function public.study_lti_enrol(uuid, uuid, boolean, text, text),
  public.study_lti_trusts_email(uuid, text), public.study_lti_pending_add(uuid, text, text, boolean, text, text),
  public.study_lti_bind(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.study_lti_enrol(uuid, uuid, boolean, text, text),
  public.study_lti_trusts_email(uuid, text), public.study_lti_pending_add(uuid, text, text, boolean, text, text),
  public.study_lti_bind(uuid, text, uuid) to service_role;
revoke all on function public.study_lti_pending_peek(text), public.study_lti_link(text) from public, anon;
grant execute on function public.study_lti_pending_peek(text) to anon, authenticated;
grant execute on function public.study_lti_link(text) to authenticated;
