-- For Chip Study's room server (service role, 2026-11-08): everyone in a
-- room with what they may do now, so the server can apply a host's changes
-- (who edits, who's let in or taken out) to people already connected.

create function public.study_room_roster(p_room uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_room public.study_rooms;
begin
  select * into v_room from public.study_rooms where id = p_room;
  if v_room.id is null then raise exception 'no such room'; end if;
  return jsonb_build_object(
    'live', public._study_room_live(v_room), 'ends_at', v_room.ends_at, 'max_people', v_room.max_people,
    'edit_mode', v_room.edit_mode, 'assignment_id', v_room.assignment_id, 'host_id', v_room.host_id,
    'members', coalesce((select jsonb_agg(jsonb_build_object(
        'user_id', m.user_id, 'name', public._study_person_name(m.user_id), 'role', m.role, 'state', m.state,
        'can_edit', public._study_room_can_edit(v_room, m)) order by m.joined_at)
        from public.study_room_members m where m.room_id = p_room), '[]'::jsonb));
end;
$$;

revoke all on function public.study_room_roster(uuid) from public, anon, authenticated;
grant execute on function public.study_room_roster(uuid) to service_role;

-- ── Chip in a room ──────────────────────────────────────────────────────
-- A room has one Chip conversation, kept on the host's assignment (so the
-- host finds it afterwards). Each question is charged to whoever asked, and
-- the assignment's AI-use record names them; the host sees every use on
-- their own assignment, including others' in their rooms.

alter table public.study_rooms add column chip_thread uuid references public.study_threads (id) on delete set null;

drop policy "study_ai_log: own" on public.study_ai_log;
create policy "study_ai_log: own and on my assignments" on public.study_ai_log for select to authenticated
  using (user_id = auth.uid()
         or exists (select 1 from public.study_assignments a where a.id = assignment_id and a.user_id = auth.uid()));

/** The course-tutor rules for a room's assignment: when the host's
 * assignment is linked to a class they're a student in. For anyone in the room. */
create function public.study_room_tutor(p_room uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('class', c.name, 'institution', i.name, 'course_brief', c.course_brief,
                            'help_level', c.help_level, 'tutor_notes', c.tutor_notes)
    from public.study_rooms r
    join public.study_room_members me on me.room_id = r.id and me.user_id = auth.uid() and me.state = 'in'
    join public.study_assignments a on a.id = r.assignment_id
    join public.study_classes c on c.id = a.class_id
    join public.study_institutions i on i.id = c.institution_id
   where r.id = p_room and public._study_room_live(r) and a.user_id = r.host_id and not c.archived
     and public._study_inst_active(i.id)
     and exists (select 1 from public.study_class_members m
                  where m.class_id = c.id and m.user_id = r.host_id and m.role = 'student');
$$;

/** Someone who can edit put Chip's words into the room's shared work: the
 * room's version of study_log_use, recorded under their own name. */
create function public.study_room_log_use(
  p_room uuid, p_action text, p_message uuid default null, p_words int default 0, p_excerpt text default '')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_room public.study_rooms;
  v_m public.study_room_members;
  v_message public.study_messages;
  v_id uuid;
begin
  select * into v_room from public.study_rooms where id = p_room;
  select * into v_m from public.study_room_members where room_id = p_room and user_id = auth.uid();
  if v_room.id is null or v_m.user_id is null or not public._study_room_live(v_room)
     or not public._study_room_can_edit(v_room, v_m) then
    raise exception 'not allowed';
  end if;
  if p_action not in ('inserted', 'replaced', 'added_tasks', 'added_sources') then raise exception 'unknown action'; end if;
  if p_message is not null then
    select * into v_message from public.study_messages
     where id = p_message and thread_id = v_room.chip_thread and role = 'chip';
    if not found then raise exception 'unknown message'; end if;
  end if;
  insert into public.study_ai_log (assignment_id, user_id, message_id, action, summary, output, words, model, room_id)
  values (v_room.assignment_id, auth.uid(), p_message, p_action,
    case p_action
      when 'inserted' then 'Put Chip''s words into the document'
      when 'replaced' then 'Replaced their own words with Chip''s rewrite'
      when 'added_tasks' then 'Added the tasks Chip suggested to the checklist'
      else 'Added the sources Chip suggested' end || ' (in a study room)',
    left(coalesce(p_excerpt, ''), 4000), least(greatest(coalesce(p_words, 0), 0), 200000),
    coalesce(v_message.meta ->> 'model', ''), p_room)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.study_room_tutor(uuid), public.study_room_log_use(uuid, text, uuid, int, text) from public, anon;
grant execute on function public.study_room_tutor(uuid), public.study_room_log_use(uuid, text, uuid, int, text) to authenticated;
