-- Notifications: someone wants to be your friend, accepted your request,
-- or challenged you to a game.
--
--   * One row per notification, written by triggers on friend_requests and
--     match_invites, so every way of sending one is covered.
--   * The app watches its own rows live (an alert pops up wherever you are)
--     and lists them in its notifications inbox.
--   * Answering a request or invite marks its notification read, wherever
--     it was answered from.

create table public.notifications (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in ('friend_request', 'friend_accepted', 'game_invite')),
  actor_id   uuid references public.profiles (id) on delete cascade,
  ref_id     uuid,
  data       jsonb not null default '{}'::jsonb,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_idx on public.notifications (user_id, id desc);

alter table public.notifications enable row level security;
revoke insert, update, delete on public.notifications from authenticated, anon;

create policy "see your own notifications" on public.notifications
  for select using (user_id = auth.uid());

create function public.mark_notifications_read(p_ids bigint[] default null)
returns void
language sql
security definer
set search_path = public
as $$
  update public.notifications
    set read_at = now()
    where user_id = auth.uid()
      and read_at is null
      and (p_ids is null or id = any (p_ids));
$$;

revoke all on function public.mark_notifications_read(bigint[]) from public;
grant execute on function public.mark_notifications_read(bigint[]) to authenticated;

create function public._notify_friend_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- A new request (or one sent again after being declined). Re-sending a
  -- request that's still pending doesn't notify twice.
  if new.status = 'pending' and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    insert into public.notifications (user_id, kind, actor_id, ref_id)
      values (new.to_user, 'friend_request', new.from_user, new.id);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status <> 'pending' then
    update public.notifications
      set read_at = coalesce(read_at, now())
      where kind = 'friend_request' and ref_id = new.id;
    if new.status = 'accepted' then
      insert into public.notifications (user_id, kind, actor_id, ref_id)
        values (new.from_user, 'friend_accepted', new.to_user, new.id);
    end if;
  end if;
  return new;
end;
$$;

create trigger friend_requests_notify
  after insert or update on public.friend_requests
  for each row execute function public._notify_friend_request();

create function public._notify_match_invite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    insert into public.notifications (user_id, kind, actor_id, ref_id, data)
      values (
        new.to_user, 'game_invite', new.from_user, new.id,
        jsonb_build_object(
          'game', new.game, 'stake', new.stake,
          'minutes', new.minutes, 'increment', new.increment
        )
      );
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status <> 'pending' then
    update public.notifications
      set read_at = coalesce(read_at, now())
      where kind = 'game_invite' and ref_id = new.id;
  end if;
  return new;
end;
$$;

create trigger match_invites_notify
  after insert or update on public.match_invites
  for each row execute function public._notify_match_invite();

-- friend_requests goes live too, so the friends list updates as requests
-- are answered.
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.friend_requests;
