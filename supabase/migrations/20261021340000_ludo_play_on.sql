-- Ludo: with three or more at the table, the game goes on after the first
-- player gets all four pieces home. They take the pot straight away and
-- can watch or go; the others race on for the places after them, and the
-- game ends once at most one is left racing.
--
-- The state's `finished` holds the colors home with all four, first place
-- first (see LudoState.finished). Also here: a piece sent home can react
-- to it ("sad" or "again"), so those are allowed as chat reactions.

-- Colors that no longer take turns: gone, or home with all four. (The
-- winner too, for a game saved before `finished` existed.)
create function public._ludo_out(p_state jsonb)
returns jsonb
language sql
immutable
as $$
  select coalesce(p_state -> 'left', '[]'::jsonb)
      || coalesce(p_state -> 'finished', '[]'::jsonb)
      || case when p_state ->> 'winner' is null then '[]'::jsonb
              else jsonb_build_array(p_state ->> 'winner') end;
$$;

-- The colors still racing, in seat order.
create function public._ludo_racing(p_colors text[], p_out jsonb)
returns text[]
language sql
immutable
as $$
  select coalesce(array_agg(c order by ord), '{}')
  from unnest(p_colors) with ordinality as t(c, ord)
  where not coalesce(p_out, '[]'::jsonb) ? c;
$$;

-- Pays the pot once, to the first home (or refunds everyone when there's
-- no winner), and ends the game once no more than one player is left
-- racing. Called again later in the same game it only ends it.
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
  v_out jsonb;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;
  if v_match.status <> 'active' then
    return; -- already settled/aborted; idempotent no-op
  end if;

  if v_match.winner_id is null then
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
      set winner_id = p_winner_id, result = p_result, updated_at = now()
      where id = p_match_id;
  end if;

  v_out := public._ludo_out(v_match.state);
  if p_winner_id is not null then
    v_out := v_out || to_jsonb(v_match.colors[array_position(v_match.players, p_winner_id)]);
  end if;
  if p_winner_id is null
     or cardinality(public._ludo_racing(v_match.colors, v_out)) <= 1 then
    update public.ludo_matches
      set status = 'completed', ended_at = now(), updated_at = now()
      where id = p_match_id;
  end if;
end;
$$;

revoke all on function public._settle_ludo(uuid, uuid, text) from public, anon, authenticated;

-- A player leaving (or timed out). Someone who's finished just goes: their
-- place and their prize stand. Anyone else is out, their pieces off the
-- board; once no more than one is left racing the game ends, and the pot
-- goes to the first home (or, if no one got home, the last one standing).
create or replace function public._ludo_remove_player(p_match_id uuid, p_user uuid, p_result text)
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
  v_racing text[];
  v_winner text;
begin
  select * into v_match from public.ludo_matches where id = p_match_id for update;
  if v_match is null or v_match.status <> 'active' then return; end if;

  v_color := v_match.colors[array_position(v_match.players, p_user)];
  if v_color is null then raise exception 'not a player in this match'; end if;

  v_state := v_match.state;
  if coalesce(v_state -> 'finished', '[]'::jsonb) ? v_color then return; end if;

  v_left := coalesce(v_state -> 'left', '[]'::jsonb);
  if not v_left ? v_color then
    v_left := v_left || to_jsonb(v_color);
  end if;
  v_state := jsonb_set(v_state, '{left}', v_left);
  v_state := jsonb_set(v_state, array['tokens', v_color], '[-1,-1,-1,-1]'::jsonb);

  v_racing := public._ludo_racing(v_match.colors, public._ludo_out(v_state));

  if cardinality(v_racing) <= 1 then
    update public.ludo_matches set state = v_state where id = p_match_id;
    v_winner := coalesce(v_state -> 'finished' ->> 0, v_state ->> 'winner', v_racing[1]);
    perform public._settle_ludo(
      p_match_id,
      v_match.players[array_position(v_match.colors, v_winner)],
      p_result
    );
    return;
  end if;

  if v_state ->> 'turn' = v_color then
    v_state := v_state || jsonb_build_object(
      'turn', public._ludo_next_color(v_match.colors, public._ludo_out(v_state), v_color),
      'dice_value', null, 'has_rolled', false, 'consecutive_sixes', 0
    );
  end if;

  update public.ludo_matches set state = v_state, updated_at = now() where id = p_match_id;
end;
$$;

revoke all on function public._ludo_remove_player(uuid, uuid, text) from public, anon, authenticated;

-- Moves as before; and when everyone but one is home (or gone) after the
-- pot's been paid, that's the end of the game.
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

  if v_match.winner_id is not null
     and cardinality(public._ludo_racing(v_match.colors, public._ludo_out(p_state_after))) <= 1 then
    update public.ludo_matches
      set status = 'completed', ended_at = now()
      where id = p_match_id;
  end if;
end;
$$;

-- The turn timer: as before, but it never waits on someone who's finished,
-- and passes the turn only among those still racing.
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
  v_out jsonb;
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
    'turn', public._ludo_next_color(v_match.colors, v_out, v_color),
    'dice_value', null,
    'has_rolled', false,
    'consecutive_sixes', 0
  );

  update public.ludo_matches set state = v_state, updated_at = now() where id = p_match_id;
  return true;
end;
$$;

-- Games gone quiet: whoever's on the clock is out. One that's over but
-- never got settled (everyone closed the app) is settled now.
create or replace function public.forfeit_abandoned_ludo_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match record;
  v_idle uuid;
  v_first text;
begin
  for v_match in
    select * from public.ludo_matches
      where status = 'active' and updated_at < now() - interval '15 minutes'
  loop
    v_first := coalesce(v_match.state -> 'finished' ->> 0, v_match.state ->> 'winner');
    if v_first is not null
       and cardinality(public._ludo_racing(v_match.colors, public._ludo_out(v_match.state))) <= 1 then
      perform public._settle_ludo(
        v_match.id, v_match.players[array_position(v_match.colors, v_first)], 'win');
      continue;
    end if;
    -- Whoever is on the clock is the one who went quiet.
    v_idle := v_match.players[array_position(v_match.colors, v_match.state ->> 'turn')];
    if v_idle is not null then
      perform public._ludo_remove_player(v_match.id, v_idle, 'timeout');
    end if;
  end loop;
end;
$$;

revoke all on function public.forfeit_abandoned_ludo_matches() from public, anon, authenticated;

-- Chat: a piece sent home can react too ("sad", or "again": not giving up).
CREATE OR REPLACE FUNCTION public.send_ludo_chat(p_match_id uuid, p_kind text, p_body text)
 RETURNS ludo_chat_messages
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  if p_kind not in ('text', 'quick', 'emote', 'reaction', 'voice') then raise exception 'invalid message kind'; end if;
  if v_body is null or char_length(v_body) = 0 then raise exception 'empty message'; end if;
  if char_length(v_body) > 200 then raise exception 'message too long'; end if;
  if p_kind = 'reaction' and v_body not in ('war', 'peace', 'sad', 'again') then
    raise exception 'invalid reaction';
  end if;
  if p_kind = 'voice' and v_body !~ (
    '^voice:' || p_match_id::text || '/[0-9a-f-]{36}\.(m4a|wav)\|[0-9]{1,6}\|[0-9]{0,40}$'
  ) then
    raise exception 'invalid voice note';
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
$function$
;

-- Events and quests: a Ludo game counts once it's over, or as soon as
-- you've finished (you may not stay to watch the rest).
create or replace function public.event_count_game(p_game text, p_match uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_event public.events;
  v_new text[] := '{}';
  v_ok boolean;
  v_offline boolean := p_match is null;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_game not in ('chess', 'checkers', 'ludo', 'doodle') then
    raise exception 'unknown game';
  end if;
  perform public._ensure_weekly();

  if not v_offline then
    v_ok := case p_game
      when 'ludo' then exists (
        select 1 from public.ludo_matches
        where id = p_match and v_me = any (players)
          and (status = 'completed'
               or coalesce(state -> 'finished', '[]'::jsonb)
                    ? colors[array_position(players, v_me)]))
      when 'doodle' then exists (
        select 1 from public.doodle_games g
        join public.doodle_players p on p.game_id = g.id
        where g.id = p_match and g.status in ('over', 'closed')
          and p.user_id = v_me and p.left_at is null)
      else exists (
        select 1 from public.matches
        where id = p_match and status = 'completed'
          and v_me in (player_white, player_black))
    end;
    if not v_ok then raise exception 'not a finished game of yours'; end if;
    insert into public.event_counted (user_id, match_id) values (v_me, p_match)
      on conflict do nothing;
    if not found then return public._event_state(v_me, v_new, false); end if;
  elsif exists (
    select 1 from public.event_progress p
    join public.events e on e.id = p.event_id
    where p.user_id = v_me and now() between e.starts_at and e.ends_at
      and (p.last_offline_at > now() - interval '1 minute'
           or (p.offline_day = v_today and p.offline_today >= 10))
  ) then
    return public._event_state(v_me, v_new, false);
  end if;

  for v_event in
    select * from public.events where now() between starts_at and ends_at
  loop
    insert into public.event_progress (
      user_id, event_id, games, days, last_day, offline_day, offline_today, last_offline_at
    )
    values (
      v_me, v_event.id, 1, 1, v_today,
      case when v_offline then v_today end,
      case when v_offline then 1 else 0 end,
      case when v_offline then now() end
    )
    on conflict (user_id, event_id) do update set
      games = event_progress.games + 1,
      days = event_progress.days
        + case when event_progress.last_day is distinct from v_today then 1 else 0 end,
      last_day = v_today,
      offline_today = case
        when not v_offline then event_progress.offline_today
        when event_progress.offline_day is distinct from v_today then 1
        else event_progress.offline_today + 1 end,
      offline_day = case when v_offline then v_today else event_progress.offline_day end,
      last_offline_at = case when v_offline then now() else event_progress.last_offline_at end;
    v_new := v_new || public._event_award(v_me, v_event);
  end loop;
  return public._event_state(v_me, v_new, true);
end;
$$;
revoke all on function public.event_count_game(text, uuid) from public;
grant execute on function public.event_count_game(text, uuid) to authenticated;
