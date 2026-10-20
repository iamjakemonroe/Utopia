-- A challenge lasts 10 minutes, and a game only starts while the one who
-- sent it is still here.
--
-- A challenge stayed open until it was answered, however long that took:
-- accepted hours later, after its sender had gone, the game began without
-- them and was called off. Now:
--
--   * Each challenge expires 10 minutes after it's sent (expires_at); a
--     sweep every 30 seconds marks those that have 'expired', and they
--     leave both players' screens.
--   * Accepting one needs its sender online (presence_status). If they've
--     stepped away, it says so and the challenge waits (until it expires)
--     for them to come back.
--   * Refusing an accept no longer tries to mark the challenge in the
--     same breath (an error undoes that); the sweep does it.

alter table public.match_invites
  add column expires_at timestamptz not null default now() + interval '10 minutes';
update public.match_invites set expires_at = created_at + interval '10 minutes';
update public.match_invites
   set status = 'expired', responded_at = now()
 where status = 'pending' and expires_at <= now();

/** Marks the challenges that have run out. */
create function public.expire_challenges()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  update public.match_invites
     set status = 'expired', responded_at = now()
   where status = 'pending' and expires_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.expire_challenges() from public, anon, authenticated;

select cron.schedule('expire-challenges', '30 seconds', 'select public.expire_challenges()');

create or replace function public.respond_match_invite(p_invite_id uuid, p_accept boolean)
returns uuid -- match id if accepted
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_invite public.match_invites;
  v_match_id uuid;
  v_from_balance bigint;
  v_to_balance bigint;
begin
  -- Locked so a double tap (or the same account on two devices) can't
  -- create two matches from one invite.
  select * into v_invite
    from public.match_invites where id = p_invite_id and status = 'pending'
    for update;

  if v_invite is null then raise exception 'invite not found'; end if;
  if v_invite.to_user <> v_me then raise exception 'not your invite to answer'; end if;

  if not p_accept then
    update public.match_invites set status = 'declined', responded_at = now() where id = p_invite_id;
    return null;
  end if;

  if v_invite.expires_at <= now() then
    raise exception 'challenge expired';
  end if;
  if not coalesce(
    (select online from public.presence_status where user_id = v_invite.from_user),
    false
  ) then
    raise exception 'challenger away';
  end if;

  select balance into v_from_balance from public.profiles where id = v_invite.from_user;
  select balance into v_to_balance from public.profiles where id = v_invite.to_user;
  if v_from_balance is null or v_from_balance < v_invite.stake
     or v_to_balance is null or v_to_balance < v_invite.stake then
    raise exception 'a player no longer has enough balance for this stake';
  end if;

  v_match_id := public._board_create_match(
    v_invite.game, v_invite.from_user, v_invite.to_user, v_invite.stake,
    v_invite.minutes, v_invite.increment
  );

  update public.match_invites
    set status = 'accepted', responded_at = now(), match_id = v_match_id
    where id = p_invite_id;

  return v_match_id;
end;
$$;
