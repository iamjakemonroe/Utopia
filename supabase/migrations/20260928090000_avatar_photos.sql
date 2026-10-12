-- Real photo avatars: a public Supabase Storage bucket plus the one
-- client-facing setter for `profiles.avatar_url`, following the exact
-- pattern set_username already uses (SECURITY DEFINER, format-checked,
-- the only way a user can touch this column on their own row).

alter table public.profiles add column avatar_url text;

insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do nothing;

comment on column public.profiles.avatar_url is 'Public URL of the user''s uploaded photo (storage.objects, bucket "avatars", path "<user id>/..."). Null until they set one — callers fall back to profileDisplayName-style initials/placeholder.';

-- Storage RLS: the bucket is public for reading (so anyone can see anyone's
-- avatar in a match/friends list), but a user may only write to a path
-- prefixed with their own uid, so no one can overwrite someone else's file.
create policy "avatar images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "users can upload their own avatar"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "users can replace their own avatar"
  on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "users can delete their own avatar"
  on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create function public.set_avatar_url(p_avatar_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  -- Storage RLS already stops anyone from uploading into a path that isn't
  -- their own uid, but nothing stops a client from calling this function
  -- directly with an arbitrary string — this check keeps the column
  -- pointed at something actually uploaded to this user's own folder in
  -- our bucket, not an arbitrary external image.
  if p_avatar_url is not null
     and p_avatar_url !~ ('/storage/v1/object/public/avatars/' || v_me::text || '/') then
    raise exception 'avatar_url must point to your own uploaded avatar';
  end if;

  update public.profiles set avatar_url = p_avatar_url, updated_at = now() where id = v_me;
end;
$$;

comment on function public.set_avatar_url is 'Client-facing setter for the one profile column a user is allowed to change themselves besides username. Format-validated here since there is no client write path to check it any other way.';

revoke all on function public.set_avatar_url(text) from public;
grant execute on function public.set_avatar_url(text) to authenticated;
