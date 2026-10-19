-- Voice notes recorded in a browser are WAV (.wav), the apps' AAC (.m4a):
-- the chats take a voice message of either. They only took .m4a, so every
-- voice note sent from the web was uploaded and then turned away.
-- (The functions as they are live, with only that pattern changed.)

CREATE OR REPLACE FUNCTION public.send_chess_chat(p_match_id uuid, p_kind text, p_body text)
 RETURNS chess_chat_messages
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me uuid := auth.uid();
  v_match public.matches;
  v_body text := btrim(p_body);
  v_recent int;
  v_row public.chess_chat_messages;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_match from public.matches where id = p_match_id;
  if v_match is null then raise exception 'match not found'; end if;
  if v_me is distinct from v_match.player_white and v_me is distinct from v_match.player_black then
    raise exception 'not a player in this match';
  end if;
  if p_kind not in ('text', 'quick', 'emote', 'voice') then raise exception 'invalid message kind'; end if;
  if v_body is null or char_length(v_body) = 0 then raise exception 'empty message'; end if;
  if char_length(v_body) > 200 then raise exception 'message too long'; end if;
  if p_kind = 'voice' and v_body !~ (
    '^voice:' || p_match_id::text || '/[0-9a-f-]{36}\.(m4a|wav)\|[0-9]{1,6}\|[0-9]{0,40}$'
  ) then
    raise exception 'invalid voice note';
  end if;

  select count(*) into v_recent from public.chess_chat_messages
    where match_id = p_match_id and sender_id = v_me
      and created_at > now() - interval '10 seconds';
  if v_recent >= 6 then raise exception 'slow down'; end if;

  -- Friends' games started from an invite; everything else is public.
  if p_kind in ('text', 'quick')
     and not exists (select 1 from public.match_invites where match_id = p_match_id) then
    v_body := public.mask_offensive(v_body);
  end if;

  insert into public.chess_chat_messages (match_id, sender_id, kind, body)
    values (p_match_id, v_me, p_kind, v_body)
    returning * into v_row;
  return v_row;
end;
$function$
;

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
  if p_kind = 'reaction' and v_body not in ('war', 'peace') then
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
