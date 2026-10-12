-- Chat in chess games, the same as Ludo's: typed messages, quick phrases,
-- stickers and voice notes.
--
--   * chess_chat_messages mirrors ludo_chat_messages. Only the two players
--     can read a game's chat, and send_chess_chat is the only way in.
--   * Games against a random opponent are kept friendly (offensive words
--     are masked); games between friends (started from an invite) aren't.
--   * Voice notes share the voice-notes bucket. The folder is the match id,
--     and a chess match id now counts as well as a Ludo one.

create function public._is_chess_player(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.matches
    where id = p_match_id and auth.uid() in (player_white, player_black)
  );
$$;

revoke all on function public._is_chess_player(uuid) from public;
grant execute on function public._is_chess_player(uuid) to authenticated;

create table public.chess_chat_messages (
  id         bigint generated always as identity primary key,
  match_id   uuid not null references public.matches (id) on delete cascade,
  sender_id  uuid not null references public.profiles (id) on delete cascade,
  kind       text not null default 'text' check (kind in ('text', 'quick', 'emote', 'voice')),
  body       text not null check (char_length(body) between 1 and 200),
  created_at timestamptz not null default now()
);

create index chess_chat_messages_match_idx on public.chess_chat_messages (match_id, id);

alter table public.chess_chat_messages enable row level security;
revoke insert, update, delete on public.chess_chat_messages from authenticated, anon;

create policy "select chat of own chess matches" on public.chess_chat_messages
  for select using (public._is_chess_player(match_id));

create function public.send_chess_chat(p_match_id uuid, p_kind text, p_body text)
returns public.chess_chat_messages
language plpgsql
security definer
set search_path = public
as $$
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
    '^voice:' || p_match_id::text || '/[0-9a-f-]{36}\.m4a\|[0-9]{1,6}\|[0-9]{0,40}$'
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
$$;

revoke all on function public.send_chess_chat(uuid, text, text) from public;
grant execute on function public.send_chess_chat(uuid, text, text) to authenticated;

-- Voice notes: a chess game's players can use its folder too.
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
  return public._is_ludo_player(p_folder::uuid) or public._is_chess_player(p_folder::uuid);
end;
$$;

-- A table left off this publication silently never syncs to clients.
alter publication supabase_realtime add table public.chess_chat_messages;
