-- Paintings kept with the account. Until now the sketchbook lived only on
-- the device: in the app's files on a phone, and in the browser's local
-- storage on the web, which holds about 5 MB for the whole site (a few
-- paintings fill it, and saving then fails) and which Safari empties
-- after a week away. Now every piece is also kept here, in the player's
-- own folder of a private bucket, so it's never lost and shows on every
-- device they sign in on.
--
-- Each piece is three files in <player id>/: <id>.json (everything drawn),
-- <id>.png (its small picture) and <id>~<kind>~<page>.meta (empty; its
-- name says what the list needs, its time when it was last saved).
--
-- A guest who signs in to an account they already had brings their
-- paintings along: that account can read the guest's folder (copying the
-- pieces into its own) and clear it afterwards.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('sketchbook', 'sketchbook', false, 8388608,
          array['application/json', 'image/png'])
  on conflict (id) do nothing;

-- p_folder is a guest whose things moved to the caller when they signed in.
create function public._art_from_guest(p_folder text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.guest_transfers
      where guest_id::text = p_folder and done_by = auth.uid()
  );
$$;

revoke all on function public._art_from_guest(text) from public, anon;
grant execute on function public._art_from_guest(text) to authenticated;

-- The guests whose things moved to the caller (their paintings to bring
-- along).
create function public.my_guest_folders()
returns setof text
language sql
stable
security definer
set search_path = public
as $$
  select guest_id::text from public.guest_transfers where done_by = auth.uid();
$$;

revoke all on function public.my_guest_folders() from public, anon;
grant execute on function public.my_guest_folders() to authenticated;

create policy "players read their own paintings"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'sketchbook'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public._art_from_guest((storage.foldername(name))[1]))
  );

create policy "players save their own paintings"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'sketchbook' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "players resave their own paintings"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'sketchbook' and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'sketchbook' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "players delete their own paintings"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'sketchbook'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public._art_from_guest((storage.foldername(name))[1]))
  );
