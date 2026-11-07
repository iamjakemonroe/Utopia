-- Small gaps the institution screens found (2026-11-08):
--   * admins see their own under-18 setting (study_institution_overview);
--   * invoices in pounds and euros too, as the institution price has them.

create or replace function public.study_institution_overview(p_inst uuid)
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
        'review_note', i.review_note, 'created_at', i.created_at, 'minors_consent', i.minors_consent)
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

alter table public.study_institution_invoices drop constraint study_institution_invoices_currency_check;
alter table public.study_institution_invoices
  add constraint study_institution_invoices_currency_check check (currency in ('USD', 'NGN', 'GBP', 'EUR'));
