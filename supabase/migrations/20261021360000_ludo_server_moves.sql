-- Ludo's rules move to the server. Until now each player's app worked out
-- its own rolls and moves and sent the board that resulted, and the server
-- stored it: an app changed to send "all my pieces are home" would have
-- won the pot. Now the server rolls the die (roll_ludo_dice) and works out
-- every move from the board it holds (move_ludo_token), with the same rules
-- as LudoEngine in lib/features/ludo/domain/ludo_engine.dart; it settles the
-- pot itself when someone gets home. Boards sent by an app are refused.
--
-- The state JSON is unchanged (LudoState.toJson), so the apps show it as
-- before.

-- ── the board ─────────────────────────────────────────────────────────────

-- Every seat on a board, clockwise: the classic cross or the six-arm star.
create function public._ludo_seats(p_board text)
returns text[]
language sql
immutable
as $$
  select case when p_board = 'hex'
    then array['red', 'orange', 'yellow', 'green', 'blue', 'purple']
    else array['red', 'green', 'yellow', 'blue'] end;
$$;

-- Squares round the shared ring: 13 an arm.
create function public._ludo_ring(p_board text)
returns int
language sql
immutable
as $$
  select 13 * cardinality(public._ludo_seats(p_board));
$$;

-- The ring square a piece of p_color is on, p_rel steps along its path.
create function public._ludo_abs(p_board text, p_color text, p_rel int)
returns int
language sql
immutable
as $$
  select ((array_position(public._ludo_seats(p_board), p_color) - 1) * 13 + p_rel)
         % public._ludo_ring(p_board);
$$;

-- A piece at p_pos can move p_dice: out of the yard only on a six, never
-- once home, and never past home.
create function public._ludo_can_move(p_board text, p_pos int, p_dice int)
returns boolean
language sql
immutable
as $$
  select case
    when p_pos = -1 then p_dice = 6
    when p_pos >= public._ludo_ring(p_board) + 4 then false
    else p_pos + p_dice <= public._ludo_ring(p_board) + 4 end;
$$;

-- p_color's pieces, as positions.
create function public._ludo_pieces(p_state jsonb, p_color text)
returns int[]
language sql
immutable
as $$
  select coalesce(array_agg(p::int order by i), '{}')
  from jsonb_array_elements_text(p_state -> 'tokens' -> p_color) with ordinality as t(p, i);
$$;

-- The pieces the player on turn can move with p_dice (0-based).
create function public._ludo_movable(p_state jsonb, p_dice int)
returns int[]
language sql
immutable
as $$
  select coalesce(array_agg(i - 1 order by i), '{}')
  from unnest(public._ludo_pieces(p_state, p_state ->> 'turn')) with ordinality as t(p, i)
  where public._ludo_can_move(coalesce(p_state ->> 'board', 'classic'), p, p_dice);
$$;

-- The row as the apps read it.
create function public._ludo_row(p_match_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select to_jsonb(m) from public.ludo_matches m where id = p_match_id;
$$;

revoke all on function public._ludo_row(uuid) from public, anon, authenticated;

-- ── rolling ───────────────────────────────────────────────────────────────

-- Rolls the die for the player on turn. A third six in a row is void and
-- the turn passes; so does a roll no piece can use (everyone sees what came
-- up first). Returns the match row.
create function public.roll_ludo_dice(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_color text;
  v_state jsonb;
  v_dice int := 1 + floor(random() * 6)::int;
  v_streak int;
  v_pass boolean;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;
  if v_match is null then raise exception 'match not found'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  v_color := v_match.colors[array_position(v_match.players, v_me)];
  v_state := v_match.state;
  if v_state ->> 'turn' <> v_color or public._ludo_out(v_state) ? v_color then
    raise exception 'not your turn';
  end if;
  if coalesce((v_state ->> 'has_rolled')::boolean, false) then
    raise exception 'already rolled';
  end if;

  v_streak := case when v_dice = 6
    then coalesce((v_state ->> 'consecutive_sixes')::int, 0) + 1 else 0 end;
  v_state := v_state || jsonb_build_object(
    'roll_seq', coalesce((v_state ->> 'roll_seq')::int, 0) + 1,
    'last_roll', jsonb_build_object('color', v_color, 'value', v_dice)
  );
  v_pass := (v_dice = 6 and v_streak >= 3)
            or cardinality(public._ludo_movable(v_state, v_dice)) = 0;

  if v_pass then
    v_state := v_state || jsonb_build_object(
      'turn', public._ludo_next_color(v_match.colors, public._ludo_out(v_state), v_color),
      'dice_value', null, 'has_rolled', false, 'consecutive_sixes', 0);
    update public.ludo_matches
      set state = v_state, turn_count = turn_count + 1, updated_at = now(),
          missed_turns = missed_turns - v_color
      where id = p_match_id;
  else
    v_state := v_state || jsonb_build_object(
      'dice_value', v_dice, 'has_rolled', true, 'consecutive_sixes', v_streak);
    update public.ludo_matches
      set state = v_state, updated_at = now(), missed_turns = missed_turns - v_color
      where id = p_match_id;
  end if;
  return public._ludo_row(p_match_id);
end;
$$;

-- ── moving ────────────────────────────────────────────────────────────────

-- Moves piece p_token (0-3) by the die just rolled: out of the yard on a
-- six, round the ring, up the home stretch. Landing on others (off the safe
-- squares) sends them home. A six, a capture or a piece home earns another
-- go. All four home takes the next place; the first home takes the pot.
-- Returns the match row.
create function public.move_ludo_token(p_match_id uuid, p_token int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_color text;
  v_state jsonb;
  v_board text;
  v_ring int;
  v_finish int;
  v_dice int;
  v_mine int[];
  v_from int;
  v_to int;
  v_tokens jsonb;
  v_square int;
  v_other text;
  v_theirs int[];
  v_victims jsonb := '[]'::jsonb;
  v_won boolean;
  v_extra boolean;
  v_finished jsonb;
  v_out jsonb;
  v_over boolean;
  v_first text;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;
  if v_match is null then raise exception 'match not found'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  v_color := v_match.colors[array_position(v_match.players, v_me)];
  v_state := v_match.state;
  if v_state ->> 'turn' <> v_color then raise exception 'not your turn'; end if;
  v_dice := (v_state ->> 'dice_value')::int;
  if not coalesce((v_state ->> 'has_rolled')::boolean, false) or v_dice is null then
    raise exception 'roll first';
  end if;
  if p_token is null or p_token not between 0 and 3 then raise exception 'no such piece'; end if;

  v_board := coalesce(v_state ->> 'board', 'classic');
  v_ring := public._ludo_ring(v_board);
  v_finish := v_ring + 4;
  v_mine := public._ludo_pieces(v_state, v_color);
  v_from := v_mine[p_token + 1];
  if not public._ludo_can_move(v_board, v_from, v_dice) then
    raise exception 'that piece can''t move';
  end if;

  -- Out of the yard lands on the start square; anything else moves on.
  v_to := case when v_from = -1 then 0 else v_from + v_dice end;
  v_mine[p_token + 1] := v_to;
  v_tokens := jsonb_set(v_state -> 'tokens', array[v_color], to_jsonb(v_mine));

  -- Captures: on the shared ring, off the safe squares, anyone still in.
  if v_to between 0 and v_ring - 2 then
    v_square := public._ludo_abs(v_board, v_color, v_to);
    if v_square % 13 not in (0, 8) then
      for v_other in select jsonb_array_elements_text(v_state -> 'players') loop
        continue when v_other = v_color
          or coalesce(v_state -> 'left', '[]'::jsonb) ? v_other;
        v_theirs := public._ludo_pieces(v_state, v_other);
        for i in 1..cardinality(v_theirs) loop
          if v_theirs[i] between 0 and v_ring - 2
             and public._ludo_abs(v_board, v_other, v_theirs[i]) = v_square then
            v_theirs[i] := -1;
            v_victims := v_victims || jsonb_build_array(
              jsonb_build_object('color', v_other, 'token', i - 1));
          end if;
        end loop;
        v_tokens := jsonb_set(v_tokens, array[v_other], to_jsonb(v_theirs));
      end loop;
    end if;
  end if;

  v_won := not exists (select 1 from unnest(v_mine) as p where p < v_finish);
  v_extra := not v_won
    and (v_dice = 6 or jsonb_array_length(v_victims) > 0 or v_to >= v_finish);
  v_finished := coalesce(v_state -> 'finished', '[]'::jsonb);
  if v_won and not v_finished ? v_color then
    v_finished := v_finished || to_jsonb(v_color);
  end if;

  v_state := v_state || jsonb_build_object('tokens', v_tokens, 'finished', v_finished);
  if v_won and v_state ->> 'winner' is null then
    v_state := v_state || jsonb_build_object('winner', v_color);
  end if;
  v_out := public._ludo_out(v_state);
  v_over := v_won and cardinality(public._ludo_racing(v_match.colors, v_out)) <= 1;

  v_state := v_state || jsonb_build_object(
    'turn', case when v_extra or v_over then v_color
                 else public._ludo_next_color(v_match.colors, v_out, v_color) end,
    'dice_value', null,
    'has_rolled', false,
    'consecutive_sixes', case when v_extra and v_dice = 6
      then coalesce((v_state ->> 'consecutive_sixes')::int, 0) else 0 end,
    'capture', case when jsonb_array_length(v_victims) > 0
      then jsonb_build_object(
        'seq', coalesce((v_state -> 'capture' ->> 'seq')::int, 0) + 1,
        'by', v_color, 'token', p_token, 'victims', v_victims)
      else v_state -> 'capture' end
  );

  insert into public.ludo_moves (
    match_id, turn_number, player_id, dice_value, token_index, captured, reached_home, state_after
  ) values (
    p_match_id, v_match.turn_count + 1, v_me, v_dice, p_token,
    jsonb_array_length(v_victims) > 0, v_to >= v_finish, v_state
  );
  update public.ludo_matches
    set state = v_state, turn_count = turn_count + 1, updated_at = now(),
        missed_turns = missed_turns - v_color
    where id = p_match_id;

  -- Home with all four: the first home takes the pot (straight away), and
  -- the game ends once no more than one is left racing.
  if v_won then
    v_first := v_finished ->> 0;
    perform public._settle_ludo(
      p_match_id, v_match.players[array_position(v_match.colors, v_first)], 'win');
  end if;
  return public._ludo_row(p_match_id);
end;
$$;

revoke all on function public.roll_ludo_dice(uuid) from public, anon;
revoke all on function public.move_ludo_token(uuid, int) from public, anon;
grant execute on function public.roll_ludo_dice(uuid) to authenticated;
grant execute on function public.move_ludo_token(uuid, int) to authenticated;

-- ── what the apps used to send ────────────────────────────────────────────

-- Boards sent by an app aren't taken any more.
create or replace function public.record_ludo_roll(p_match_id uuid, p_state jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'update Utopia to keep playing';
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
begin
  raise exception 'update Utopia to keep playing';
end;
$$;

-- Nor results reported by the apps: the server settles when someone gets
-- home (two players agreeing on a winner could otherwise take a third's
-- entry).
create or replace function public.report_ludo_match_result(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  return;
end;
$$;
