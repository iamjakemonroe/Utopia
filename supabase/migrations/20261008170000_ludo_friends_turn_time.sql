-- Longer turns among friends.
--
-- In a room of friends each action (a roll, then picking a piece) now has 30
-- seconds; public games keep 15. The app shows the matching countdown.

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
  v_missed int;
  v_state jsonb;
  v_turn interval;
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
  -- Friends get longer to think than strangers.
  v_turn := case when v_match.mode = 'friends' then interval '30 seconds'
                 else interval '15 seconds' end;
  if v_match.updated_at > now() - v_turn then
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

