-- Leaving a game by accident (the app closed, the phone rang, the tab was
-- shut) no longer costs the game. Until now, three turns run out in a row
-- in online Ludo or Crazy Eights and the player was out, and a Guess My
-- Doodle player gone 40 seconds couldn't be brought back to the room.
--
-- Now, while a player is away, the server plays their turns for them (a
-- roll and a careful move in Ludo; a card that goes, or a draw, in Crazy
-- Eights) and they stay in, however long they're gone: when they come
-- back, the game is where it is, with everything they had. Leaving on
-- purpose is still leaving. missed_turns still counts the turns played
-- for them in a row, so the others can see they're away.
--
-- my_doodle_game now finds a room the player was dropped from for going
-- quiet (not one they left), so the app takes them back to it; checking
-- in there puts them back in the game with their points (tick_doodle).

-- ── Ludo ──────────────────────────────────────────────────────────────────

-- roll_ludo_dice, for p_user (the caller, or the server for someone away).
create function public._ludo_roll(p_match_id uuid, p_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.ludo_matches;
  v_color text;
  v_state jsonb;
  v_dice int := 1 + floor(random() * 6)::int;
  v_streak int;
  v_pass boolean;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;
  if v_match is null then raise exception 'match not found'; end if;
  if not (p_user = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  v_color := v_match.colors[array_position(v_match.players, p_user)];
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

-- move_ludo_token, for p_user (the caller, or the server for someone away).
create function public._ludo_move(p_match_id uuid, p_user uuid, p_token int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
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
  if not (p_user = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  v_color := v_match.colors[array_position(v_match.players, p_user)];
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
    p_match_id, v_match.turn_count + 1, p_user, v_dice, p_token,
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

revoke all on function public._ludo_roll(uuid, uuid) from public, anon, authenticated;
revoke all on function public._ludo_move(uuid, uuid, int) from public, anon, authenticated;

create or replace function public.roll_ludo_dice(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public._ludo_roll(p_match_id, auth.uid());
end;
$$;

create or replace function public.move_ludo_token(p_match_id uuid, p_token int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public._ludo_move(p_match_id, auth.uid(), p_token);
end;
$$;

-- The move a careful player makes with p_dice, for the player on turn:
-- a capture first, then a piece home, then one out of the yard, then the
-- one furthest along. Null when nothing can move.
create function public._ludo_pick(p_state jsonb, p_dice int)
returns int
language plpgsql
immutable
as $$
declare
  v_color text := p_state ->> 'turn';
  v_board text := coalesce(p_state ->> 'board', 'classic');
  v_ring int := public._ludo_ring(v_board);
  v_mine int[] := public._ludo_pieces(p_state, v_color);
  v_best int;
  v_best_score int := -1;
  v_score int;
  v_to int;
  v_square int;
  v_other text;
begin
  for i in 1..cardinality(v_mine) loop
    continue when not public._ludo_can_move(v_board, v_mine[i], p_dice);
    v_to := case when v_mine[i] = -1 then 0 else v_mine[i] + p_dice end;
    v_score := case
      when v_to >= v_ring + 4 then 400
      when v_mine[i] = -1 then 200
      else 100 + v_mine[i] end;
    if v_to between 0 and v_ring - 2 then
      v_square := public._ludo_abs(v_board, v_color, v_to);
      if v_square % 13 not in (0, 8) then
        for v_other in select jsonb_array_elements_text(p_state -> 'players') loop
          continue when v_other = v_color
            or coalesce(p_state -> 'left', '[]'::jsonb) ? v_other;
          if exists (
            select 1 from unnest(public._ludo_pieces(p_state, v_other)) as t(p)
              where t.p between 0 and v_ring - 2
                and public._ludo_abs(v_board, v_other, t.p) = v_square
          ) then
            v_score := v_score + 500;
          end if;
        end loop;
      end if;
    end if;
    if v_score > v_best_score then
      v_best := i - 1;
      v_best_score := v_score;
    end if;
  end loop;
  return v_best;
end;
$$;

-- The turn timer. The player on turn ran out of time: their turn is played
-- for them (the roll, if they hadn't, and a careful move), and they stay
-- in the game however many go by. A turn stuck on someone who's finished
-- just passes.
create or replace function public.skip_ludo_turn(p_match_id uuid, p_turn_count int, p_roll_seq int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.ludo_matches;
  v_color text;
  v_user uuid;
  v_missed int;
  v_state jsonb;
  v_turn interval;
  v_out jsonb;
  v_pick int;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;

  if v_match is null then raise exception 'match not found'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then return true; end if;
  if v_match.turn_count <> p_turn_count
     or coalesce((v_match.state ->> 'roll_seq')::int, 0) <> p_roll_seq then
    return true;
  end if;
  v_out := public._ludo_out(v_match.state);
  if cardinality(public._ludo_racing(v_match.colors, v_out)) <= 1 then return true; end if;
  -- Friends get longer to think than strangers.
  v_turn := case when v_match.mode = 'friends' then interval '40 seconds'
                 else interval '15 seconds' end;
  if v_match.updated_at > now() - v_turn then
    return false;
  end if;

  v_color := v_match.state ->> 'turn';

  -- The turn is stuck on someone who's finished: pass it on, no one missed it.
  if v_out ? v_color then
    v_state := v_match.state || jsonb_build_object(
      'turn', public._ludo_next_color(v_match.colors, v_out, v_color),
      'dice_value', null, 'has_rolled', false, 'consecutive_sixes', 0
    );
    update public.ludo_matches
      set state = v_state, turn_count = turn_count + 1, updated_at = now()
      where id = p_match_id;
    return true;
  end if;

  v_missed := coalesce((v_match.missed_turns ->> v_color)::int, 0) + 1;
  v_user := v_match.players[array_position(v_match.colors, v_color)];

  if not coalesce((v_match.state ->> 'has_rolled')::boolean, false) then
    perform public._ludo_roll(p_match_id, v_user);
    select * into v_match from public.ludo_matches where id = p_match_id;
  end if;
  if v_match.status = 'active' and v_match.state ->> 'turn' = v_color
     and coalesce((v_match.state ->> 'has_rolled')::boolean, false) then
    v_pick := public._ludo_pick(v_match.state, (v_match.state ->> 'dice_value')::int);
    if v_pick is not null then
      perform public._ludo_move(p_match_id, v_user, v_pick);
    end if;
  end if;

  -- Playing it cleared their count (as their own move would): put it back.
  update public.ludo_matches
    set missed_turns = missed_turns || jsonb_build_object(v_color, v_missed)
    where id = p_match_id;
  return true;
end;
$$;

-- ── Crazy Eights ──────────────────────────────────────────────────────────

-- play_eights_card, for p_user (the caller, or the server for someone
-- away). Returns their hand afterwards.
create function public._eights_play(p_match_id uuid, p_user uuid, p_card text, p_suit text)
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.eights_matches;
  v_seat int;
  v_state jsonb;
  v_hand text[];
  v_top text;
  v_eight boolean := left(p_card, 1) = '8';
  v_out boolean;
begin
  select * into v_match from public.eights_matches where id = p_match_id for update;
  if v_match.id is null then raise exception 'match not found'; end if;
  if not (p_user = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then raise exception 'match is not active'; end if;
  v_seat := array_position(v_match.players, p_user) - 1;
  if (v_match.state ->> 'turn')::int <> v_seat then raise exception 'not your turn'; end if;
  v_state := v_match.state;

  select cards into v_hand from public.eights_hands
    where match_id = p_match_id and user_id = p_user for update;
  if not (p_card = any (v_hand)) then raise exception 'not in your hand'; end if;

  v_top := v_state ->> 'top';
  if not v_eight and right(p_card, 1) <> v_state ->> 'suit'
     and left(p_card, 1) <> left(v_top, 1) then
    raise exception 'that card doesn''t go';
  end if;
  if v_eight and (p_suit is null or p_suit not in ('S', 'H', 'D', 'C')) then
    raise exception 'name a suit for the eight';
  end if;

  v_hand := array_remove(v_hand, p_card);
  v_out := cardinality(v_hand) = 0;
  update public.eights_hands set cards = v_hand where match_id = p_match_id and user_id = p_user;
  update public.eights_decks set discard = discard || v_top where match_id = p_match_id;

  v_state := public._eights_count(v_state, v_seat, cardinality(v_hand)) || jsonb_build_object(
    'top', p_card,
    'suit', case when v_eight then p_suit else right(p_card, 1) end,
    'turn', case when v_out then v_seat
                 else public._eights_next_seat(cardinality(v_match.players), v_state -> 'left', v_seat) end,
    'drawn', false,
    'seq', coalesce((v_state ->> 'seq')::int, 0) + 1,
    'last', jsonb_build_object('seat', v_seat, 'kind', 'play', 'card', p_card,
                               'suit', case when v_eight then p_suit end),
    'winner', case when v_out then v_seat end
  );
  update public.eights_matches
    set state = v_state, turn_count = turn_count + 1, updated_at = now(),
        missed_turns = missed_turns - v_seat::text
    where id = p_match_id;

  if v_out then perform public._settle_eights(p_match_id, p_user, 'win'); end if;
  return v_hand;
end;
$$;

revoke all on function public._eights_play(uuid, uuid, text, text) from public, anon, authenticated;

create or replace function public.play_eights_card(p_match_id uuid, p_card text, p_suit text default null)
returns text[]
language plpgsql
security definer
set search_path = public
as $$
begin
  return public._eights_play(p_match_id, auth.uid(), p_card, p_suit);
end;
$$;

-- The card a careful player plays from p_hand on p_top (p_suit to follow):
-- one that goes without an eight, of the suit they hold most of; an eight
-- only when nothing else goes, naming that suit. Null when nothing goes.
create function public._eights_pick(p_hand text[], p_top text, p_suit text)
returns table (card text, suit text)
language sql
immutable
as $$
  with held as (
    select c, right(c, 1) as s, left(c, 1) as r from unnest(p_hand) as c
  ),
  most as (
    select s from held where r <> '8'
      group by s order by count(*) desc, s limit 1
  )
  select h.c,
         case when h.r = '8'
           then coalesce((select s from most), right(h.c, 1)) end
  from held h
  where h.r = '8' or h.s = p_suit or h.r = left(p_top, 1)
  order by (h.r = '8'),
           (select count(*) from held x where x.s = h.s) desc,
           h.c
  limit 1;
$$;

-- The player on turn ran out of time (20 seconds a go; 40 among friends):
-- their turn is played for them (a card that goes; if none, a draw, and the
-- drawn card if it goes), and they stay in the game however many go by.
-- Anyone at the table can call it; p_seq names the action that timed out,
-- so a late call can't skip the next one.
create or replace function public.skip_eights_turn(p_match_id uuid, p_seq int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.eights_matches;
  v_state jsonb;
  v_seat int;
  v_user uuid;
  v_missed int;
  v_card text;
  v_hand text[];
  v_turn interval;
  v_play text;
  v_suit text;
begin
  select * into v_match from public.eights_matches where id = p_match_id for update;
  if v_match is null then raise exception 'match not found'; end if;
  if not (auth.uid() = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then return true; end if;
  v_state := v_match.state;
  if coalesce((v_state ->> 'seq')::int, 0) <> p_seq then return true; end if;
  v_turn := case when v_match.mode = 'friends' then interval '40 seconds'
                 else interval '20 seconds' end;
  if v_match.updated_at > now() - v_turn then return false; end if;

  v_seat := (v_state ->> 'turn')::int;
  v_user := v_match.players[v_seat + 1];
  v_missed := coalesce((v_match.missed_turns ->> v_seat::text)::int, 0) + 1;

  select cards into v_hand from public.eights_hands
    where match_id = p_match_id and user_id = v_user;
  select p.card, p.suit into v_play, v_suit
    from public._eights_pick(v_hand, v_state ->> 'top', v_state ->> 'suit') as p;

  -- Nothing goes: draw one (if they hadn't), and play it if it goes (it's
  -- the only one that can).
  if v_play is null and not coalesce((v_state ->> 'drawn')::boolean, false) then
    v_card := public._eights_take_card(p_match_id);
    if v_card is not null then
      update public.eights_hands set cards = cards || v_card
        where match_id = p_match_id and user_id = v_user
        returning cards into v_hand;
      v_state := public._eights_count(v_state, v_seat, cardinality(v_hand));
      select p.card, p.suit into v_play, v_suit
        from public._eights_pick(v_hand, v_state ->> 'top', v_state ->> 'suit') as p;
      if v_play is not null then
        update public.eights_matches
          set state = v_state || jsonb_build_object(
                'draw', public._eights_draw_count(p_match_id),
                'drawn', true,
                'seq', coalesce((v_state ->> 'seq')::int, 0) + 1)
          where id = p_match_id;
      end if;
    end if;
  end if;

  if v_play is not null then
    perform public._eights_play(p_match_id, v_user, v_play, v_suit);
  else
    v_state := v_state || jsonb_build_object(
      'turn', public._eights_next_seat(cardinality(v_match.players), v_state -> 'left', v_seat),
      'drawn', false,
      'draw', public._eights_draw_count(p_match_id),
      'seq', coalesce((v_state ->> 'seq')::int, 0) + 1,
      'last', jsonb_build_object('seat', v_seat, 'kind', 'timeout', 'card', null, 'suit', null));
    update public.eights_matches
      set state = v_state, turn_count = turn_count + 1, updated_at = now()
      where id = p_match_id;
  end if;

  -- Playing it cleared their count (as their own play would): put it back.
  update public.eights_matches
    set missed_turns = missed_turns || jsonb_build_object(v_seat::text, v_missed)
    where id = p_match_id;
  return true;
end;
$$;

-- ── Guess My Doodle ───────────────────────────────────────────────────────

-- The game the player is in right now, if any, to get back to it after the
-- app closes: one they're still in, or else one still going that they were
-- dropped from for going quiet (tick_doodle lets them back in, points and
-- all). Never one they left.
create or replace function public.my_doodle_game()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.game_id from public.doodle_players p
    join public.doodle_games g on g.id = p.game_id
    where p.user_id = auth.uid() and g.status <> 'closed'
      and (p.left_at is null
           or (not p.left_by_self
               and g.status in ('lobby', 'choosing', 'drawing', 'reveal')
               and p.left_at > now() - interval '30 minutes'
               and public._doodle_active(g.id) < g.max_players))
    order by (p.left_at is null) desc, coalesce(p.left_at, p.joined_at) desc
    limit 1;
$$;
