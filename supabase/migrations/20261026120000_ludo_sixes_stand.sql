-- Sixes always stand. Until now a third six in a row was void and the turn
-- passed; now every six is played like any other roll and earns another roll
-- after the move, however many come in a row (the apps' engine agrees:
-- LudoEngine.registerRoll). Only a roll no piece can use passes the turn.

create or replace function public._ludo_roll(p_match_id uuid, p_user uuid)
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

  -- Still counted (it's part of the state the apps read), but it no longer voids anything.
  v_streak := case when v_dice = 6
    then coalesce((v_state ->> 'consecutive_sixes')::int, 0) + 1 else 0 end;
  v_state := v_state || jsonb_build_object(
    'roll_seq', coalesce((v_state ->> 'roll_seq')::int, 0) + 1,
    'last_roll', jsonb_build_object('color', v_color, 'value', v_dice)
  );
  v_pass := cardinality(public._ludo_movable(v_state, v_dice)) = 0;

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
