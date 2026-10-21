-- Voice notes in Guess My Doodle's chat, as in the other games' chat: a
-- recording in the voice-notes bucket under the game's folder, and a chat
-- line of kind 'voice' whose body is "voice:<game>/<note>.(m4a|wav)|<ms>|
-- <waveform>".
--
-- Talk can't be checked for the word the way typed guesses are, so while
-- someone draws only those who know the word may talk: the drawer and the
-- players who've guessed it, heard only by each other (the same rule as
-- their typed chat). Between turns, in the lobby and once the game's over,
-- everyone talks to everyone.

alter table public.doodle_messages
  drop constraint doodle_messages_kind_check,
  add constraint doodle_messages_kind_check
    check (kind in ('chat', 'guessed', 'close', 'reveal', 'joined', 'left', 'drawing', 'voice'));

-- A game's players can upload and listen to its voice notes.
create or replace function public._is_ludo_voice_folder(p_folder text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_folder is null or p_folder !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return public._is_ludo_player(p_folder::uuid)
      or public._is_chess_player(p_folder::uuid)
      or public._is_eights_player(p_folder::uuid)
      or public._doodle_member(p_folder::uuid);
end;
$$;

create function public.send_doodle_voice(p_game uuid, p_body text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
  v_audience text := 'all';
  v_recent int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into g from public.doodle_games where id = p_game;
  if g is null then raise exception 'game not found'; end if;
  if not exists (
    select 1 from public.doodle_players where game_id = p_game and user_id = v_me and left_at is null
  ) then
    raise exception 'not in this game';
  end if;
  if p_body !~ (
    '^voice:' || p_game::text || '/[0-9a-f-]{36}\.(m4a|wav)\|[0-9]{1,6}\|[0-9]{0,40}$'
  ) then
    raise exception 'invalid voice note';
  end if;

  select count(*) into v_recent from public.doodle_messages
    where game_id = p_game and sender_id = v_me and kind = 'voice'
      and created_at > now() - interval '10 seconds';
  if v_recent >= 3 then raise exception 'slow down'; end if;

  if g.status in ('choosing', 'drawing') then
    if g.drawer_id = v_me
      or exists (
        select 1 from public.doodle_players
          where game_id = p_game and user_id = v_me and guessed_turn = g.turn
      ) then
      v_audience := 'guessed';
    else
      raise exception 'guess the word first';
    end if;
  end if;

  insert into public.doodle_messages (game_id, sender_id, turn, drawer_id, kind, body, audience)
    values (p_game, v_me, g.turn, g.drawer_id, 'voice', p_body, v_audience);
end;
$$;

revoke all on function public.send_doodle_voice(uuid, text) from public, anon;
grant execute on function public.send_doodle_voice(uuid, text) to authenticated;
