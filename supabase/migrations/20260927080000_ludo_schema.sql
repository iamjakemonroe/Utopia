-- Ludo matches, matchmaking, and settlement. Same trust model, RLS shape,
-- and money model as chess (see 20260922120000_chess_social_schema.sql
-- header) — coins are virtual-only, so mutual-report settlement substitutes
-- for a server-verified rules engine, and record_ludo_move trusts the
-- client the same way record_move does for chess. Re-read that header
-- before real money ever touches this.
--
-- Scope note: online/staked matches are 2 players only for now (fixed as
-- red vs yellow, opposite corners) — matchmaking and invites both assume
-- exactly two seats, mirroring the chess tables. The Flutter engine
-- (lib/features/ludo/domain/ludo_engine.dart) itself supports more players
-- for a local pass-and-play mode; extending staked play to 3-4 players is
-- future work (payout splitting isn't winner-take-all-of-a-pot once there
-- are 3+ stakes, and needs its own design pass).

create table public.ludo_matches (
  id             uuid primary key default gen_random_uuid(),
  status         public.match_status not null default 'pending',
  stake          bigint not null check (stake >= 0),
  commission_bps int not null default 500,
  player_red     uuid not null references public.profiles (id),
  player_yellow  uuid references public.profiles (id),
  state          jsonb not null,
  turn_count     int not null default 0,
  winner_id      uuid references public.profiles (id),
  result         text, -- 'win' | 'resignation' | 'timeout' | 'disputed'
  created_at     timestamptz not null default now(),
  started_at     timestamptz,
  ended_at       timestamptz
);

comment on table public.ludo_matches is 'One row per Ludo game. state is the authoritative LudoState JSON (see LudoState.toJson/fromJson), updated by record_ludo_move. Realtime clients subscribe to this row + ludo_moves for live sync.';

create index ludo_matches_player_red_idx on public.ludo_matches (player_red, created_at desc);
create index ludo_matches_player_yellow_idx on public.ludo_matches (player_yellow, created_at desc);

create table public.ludo_moves (
  id           bigint generated always as identity primary key,
  match_id     uuid not null references public.ludo_matches (id) on delete cascade,
  turn_number  int not null,
  player_id    uuid not null references public.profiles (id),
  dice_value   int not null,
  token_index  int, -- null when the roll had no legal move and the turn just passed
  captured     boolean not null default false,
  reached_home boolean not null default false,
  state_after  jsonb not null,
  created_at   timestamptz not null default now(),
  unique (match_id, turn_number)
);

comment on table public.ludo_moves is 'Append-only move log. Both clients run the same engine locally and broadcast/replay from this table over Supabase Realtime, same sync-source-of-truth-not-anti-cheat role as match_moves for chess.';

create table public.ludo_match_result_reports (
  match_id    uuid not null references public.ludo_matches (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id),
  winner_id   uuid references public.profiles (id),
  result      text not null,
  created_at  timestamptz not null default now(),
  primary key (match_id, reporter_id)
);

create table public.ludo_matchmaking_queue (
  user_id   uuid primary key references public.profiles (id) on delete cascade,
  stake     bigint not null check (stake >= 0),
  queued_at timestamptz not null default now()
);

comment on table public.ludo_matchmaking_queue is 'Waiting room for "Play Random" Ludo. join_ludo_matchmaking_queue pairs two rows at the same stake, oldest first.';

-- ── RLS: select-only for clients ─────────────────────────────────────────

alter table public.ludo_matches enable row level security;
alter table public.ludo_moves enable row level security;
alter table public.ludo_match_result_reports enable row level security;
alter table public.ludo_matchmaking_queue enable row level security;

revoke insert, update, delete on public.ludo_matches from authenticated, anon;
revoke insert, update, delete on public.ludo_moves from authenticated, anon;
revoke insert, update, delete on public.ludo_match_result_reports from authenticated, anon;
revoke insert, update, delete on public.ludo_matchmaking_queue from authenticated, anon;

create policy "select own ludo matches" on public.ludo_matches
  for select using (auth.uid() = player_red or auth.uid() = player_yellow);

create policy "select moves of own ludo matches" on public.ludo_moves
  for select using (
    exists (
      select 1 from public.ludo_matches m
      where m.id = match_id and (m.player_red = auth.uid() or m.player_yellow = auth.uid())
    )
  );

create policy "select own ludo result reports" on public.ludo_match_result_reports
  for select using (
    exists (
      select 1 from public.ludo_matches m
      where m.id = match_id and (m.player_red = auth.uid() or m.player_yellow = auth.uid())
    )
  );

create policy "select own ludo queue row" on public.ludo_matchmaking_queue
  for select using (auth.uid() = user_id);

-- ── matchmaking ───────────────────────────────────────────────────────────

create function public.join_ludo_matchmaking_queue(p_stake bigint)
returns uuid -- returns a match id if a pairing happened immediately, else null
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_opponent uuid;
  v_match_id uuid;
  v_my_balance bigint;
  v_initial_state jsonb;
begin
  if v_me is null then
    raise exception 'not authenticated';
  end if;

  select balance into v_my_balance from public.profiles where id = v_me;
  if v_my_balance is null or v_my_balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  insert into public.ludo_matchmaking_queue (user_id, stake)
    values (v_me, p_stake)
    on conflict (user_id) do update set stake = excluded.stake, queued_at = now();

  select user_id into v_opponent
    from public.ludo_matchmaking_queue
    where stake = p_stake and user_id <> v_me
    order by queued_at
    limit 1
    for update skip locked;

  if v_opponent is null then
    return null;
  end if;

  delete from public.ludo_matchmaking_queue where user_id in (v_me, v_opponent);

  v_initial_state := jsonb_build_object(
    'players', jsonb_build_array('red', 'yellow'),
    'tokens', jsonb_build_object(
      'red', jsonb_build_array(-1, -1, -1, -1),
      'yellow', jsonb_build_array(-1, -1, -1, -1)
    ),
    'turn', 'red',
    'dice_value', null,
    'has_rolled', false,
    'consecutive_sixes', 0,
    'winner', null
  );

  insert into public.ludo_matches (player_red, player_yellow, stake, status, started_at, state)
    values (v_me, v_opponent, p_stake, 'active', now(), v_initial_state)
    returning id into v_match_id;

  perform public._ledger_move(v_me, 'match_stake', -p_stake, v_match_id);
  perform public._ledger_move(v_opponent, 'match_stake', -p_stake, v_match_id);

  update public.profiles set lifetime_wagered = lifetime_wagered + p_stake where id in (v_me, v_opponent);

  return v_match_id;
end;
$$;

revoke all on function public.join_ludo_matchmaking_queue(bigint) from public;
grant execute on function public.join_ludo_matchmaking_queue(bigint) to authenticated;

create function public.leave_ludo_matchmaking_queue()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.ludo_matchmaking_queue where user_id = auth.uid();
$$;

revoke all on function public.leave_ludo_matchmaking_queue() from public;
grant execute on function public.leave_ludo_matchmaking_queue() to authenticated;

-- ── moves ─────────────────────────────────────────────────────────────────

create function public.record_ludo_move(
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
  if v_me <> v_match.player_red and v_me <> v_match.player_yellow then
    raise exception 'not a player in this match';
  end if;

  insert into public.ludo_moves (
    match_id, turn_number, player_id, dice_value, token_index, captured, reached_home, state_after
  ) values (
    p_match_id, p_turn_number, v_me, p_dice_value, p_token_index, p_captured, p_reached_home, p_state_after
  );

  update public.ludo_matches
    set state = p_state_after, turn_count = p_turn_number
    where id = p_match_id;
end;
$$;

comment on function public.record_ludo_move is 'Appends a move and advances state. Does NOT validate Ludo legality server-side — same v1 tradeoff as record_move for chess (see 20260922120000_chess_social_schema.sql header).';

revoke all on function public.record_ludo_move(uuid, int, int, int, boolean, boolean, jsonb) from public;
grant execute on function public.record_ludo_move(uuid, int, int, int, boolean, boolean, jsonb) to authenticated;

-- ── settlement (reuses public._ledger_move, already game-agnostic) ────────

create function public._settle_ludo(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.ludo_matches;
  v_pot bigint;
  v_commission bigint;
  v_payout bigint;
  v_loser_id uuid;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;
  if v_match.status <> 'active' then
    return; -- already settled/aborted; idempotent no-op
  end if;

  v_pot := v_match.stake * 2;

  if p_winner_id is null then
    perform public._ledger_move(v_match.player_red, 'match_refund', v_match.stake, p_match_id);
    perform public._ledger_move(v_match.player_yellow, 'match_refund', v_match.stake, p_match_id);
  else
    v_commission := (v_pot * v_match.commission_bps) / 10000;
    v_payout := v_pot - v_commission;
    v_loser_id := case when p_winner_id = v_match.player_red then v_match.player_yellow else v_match.player_red end;

    perform public._ledger_move(p_winner_id, 'match_payout', v_payout, p_match_id);
    if v_commission > 0 then
      perform public._ledger_move(p_winner_id, 'commission', -v_commission, p_match_id, jsonb_build_object('loser', v_loser_id));
    end if;
  end if;

  update public.ludo_matches
    set status = 'completed', winner_id = p_winner_id, result = p_result, ended_at = now()
    where id = p_match_id;
end;
$$;

revoke all on function public._settle_ludo(uuid, uuid, text) from public;

create function public.report_ludo_match_result(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_other_report public.ludo_match_result_reports;
begin
  select * into v_match from public.ludo_matches where id = p_match_id;
  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if v_me <> v_match.player_red and v_me <> v_match.player_yellow then
    raise exception 'not a player in this match';
  end if;
  if p_winner_id is not null and p_winner_id <> v_match.player_red and p_winner_id <> v_match.player_yellow then
    raise exception 'winner must be a player in this match';
  end if;

  insert into public.ludo_match_result_reports (match_id, reporter_id, winner_id, result)
    values (p_match_id, v_me, p_winner_id, p_result)
    on conflict (match_id, reporter_id) do update set winner_id = excluded.winner_id, result = excluded.result, created_at = now();

  select * into v_other_report
    from public.ludo_match_result_reports
    where match_id = p_match_id and reporter_id <> v_me;

  if v_other_report is null then
    return; -- waiting on the other player
  end if;

  if v_other_report.winner_id is not distinct from p_winner_id and v_other_report.result = p_result then
    perform public._settle_ludo(p_match_id, p_winner_id, p_result);
  else
    update public.ludo_matches set status = 'disputed' where id = p_match_id;
  end if;
end;
$$;

comment on function public.report_ludo_match_result is 'Both players must independently report the same outcome before coins move — same reasoning as report_match_result for chess.';

revoke all on function public.report_ludo_match_result(uuid, uuid, text) from public;
grant execute on function public.report_ludo_match_result(uuid, uuid, text) to authenticated;

create function public.resign_ludo_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_winner uuid;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;
  if v_match is null then raise exception 'match not found'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  if v_me <> v_match.player_red and v_me <> v_match.player_yellow then
    raise exception 'not a player in this match';
  end if;

  v_winner := case when v_me = v_match.player_red then v_match.player_yellow else v_match.player_red end;
  perform public._settle_ludo(p_match_id, v_winner, 'resignation');
end;
$$;

revoke all on function public.resign_ludo_match(uuid) from public;
grant execute on function public.resign_ludo_match(uuid) to authenticated;

-- ── abandonment sweep (same pattern as forfeit_abandoned_matches) ─────────

create function public.forfeit_abandoned_ludo_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match record;
  v_last_activity timestamptz;
  v_winner uuid;
  v_turn text;
begin
  for v_match in select * from public.ludo_matches where status = 'active' loop
    select max(created_at) into v_last_activity
      from public.ludo_moves where match_id = v_match.id;
    v_last_activity := coalesce(v_last_activity, v_match.started_at, v_match.created_at);

    continue when v_last_activity >= now() - interval '15 minutes';

    -- Forfeit goes to whoever is NOT on the clock (they're the one still here).
    v_turn := v_match.state ->> 'turn';
    v_winner := case
      when v_turn = 'red' then v_match.player_yellow
      else v_match.player_red
    end;

    if v_winner is not null then
      perform public._settle_ludo(v_match.id, v_winner, 'timeout');
    end if;
  end loop;
end;
$$;

comment on function public.forfeit_abandoned_ludo_matches is 'Run by pg_cron every 5 minutes, not callable by clients — same abandonment-safety pattern as forfeit_abandoned_matches for chess.';

revoke all on function public.forfeit_abandoned_ludo_matches() from public, authenticated, anon;

select cron.schedule(
  'forfeit-abandoned-ludo-matches',
  '*/5 * * * *',
  $$select public.forfeit_abandoned_ludo_matches();$$
);

-- ── realtime ──────────────────────────────────────────────────────────────
-- Learned the hard way with chess: a table left off this publication just
-- silently never syncs to clients. See 20260923060000_realtime_publication.sql.

alter publication supabase_realtime add table public.ludo_matches;
alter publication supabase_realtime add table public.ludo_moves;
alter publication supabase_realtime add table public.ludo_matchmaking_queue;
