-- "Report a bug" and "Suggest a feature", with the loop closed:
--
--   * Reports carry what's needed to act on them: the screen the player
--     was on, their world, and an optional screenshot.
--   * Screenshots live in a private bucket, one folder per player. Players
--     can only put files in their own folder and never read anyone's; the
--     team reads them with the secret key (tool/reports.sh).
--   * Each report gets a note back (resolution), which the player sees
--     under their report in the app: "Fixed in 1.0.0+15".

alter table public.bug_reports
  add column screen text check (char_length(screen) <= 120),
  add column world text check (char_length(world) <= 60),
  add column screenshot_path text check (char_length(screenshot_path) <= 200),
  add column resolution text check (char_length(resolution) <= 300);

comment on column public.bug_reports.resolution is 'A note back to the player, shown under their report: what was done about it.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bug-screenshots', 'bug-screenshots', false, 4194304, array['image/jpeg', 'image/png'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "players add screenshots to their own reports folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'bug-screenshots'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- The same submit, with the new details (all optional, so older versions of
-- the app keep working). One function, so calls with fewer details still
-- find it.
drop function public.submit_bug_report(text, text, text, text, text);

create function public.submit_bug_report(
  p_description text,
  p_category text default 'bug',
  p_app_version text default null,
  p_platform text default null,
  p_contact text default null,
  p_screen text default null,
  p_world text default null,
  p_screenshot_path text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
  v_recent int;
  v_shot text := nullif(btrim(p_screenshot_path), '');
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select count(*) into v_recent from public.bug_reports
    where user_id = v_me and created_at > now() - interval '1 hour';
  if v_recent >= 10 then raise exception 'too many reports, try again later'; end if;
  -- A screenshot has to be one the player uploaded themselves.
  if v_shot is not null and v_shot not like v_me::text || '/%' then
    v_shot := null;
  end if;

  insert into public.bug_reports (
    user_id, description, category, app_version, platform, contact,
    screen, world, screenshot_path
  )
  values (
    v_me, btrim(p_description), p_category, p_app_version, p_platform,
    nullif(btrim(p_contact), ''), left(p_screen, 120), left(p_world, 60), v_shot
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.submit_bug_report(text, text, text, text, text, text, text, text) from public;
grant execute on function public.submit_bug_report(text, text, text, text, text, text, text, text) to authenticated;
