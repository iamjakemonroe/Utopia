-- A class gets a new code (2026-11-07): when its code was shared too widely,
-- the institution's admins or the class's teachers replace it. The old code
-- stops working at once; everyone already in the class stays.

/** Gives a class a new code and answers it. */
create function public.study_class_new_code(p_class uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_inst uuid := (select institution_id from public.study_classes where id = p_class);
  v_code text;
begin
  if v_inst is null or not (
       coalesce(public._study_inst_role(v_inst, auth.uid()) = 'admin', false)
       or exists (select 1 from public.study_class_members
                   where class_id = p_class and user_id = auth.uid() and role = 'teacher')) then
    raise exception 'not allowed';
  end if;
  v_code := public._study_new_class_code();
  update public.study_classes set code = v_code where id = p_class;
  return v_code;
end;
$$;

revoke all on function public.study_class_new_code(uuid) from public, anon;
grant execute on function public.study_class_new_code(uuid) to authenticated;
