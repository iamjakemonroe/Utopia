-- Taking back a challenge you've sent.
--
--   * cancel_match_invite: the one who sent a challenge can call it off
--     while it's still waiting for an answer. It's locked like an answer
--     is, so a cancel and an accept at the same moment can't both happen:
--     whichever comes first wins. The friend's notification of it goes.
--   * Challenging the same friend to the same game again replaces the one
--     still waiting (it's cancelled), so they never pile up.

create function public.cancel_match_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_invite public.match_invites;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_invite
    from public.match_invites where id = p_invite_id
    for update;
  if v_invite is null or v_invite.from_user <> v_me then
    raise exception 'invite not found';
  end if;
  if v_invite.status <> 'pending' then
    raise exception 'challenge already answered';
  end if;
  update public.match_invites
     set status = 'cancelled', responded_at = now()
   where id = p_invite_id;
  delete from public.notifications
   where kind = 'game_invite' and ref_id = p_invite_id;
end;
$$;

revoke all on function public.cancel_match_invite(uuid) from public, anon;
grant execute on function public.cancel_match_invite(uuid) to authenticated;

create or replace function public.send_board_invite(
  p_to_user uuid,
  p_game text,
  p_stake bigint,
  p_minutes int default 10,
  p_increment int default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_game public.game_kind := public._board_game(p_game);
  v_id uuid;
  v_balance bigint;
  v_old uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if v_me = p_to_user then raise exception 'cannot invite yourself'; end if;
  if p_stake < 0 then raise exception 'invalid stake'; end if;
  if not public._chess_time_control_ok(p_minutes, p_increment) then
    raise exception 'unknown time control';
  end if;

  select balance into v_balance from public.profiles where id = v_me;
  if v_balance is null or v_balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  -- The one still waiting for them in this game makes way for this one.
  for v_old in
    select id from public.match_invites
     where from_user = v_me and to_user = p_to_user and game = v_game
       and status = 'pending'
     for update
  loop
    update public.match_invites
       set status = 'cancelled', responded_at = now()
     where id = v_old;
    delete from public.notifications
     where kind = 'game_invite' and ref_id = v_old;
  end loop;

  insert into public.match_invites (game, from_user, to_user, stake, minutes, increment)
    values (v_game, v_me, p_to_user, p_stake, p_minutes, p_increment)
    returning id into v_id;

  return v_id;
end;
$$;
