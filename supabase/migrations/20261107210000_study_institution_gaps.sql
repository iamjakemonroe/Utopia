-- What Chip Study's institution screens needed, 2026-11-07:
--   * see what a class code is before joining it (for the consent step);
--   * list an institution's open invites, to copy or cancel them later;
--   * Kaivon staff can remove a confirmed email domain;
--   * a plain "am I Kaivon staff" check;
--   * deleting your study data also takes you out of institutions you
--     joined as a student (admins and teachers leave by choice, so an
--     institution never loses its last admin this way).

/** A class code's class and institution, before joining. */
create function public.study_class_peek(p_code text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_class public.study_classes;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_class from public.study_classes where code = upper(btrim(coalesce(p_code, ''))) and not archived;
  if v_class.id is null then return jsonb_build_object('found', false); end if;
  return jsonb_build_object(
    'found', true, 'class', v_class.name,
    'institution', (select name from public.study_institutions where id = v_class.institution_id),
    'active', public._study_inst_active(v_class.institution_id),
    'member', public._study_inst_role(v_class.institution_id, auth.uid()));
end;
$$;

/** Open invites: all of them for an admin, their own classes' for a teacher. */
create function public.study_institution_invites_list(p_inst uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_role text := public._study_inst_role(p_inst, auth.uid());
begin
  if coalesce(v_role, '') not in ('admin', 'teacher') then raise exception 'not allowed'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'email', i.email, 'role', i.role, 'token', i.token, 'class', c.name, 'class_id', i.class_id,
      'created_at', i.created_at, 'expires_at', i.expires_at) order by i.created_at desc)
      from public.study_institution_invites i left join public.study_classes c on c.id = i.class_id
     where i.institution_id = p_inst and i.accepted_at is null and not i.revoked and i.expires_at > now()
       and (v_role = 'admin'
            or exists (select 1 from public.study_class_members t
                        where t.class_id = i.class_id and t.user_id = auth.uid() and t.role = 'teacher'))), '[]'::jsonb);
end;
$$;

-- A teacher can also cancel invites into their own classes.
create or replace function public.study_invite_revoke(p_token text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_inv public.study_institution_invites;
begin
  select * into v_inv from public.study_institution_invites where token = p_token;
  if v_inv.id is null or not (
       coalesce(public._study_inst_role(v_inv.institution_id, auth.uid()) = 'admin', false)
       or exists (select 1 from public.study_class_members t
                   where t.class_id = v_inv.class_id and t.user_id = auth.uid() and t.role = 'teacher')) then
    raise exception 'not allowed';
  end if;
  update public.study_institution_invites set revoked = true where id = v_inv.id;
end;
$$;

create function public.study_am_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select public._study_is_staff(auth.uid());
$$;

-- Staff can now clear a confirmed domain (p_clear_domain).
drop function public.study_staff_review(uuid, text, int, int, text, text, text, date);
create function public.study_staff_review(
  p_inst uuid, p_status text, p_seats int default null, p_pilot_days int default null,
  p_email_domain text default null, p_note text default null, p_plan text default null, p_paid_until date default null,
  p_clear_domain boolean default false)
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
    email_domain = case when coalesce(p_clear_domain, false) then null else coalesce(v_domain, email_domain) end,
    plan = coalesce(p_plan, plan),
    paid_until = coalesce(p_paid_until, paid_until),
    review_note = coalesce(p_note, review_note),
    reviewed_by = auth.uid(),
    reviewed_at = now()
   where id = p_inst;
  if not found then raise exception 'no such institution'; end if;
end;
$$;

create or replace function public.study_forget(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.study_focus where user_id = p_user;
  delete from public.study_cards where user_id = p_user;
  delete from public.study_practice where user_id = p_user;
  delete from public.study_assignments where user_id = p_user;
  -- Out of the institutions they joined as a student, and their classes.
  delete from public.study_class_members cm using public.study_classes c, public.study_institution_members m
   where c.id = cm.class_id and m.institution_id = c.institution_id and m.user_id = p_user
     and m.role = 'student' and cm.user_id = p_user;
  delete from public.study_institution_members where user_id = p_user and role = 'student';
end;
$$;
revoke all on function public.study_forget(uuid) from public, anon, authenticated;
grant execute on function public.study_forget(uuid) to service_role;

revoke all on function public.study_class_peek(text), public.study_institution_invites_list(uuid),
  public.study_am_staff(), public.study_staff_review(uuid, text, int, int, text, text, text, date, boolean)
  from public, anon;
grant execute on function public.study_class_peek(text), public.study_institution_invites_list(uuid),
  public.study_am_staff(), public.study_staff_review(uuid, text, int, int, text, text, text, date, boolean)
  to authenticated;
