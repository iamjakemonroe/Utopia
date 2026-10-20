-- Friends online, now. Before, the app checked in once a minute and friends
-- asked every 30 seconds who'd checked in within two minutes: someone came
-- online up to half a minute late, and went offline up to two and a half
-- minutes late.
--
--   * presence_status: whether each player is online, changed only when
--     they come or go, and sent live (Realtime) to their friends, and only
--     their friends (it can be read by them alone): the app shows it the
--     moment it changes.
--   * Opening the app (or coming back to it) checks in at once
--     (touch_presence); leaving it (or signing out) says so at once
--     (go_offline). While open, the app checks in every 25 seconds.
--   * An app that stops without saying (closed by the phone, signal lost)
--     is marked offline once it's been quiet 60 seconds: a sweep every 20.
--   * friends_online counts the same 60 seconds, for a fresh look.

create table public.presence_status (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  online     boolean not null default false,
  changed_at timestamptz not null default now()
);

comment on table public.presence_status is
  'Whether each player is online, changed only when they come or go; sent live to their friends.';

alter table public.presence_status enable row level security;
revoke all on public.presence_status from anon, authenticated;
grant select on public.presence_status to authenticated;
create policy "friends see each other come and go" on public.presence_status
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.friendships f
      where (f.user_low = auth.uid() and f.user_high = presence_status.user_id)
         or (f.user_high = auth.uid() and f.user_low = presence_status.user_id)
    )
  );

insert into public.presence_status (user_id, online, changed_at)
  select user_id, seen_at > now() - interval '60 seconds', seen_at from public.presence;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'presence_status'
  ) then
    alter publication supabase_realtime add table public.presence_status;
  end if;
end $$;

/** The app is open: the player is around now (and if they weren't, their
 * friends hear so at once). */
create or replace function public.touch_presence()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.presence (user_id, seen_at) values (auth.uid(), now())
    on conflict (user_id) do update set seen_at = now();
  insert into public.presence_status (user_id, online, changed_at)
    values (auth.uid(), true, now())
    on conflict (user_id) do update set online = true, changed_at = now()
    where not public.presence_status.online;
end;
$$;

/** The app is closing or going to the background: the player's gone. */
create function public.go_offline()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then return; end if;
  update public.presence set seen_at = now() - interval '1 hour' where user_id = auth.uid();
  update public.presence_status set online = false, changed_at = now()
   where user_id = auth.uid() and online;
end;
$$;

/** Apps that stopped without saying: offline after a quiet minute. */
create function public.sweep_presence()
returns void
language sql
security definer
set search_path = public
as $$
  update public.presence_status s set online = false, changed_at = now()
    from public.presence p
   where p.user_id = s.user_id and s.online and p.seen_at < now() - interval '60 seconds';
$$;

/** The player's friends who are around now. */
create or replace function public.friends_online()
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(p.user_id), '{}')
  from public.presence p
  join public.presence_status s on s.user_id = p.user_id and s.online
  join public.friendships f
    on (f.user_low = auth.uid() and f.user_high = p.user_id)
    or (f.user_high = auth.uid() and f.user_low = p.user_id)
  where p.seen_at > now() - interval '60 seconds';
$$;

revoke all on function public.go_offline() from public, anon;
revoke all on function public.sweep_presence() from public, anon, authenticated;
grant execute on function public.go_offline() to authenticated;

select cron.schedule('sweep-presence', '20 seconds', 'select public.sweep_presence()');
