-- Checkers on the shared board-game tables.
--
--   * Matches, queue entries and invites now say which game they are, and
--     a checkers match starts from the checkers board. The first mover
--     ("dark" in checkers) sits in player_white, so the existing move,
--     clock, timeout, resign and chat functions work unchanged.
--   * The chess queue now records which game a player is waiting for (it
--     never updated it before, so switching games would have stuck).
--   * A one-sided result report settles by move-count parity instead of
--     reading the chess board, and checkers' "win" counts like checkmate.
--   * Player stats count chess and checkers separately.

create or replace function public._board_create_match(
  p_game public.game_kind,
  p_white uuid,
  p_black uuid,
  p_stake bigint,
  p_minutes int,
  p_increment int
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ms bigint := p_minutes * 60000;
  v_match_id uuid;
begin
  insert into public.matches (
    game, player_white, player_black, stake, status, started_at,
    clock_initial_ms, clock_increment_ms, white_ms, black_ms, turn_started_at,
    board_fen
  ) values (
    p_game, p_white, p_black, p_stake, 'active', now(),
    v_ms, p_increment * 1000, v_ms, v_ms, now(),
    case when p_game = 'checkers'
      then 'llllllllllll........dddddddddddd d 0'
      else 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' end
  ) returning id into v_match_id;

  if p_stake > 0 then
    perform public._ledger_move(p_white, 'match_stake', -p_stake, v_match_id);
    perform public._ledger_move(p_black, 'match_stake', -p_stake, v_match_id);
    update public.profiles set lifetime_wagered = lifetime_wagered + p_stake
      where id in (p_white, p_black);
  end if;

  return v_match_id;
end;
$$;

revoke all on function public._board_create_match(public.game_kind, uuid, uuid, bigint, int, int) from public;

create or replace function public._chess_create_match(
  p_white uuid,
  p_black uuid,
  p_stake bigint,
  p_minutes int,
  p_increment int
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  return public._board_create_match('chess', p_white, p_black, p_stake, p_minutes, p_increment);
end;
$$;

create or replace function public._board_game(p_game text)
returns public.game_kind
language plpgsql
immutable
as $$
begin
  if p_game not in ('chess', 'checkers') then raise exception 'unknown game'; end if;
  return p_game::public.game_kind;
end;
$$;

create or replace function public.join_board_queue(
  p_game text,
  p_stake bigint,
  p_minutes int default 10,
  p_increment int default 0
)
returns uuid -- the match id if this call paired with someone, else null
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_game public.game_kind := public._board_game(p_game);
  v_opponent uuid;
  v_balance bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_stake < 0 then raise exception 'invalid stake'; end if;
  if not public._chess_time_control_ok(p_minutes, p_increment) then
    raise exception 'unknown time control';
  end if;

  select balance into v_balance from public.profiles where id = v_me;
  if v_balance is null or v_balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  insert into public.matchmaking_queue (user_id, game, stake, minutes, increment)
    values (v_me, v_game, p_stake, p_minutes, p_increment)
    on conflict (user_id) do update
      set game = excluded.game, stake = excluded.stake, minutes = excluded.minutes,
          increment = excluded.increment, queued_at = now();

  select user_id into v_opponent
    from public.matchmaking_queue
    where game = v_game and stake = p_stake and minutes = p_minutes
      and increment = p_increment and user_id <> v_me
    order by queued_at
    limit 1
    for update skip locked;

  if v_opponent is null then
    return null;
  end if;

  delete from public.matchmaking_queue where user_id in (v_me, v_opponent);

  -- Whoever waited longer moves first.
  return public._board_create_match(v_game, v_opponent, v_me, p_stake, p_minutes, p_increment);
end;
$$;

revoke all on function public.join_board_queue(text, bigint, int, int) from public;
grant execute on function public.join_board_queue(text, bigint, int, int) to authenticated;

create or replace function public.join_matchmaking_queue(
  p_stake bigint,
  p_minutes int default 10,
  p_increment int default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.join_board_queue('chess', p_stake, p_minutes, p_increment);
end;
$$;

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

  insert into public.match_invites (game, from_user, to_user, stake, minutes, increment)
    values (v_game, v_me, p_to_user, p_stake, p_minutes, p_increment)
    returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.send_board_invite(uuid, text, bigint, int, int) from public;
grant execute on function public.send_board_invite(uuid, text, bigint, int, int) to authenticated;

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

  select balance into v_from_balance from public.profiles where id = v_invite.from_user;
  select balance into v_to_balance from public.profiles where id = v_invite.to_user;
  if v_from_balance is null or v_from_balance < v_invite.stake
     or v_to_balance is null or v_to_balance < v_invite.stake then
    update public.match_invites set status = 'expired', responded_at = now() where id = p_invite_id;
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

create or replace function public._chess_settle_unanswered(p_match public.matches)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reports int;
  v_report public.match_result_reports;
  v_other uuid;
  v_other_seen timestamptz;
  v_last_mover uuid;
begin
  if p_match.status <> 'active' then return null; end if;

  select count(*) into v_reports from public.match_result_reports where match_id = p_match.id;
  if v_reports <> 1 then return null; end if;
  select * into v_report from public.match_result_reports where match_id = p_match.id;
  if v_report.created_at > now() - interval '15 seconds' then return null; end if;

  v_other := case when v_report.reporter_id = p_match.player_white
                  then p_match.player_black else p_match.player_white end;
  select seen_at into v_other_seen from public.chess_presence
    where match_id = p_match.id and user_id = v_other;
  if v_other_seen is not null and v_other_seen > now() - interval '20 seconds' then
    return null;
  end if;

  if v_report.result in ('checkmate', 'win') then
    -- The side to move lost, so the winner made the last move. Even move
    -- counts mean the first mover (player_white) is to move.
    v_last_mover := case when p_match.ply_count % 2 = 0
                         then p_match.player_black else p_match.player_white end;
    if p_match.ply_count = 0 or v_report.winner_id is distinct from v_last_mover then
      return null;
    end if;
  elsif v_report.result in ('stalemate', 'draw') then
    if v_report.winner_id is not null then return null; end if;
  else
    return null;
  end if;

  perform public._settle(p_match.id, v_report.winner_id, v_report.result);
  return v_report.result;
end;
$$;

create or replace function public.get_player_stats(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'ludo_played', (select count(*) from public.ludo_matches
                      where p_user = any (players) and status = 'completed'),
    'ludo_won', (select count(*) from public.ludo_matches
                   where winner_id = p_user and status = 'completed'),
    'chess_played', (select count(*) from public.matches
                       where game::text = 'chess' and status = 'completed'
                         and (player_white = p_user or player_black = p_user)),
    'chess_won', (select count(*) from public.matches
                    where game::text = 'chess' and winner_id = p_user and status = 'completed'),
    'checkers_played', (select count(*) from public.matches
                          where game::text = 'checkers' and status = 'completed'
                            and (player_white = p_user or player_black = p_user)),
    'checkers_won', (select count(*) from public.matches
                       where game::text = 'checkers' and winner_id = p_user and status = 'completed'),
    'member_since', (select created_at from public.profiles where id = p_user)
  );
$$;
