-- Accepting a friend request never worked.
--
-- respond_friend_request wrote its new status from a CASE expression, which
-- Postgres types as text, into a friend_request_status column, so every
-- accept and decline failed with a type error. The status is now cast to
-- the enum.
--
-- Answering twice (a double tap, or the alert and the inbox both open) is
-- now harmless: answering a request the same way again just returns.

create or replace function public.respond_friend_request(p_request_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_from uuid;
  v_to uuid;
  v_status public.friend_request_status;
  v_new public.friend_request_status :=
    case when p_accept then 'accepted' else 'declined' end::public.friend_request_status;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select from_user, to_user, status into v_from, v_to, v_status
    from public.friend_requests where id = p_request_id;

  if v_from is null then raise exception 'request not found'; end if;
  if v_to <> v_me then raise exception 'not your request to answer'; end if;
  if v_status = v_new then return; end if;
  if v_status <> 'pending' then raise exception 'request not found'; end if;

  update public.friend_requests
    set status = v_new, responded_at = now()
    where id = p_request_id;

  if p_accept then
    insert into public.friendships (user_low, user_high)
      values (least(v_from, v_to), greatest(v_from, v_to))
      on conflict do nothing;
  end if;
end;
$$;

revoke all on function public.respond_friend_request(uuid, boolean) from public;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
