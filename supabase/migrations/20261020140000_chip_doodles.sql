-- Chip draws, you guess: Guess My Doodle on your own. Chip draws a word,
-- stroke by stroke, and the player races to guess it.
--
--   * chip_doodles: Chip's drawing of each word, drawn once (by Claude, in
--     the chip function) and shared by every player. Clients never read it:
--     the function hands over one doodle a round.
--   * chip_doodle_seen: the doodles each player has had, so they get ones
--     they haven't seen until they've seen them all.
--   * A word without a doodle is drawn when a player needs one (or, as
--     people play, in the background, until every word has one). Drawing
--     counts against Chip's daily allowance: chip_take('doodle'), 6 a
--     player (12 for Maestro members) and 300 for everyone.

create table public.chip_doodles (
  word       text primary key references public.doodle_words (word) on delete cascade,
  status     text not null default 'drawing'
             check (status in ('drawing', 'ready', 'failed', 'refused')),
  -- SVG path data, in drawing order, on a 1000 x 1000 canvas.
  strokes    text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.chip_doodles is 'Chip''s doodle of each Guess My Doodle word, shared by every player. Service role only: rounds come from the chip function.';

alter table public.chip_doodles enable row level security;
revoke all on public.chip_doodles from anon, authenticated;

create table public.chip_doodle_seen (
  user_id uuid not null references public.profiles (id) on delete cascade,
  word    text not null references public.chip_doodles (word) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (user_id, word)
);

alter table public.chip_doodle_seen enable row level security;
revoke all on public.chip_doodle_seen from anon, authenticated;

alter table public.chip_usage add column doodles int not null default 0;

/**
 * A round for [p_user]: a ready doodle they haven't seen (at random), or
 * when [p_fresh_only] is false and they've seen them all, the one they saw
 * longest ago. Marks it seen. No rows when there's nothing to give.
 */
create function public._chip_doodle_pick(p_user uuid, p_fresh_only boolean)
returns table (word text, strokes text[], fresh boolean)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_word text;
  v_fresh boolean := true;
begin
  select d.word into v_word
  from public.chip_doodles d
  where d.status = 'ready'
    and not exists (select 1 from public.chip_doodle_seen s
                    where s.user_id = p_user and s.word = d.word)
  order by random()
  limit 1;

  if v_word is null and not p_fresh_only then
    v_fresh := false;
    select s.word into v_word
    from public.chip_doodle_seen s
    join public.chip_doodles d on d.word = s.word and d.status = 'ready'
    where s.user_id = p_user
    order by s.seen_at, random()
    limit 1;
  end if;
  if v_word is null then return; end if;

  insert into public.chip_doodle_seen (user_id, word) values (p_user, v_word)
    on conflict (user_id, word) do update set seen_at = now();
  return query
    select d.word, d.strokes, v_fresh from public.chip_doodles d where d.word = v_word;
end;
$$;

/**
 * Claims a word for Chip to draw: one with no doodle yet, or whose drawing
 * failed a day ago or more, or got stuck. Level 1 words first (the
 * everyday ones). Null when every word is drawn or being drawn.
 */
create function public._chip_doodle_claim()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_word text;
begin
  -- A doodle that failed or stuck can be tried again.
  update public.chip_doodles
     set status = 'drawing', updated_at = now()
   where word = (
     select word from public.chip_doodles
     where (status = 'failed' and updated_at < now() - interval '1 day')
        or (status = 'drawing' and updated_at < now() - interval '10 minutes')
     order by random()
     limit 1
     for update skip locked
   )
  returning word into v_word;
  if v_word is not null then return v_word; end if;

  for v_word in
    select w.word from public.doodle_words w
    where not exists (select 1 from public.chip_doodles d where d.word = w.word)
    order by w.level, random()
    limit 5
  loop
    insert into public.chip_doodles (word) values (v_word)
      on conflict (word) do nothing;
    if found then return v_word; end if;
  end loop;
  return null;
end;
$$;

revoke all on function public._chip_doodle_pick(uuid, boolean) from public, anon, authenticated;
revoke all on function public._chip_doodle_claim() from public, anon, authenticated;
grant execute on function public._chip_doodle_pick(uuid, boolean) to service_role;
grant execute on function public._chip_doodle_claim() to service_role;

-- Chip's allowance as before, with doodles.
create or replace function public.chip_take(p_kind text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_member boolean;
  v_used int;
  v_everyone int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('chat', 'vibe', 'draw', 'paint', 'doodle') then
    raise exception 'unknown kind';
  end if;
  v_member := public._maestro_until(v_me) is not null;

  insert into public.chip_usage (user_id, day) values (v_me, v_today)
    on conflict (user_id, day) do nothing;

  if p_kind = 'chat' then
    update public.chip_usage set chats = chats + 1
      where user_id = v_me and day = v_today and chats < 40
      returning chats into v_used;
  elsif p_kind = 'vibe' then
    update public.chip_usage set vibes = vibes + 1
      where user_id = v_me and day = v_today and vibes < 150
      returning vibes into v_used;
  elsif p_kind = 'draw' then
    select coalesce(sum(draws), 0) into v_everyone
      from public.chip_usage where day = v_today;
    if v_everyone >= 300 then return false; end if;
    update public.chip_usage set draws = draws + 1
      where user_id = v_me and day = v_today
        and draws < case when v_member then 10 else 4 end
      returning draws into v_used;
  elsif p_kind = 'doodle' then
    select coalesce(sum(doodles), 0) into v_everyone
      from public.chip_usage where day = v_today;
    if v_everyone >= 300 then return false; end if;
    update public.chip_usage set doodles = doodles + 1
      where user_id = v_me and day = v_today
        and doodles < case when v_member then 12 else 6 end
      returning doodles into v_used;
  else
    select coalesce(sum(paints), 0) into v_everyone
      from public.chip_usage where day = v_today;
    if v_everyone >= 3000 then return false; end if;
    update public.chip_usage set paints = paints + 1
      where user_id = v_me and day = v_today
        and paints < case when v_member then 100 else 20 end
      returning paints into v_used;
  end if;

  return v_used is not null;
end;
$$;

-- Account deletion as before, and which doodles they've seen goes too.
create or replace function public.anonymize_account(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set display_name = 'Deleted player',
         username = null,
         avatar_url = null,
         avatar_kind = null,
         avatar_seed = null,
         equipped_aura = null,
         aura_expires_at = null,
         show_coins = false,
         updated_at = now()
   where id = p_user;

  delete from public.friendships where user_low = p_user or user_high = p_user;
  delete from public.friend_requests where from_user = p_user or to_user = p_user;
  delete from public.match_invites
   where (from_user = p_user or to_user = p_user) and match_id is null;
  delete from public.matchmaking_queue where user_id = p_user;
  delete from public.ludo_matchmaking_queue where user_id = p_user;
  delete from public.ludo_room_members where user_id = p_user;
  delete from public.chess_presence where user_id = p_user;
  delete from public.chess_chat_messages where sender_id = p_user;
  delete from public.ludo_chat_messages where sender_id = p_user;
  delete from public.notifications where user_id = p_user or actor_id = p_user;
  delete from public.chip_usage where user_id = p_user;
  update public.bug_reports set user_id = null, contact = null where user_id = p_user;
  -- Everything personal that came later.
  delete from public.chip_memories where user_id = p_user;
  delete from public.user_birthdays where user_id = p_user;
  delete from public.app_events where user_id = p_user;
  delete from public.doodle_messages where sender_id = p_user;
  delete from public.doodle_guesses where user_id = p_user;
  delete from public.coloring_asks where user_id = p_user;
  delete from public.player_ratings where user_id = p_user;
  delete from public.rating_changes where user_id = p_user;
  delete from public.chip_doodle_seen where user_id = p_user;
end;
$$;

revoke all on function public.anonymize_account(uuid) from public, anon, authenticated;
grant execute on function public.anonymize_account(uuid) to service_role;
