-- Under-18s and institutions (2026-11-07): the age rule now holds where
-- people join. A student who said they're under 18 (with a guardian's
-- agreement) can join an institution only if it said under-18s will join
-- and it has their parents' consent (minors_consent). Every way in (an
-- invite, a class code, a school email, a learning platform) goes through
-- _study_add_student. Admins can turn the setting on in their settings,
-- and Kaivon staff see it when they review.

create or replace function public._study_add_student(p_inst uuid, p_user uuid, p_by uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_role text := public._study_inst_role(p_inst, p_user);
begin
  if v_role is not null then return; end if;
  if not public._study_inst_active(p_inst) then raise exception 'institution not active'; end if;
  if (select answer from public.study_age where user_id = p_user) = 'guardian'
     and not (select minors_consent from public.study_institutions where id = p_inst) then
    raise exception 'under 18 not allowed here';
  end if;
  perform 1 from public.study_institutions where id = p_inst for update;
  if public._study_students_count(p_inst) >= (select seats from public.study_institutions where id = p_inst) then
    raise exception 'no seats left';
  end if;
  insert into public.study_institution_members (institution_id, user_id, role, added_by)
  values (p_inst, p_user, 'student', p_by);
end;
$$;

/** An admin says whether under-18s will join, confirming the institution
 * has their parents' or guardians' consent. A school can't turn it off. */
create function public.study_institution_minors(p_inst uuid, p_minors_consent boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if public._study_inst_role(p_inst, auth.uid()) is distinct from 'admin' then raise exception 'not allowed'; end if;
  if not p_minors_consent and (select kind from public.study_institutions where id = p_inst) = 'school' then
    raise exception 'schools need it';
  end if;
  update public.study_institutions set minors_consent = p_minors_consent where id = p_inst;
end;
$$;

create or replace function public.study_staff_institutions(p_status text default 'pending')
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
      'review_note', i.review_note, 'created_at', i.created_at, 'reviewed_at', i.reviewed_at,
      'minors_consent', i.minors_consent)
      order by i.created_at desc)
      from public.study_institutions i
     where p_status = 'all' or i.status = p_status), '[]'::jsonb);
end;
$$;

revoke all on function public.study_institution_minors(uuid, boolean) from public, anon;
grant execute on function public.study_institution_minors(uuid, boolean) to authenticated;
