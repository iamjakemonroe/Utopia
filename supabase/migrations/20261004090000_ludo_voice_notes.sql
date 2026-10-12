-- Voice notes in Ludo chat.
--
--   * Recordings live in a private storage bucket, one folder per match:
--     voice-notes/<match id>/<note id>.m4a. Only players in that match can
--     upload there or listen.
--   * A voice message is a chat row of kind 'voice' whose body is
--     "voice:<path>|<length ms>|<waveform>" (waveform: up to 40 digits 0-9,
--     one per bar). send_ludo_chat checks the path belongs to this match.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voice-notes', 'voice-notes', false, 1048576, array['audio/mp4', 'audio/m4a', 'audio/aac', 'audio/x-m4a'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- True when the storage folder is a Ludo match the caller plays in.
create function public._is_ludo_voice_folder(p_folder text)
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
  return public._is_ludo_player(p_folder::uuid);
end;
$$;

revoke all on function public._is_ludo_voice_folder(text) from public;
grant execute on function public._is_ludo_voice_folder(text) to authenticated;

create policy "players can upload voice notes to their match"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'voice-notes'
    and public._is_ludo_voice_folder((storage.foldername(name))[1])
  );

create policy "players can listen to voice notes in their match"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'voice-notes'
    and public._is_ludo_voice_folder((storage.foldername(name))[1])
  );

alter table public.ludo_chat_messages
  drop constraint ludo_chat_messages_kind_check,
  add constraint ludo_chat_messages_kind_check
    check (kind in ('text', 'quick', 'emote', 'reaction', 'voice'));

create or replace function public.send_ludo_chat(p_match_id uuid, p_kind text, p_body text)
returns public.ludo_chat_messages
language plpgsql
security definer
set search_path = public
as $$
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
    '^voice:' || p_match_id::text || '/[0-9a-f-]{36}\.m4a\|[0-9]{1,6}\|[0-9]{0,40}$'
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
$$;
