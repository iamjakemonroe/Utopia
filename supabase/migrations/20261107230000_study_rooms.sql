-- Chip Study rooms (2026-11-07): studying together, live. A room opens on
-- one of the host's assignments or topics; everyone in it shares that
-- workspace (its documents, notes and tasks, edited live, and one Chip),
-- with audio, video, screen sharing and chat.
--
-- The live part runs on Chip Study's room server (a Cloudflare Durable
-- Object per room; video through Cloudflare Realtime). This is who may be in
-- a room and what they may do; the room server asks study_room_access with
-- the person's own sign-in on every connection, and saves the shared work
-- back to the host's assignment through study_room_save (service role).
-- Members never read the host's rows directly.
--
-- Two kinds:
--   * a personal room: anyone with its link (or, if the host chooses, once
--     the host lets them in). Adults only: live video between strangers is
--     not for under-18s. Free hosts: up to 4 people for 60 minutes; Pro: 10,
--     no time limit.
--   * a class room: a teacher or admin of an institution, for the students
--     they invite (whole classes or chosen people). Up to 50, no time limit.
--     The institution's other teachers of an invited class, and its admins,
--     join as co-hosts.
-- Editing: the host and co-hosts always can. Otherwise "everyone" (the
-- default for personal rooms) or "chosen" people (the default for class
-- rooms), set by the host. Nothing is recorded.

create table public.study_rooms (
  id             uuid primary key default gen_random_uuid(),
  assignment_id  uuid not null references public.study_assignments (id) on delete cascade,
  host_id        uuid not null references public.profiles (id) on delete cascade,
  institution_id uuid references public.study_institutions (id) on delete cascade,
  title          text not null check (char_length(title) between 1 and 200),
  token          text not null unique,
  edit_mode      text not null check (edit_mode in ('everyone', 'chosen')),
  -- 'link': anyone with the link; 'ask': the host lets each person in;
  -- 'invited': class rooms, only those invited.
  admission      text not null check (admission in ('link', 'ask', 'invited')),
  max_people     int not null check (max_people between 2 and 50),
  ends_at        timestamptz,
  status         text not null default 'open' check (status in ('open', 'ended')),
  created_at     timestamptz not null default now(),
  last_active_at timestamptz not null default now(),
  ended_at       timestamptz
);
create unique index study_rooms_one_open on public.study_rooms (assignment_id) where status = 'open';
create index study_rooms_by_host on public.study_rooms (host_id, created_at desc);

-- Who a class room is for: whole classes, or chosen people.
create table public.study_room_invites (
  room_id  uuid not null references public.study_rooms (id) on delete cascade,
  class_id uuid references public.study_classes (id) on delete cascade,
  user_id  uuid references public.profiles (id) on delete cascade,
  check ((class_id is null) <> (user_id is null))
);
create unique index study_room_invites_class on public.study_room_invites (room_id, class_id) where class_id is not null;
create unique index study_room_invites_user on public.study_room_invites (room_id, user_id) where user_id is not null;

-- Everyone who has joined. 'state': 'in' (let in), 'waiting' (asked to
-- join), 'removed' (taken out by a host; can't come back). Who is connected
-- right now is the room server's to know.
create table public.study_room_members (
  room_id   uuid not null references public.study_rooms (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  role      text not null default 'member' check (role in ('host', 'cohost', 'member')),
  can_edit  boolean not null default false,
  state     text not null default 'in' check (state in ('in', 'waiting', 'removed')),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);
create index study_room_members_by_user on public.study_room_members (user_id);

alter table public.study_rooms enable row level security;
alter table public.study_room_invites enable row level security;
alter table public.study_room_members enable row level security;

-- Chip's record of an assignment says which room a use happened in.
alter table public.study_ai_log add column room_id uuid references public.study_rooms (id) on delete set null;

-- ── Helpers ─────────────────────────────────────────────────────────────

-- A room shows people's names, never any part of their email: personal
-- rooms can have people who don't know each other.
create function public._study_person_name(p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select coalesce(nullif(btrim(p.display_name), ''), nullif(btrim(p.username), ''))
                     from public.profiles p where p.id = p_user), 'Student');
$$;

/** Whether a room is still running: open, inside its time, and used in the
 * last six hours (a room everyone walked away from ends by itself). */
create function public._study_room_live(r public.study_rooms)
returns boolean language sql stable as $$
  select r.status = 'open' and (r.ends_at is null or r.ends_at > now())
     and r.last_active_at > now() - interval '6 hours';
$$;

create function public._study_room_can_edit(r public.study_rooms, m public.study_room_members)
returns boolean language sql stable as $$
  select m.state = 'in' and (m.role in ('host', 'cohost') or r.edit_mode = 'everyone' or m.can_edit);
$$;

/** The caller's role if they may run the room (host or co-host), else an error. */
create function public._study_room_manager(p_room uuid)
returns public.study_rooms language plpgsql stable security definer set search_path = public as $$
declare
  v_room public.study_rooms;
begin
  select * into v_room from public.study_rooms where id = p_room;
  if v_room.id is null or not exists (
       select 1 from public.study_room_members
        where room_id = p_room and user_id = auth.uid() and state = 'in' and role in ('host', 'cohost')) then
    raise exception 'not allowed';
  end if;
  return v_room;
end;
$$;

/** How a class room sees the caller: 'cohost' for the institution's admins
 * and teachers of an invited class, 'member' for an invited student, or
 * null for anyone else. */
create function public._study_room_class_role(r public.study_rooms, p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when public._study_inst_role(r.institution_id, p_user) = 'admin' then 'cohost'
    when exists (select 1 from public.study_room_invites i join public.study_class_members cm on cm.class_id = i.class_id
                  where i.room_id = r.id and cm.user_id = p_user and cm.role = 'teacher') then 'cohost'
    when public._study_inst_role(r.institution_id, p_user) is null then null
    when exists (select 1 from public.study_room_invites i where i.room_id = r.id and i.user_id = p_user) then 'member'
    when exists (select 1 from public.study_room_invites i join public.study_class_members cm on cm.class_id = i.class_id
                  where i.room_id = r.id and cm.user_id = p_user) then 'member'
    else null end;
$$;

-- ── Opening and inviting ────────────────────────────────────────────────

/** Opens a room on one of the caller's assignments (or answers the one
 * already open). With p_institution, a class room for that institution. */
create function public.study_room_open(p_assignment uuid, p_institution uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._study_need_account();
  v_a public.study_assignments;
  v_room public.study_rooms;
  v_pro boolean;
begin
  select * into v_a from public.study_assignments where id = p_assignment and user_id = v_me;
  if v_a.id is null then raise exception 'no such assignment'; end if;
  select * into v_room from public.study_rooms where assignment_id = p_assignment and status = 'open';
  if v_room.id is not null and not public._study_room_live(v_room) then
    update public.study_rooms set status = 'ended', ended_at = now() where id = v_room.id;
    v_room := null;
  end if;
  if v_room.id is null then
    if p_institution is not null then
      if coalesce(public._study_inst_role(p_institution, v_me), '') not in ('admin', 'teacher') then
        raise exception 'not allowed';
      end if;
      if not public._study_inst_active(p_institution) then raise exception 'institution not active'; end if;
      insert into public.study_rooms (assignment_id, host_id, institution_id, title, token, edit_mode, admission, max_people)
      values (p_assignment, v_me, p_institution, v_a.title, public._study_new_token(), 'chosen', 'invited', 50)
      returning * into v_room;
    else
      if (select answer from public.study_age where user_id = v_me) is distinct from 'adult' then
        raise exception 'adults only';
      end if;
      v_pro := public._study_tier(v_me) = 'pro';
      insert into public.study_rooms (assignment_id, host_id, title, token, edit_mode, admission, max_people, ends_at)
      values (p_assignment, v_me, v_a.title, public._study_new_token(), 'everyone', 'link',
              case when v_pro then 10 else 4 end, case when v_pro then null else now() + interval '60 minutes' end)
      returning * into v_room;
    end if;
    insert into public.study_room_members (room_id, user_id, role, can_edit) values (v_room.id, v_me, 'host', true);
  elsif v_room.institution_id is distinct from p_institution then
    raise exception 'a room is already open';
  end if;
  return public.study_room_get(v_room.id);
end;
$$;

/** A room as its hosts see it: settings, who's in, who's waiting, who's invited. */
create function public.study_room_get(p_room uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_room public.study_rooms := public._study_room_manager(p_room);
begin
  return jsonb_build_object(
    'id', v_room.id, 'assignment_id', v_room.assignment_id, 'title', v_room.title, 'token', v_room.token,
    'institution_id', v_room.institution_id, 'edit_mode', v_room.edit_mode, 'admission', v_room.admission,
    'max_people', v_room.max_people, 'ends_at', v_room.ends_at, 'live', public._study_room_live(v_room),
    'members', coalesce((select jsonb_agg(jsonb_build_object(
        'user_id', m.user_id, 'name', public._study_person_name(m.user_id), 'role', m.role, 'state', m.state,
        'can_edit', public._study_room_can_edit(v_room, m), 'joined_at', m.joined_at) order by m.joined_at)
        from public.study_room_members m where m.room_id = p_room), '[]'::jsonb),
    'invited_classes', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name) order by c.name)
        from public.study_room_invites i join public.study_classes c on c.id = i.class_id where i.room_id = p_room), '[]'::jsonb),
    'invited_people', coalesce((select jsonb_agg(jsonb_build_object('user_id', i.user_id,
        'name', public._study_person_name(i.user_id)) order by public._study_person_name(i.user_id))
        from public.study_room_invites i where i.room_id = p_room and i.user_id is not null), '[]'::jsonb));
end;
$$;

/** Invites classes and people of the institution to a class room. A
 * teacher invites classes they teach and their students; an admin, anyone
 * in the institution. */
create function public.study_room_invite(p_room uuid, p_classes uuid[] default '{}', p_people uuid[] default '{}')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_room public.study_rooms := public._study_room_manager(p_room);
  v_admin boolean;
  v_id uuid;
begin
  if v_room.institution_id is null then raise exception 'personal rooms use their link'; end if;
  if not public._study_room_live(v_room) then raise exception 'room ended'; end if;
  v_admin := coalesce(public._study_inst_role(v_room.institution_id, auth.uid()) = 'admin', false);
  foreach v_id in array coalesce(p_classes, '{}') loop
    if not exists (select 1 from public.study_classes c where c.id = v_id and c.institution_id = v_room.institution_id
                     and (v_admin or exists (select 1 from public.study_class_members t
                                              where t.class_id = c.id and t.user_id = auth.uid() and t.role = 'teacher'))) then
      raise exception 'not your class';
    end if;
    insert into public.study_room_invites (room_id, class_id) values (p_room, v_id) on conflict do nothing;
  end loop;
  foreach v_id in array coalesce(p_people, '{}') loop
    if public._study_inst_role(v_room.institution_id, v_id) is null then raise exception 'not in the institution'; end if;
    if not v_admin and public._study_inst_role(v_room.institution_id, v_id) = 'student' and not exists (
         select 1 from public.study_class_members s join public.study_class_members t on t.class_id = s.class_id
          where s.user_id = v_id and t.user_id = auth.uid() and t.role = 'teacher') then
      raise exception 'not your student';
    end if;
    insert into public.study_room_invites (room_id, user_id) values (p_room, v_id) on conflict do nothing;
  end loop;
  return public.study_room_get(p_room);
end;
$$;

create function public.study_room_uninvite(p_room uuid, p_class uuid default null, p_person uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_room public.study_rooms := public._study_room_manager(p_room);
begin
  delete from public.study_room_invites
   where room_id = p_room and ((p_class is not null and class_id = p_class) or (p_person is not null and user_id = p_person));
  return public.study_room_get(v_room.id);
end;
$$;

-- ── Joining ─────────────────────────────────────────────────────────────

/** What a room link is, before joining: for the join page. */
create function public.study_room_peek(p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_room public.study_rooms;
  v_m public.study_room_members;
  v_why text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_room from public.study_rooms where token = p_token;
  if v_room.id is null then return jsonb_build_object('found', false); end if;
  select * into v_m from public.study_room_members where room_id = v_room.id and user_id = v_me;
  v_why := case
    when not public._study_room_live(v_room) then 'ended'
    when v_m.state = 'removed' then 'removed'
    when v_m.state is not null then null
    when v_room.institution_id is not null and public._study_room_class_role(v_room, v_me) is null then 'not_invited'
    when v_room.institution_id is not null then null
    when (select answer from public.study_age where user_id = v_me) is null then 'age_unknown'
    when (select answer from public.study_age where user_id = v_me) <> 'adult' then 'adults_only'
    else null end;
  return jsonb_build_object(
    'found', true, 'title', v_room.title, 'host', public._study_person_name(v_room.host_id),
    'institution', (select name from public.study_institutions where id = v_room.institution_id),
    'class_room', v_room.institution_id is not null, 'admission', v_room.admission,
    'ends_at', v_room.ends_at, 'state', v_m.state, 'can_join', v_why is null, 'reason', v_why);
end;
$$;

/** Joins a room by its link. Answers the caller's place in it; 'waiting'
 * when the host lets people in one by one. */
create function public.study_room_join(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public._study_need_account();
  v_room public.study_rooms;
  v_m public.study_room_members;
  v_peek jsonb := public.study_room_peek(p_token);
  v_role text := 'member';
begin
  if not (v_peek ->> 'found')::boolean then raise exception 'no such room'; end if;
  if not (v_peek ->> 'can_join')::boolean then raise exception '%', v_peek ->> 'reason'; end if;
  select * into v_room from public.study_rooms where token = p_token;
  select * into v_m from public.study_room_members where room_id = v_room.id and user_id = v_me;
  if v_m.user_id is null then
    if v_room.institution_id is not null then v_role := public._study_room_class_role(v_room, v_me); end if;
    insert into public.study_room_members (room_id, user_id, role, state)
    values (v_room.id, v_me, v_role,
            case when v_room.admission = 'ask' and v_role = 'member' then 'waiting' else 'in' end)
    returning * into v_m;
  end if;
  return jsonb_build_object('room_id', v_room.id, 'role', v_m.role, 'state', v_m.state,
                            'can_edit', public._study_room_can_edit(v_room, v_m));
end;
$$;

/** For the room server, with the person's own sign-in: may they be in the
 * room, and what may they do. */
create function public.study_room_access(p_room uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_room public.study_rooms;
  v_m public.study_room_members;
begin
  select * into v_room from public.study_rooms where id = p_room;
  select * into v_m from public.study_room_members where room_id = p_room and user_id = auth.uid();
  if v_room.id is null or v_m.user_id is null then raise exception 'not a member'; end if;
  return jsonb_build_object(
    'room_id', v_room.id, 'user_id', v_m.user_id, 'name', public._study_person_name(v_m.user_id),
    'role', v_m.role, 'state', v_m.state, 'can_edit', public._study_room_can_edit(v_room, v_m),
    'live', public._study_room_live(v_room), 'max_people', v_room.max_people, 'ends_at', v_room.ends_at,
    'assignment_id', v_room.assignment_id, 'host_id', v_room.host_id, 'title', v_room.title,
    'class_room', v_room.institution_id is not null, 'edit_mode', v_room.edit_mode);
end;
$$;

/** The shared workspace as it was when the room opened, for a member who's
 * in: the assignment, its documents, sources, notes and tasks. From then on
 * the room server carries the live changes. */
create function public.study_room_workspace(p_room uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_room public.study_rooms;
  v_a public.study_assignments;
begin
  select * into v_room from public.study_rooms where id = p_room;
  if v_room.id is null or not public._study_room_live(v_room) or not exists (
       select 1 from public.study_room_members where room_id = p_room and user_id = auth.uid() and state = 'in') then
    raise exception 'not allowed';
  end if;
  select * into v_a from public.study_assignments where id = v_room.assignment_id;
  return jsonb_build_object(
    'assignment', jsonb_build_object('id', v_a.id, 'title', v_a.title, 'course', v_a.course, 'brief', v_a.brief,
      'rubric', v_a.rubric, 'due_at', v_a.due_at, 'word_target', v_a.word_target, 'style', v_a.style,
      'kind', v_a.kind, 'color', v_a.color),
    'documents', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'title', d.title,
        'content', d.content, 'version', d.version, 'sort', d.sort) order by d.sort, d.created_at)
        from public.study_documents d where d.assignment_id = v_a.id), '[]'::jsonb),
    'sources', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'kind', s.kind, 'data', s.data,
        'note', s.note, 'file_name', s.file_name) order by s.created_at)
        from public.study_sources s where s.assignment_id = v_a.id), '[]'::jsonb),
    'notes', coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'body', n.body, 'pinned', n.pinned)
        order by n.pinned desc, n.created_at) from public.study_notes n where n.assignment_id = v_a.id), '[]'::jsonb),
    'tasks', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'title', t.title, 'due_on', t.due_on,
        'done', t.done) order by t.done, t.due_on nulls last, t.created_at)
        from public.study_tasks t where t.assignment_id = v_a.id), '[]'::jsonb));
end;
$$;

-- ── Running a room ──────────────────────────────────────────────────────

/** Settings: who may edit ('everyone' or 'chosen') and, for personal
 * rooms, whether people join with the link or are let in ('link'/'ask'). */
create function public.study_room_settings(p_room uuid, p_edit_mode text default null, p_admission text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_room public.study_rooms := public._study_room_manager(p_room);
begin
  if p_edit_mode is not null and p_edit_mode not in ('everyone', 'chosen') then raise exception 'bad edit mode'; end if;
  if p_admission is not null and (v_room.institution_id is not null or p_admission not in ('link', 'ask')) then
    raise exception 'bad admission';
  end if;
  update public.study_rooms set edit_mode = coalesce(p_edit_mode, edit_mode), admission = coalesce(p_admission, admission)
   where id = p_room;
  return public.study_room_get(p_room);
end;
$$;

/** A host lets someone in, lets them edit (or stops them), or takes them out. */
create function public.study_room_member_set(p_room uuid, p_user uuid, p_state text default null, p_can_edit boolean default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_room public.study_rooms := public._study_room_manager(p_room);
  v_m public.study_room_members;
begin
  select * into v_m from public.study_room_members where room_id = p_room and user_id = p_user;
  if v_m.user_id is null then raise exception 'not a member'; end if;
  if v_m.role = 'host' or (v_m.role = 'cohost' and auth.uid() <> v_room.host_id) then raise exception 'not allowed'; end if;
  if p_state is not null and p_state not in ('in', 'removed') then raise exception 'bad state'; end if;
  update public.study_room_members set state = coalesce(p_state, state), can_edit = coalesce(p_can_edit, can_edit)
   where room_id = p_room and user_id = p_user;
  return public.study_room_get(p_room);
end;
$$;

/** A new link for a personal room; the old one stops working for anyone
 * who hasn't joined yet. */
create function public.study_room_new_link(p_room uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_room public.study_rooms := public._study_room_manager(p_room);
begin
  update public.study_rooms set token = public._study_new_token() where id = v_room.id;
  return public.study_room_get(p_room);
end;
$$;

create function public.study_room_end(p_room uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_room public.study_rooms := public._study_room_manager(p_room);
begin
  update public.study_rooms set status = 'ended', ended_at = now() where id = v_room.id and status = 'open';
end;
$$;

/** Rooms running now that the caller is in, hosts, or is invited to. */
create function public.study_rooms_mine()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id, 'token', r.token, 'title', r.title, 'host', public._study_person_name(r.host_id),
      'institution', (select name from public.study_institutions where id = r.institution_id),
      'mine', r.host_id = auth.uid(), 'ends_at', r.ends_at, 'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
    from public.study_rooms r
   where public._study_room_live(r)
     and (exists (select 1 from public.study_room_members m
                   where m.room_id = r.id and m.user_id = auth.uid() and m.state <> 'removed')
          or (r.institution_id is not null and public._study_room_class_role(r, auth.uid()) is not null
              and not exists (select 1 from public.study_room_members m
                               where m.room_id = r.id and m.user_id = auth.uid() and m.state = 'removed')));
$$;

-- ── For the room server (service role) ──────────────────────────────────

/** Saves the shared work to the host's assignment. Documents are updated
 * (or added) by ID; notes and tasks are made to match the room's (added,
 * changed, or removed). Keeps the room alive. */
create function public.study_room_save(p_room uuid, p_documents jsonb default null, p_notes jsonb default null, p_tasks jsonb default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_room public.study_rooms;
  v_d jsonb;
begin
  select * into v_room from public.study_rooms where id = p_room;
  if v_room.id is null then raise exception 'no such room'; end if;
  update public.study_rooms set last_active_at = now() where id = p_room and status = 'open';
  for v_d in select * from jsonb_array_elements(coalesce(p_documents, '[]'::jsonb)) loop
    insert into public.study_documents (id, assignment_id, user_id, kind, title, content, text, words, sort)
    values ((v_d ->> 'id')::uuid, v_room.assignment_id, v_room.host_id, coalesce(v_d ->> 'kind', 'doc'),
            left(coalesce(nullif(v_d ->> 'title', ''), 'Draft'), 200), coalesce(v_d -> 'content', '{}'::jsonb),
            left(coalesce(v_d ->> 'text', ''), 400000), greatest(coalesce((v_d ->> 'words')::int, 0), 0),
            coalesce((v_d ->> 'sort')::int, 0))
    on conflict (id) do update
      set title = excluded.title, content = excluded.content, text = excluded.text, words = excluded.words,
          version = public.study_documents.version + 1, updated_at = now()
      where public.study_documents.assignment_id = v_room.assignment_id;
  end loop;
  if p_notes is not null then
    delete from public.study_notes where assignment_id = v_room.assignment_id
       and id not in (select (n ->> 'id')::uuid from jsonb_array_elements(p_notes) n);
    insert into public.study_notes (id, assignment_id, user_id, body, pinned)
    select (n ->> 'id')::uuid, v_room.assignment_id, v_room.host_id, left(coalesce(n ->> 'body', ''), 20000),
           coalesce((n ->> 'pinned')::boolean, false)
      from jsonb_array_elements(p_notes) n
    on conflict (id) do update set body = excluded.body, pinned = excluded.pinned, updated_at = now()
      where public.study_notes.assignment_id = v_room.assignment_id;
  end if;
  if p_tasks is not null then
    delete from public.study_tasks where assignment_id = v_room.assignment_id
       and id not in (select (t ->> 'id')::uuid from jsonb_array_elements(p_tasks) t);
    insert into public.study_tasks (id, assignment_id, user_id, title, due_on, done, done_at)
    select (t ->> 'id')::uuid, v_room.assignment_id, v_room.host_id, left(coalesce(nullif(t ->> 'title', ''), 'Task'), 300),
           nullif(t ->> 'due_on', '')::date, coalesce((t ->> 'done')::boolean, false),
           case when coalesce((t ->> 'done')::boolean, false) then now() end
      from jsonb_array_elements(p_tasks) t
    on conflict (id) do update
      set title = excluded.title, due_on = excluded.due_on, done = excluded.done,
          done_at = case when excluded.done and not public.study_tasks.done then now()
                         when not excluded.done then null else public.study_tasks.done_at end
      where public.study_tasks.assignment_id = v_room.assignment_id;
  end if;
  update public.study_assignments set updated_at = now(),
         words = coalesce((select words from public.study_documents where assignment_id = v_room.assignment_id
                            order by sort, created_at limit 1), words)
   where id = v_room.assignment_id;
end;
$$;

/** The room server ends a room nobody is in any more (or a free room whose
 * time is up). */
create function public.study_room_close(p_room uuid)
returns void language sql security definer set search_path = public as $$
  update public.study_rooms set status = 'ended', ended_at = now() where id = p_room and status = 'open';
$$;

-- ── Permissions ─────────────────────────────────────────────────────────

revoke all on function public._study_person_name(uuid), public._study_room_manager(uuid),
  public._study_room_class_role(public.study_rooms, uuid) from public, anon, authenticated;
revoke all on function public.study_room_open(uuid, uuid), public.study_room_get(uuid),
  public.study_room_invite(uuid, uuid[], uuid[]), public.study_room_uninvite(uuid, uuid, uuid),
  public.study_room_peek(text), public.study_room_join(text), public.study_room_access(uuid),
  public.study_room_workspace(uuid), public.study_room_settings(uuid, text, text),
  public.study_room_member_set(uuid, uuid, text, boolean), public.study_room_new_link(uuid),
  public.study_room_end(uuid), public.study_rooms_mine() from public, anon;
grant execute on function public.study_room_open(uuid, uuid), public.study_room_get(uuid),
  public.study_room_invite(uuid, uuid[], uuid[]), public.study_room_uninvite(uuid, uuid, uuid),
  public.study_room_peek(text), public.study_room_join(text), public.study_room_access(uuid),
  public.study_room_workspace(uuid), public.study_room_settings(uuid, text, text),
  public.study_room_member_set(uuid, uuid, text, boolean), public.study_room_new_link(uuid),
  public.study_room_end(uuid), public.study_rooms_mine() to authenticated;
revoke all on function public.study_room_save(uuid, jsonb, jsonb, jsonb), public.study_room_close(uuid)
  from public, anon, authenticated;
grant execute on function public.study_room_save(uuid, jsonb, jsonb, jsonb), public.study_room_close(uuid) to service_role;
