-- Online chess and checkers moves are checked by the server. Until now a
-- player's app worked out the position after its move and sent it, and the
-- server stored it: a changed app could have sent any board. Now moves go
-- through the board-move function, which works out the move with the apps'
-- own rules (lib/features/house/domain/board_referee.dart) from the board
-- the server holds, and saves it with board_play_move. A move that ends the
-- game (checkmate, stalemate, a draw by the rules, a checkers win) settles
-- it there and then.
--
-- So players no longer report how a game ended: the referee, resigning and
-- the clocks decide (and a house player's own engine, for its moves).

-- The referee's move for p_mover, made on the position at p_ply: saved as
-- any move is (the clocks too), and the game settled if it ended it. False
-- if the clock had already run out (the move doesn't count).
create function public.board_play_move(
  p_match uuid,
  p_mover uuid,
  p_ply int,
  p_from text,
  p_to text,
  p_promotion text,
  p_san text,
  p_fen_after text,
  p_winner text,
  p_result text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
  v_ply int;
begin
  select * into v_match from public.matches where id = p_match for update;
  if v_match is null then raise exception 'match not found'; end if;
  -- The position the referee judged is still the board.
  if v_match.ply_count <> p_ply then raise exception 'out of sync'; end if;

  perform public._record_move_as(p_mover, p_match, p_from, p_to, p_promotion, p_san, p_fen_after);

  select ply_count into v_ply from public.matches where id = p_match;
  if v_ply <> p_ply + 1 then return false; end if;

  if p_result is not null then
    perform public._settle(
      p_match,
      case p_winner when 'white' then v_match.player_white
                    when 'black' then v_match.player_black end,
      p_result
    );
  end if;
  return true;
end;
$$;

revoke all on function public.board_play_move(uuid, uuid, int, text, text, text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.board_play_move(uuid, uuid, int, text, text, text, text, text, text, text)
  to service_role;

-- Boards sent by an app aren't taken any more.
create or replace function public.record_move(p_match_id uuid, p_from text, p_to text, p_promotion text, p_san text, p_fen_after text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'moves are checked by the server now: update the app';
end;
$$;

-- Nor are results: the server works out how a game ends.
create or replace function public.report_match_result(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'the server decides how games end now: update the app';
end;
$$;

-- A house player's engine reads the server's own board, so how it says a
-- game ended is final.
create or replace function public.house_report_result(p_match uuid, p_winner text, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
begin
  select * into v_match from public.matches where id = p_match for update;
  if v_match.house_player is null or v_match.status <> 'active' then return; end if;
  perform public._settle(
    p_match,
    case p_winner when 'white' then v_match.player_white
                  when 'black' then v_match.player_black end,
    p_result
  );
end;
$$;
