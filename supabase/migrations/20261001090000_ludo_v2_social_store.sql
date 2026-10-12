-- Ludo v2 and the social/store layer around it:
--
--   * Ludo for 2-6 players: seats (players[] + colors[]) instead of fixed
--     red/yellow columns. 2-4 players use the classic board, 5-6 the
--     six-arm "hex" board. Winner takes the whole pot.
--   * Quick match for 2 or 4 players; friend rooms joined with a 6-letter
--     code (2-6 players, optional stake, host starts the game).
--   * Dice rolls are synced (record_ludo_roll), so everyone sees every roll.
--   * Leaving a game is a forfeit: 2 players left -> the other one wins;
--     more -> the leaver's tokens are cleared and the game goes on.
--   * In-game chat. Public (matchmade) games mask offensive words
--     server-side; friend games are unfiltered. Capture reactions
--     (war/peace) ride the same table.
--   * Player reports, bug reports, public player stats.
--   * Cosmetics ownership (themes, piece sets) and equipped items.
--   * Fixes settlement taking the commission twice (chess and Ludo): the
--     winner was credited pot - commission and then debited the commission
--     again. Now the full pot is credited and the commission debited once,
--     so the net is pot - commission, matching what the app shows.
--
-- Trust model is unchanged from 20260927080000_ludo_schema.sql: game state
-- is client-authored and both/all clients run the same engine; coins only
-- move inside SECURITY DEFINER functions here.

-- ── settlement fix (chess) ────────────────────────────────────────────────

create or replace function public._settle(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
  v_pot bigint;
  v_commission bigint;
  v_loser_id uuid;
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if v_match.status <> 'active' then
    return; -- already settled/aborted; idempotent no-op
  end if;

  v_pot := v_match.stake * 2;

  if p_winner_id is null then
    if v_match.stake > 0 then
      perform public._ledger_move(v_match.player_white, 'match_refund', v_match.stake, p_match_id);
      perform public._ledger_move(v_match.player_black, 'match_refund', v_match.stake, p_match_id);
    end if;
  elsif v_pot > 0 then
    v_commission := (v_pot * v_match.commission_bps) / 10000;
    v_loser_id := case when p_winner_id = v_match.player_white then v_match.player_black else v_match.player_white end;
    perform public._ledger_move(p_winner_id, 'match_payout', v_pot, p_match_id);
    if v_commission > 0 then
      perform public._ledger_move(p_winner_id, 'commission', -v_commission, p_match_id, jsonb_build_object('loser', v_loser_id));
    end if;
  end if;

  update public.matches
    set status = 'completed', winner_id = p_winner_id, result = p_result, ended_at = now()
    where id = p_match_id;
end;
$$;

revoke all on function public._settle(uuid, uuid, text) from public;

-- ── ludo_matches: seats ───────────────────────────────────────────────────

alter table public.ludo_matches
  add column players uuid[],
  add column colors text[],
  add column board text not null default 'classic' check (board in ('classic', 'hex')),
  add column mode text not null default 'public' check (mode in ('public', 'friends')),
  add column updated_at timestamptz not null default now();

update public.ludo_matches
  set players = array_remove(array[player_red, player_yellow], null),
      colors = case when player_yellow is null then array['red'] else array['red', 'yellow'] end
  where players is null;

alter table public.ludo_matches
  alter column players set not null,
  alter column colors set not null,
  alter column player_red drop not null,
  add constraint ludo_matches_seats check (
    cardinality(players) = cardinality(colors) and cardinality(players) between 1 and 6
  );

comment on column public.ludo_matches.players is 'Seat order. players[i] plays colors[i]; turn order follows seats.';
comment on column public.ludo_matches.mode is 'public = matchmade (chat filtered), friends = friend room (chat unfiltered).';

create index ludo_matches_players_idx on public.ludo_matches using gin (players);

-- Membership check usable from RLS policies on other tables without
-- tripping over ludo_matches' own RLS.
create function public._is_ludo_player(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.ludo_matches where id = p_match_id and auth.uid() = any (players)
  );
$$;

revoke all on function public._is_ludo_player(uuid) from public;
grant execute on function public._is_ludo_player(uuid) to authenticated;

drop policy "select own ludo matches" on public.ludo_matches;
create policy "select own ludo matches" on public.ludo_matches
  for select using (auth.uid() = any (players));

drop policy "select moves of own ludo matches" on public.ludo_moves;
create policy "select moves of own ludo matches" on public.ludo_moves
  for select using (public._is_ludo_player(match_id));

drop policy "select own ludo result reports" on public.ludo_match_result_reports;
create policy "select own ludo result reports" on public.ludo_match_result_reports
  for select using (public._is_ludo_player(match_id));

-- The colors each table size plays with. Turn order follows this order.
create function public._ludo_colors(p_count int)
returns text[]
language sql
immutable
as $$
  select case p_count
    when 2 then array['red', 'yellow']
    when 3 then array['red', 'green', 'yellow']
    when 4 then array['red', 'green', 'yellow', 'blue']
    when 5 then array['red', 'orange', 'yellow', 'green', 'blue']
    when 6 then array['red', 'orange', 'yellow', 'green', 'blue', 'purple']
  end;
$$;

create function public._ludo_initial_state(p_colors text[])
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'board', case when cardinality(p_colors) > 4 then 'hex' else 'classic' end,
    'players', to_jsonb(p_colors),
    'tokens', (select jsonb_object_agg(c, '[-1,-1,-1,-1]'::jsonb) from unnest(p_colors) as c),
    'turn', p_colors[1],
    'dice_value', null,
    'has_rolled', false,
    'consecutive_sixes', 0,
    'winner', null,
    'left', '[]'::jsonb,
    'roll_seq', 0,
    'last_roll', null,
    'capture', null
  );
$$;

-- Creates an active match for these players (seat order) and takes the
-- stakes. Callers have already checked balances.
create function public._ludo_create_match(p_players uuid[], p_stake bigint, p_mode text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_colors text[] := public._ludo_colors(cardinality(p_players));
  v_match_id uuid;
  v_player uuid;
begin
  insert into public.ludo_matches (
    player_red, player_yellow, players, colors, board, mode, stake, status, started_at, state
  ) values (
    p_players[1],
    p_players[2],
    p_players,
    v_colors,
    case when cardinality(p_players) > 4 then 'hex' else 'classic' end,
    p_mode,
    p_stake,
    'active',
    now(),
    public._ludo_initial_state(v_colors)
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

revoke all on function public._ludo_create_match(uuid[], bigint, text) from public;

-- ── quick match: 2 or 4 players ───────────────────────────────────────────

alter table public.ludo_matchmaking_queue
  add column size int not null default 2 check (size in (2, 4));

drop function public.join_ludo_matchmaking_queue(bigint);

create function public.join_ludo_matchmaking_queue(p_stake bigint, p_size int default 2)
returns uuid -- the new match id if this join completed a table, else null
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_balance bigint;
  v_group uuid[];
  v_match_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_size not in (2, 4) then raise exception 'quick match is 2 or 4 players'; end if;
  if p_stake < 0 then raise exception 'invalid stake'; end if;

  select balance into v_balance from public.profiles where id = v_me;
  if v_balance is null or v_balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  insert into public.ludo_matchmaking_queue (user_id, stake, size)
    values (v_me, p_stake, p_size)
    on conflict (user_id) do update
      set stake = excluded.stake, size = excluded.size, queued_at = now();

  select array_agg(user_id order by queued_at) into v_group
    from (
      select user_id, queued_at
        from public.ludo_matchmaking_queue
        where stake = p_stake and size = p_size
        order by queued_at
        limit p_size
        for update skip locked
    ) waiting;

  if coalesce(cardinality(v_group), 0) < p_size then
    return null;
  end if;

  delete from public.ludo_matchmaking_queue where user_id = any (v_group);
  v_match_id := public._ludo_create_match(v_group, p_stake, 'public');

  return case when v_me = any (v_group) then v_match_id else null end;
end;
$$;

revoke all on function public.join_ludo_matchmaking_queue(bigint, int) from public;
grant execute on function public.join_ludo_matchmaking_queue(bigint, int) to authenticated;

-- ── friend rooms ──────────────────────────────────────────────────────────

create table public.ludo_rooms (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique check (code ~ '^[A-Z0-9]{6}$'),
  host_id     uuid not null references public.profiles (id) on delete cascade,
  stake       bigint not null default 0 check (stake >= 0),
  max_players int not null check (max_players between 2 and 6),
  status      text not null default 'open' check (status in ('open', 'started', 'closed')),
  match_id    uuid references public.ludo_matches (id),
  created_at  timestamptz not null default now()
);

comment on table public.ludo_rooms is 'A friend lobby joined by code. The host starts it once 2+ players are in, which creates a mode=friends ludo match.';

create table public.ludo_room_members (
  room_id   uuid not null references public.ludo_rooms (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  seat      int not null check (seat between 0 and 5),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id),
  unique (room_id, seat)
);

create index ludo_room_members_user_idx on public.ludo_room_members (user_id);

create function public._is_ludo_room_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.ludo_room_members where room_id = p_room_id and user_id = auth.uid()
  );
$$;

revoke all on function public._is_ludo_room_member(uuid) from public;
grant execute on function public._is_ludo_room_member(uuid) to authenticated;

alter table public.ludo_rooms enable row level security;
alter table public.ludo_room_members enable row level security;
revoke insert, update, delete on public.ludo_rooms from authenticated, anon;
revoke insert, update, delete on public.ludo_room_members from authenticated, anon;

create policy "select rooms you are in" on public.ludo_rooms
  for select using (public._is_ludo_room_member(id));
create policy "select members of rooms you are in" on public.ludo_room_members
  for select using (public._is_ludo_room_member(room_id));

-- Leaves every open room the user is in (closing any they host alone, or
-- handing the host role on), so a player is only ever in one lobby.
create function public._leave_open_ludo_rooms(p_user uuid, p_except uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room record;
  v_next_host uuid;
begin
  for v_room in
    select r.* from public.ludo_rooms r
      join public.ludo_room_members m on m.room_id = r.id
      where m.user_id = p_user and r.status = 'open'
        and (p_except is null or r.id <> p_except)
      for update of r
  loop
    delete from public.ludo_room_members where room_id = v_room.id and user_id = p_user;
    if v_room.host_id = p_user then
      select user_id into v_next_host from public.ludo_room_members
        where room_id = v_room.id order by joined_at limit 1;
      if v_next_host is null then
        update public.ludo_rooms set status = 'closed' where id = v_room.id;
      else
        update public.ludo_rooms set host_id = v_next_host where id = v_room.id;
      end if;
    end if;
  end loop;
end;
$$;

revoke all on function public._leave_open_ludo_rooms(uuid, uuid) from public;

create function public.create_ludo_room(p_max_players int, p_stake bigint default 0)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_balance bigint;
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
  v_room_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_max_players not between 2 and 6 then raise exception 'rooms are 2-6 players'; end if;
  if p_stake < 0 then raise exception 'invalid stake'; end if;

  select balance into v_balance from public.profiles where id = v_me;
  if v_balance is null or v_balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  perform public._leave_open_ludo_rooms(v_me);

  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.ludo_rooms where code = v_code);
  end loop;

  insert into public.ludo_rooms (code, host_id, stake, max_players)
    values (v_code, v_me, p_stake, p_max_players)
    returning id into v_room_id;
  insert into public.ludo_room_members (room_id, user_id, seat) values (v_room_id, v_me, 0);

  return jsonb_build_object('id', v_room_id, 'code', v_code);
end;
$$;

revoke all on function public.create_ludo_room(int, bigint) from public;
grant execute on function public.create_ludo_room(int, bigint) to authenticated;

create function public.join_ludo_room(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room public.ludo_rooms;
  v_count int;
  v_seat int;
  v_balance bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select * into v_room from public.ludo_rooms
    where code = upper(trim(p_code))
    for update;
  if v_room is null then raise exception 'no room with that code'; end if;

  if exists (select 1 from public.ludo_room_members where room_id = v_room.id and user_id = v_me) then
    return v_room.id;
  end if;
  if v_room.status <> 'open' then raise exception 'that game has already started'; end if;

  select count(*) into v_count from public.ludo_room_members where room_id = v_room.id;
  if v_count >= v_room.max_players then raise exception 'room is full'; end if;

  select balance into v_balance from public.profiles where id = v_me;
  if v_balance is null or v_balance < v_room.stake then
    raise exception 'insufficient balance';
  end if;

  perform public._leave_open_ludo_rooms(v_me, v_room.id);

  select min(s) into v_seat from generate_series(0, v_room.max_players - 1) as s
    where s not in (select seat from public.ludo_room_members where room_id = v_room.id);

  insert into public.ludo_room_members (room_id, user_id, seat) values (v_room.id, v_me, v_seat);
  return v_room.id;
end;
$$;

revoke all on function public.join_ludo_room(text) from public;
grant execute on function public.join_ludo_room(text) to authenticated;

create function public.leave_ludo_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  perform public._leave_open_ludo_rooms(v_me);
end;
$$;

revoke all on function public.leave_ludo_room(uuid) from public;
grant execute on function public.leave_ludo_room(uuid) to authenticated;

create function public.start_ludo_room(p_room_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room public.ludo_rooms;
  v_players uuid[];
  v_short text;
  v_match_id uuid;
begin
  select * into v_room from public.ludo_rooms where id = p_room_id for update;
  if v_room is null then raise exception 'room not found'; end if;
  if v_room.host_id <> v_me then raise exception 'only the host can start the game'; end if;
  if v_room.status <> 'open' then raise exception 'that game has already started'; end if;

  select array_agg(user_id order by seat) into v_players
    from public.ludo_room_members where room_id = p_room_id;
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

  v_match_id := public._ludo_create_match(v_players, v_room.stake, 'friends');
  update public.ludo_rooms set status = 'started', match_id = v_match_id where id = p_room_id;
  return v_match_id;
end;
$$;

revoke all on function public.start_ludo_room(uuid) from public;
grant execute on function public.start_ludo_room(uuid) to authenticated;

-- ── moves and rolls ───────────────────────────────────────────────────────

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
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;

  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;

  insert into public.ludo_moves (
    match_id, turn_number, player_id, dice_value, token_index, captured, reached_home, state_after
  ) values (
    p_match_id, p_turn_number, v_me, p_dice_value, p_token_index, p_captured, p_reached_home, p_state_after
  );

  update public.ludo_matches
    set state = p_state_after, turn_count = p_turn_number, updated_at = now()
    where id = p_match_id;
end;
$$;

-- A roll that leaves the player choosing a token: the state is shared right
-- away so everyone sees the die land (and a re-roll can't be fished for).
create function public.record_ludo_roll(p_match_id uuid, p_state jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;

  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.colors[array_position(v_match.players, v_me)] <> v_match.state ->> 'turn' then
    raise exception 'not your turn';
  end if;

  update public.ludo_matches set state = p_state, updated_at = now() where id = p_match_id;
end;
$$;

revoke all on function public.record_ludo_roll(uuid, jsonb) from public;
grant execute on function public.record_ludo_roll(uuid, jsonb) to authenticated;

-- ── settlement, leaving, abandonment ──────────────────────────────────────

create or replace function public._settle_ludo(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.ludo_matches;
  v_pot bigint;
  v_commission bigint;
  v_player uuid;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;
  if v_match.status <> 'active' then
    return; -- already settled/aborted; idempotent no-op
  end if;

  v_pot := v_match.stake * cardinality(v_match.players);

  if p_winner_id is null then
    if v_match.stake > 0 then
      foreach v_player in array v_match.players loop
        perform public._ledger_move(v_player, 'match_refund', v_match.stake, p_match_id);
      end loop;
    end if;
  elsif v_pot > 0 then
    v_commission := (v_pot * v_match.commission_bps) / 10000;
    perform public._ledger_move(p_winner_id, 'match_payout', v_pot, p_match_id);
    if v_commission > 0 then
      perform public._ledger_move(p_winner_id, 'commission', -v_commission, p_match_id);
    end if;
  end if;

  update public.ludo_matches
    set status = 'completed', winner_id = p_winner_id, result = p_result,
        ended_at = now(), updated_at = now()
    where id = p_match_id;
end;
$$;

-- Takes a player out of an active match (they left, or went quiet). Their
-- stake stays in the pot. If one player remains they win; otherwise the
-- leaver's tokens are cleared and the turn moves on if it was theirs.
create function public._ludo_remove_player(p_match_id uuid, p_user uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.ludo_matches;
  v_color text;
  v_state jsonb;
  v_left jsonb;
  v_active text[];
  v_idx int;
  v_n int;
  v_next text;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;
  if v_match is null or v_match.status <> 'active' then return; end if;

  v_color := v_match.colors[array_position(v_match.players, p_user)];
  if v_color is null then raise exception 'not a player in this match'; end if;

  v_state := v_match.state;
  v_left := coalesce(v_state -> 'left', '[]'::jsonb);
  if not v_left ? v_color then
    v_left := v_left || to_jsonb(v_color);
  end if;
  v_state := jsonb_set(v_state, '{left}', v_left);
  v_state := jsonb_set(v_state, array['tokens', v_color], '[-1,-1,-1,-1]'::jsonb);

  select array_agg(c order by ord) into v_active
    from unnest(v_match.colors) with ordinality as t(c, ord)
    where not v_left ? c;

  if coalesce(cardinality(v_active), 0) <= 1 then
    update public.ludo_matches set state = v_state where id = p_match_id;
    perform public._settle_ludo(
      p_match_id,
      v_match.players[array_position(v_match.colors, v_active[1])],
      p_result
    );
    return;
  end if;

  if v_state ->> 'turn' = v_color then
    v_idx := array_position(v_match.colors, v_color);
    v_n := cardinality(v_match.colors);
    for i in 1..v_n loop
      v_next := v_match.colors[((v_idx - 1 + i) % v_n) + 1];
      exit when not v_left ? v_next;
    end loop;
    v_state := v_state || jsonb_build_object(
      'turn', v_next, 'dice_value', null, 'has_rolled', false, 'consecutive_sixes', 0
    );
  end if;

  update public.ludo_matches set state = v_state, updated_at = now() where id = p_match_id;
end;
$$;

revoke all on function public._ludo_remove_player(uuid, uuid, text) from public;

create or replace function public.resign_ludo_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
begin
  select * into v_match from public.ludo_matches where id = p_match_id;
  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;

  perform public._ludo_remove_player(p_match_id, v_me, 'resignation');
end;
$$;

create or replace function public.report_ludo_match_result(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_agreeing int;
  v_disagreeing int;
begin
  select * into v_match from public.ludo_matches where id = p_match_id;
  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if p_winner_id is not null and not (p_winner_id = any (v_match.players)) then
    raise exception 'winner must be a player in this match';
  end if;

  insert into public.ludo_match_result_reports (match_id, reporter_id, winner_id, result)
    values (p_match_id, v_me, p_winner_id, p_result)
    on conflict (match_id, reporter_id) do update
      set winner_id = excluded.winner_id, result = excluded.result, created_at = now();

  select
    count(*) filter (where winner_id is not distinct from p_winner_id and result = p_result),
    count(*) filter (where not (winner_id is not distinct from p_winner_id and result = p_result))
  into v_agreeing, v_disagreeing
  from public.ludo_match_result_reports
  where match_id = p_match_id;

  -- Two independent, matching reports settle it. In a 2-player game a
  -- mismatch is a dispute; with more players the others can still agree.
  if v_agreeing >= 2 then
    perform public._settle_ludo(p_match_id, p_winner_id, p_result);
  elsif v_disagreeing > 0 and cardinality(v_match.players) = 2 then
    update public.ludo_matches set status = 'disputed', updated_at = now() where id = p_match_id;
  end if;
end;
$$;

create or replace function public.forfeit_abandoned_ludo_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match record;
  v_idle uuid;
begin
  for v_match in
    select * from public.ludo_matches
      where status = 'active' and updated_at < now() - interval '15 minutes'
  loop
    -- Whoever is on the clock is the one who went quiet.
    v_idle := v_match.players[array_position(v_match.colors, v_match.state ->> 'turn')];
    if v_idle is not null then
      perform public._ludo_remove_player(v_match.id, v_idle, 'timeout');
    end if;
  end loop;
end;
$$;

revoke all on function public.forfeit_abandoned_ludo_matches() from public, authenticated, anon;

-- ── chat ──────────────────────────────────────────────────────────────────

create table public.ludo_chat_messages (
  id         bigint generated always as identity primary key,
  match_id   uuid not null references public.ludo_matches (id) on delete cascade,
  sender_id  uuid not null references public.profiles (id) on delete cascade,
  kind       text not null default 'text' check (kind in ('text', 'quick', 'emote', 'reaction')),
  body       text not null check (char_length(body) between 1 and 200),
  created_at timestamptz not null default now()
);

create index ludo_chat_messages_match_idx on public.ludo_chat_messages (match_id, id);

alter table public.ludo_chat_messages enable row level security;
revoke insert, update, delete on public.ludo_chat_messages from authenticated, anon;

create policy "select chat of own ludo matches" on public.ludo_chat_messages
  for select using (public._is_ludo_player(match_id));

-- Masks offensive words (whole words and their common endings) with ★s.
-- The app does a stricter pass first; this is the backstop no client can
-- skip.
create function public.mask_offensive(p_text text)
returns text
language sql
immutable
as $$
  select regexp_replace(
    p_text,
    '\m(f+u+c+k+\w*|motherf\w*|sh+i+t+\w*|bullshit\w*|b+i+t+c+h+\w*|c+u+n+t+\w*|'
      || 'assholes?|bastards?|whores?|sluts?|dickheads?|niggers?|niggas?|faggots?|fags?|'
      || 'retards?|retarded|twats?|wankers?|pussy|pussies|cocks?|cocksuckers?|kys|'
      || 'rape\w*|rapist\w*|chinks?|spics?|kikes?|trann(y|ies)|dumbass\w*|jackass\w*)\M',
    '★★★',
    'gi'
  );
$$;

create function public.send_ludo_chat(p_match_id uuid, p_kind text, p_body text)
returns public.ludo_chat_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_body text := btrim(p_body);
  v_recent int;
  v_row public.ludo_chat_messages;
begin
  select * into v_match from public.ludo_matches where id = p_match_id;
  if v_match is null then raise exception 'match not found'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if p_kind not in ('text', 'quick', 'emote', 'reaction') then raise exception 'invalid message kind'; end if;
  if v_body is null or char_length(v_body) = 0 then raise exception 'empty message'; end if;
  if char_length(v_body) > 200 then raise exception 'message too long'; end if;
  if p_kind = 'reaction' and v_body not in ('war', 'peace') then
    raise exception 'invalid reaction';
  end if;

  select count(*) into v_recent from public.ludo_chat_messages
    where match_id = p_match_id and sender_id = v_me
      and created_at > now() - interval '10 seconds';
  if v_recent >= 6 then raise exception 'slow down'; end if;

  if v_match.mode = 'public' and p_kind in ('text', 'quick') then
    v_body := public.mask_offensive(v_body);
  end if;

  insert into public.ludo_chat_messages (match_id, sender_id, kind, body)
    values (p_match_id, v_me, p_kind, v_body)
    returning * into v_row;
  return v_row;
end;
$$;

revoke all on function public.send_ludo_chat(uuid, text, text) from public;
grant execute on function public.send_ludo_chat(uuid, text, text) to authenticated;

-- ── reports ───────────────────────────────────────────────────────────────

create table public.player_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reported_id uuid not null references public.profiles (id) on delete cascade,
  match_id    uuid,
  reason      text not null check (reason in ('offensive_chat', 'cheating', 'quitting', 'name_or_avatar', 'other')),
  details     text check (char_length(details) <= 500),
  created_at  timestamptz not null default now(),
  check (reporter_id <> reported_id)
);

alter table public.player_reports enable row level security;
revoke insert, update, delete on public.player_reports from authenticated, anon;
create policy "select own player reports" on public.player_reports
  for select using (auth.uid() = reporter_id);

create function public.report_player(p_reported uuid, p_reason text, p_details text default null, p_match_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if v_me = p_reported then raise exception 'cannot report yourself'; end if;
  insert into public.player_reports (reporter_id, reported_id, match_id, reason, details)
    values (v_me, p_reported, p_match_id, p_reason, nullif(btrim(p_details), ''));
end;
$$;

revoke all on function public.report_player(uuid, text, text, uuid) from public;
grant execute on function public.report_player(uuid, text, text, uuid) to authenticated;

create table public.bug_reports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles (id) on delete set null,
  description text not null check (char_length(description) between 5 and 2000),
  category    text not null default 'bug' check (category in ('bug', 'gameplay', 'payments', 'account', 'idea')),
  app_version text,
  platform    text,
  contact     text check (char_length(contact) <= 200),
  status      text not null default 'new' check (status in ('new', 'triaged', 'fixed', 'wontfix')),
  created_at  timestamptz not null default now()
);

alter table public.bug_reports enable row level security;
revoke insert, update, delete on public.bug_reports from authenticated, anon;
create policy "select own bug reports" on public.bug_reports
  for select using (auth.uid() = user_id);

create function public.submit_bug_report(
  p_description text,
  p_category text default 'bug',
  p_app_version text default null,
  p_platform text default null,
  p_contact text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
  v_recent int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select count(*) into v_recent from public.bug_reports
    where user_id = v_me and created_at > now() - interval '1 hour';
  if v_recent >= 10 then raise exception 'too many reports, try again later'; end if;

  insert into public.bug_reports (user_id, description, category, app_version, platform, contact)
    values (v_me, btrim(p_description), p_category, p_app_version, p_platform, nullif(btrim(p_contact), ''))
    returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.submit_bug_report(text, text, text, text, text) from public;
grant execute on function public.submit_bug_report(text, text, text, text, text) to authenticated;

-- ── player stats (public aggregates only) ─────────────────────────────────

create function public.get_player_stats(p_user uuid)
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
                       where (player_white = p_user or player_black = p_user) and status = 'completed'),
    'chess_won', (select count(*) from public.matches
                    where winner_id = p_user and status = 'completed'),
    'member_since', (select created_at from public.profiles where id = p_user)
  );
$$;

revoke all on function public.get_player_stats(uuid) from public;
grant execute on function public.get_player_stats(uuid) to authenticated;

-- ── cosmetics ─────────────────────────────────────────────────────────────

alter table public.profiles
  add column equipped_theme text not null default 'utopia_dark',
  add column equipped_ludo_pieces text not null default 'classic',
  add column equipped_chess_pieces text not null default 'classic';

comment on column public.profiles.equipped_ludo_pieces is 'Piece set other players see this user''s Ludo tokens in.';

create table public.user_entitlements (
  user_id        uuid not null references public.profiles (id) on delete cascade,
  item_id        text not null,
  source         text not null check (source in ('purchase', 'grant')),
  platform       text,
  product_id     text,
  transaction_id text,
  created_at     timestamptz not null default now(),
  primary key (user_id, item_id)
);

alter table public.user_entitlements enable row level security;
revoke insert, update, delete on public.user_entitlements from authenticated, anon;
create policy "select own entitlements" on public.user_entitlements
  for select using (auth.uid() = user_id);

create table public.purchase_receipts (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles (id) on delete cascade,
  platform       text not null check (platform in ('ios', 'android')),
  product_id     text not null,
  transaction_id text not null,
  verification   text,
  verified       boolean not null default false,
  created_at     timestamptz not null default now(),
  unique (platform, transaction_id)
);

comment on table public.purchase_receipts is 'Every store purchase the app reports. verified stays false until server-side receipt verification (App Store Server API / Play Developer API) is wired up; see claim_purchase.';

alter table public.purchase_receipts enable row level security;
revoke insert, update, delete on public.purchase_receipts from authenticated, anon;

-- Free items everyone owns.
create function public._free_item(p_item_id text)
returns boolean
language sql
immutable
as $$
  select p_item_id in ('utopia_dark', 'azure_dusk', 'classic', 'bubble');
$$;

-- Records a completed store purchase and grants its items.
--
-- NOT YET VERIFIED: until a server-side receipt check is added (needs App
-- Store Server API keys / a Play service account), this trusts the app's
-- report. The receipt is stored so purchases can be verified retroactively.
create function public.claim_purchase(
  p_platform text,
  p_product_id text,
  p_transaction_id text,
  p_verification text,
  p_item_ids text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_item text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if coalesce(cardinality(p_item_ids), 0) = 0 or cardinality(p_item_ids) > 64 then
    raise exception 'invalid items';
  end if;

  insert into public.purchase_receipts (user_id, platform, product_id, transaction_id, verification)
    values (v_me, p_platform, p_product_id, p_transaction_id, p_verification)
    on conflict (platform, transaction_id) do nothing;

  foreach v_item in array p_item_ids loop
    insert into public.user_entitlements (user_id, item_id, source, platform, product_id, transaction_id)
      values (v_me, v_item, 'purchase', p_platform, p_product_id, p_transaction_id)
      on conflict (user_id, item_id) do nothing;
  end loop;
end;
$$;

revoke all on function public.claim_purchase(text, text, text, text, text[]) from public;
grant execute on function public.claim_purchase(text, text, text, text, text[]) to authenticated;

create function public.equip_item(p_kind text, p_item_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not public._free_item(p_item_id) and not exists (
    select 1 from public.user_entitlements where user_id = v_me and item_id = p_item_id
  ) then
    raise exception 'you don''t own that yet';
  end if;

  case p_kind
    when 'theme' then update public.profiles set equipped_theme = p_item_id where id = v_me;
    when 'ludo_pieces' then update public.profiles set equipped_ludo_pieces = p_item_id where id = v_me;
    when 'chess_pieces' then update public.profiles set equipped_chess_pieces = p_item_id where id = v_me;
    else raise exception 'invalid item kind';
  end case;
end;
$$;

revoke all on function public.equip_item(text, text) from public;
grant execute on function public.equip_item(text, text) to authenticated;

-- ── realtime ──────────────────────────────────────────────────────────────

alter publication supabase_realtime add table public.ludo_rooms;
alter publication supabase_realtime add table public.ludo_room_members;
alter publication supabase_realtime add table public.ludo_chat_messages;
