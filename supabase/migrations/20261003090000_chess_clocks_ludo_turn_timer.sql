-- Chess clocks and the Ludo turn timer.
--
-- Chess
--   * Every new game has a time control (minutes + increment per move),
--     chosen in the lobby or on an invite. Quick match only pairs players
--     who picked the same stake and time control.
--   * The server keeps the clocks: record_move charges the mover for the
--     time since the last move and adds the increment. Each side's first
--     move is off the clock; if a first move doesn't come within 30
--     seconds the game is called off and entries are refunded.
--   * claim_chess_timeout lets either player end a game whose clock has
--     run out (the cron sweep does the same if nobody is around).
--   * record_move now refuses moves from the player who isn't on turn.
--
-- Ludo
--   * Each action (roll, then pick a token) has 15 seconds. When time is
--     up any player can call skip_ludo_turn and the turn passes. Three
--     missed turns in a row and the player is out of the game, same as
--     leaving it.
--   * record_ludo_move now refuses moves from the player who isn't on turn,
--     so a move that arrives after a skip can't overwrite it.
--
-- Matches created before this migration have no clocks and keep the old
-- 15 minute abandonment rule.

-- ── chess: time controls ──────────────────────────────────────────────────

alter table public.matches
  add column clock_initial_ms int,
  add column clock_increment_ms int not null default 0,
  add column white_ms bigint,
  add column black_ms bigint,
  add column turn_started_at timestamptz;

comment on column public.matches.white_ms is 'White''s remaining time as of turn_started_at. Null for untimed (pre-clock) games.';
comment on column public.matches.turn_started_at is 'When the side to move started thinking: the last move, or the start of the game.';

alter table public.matchmaking_queue
  add column minutes int not null default 10,
  add column increment int not null default 0;

alter table public.match_invites
  add column minutes int not null default 10,
  add column increment int not null default 0;

-- The time controls the app offers: bullet, blitz, rapid, classical.
create function public._chess_time_control_ok(p_minutes int, p_increment int)
returns boolean
language sql
immutable
as $$
  select (p_minutes, p_increment) in (
    (1, 0), (2, 1), (3, 0), (3, 2), (5, 0), (10, 0), (15, 10), (30, 0)
  );
$$;

-- Creates an active, timed match and takes both entries. Callers have
-- already checked balances.
create function public._chess_create_match(
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
    player_white, player_black, stake, status, started_at,
    clock_initial_ms, clock_increment_ms, white_ms, black_ms, turn_started_at
  ) values (
    p_white, p_black, p_stake, 'active', now(),
    v_ms, p_increment * 1000, v_ms, v_ms, now()
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

revoke all on function public._chess_create_match(uuid, uuid, bigint, int, int) from public;

drop function public.join_matchmaking_queue(bigint);

create function public.join_matchmaking_queue(
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
    values (v_me, 'chess', p_stake, p_minutes, p_increment)
    on conflict (user_id) do update
      set stake = excluded.stake, minutes = excluded.minutes,
          increment = excluded.increment, queued_at = now();

  select user_id into v_opponent
    from public.matchmaking_queue
    where game = 'chess' and stake = p_stake and minutes = p_minutes
      and increment = p_increment and user_id <> v_me
    order by queued_at
    limit 1
    for update skip locked;

  if v_opponent is null then
    return null;
  end if;

  delete from public.matchmaking_queue where user_id in (v_me, v_opponent);

  -- Whoever waited longer gets white.
  return public._chess_create_match(v_opponent, v_me, p_stake, p_minutes, p_increment);
end;
$$;

revoke all on function public.join_matchmaking_queue(bigint, int, int) from public;
grant execute on function public.join_matchmaking_queue(bigint, int, int) to authenticated;

drop function public.send_match_invite(uuid, bigint);

create function public.send_match_invite(
  p_to_user uuid,
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

  insert into public.match_invites (from_user, to_user, stake, minutes, increment)
    values (v_me, p_to_user, p_stake, p_minutes, p_increment)
    returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.send_match_invite(uuid, bigint, int, int) from public;
grant execute on function public.send_match_invite(uuid, bigint, int, int) to authenticated;

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

  v_match_id := public._chess_create_match(
    v_invite.from_user, v_invite.to_user, v_invite.stake, v_invite.minutes, v_invite.increment
  );

  update public.match_invites
    set status = 'accepted', responded_at = now(), match_id = v_match_id
    where id = p_invite_id;

  return v_match_id;
end;
$$;

-- ── chess: moves on the clock ─────────────────────────────────────────────

-- Ends a timed game whose clock has run out. Returns the result it settled
-- with ('timeout' or 'aborted'), or null if time isn't up. Expects the
-- caller to hold the row lock.
create function public._chess_check_clock(p_match public.matches)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_white_to_move boolean := p_match.ply_count % 2 = 0;
  v_elapsed bigint;
  v_left bigint;
begin
  if p_match.status <> 'active' or p_match.white_ms is null then
    return null;
  end if;

  v_elapsed := (extract(epoch from (now() - p_match.turn_started_at)) * 1000)::bigint;

  if p_match.ply_count < 2 then
    -- Nobody's clock runs until both sides have moved once; a first move
    -- that never comes calls the game off instead.
    if v_elapsed >= 30000 then
      perform public._settle(p_match.id, null, 'aborted');
      return 'aborted';
    end if;
    return null;
  end if;

  v_left := case when v_white_to_move then p_match.white_ms else p_match.black_ms end - v_elapsed;
  if v_left > 0 then
    return null;
  end if;

  perform public._settle(
    p_match.id,
    case when v_white_to_move then p_match.player_black else p_match.player_white end,
    'timeout'
  );
  return 'timeout';
end;
$$;

revoke all on function public._chess_check_clock(public.matches) from public;

create or replace function public.record_move(p_match_id uuid, p_from text, p_to text, p_promotion text, p_san text, p_fen_after text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.matches;
  v_white_to_move boolean;
  v_mover uuid;
  v_next_ply int;
  v_left bigint;
begin
  select * into v_match from public.matches where id = p_match_id for update;

  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if v_me <> v_match.player_white and v_me <> v_match.player_black then
    raise exception 'not a player in this match';
  end if;

  v_white_to_move := v_match.ply_count % 2 = 0;
  v_mover := case when v_white_to_move then v_match.player_white else v_match.player_black end;
  if v_me <> v_mover then
    raise exception 'not your turn';
  end if;

  -- Out of time (or a first move that came too late): the game ends here
  -- and the move doesn't count.
  if public._chess_check_clock(v_match) is not null then
    return;
  end if;

  v_next_ply := v_match.ply_count + 1;

  insert into public.match_moves (match_id, ply, player_id, from_square, to_square, promotion, san, fen_after)
    values (p_match_id, v_next_ply, v_me, p_from, p_to, p_promotion, p_san, p_fen_after);

  if v_match.white_ms is null then
    update public.matches
      set board_fen = p_fen_after, ply_count = v_next_ply, turn_started_at = now()
      where id = p_match_id;
    return;
  end if;

  v_left := case when v_white_to_move then v_match.white_ms else v_match.black_ms end;
  if v_match.ply_count >= 2 then
    v_left := v_left
      - (extract(epoch from (now() - v_match.turn_started_at)) * 1000)::bigint
      + v_match.clock_increment_ms;
  end if;

  update public.matches
    set board_fen = p_fen_after,
        ply_count = v_next_ply,
        white_ms = case when v_white_to_move then v_left else white_ms end,
        black_ms = case when v_white_to_move then black_ms else v_left end,
        turn_started_at = now()
    where id = p_match_id;
end;
$$;

create function public.claim_chess_timeout(p_match_id uuid)
returns text -- 'timeout', 'aborted', or null if time isn't up yet
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.matches;
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if v_match is null then raise exception 'match not found'; end if;
  if v_me <> v_match.player_white and v_me <> v_match.player_black then
    raise exception 'not a player in this match';
  end if;
  if v_match.status <> 'active' then
    return v_match.result;
  end if;

  return public._chess_check_clock(v_match);
end;
$$;

revoke all on function public.claim_chess_timeout(uuid) from public;
grant execute on function public.claim_chess_timeout(uuid) to authenticated;

-- Timed games end on the clock even when nobody is there to claim it;
-- untimed (older) games keep the 15 minute rule.
create or replace function public.forfeit_abandoned_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
  v_last_activity timestamptz;
begin
  for v_match in select * from public.matches where status = 'active' for update skip locked loop
    if v_match.white_ms is not null then
      perform public._chess_check_clock(v_match);
      continue;
    end if;

    select max(created_at) into v_last_activity
      from public.match_moves where match_id = v_match.id;
    v_last_activity := coalesce(v_last_activity, v_match.started_at, v_match.created_at);
    continue when v_last_activity >= now() - interval '15 minutes';

    perform public._settle(
      v_match.id,
      case when v_match.ply_count % 2 = 0 then v_match.player_black else v_match.player_white end,
      'timeout'
    );
  end loop;
end;
$$;

revoke all on function public.forfeit_abandoned_matches() from public, authenticated, anon;

-- ── ludo: turn timer ──────────────────────────────────────────────────────

alter table public.ludo_matches
  add column missed_turns jsonb not null default '{}'::jsonb;

comment on column public.ludo_matches.missed_turns is 'Turns each color has let run out in a row ({"red": 1}). Reset when that player acts; three and they are out.';

-- The next seat after p_from that is still in the game.
create function public._ludo_next_color(p_colors text[], p_left jsonb, p_from text)
returns text
language plpgsql
immutable
as $$
declare
  v_idx int := array_position(p_colors, p_from);
  v_n int := cardinality(p_colors);
  v_next text;
begin
  for i in 1..v_n loop
    v_next := p_colors[((v_idx - 1 + i) % v_n) + 1];
    exit when not coalesce(p_left, '[]'::jsonb) ? v_next;
  end loop;
  return v_next;
end;
$$;

-- Passes the turn on when the player on turn has let their 15 seconds run
-- out. The caller says which turn it saw (turn_count + roll_seq) so a skip
-- can never land on a turn that has already moved on. Returns true if the
-- turn moved on (by this call or already), false if time isn't up yet.
create function public.skip_ludo_turn(p_match_id uuid, p_turn_count int, p_roll_seq int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_color text;
  v_missed int;
  v_state jsonb;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;

  if v_match is null then raise exception 'match not found'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then return true; end if;
  if v_match.turn_count <> p_turn_count
     or coalesce((v_match.state ->> 'roll_seq')::int, 0) <> p_roll_seq then
    return true;
  end if;
  if v_match.state ->> 'winner' is not null then return true; end if;
  if v_match.updated_at > now() - interval '15 seconds' then
    return false;
  end if;

  v_color := v_match.state ->> 'turn';
  v_missed := coalesce((v_match.missed_turns ->> v_color)::int, 0) + 1;

  update public.ludo_matches
    set missed_turns = missed_turns || jsonb_build_object(v_color, v_missed),
        turn_count = turn_count + 1
    where id = p_match_id;

  if v_missed >= 3 then
    perform public._ludo_remove_player(
      p_match_id,
      v_match.players[array_position(v_match.colors, v_color)],
      'timeout'
    );
    return true;
  end if;

  v_state := v_match.state || jsonb_build_object(
    'turn', public._ludo_next_color(v_match.colors, v_match.state -> 'left', v_color),
    'dice_value', null,
    'has_rolled', false,
    'consecutive_sixes', 0
  );

  update public.ludo_matches set state = v_state, updated_at = now() where id = p_match_id;
  return true;
end;
$$;

revoke all on function public.skip_ludo_turn(uuid, int, int) from public;
grant execute on function public.skip_ludo_turn(uuid, int, int) to authenticated;

create or replace function public.record_ludo_roll(p_match_id uuid, p_state jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_color text;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;

  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;

  v_color := v_match.colors[array_position(v_match.players, v_me)];
  if v_color <> v_match.state ->> 'turn' then
    raise exception 'not your turn';
  end if;

  update public.ludo_matches
    set state = p_state, updated_at = now(), missed_turns = missed_turns - v_color
    where id = p_match_id;
end;
$$;

create or replace function public.record_ludo_move(
  p_match_id uuid,
  p_turn_number int,
  p_dice_value int,
  p_token_index int,
  p_captured boolean,
  p_reached_home boolean,
  p_state_after jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_color text;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;

  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;

  v_color := v_match.colors[array_position(v_match.players, v_me)];
  if v_color <> v_match.state ->> 'turn' then
    raise exception 'not your turn';
  end if;

  insert into public.ludo_moves (
    match_id, turn_number, player_id, dice_value, token_index, captured, reached_home, state_after
  ) values (
    p_match_id, p_turn_number, v_me, p_dice_value, p_token_index, p_captured, p_reached_home, p_state_after
  );

  update public.ludo_matches
    set state = p_state_after, turn_count = p_turn_number, updated_at = now(),
        missed_turns = missed_turns - v_color
    where id = p_match_id;
end;
$$;
