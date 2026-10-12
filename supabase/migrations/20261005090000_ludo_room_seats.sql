-- Choosing your color in a friends' room.
--
--   * Each seat in a room has a fixed color: the colors of a full table of
--     that size (a 4-seat room is red, green, yellow, blue). Players can move
--     to any open seat with take_ludo_room_seat, first come first served.
--   * start_ludo_room now gives everyone the color of the seat they picked
--     and plays on the room's board (classic up to 4 seats, star for 5-6),
--     instead of handing out colors by headcount.

create or replace function public._ludo_initial_state(p_colors text[], p_board text)
returns jsonb
language sql
immutable
as $$
  select public._ludo_initial_state(p_colors) || jsonb_build_object('board', p_board);
$$;

-- Like _ludo_create_match, with each player's color and the board given.
create function public._ludo_create_seated_match(
  p_players uuid[],
  p_colors text[],
  p_board text,
  p_stake bigint,
  p_mode text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_id uuid;
  v_player uuid;
begin
  insert into public.ludo_matches (
    player_red, player_yellow, players, colors, board, mode, stake, status, started_at, state
  ) values (
    p_players[1],
    p_players[2],
    p_players,
    p_colors,
    p_board,
    p_mode,
    p_stake,
    'active',
    now(),
    public._ludo_initial_state(p_colors, p_board)
  ) returning id into v_match_id;

  if p_stake > 0 then
    foreach v_player in array p_players loop
      perform public._ledger_move(v_player, 'match_stake', -p_stake, v_match_id);
    end loop;
    update public.profiles set lifetime_wagered = lifetime_wagered + p_stake
      where id = any (p_players);
  end if;

  return v_match_id;
end;
$$;

revoke all on function public._ludo_create_seated_match(uuid[], text[], text, bigint, text) from public;

create function public.take_ludo_room_seat(p_room_id uuid, p_seat int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room public.ludo_rooms;
begin
  select * into v_room from public.ludo_rooms where id = p_room_id for update;
  if v_room is null then raise exception 'room not found'; end if;
  if v_room.status <> 'open' then raise exception 'that game has already started'; end if;
  if not exists (select 1 from public.ludo_room_members where room_id = p_room_id and user_id = v_me) then
    raise exception 'not in this room';
  end if;
  if p_seat < 0 or p_seat >= v_room.max_players then raise exception 'no such seat'; end if;
  if exists (select 1 from public.ludo_room_members where room_id = p_room_id and seat = p_seat) then
    raise exception 'that seat is taken';
  end if;

  update public.ludo_room_members set seat = p_seat
    where room_id = p_room_id and user_id = v_me;
end;
$$;

revoke all on function public.take_ludo_room_seat(uuid, int) from public;
grant execute on function public.take_ludo_room_seat(uuid, int) to authenticated;

create or replace function public.start_ludo_room(p_room_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room public.ludo_rooms;
  v_players uuid[];
  v_colors text[];
  v_short text;
  v_match_id uuid;
begin
  select * into v_room from public.ludo_rooms where id = p_room_id for update;
  if v_room is null then raise exception 'room not found'; end if;
  if v_room.host_id <> v_me then raise exception 'only the host can start the game'; end if;
  if v_room.status <> 'open' then raise exception 'that game has already started'; end if;

  -- Seat order is turn order; each seat keeps its color.
  select array_agg(m.user_id order by m.seat),
         array_agg((public._ludo_colors(v_room.max_players))[m.seat + 1] order by m.seat)
    into v_players, v_colors
    from public.ludo_room_members m
    where m.room_id = p_room_id;
  if coalesce(cardinality(v_players), 0) < 2 then
    raise exception 'need at least 2 players';
  end if;

  if v_room.stake > 0 then
    select coalesce(username, display_name, 'a player') into v_short
      from public.profiles
      where id = any (v_players) and balance < v_room.stake
      limit 1;
    if v_short is not null then
      raise exception 'insufficient balance: %', v_short;
    end if;
  end if;

  v_match_id := public._ludo_create_seated_match(
    v_players,
    v_colors,
    case when v_room.max_players > 4 then 'hex' else 'classic' end,
    v_room.stake,
    'friends'
  );
  update public.ludo_rooms set status = 'started', match_id = v_match_id where id = p_room_id;
  return v_match_id;
end;
$$;
