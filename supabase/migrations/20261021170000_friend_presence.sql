-- Friends online. While the app is open it checks in about once a
-- minute (touch_presence), and a player can see which of their friends
-- checked in during the last two minutes (friends_online). Only friends:
-- nobody can read when anyone else was last on.

create table public.presence (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  seen_at timestamptz not null default now()
);
alter table public.presence enable row level security;
revoke all on public.presence from anon, authenticated;

/** The app is open: the player is around now. */
create function public.touch_presence()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.presence (user_id, seen_at) values (auth.uid(), now())
    on conflict (user_id) do update set seen_at = now();
end;
$$;

/** The player's friends who are around now. */
create function public.friends_online()
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(array_agg(p.user_id), '{}')
  from public.presence p
  join public.friendships f
    on (f.user_low = auth.uid() and f.user_high = p.user_id)
    or (f.user_high = auth.uid() and f.user_low = p.user_id)
  where p.seen_at > now() - interval '2 minutes';
$$;

revoke all on function public.touch_presence() from public, anon;
revoke all on function public.friends_online() from public, anon;
grant execute on function public.touch_presence() to authenticated;
grant execute on function public.friends_online() to authenticated;
