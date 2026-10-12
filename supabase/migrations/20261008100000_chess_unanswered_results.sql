-- A finished chess game no longer waits on the other player's app.
--
-- Both apps report how a game ended, and coins move once the two reports
-- agree. If one player has already closed the app (say, right after being
-- checkmated), their report never comes, and the game used to sit "active"
-- until their clock ran out.
--
--   * While a game is open, each app checks in every few seconds
--     (touch_chess_match). Check-ins live in their own table, so they don't
--     wake up every client watching the match row.
--   * A report nobody has answered settles after 15 seconds, provided the
--     other player hasn't checked in for 20 seconds (so it can't be used
--     against someone who is still at the board) and it fits the board: a
--     checkmate's winner must be whoever made the last move, and a draw
--     names no winner.
--   * Either player's app asks for this (claim_chess_timeout), and the
--     cron sweep does too.

create table public.chess_presence (
  match_id uuid not null references public.matches (id) on delete cascade,
  user_id  uuid not null references public.profiles (id) on delete cascade,
  seen_at  timestamptz not null default now(),
  primary key (match_id, user_id)
);

alter table public.chess_presence enable row level security;
revoke insert, update, delete on public.chess_presence from authenticated, anon;

create function public.touch_chess_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public._is_chess_player(p_match_id) then
    raise exception 'not a player in this match';
  end if;
  insert into public.chess_presence (match_id, user_id, seen_at)
    values (p_match_id, auth.uid(), now())
    on conflict (match_id, user_id) do update set seen_at = now();
end;
$$;

revoke all on function public.touch_chess_match(uuid) from public;
grant execute on function public.touch_chess_match(uuid) to authenticated;

-- Settles a game on its one unanswered result report when that's safe.
-- Returns the result it settled with, or null. Expects the caller to hold
-- the row lock.
create function public._chess_settle_unanswered(p_match public.matches)
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

  if v_report.result = 'checkmate' then
    -- The side to move is the side that's mated.
    v_last_mover := case when split_part(p_match.board_fen, ' ', 2) = 'w'
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

revoke all on function public._chess_settle_unanswered(public.matches) from public;

create or replace function public.claim_chess_timeout(p_match_id uuid)
returns text -- how the game ended, or null if it's still on
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.matches;
  v_result text;
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if v_match is null then raise exception 'match not found'; end if;
  if v_me <> v_match.player_white and v_me <> v_match.player_black then
    raise exception 'not a player in this match';
  end if;
  if v_match.status <> 'active' then
    return v_match.result;
  end if;

  v_result := public._chess_settle_unanswered(v_match);
  if v_result is not null then return v_result; end if;
  return public._chess_check_clock(v_match);
end;
$$;

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
    continue when public._chess_settle_unanswered(v_match) is not null;

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
