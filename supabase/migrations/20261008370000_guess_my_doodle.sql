-- Guess My Doodle: one player draws a secret word and everyone else races
-- to guess it in the chat. Words, guesses, scores, hints and the clock all
-- live here, behind SECURITY DEFINER functions; clients only read. The
-- drawing itself streams between players over a Realtime broadcast channel
-- and is saved stroke by stroke (doodle_strokes) for anyone joining late.
--
-- Time moves on when someone asks: every player calls tick_doodle every few
-- seconds (and right at each deadline), which checks them in and advances
-- the game if a deadline has passed. Players who stop checking in for 40
-- seconds count as gone.

-- ── tables ────────────────────────────────────────────────────────────────

create table public.doodle_words (
  word  text primary key check (word ~ '^[a-z][a-z -]{1,22}[a-z]$'),
  level smallint not null default 1 check (level between 1 and 3)
);

comment on table public.doodle_words is 'Words to draw. Never readable by clients: the drawer gets their three choices from doodle_secret().';

create table public.doodle_games (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique check (code ~ '^[A-Z0-9]{6}$'),
  is_public     boolean not null default false,
  host_id       uuid not null references public.profiles (id) on delete cascade,
  status        text not null default 'lobby'
                check (status in ('lobby', 'choosing', 'drawing', 'reveal', 'over', 'closed')),
  rounds        int not null default 3 check (rounds between 1 and 6),
  draw_seconds  int not null default 80 check (draw_seconds between 30 and 180),
  max_players   int not null default 8 check (max_players between 2 and 10),
  round         int not null default 0,
  -- Counts up for the life of the game (never reset by a rematch), so a
  -- turn number always names one turn.
  turn          int not null default 0,
  drawer_id     uuid references public.profiles (id) on delete set null,
  -- The deadline of the current phase: choosing, drawing, the reveal, the
  -- scores (public games restart), or a public lobby's countdown.
  phase_ends_at timestamptz,
  -- The word with its letters hidden ('_'), some shown as hints.
  word_mask     text,
  revealed_word text,
  canvas_epoch  int not null default 0,
  canvas_rev    int not null default 0,
  hints         int not null default 0,
  winner_ids    uuid[] not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table public.doodle_players (
  game_id      uuid not null references public.doodle_games (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  score        int not null default 0,
  -- Points from the latest turn, for the reveal.
  turn_points  int not null default 0,
  -- The turn they last guessed right in.
  guessed_turn int not null default 0,
  -- The round they last drew in.
  drew_round   int not null default 0,
  -- Drawing order: who joined first draws first.
  join_seq     int not null default 0,
  joined_at    timestamptz not null default now(),
  left_at      timestamptz,
  left_by_self boolean not null default false,
  primary key (game_id, user_id)
);

create index doodle_players_user_idx on public.doodle_players (user_id);

-- Kept apart from doodle_players so check-ins every few seconds don't
-- stream an update to every player.
create table public.doodle_presence (
  game_id   uuid not null references public.doodle_games (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  last_seen timestamptz not null default now(),
  primary key (game_id, user_id)
);

create table public.doodle_secrets (
  game_id uuid primary key references public.doodle_games (id) on delete cascade,
  word    text,
  choices text[] not null default '{}',
  used    text[] not null default '{}'
);

create table public.doodle_strokes (
  id         bigserial primary key,
  game_id    uuid not null references public.doodle_games (id) on delete cascade,
  turn       int not null,
  epoch      int not null,
  op         jsonb not null,
  undone     boolean not null default false,
  created_at timestamptz not null default now()
);

create index doodle_strokes_game_idx on public.doodle_strokes (game_id, turn, epoch, id);

create table public.doodle_guesses (
  game_id uuid not null references public.doodle_games (id) on delete cascade,
  turn    int not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  points  int not null,
  at      timestamptz not null default now(),
  primary key (game_id, turn, user_id)
);

create table public.doodle_messages (
  id         bigserial primary key,
  game_id    uuid not null references public.doodle_games (id) on delete cascade,
  sender_id  uuid references public.profiles (id) on delete cascade,
  turn       int not null default 0,
  -- Who was drawing when it was sent.
  drawer_id  uuid,
  kind       text not null
             check (kind in ('chat', 'guessed', 'close', 'reveal', 'joined', 'left', 'drawing')),
  body       text not null default '' check (char_length(body) <= 200),
  -- all; guessed: only the drawer and those who've guessed this turn (so
  -- nobody gives the word away); self: only the sender (a close guess).
  audience   text not null default 'all' check (audience in ('all', 'guessed', 'self')),
  created_at timestamptz not null default now()
);

create index doodle_messages_game_idx on public.doodle_messages (game_id, id);

-- ── access ────────────────────────────────────────────────────────────────

create function public._doodle_member(p_game uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.doodle_players where game_id = p_game and user_id = auth.uid()
  );
$$;

create function public._doodle_guessed(p_game uuid, p_turn int)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.doodle_guesses
      where game_id = p_game and turn = p_turn and user_id = auth.uid()
  );
$$;

revoke all on function public._doodle_member(uuid) from public;
revoke all on function public._doodle_guessed(uuid, int) from public;
grant execute on function public._doodle_member(uuid) to authenticated;
grant execute on function public._doodle_guessed(uuid, int) to authenticated;

alter table public.doodle_words enable row level security;
alter table public.doodle_games enable row level security;
alter table public.doodle_players enable row level security;
alter table public.doodle_presence enable row level security;
alter table public.doodle_secrets enable row level security;
alter table public.doodle_strokes enable row level security;
alter table public.doodle_guesses enable row level security;
alter table public.doodle_messages enable row level security;

revoke all on public.doodle_words, public.doodle_presence, public.doodle_secrets,
  public.doodle_guesses from anon, authenticated;
revoke insert, update, delete, truncate on public.doodle_games, public.doodle_players,
  public.doodle_strokes, public.doodle_messages from anon, authenticated;
revoke select on public.doodle_games, public.doodle_players, public.doodle_strokes,
  public.doodle_messages from anon;

create policy "members see the game" on public.doodle_games
  for select to authenticated using (public._doodle_member(id));
create policy "members see the players" on public.doodle_players
  for select to authenticated using (public._doodle_member(game_id));
create policy "members see the drawing" on public.doodle_strokes
  for select to authenticated using (public._doodle_member(game_id));
create policy "members see the chat meant for them" on public.doodle_messages
  for select to authenticated using (
    public._doodle_member(game_id)
    and (
      audience = 'all'
      or (audience = 'self' and sender_id = auth.uid())
      or (
        audience = 'guessed'
        and (
          drawer_id = auth.uid()
          or sender_id = auth.uid()
          or public._doodle_guessed(game_id, turn)
        )
      )
    )
  );

-- ── helpers ───────────────────────────────────────────────────────────────

-- Lowercase letters and digits, single spaces: "Puff-Puff!" is "puff puff".
create function public._doodle_norm(p_text text)
returns text
language sql
immutable
as $$
  select btrim(regexp_replace(lower(coalesce(p_text, '')), '[^a-z0-9]+', ' ', 'g'));
$$;

-- Edit distance, for "so close" guesses. Words here are short.
create function public._doodle_distance(a text, b text)
returns int
language plpgsql
immutable
as $$
declare
  la int := char_length(a);
  lb int := char_length(b);
  prev int[];
  cur int[];
  cost int;
begin
  if la = 0 then return lb; end if;
  if lb = 0 then return la; end if;
  if la > 40 or lb > 40 then return 99; end if;
  prev := array(select generate_series(0, lb));
  for i in 1..la loop
    cur := array[i];
    for j in 1..lb loop
      cost := case when substr(a, i, 1) = substr(b, j, 1) then 0 else 1 end;
      cur := cur || least(cur[j] + 1, prev[j + 1] + 1, prev[j] + cost);
    end loop;
    prev := cur;
  end loop;
  return prev[lb + 1];
end;
$$;

create function public._doodle_mask(p_word text)
returns text
language sql
immutable
as $$
  select regexp_replace(p_word, '[a-z0-9]', '_', 'g');
$$;

create function public._doodle_new_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
begin
  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.doodle_games where code = v_code);
  end loop;
  return v_code;
end;
$$;

create function public._doodle_active(p_game uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int from public.doodle_players where game_id = p_game and left_at is null;
$$;

-- ── the game's flow ───────────────────────────────────────────────────────
-- Each of these expects the caller to hold the game row's lock.

create function public._doodle_finish(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_top int;
begin
  select max(score) into v_top from public.doodle_players
    where game_id = p_game and left_at is null;
  update public.doodle_games set
    status = 'over',
    drawer_id = null,
    word_mask = null,
    phase_ends_at = now() + interval '25 seconds',
    winner_ids = coalesce(array(
      select user_id from public.doodle_players
        where game_id = p_game and left_at is null and v_top > 0 and score = v_top
        order by join_seq
    ), '{}'),
    updated_at = now()
  where id = p_game;
end;
$$;

-- The next player who hasn't drawn this round picks a word. After the last
-- one, the next round; after the last round, the scores.
create function public._doodle_start_turn(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.doodle_games;
  v_next uuid;
  v_used text[];
  v_choices text[];
begin
  select * into g from public.doodle_games where id = p_game;

  select user_id into v_next from public.doodle_players
    where game_id = p_game and left_at is null and drew_round < g.round
    order by join_seq limit 1;
  if v_next is null then
    if g.round >= g.rounds then
      perform public._doodle_finish(p_game);
      return;
    end if;
    g.round := g.round + 1;
    select user_id into v_next from public.doodle_players
      where game_id = p_game and left_at is null and drew_round < g.round
      order by join_seq limit 1;
    if v_next is null then
      update public.doodle_games set status = 'closed', updated_at = now() where id = p_game;
      return;
    end if;
  end if;

  select used into v_used from public.doodle_secrets where game_id = p_game;
  v_used := coalesce(v_used, '{}');
  v_choices := array(
    select word from public.doodle_words
      where not (word = any (v_used))
      order by random() limit 3
  );
  if cardinality(v_choices) < 3 then
    v_used := '{}';
    v_choices := array(select word from public.doodle_words order by random() limit 3);
  end if;
  update public.doodle_secrets
    set word = null, choices = v_choices, used = v_used || v_choices
    where game_id = p_game;

  update public.doodle_players set turn_points = 0 where game_id = p_game;
  update public.doodle_players set drew_round = g.round
    where game_id = p_game and user_id = v_next;
  update public.doodle_games set
    status = 'choosing',
    round = g.round,
    turn = turn + 1,
    drawer_id = v_next,
    phase_ends_at = now() + interval '15 seconds',
    word_mask = null,
    revealed_word = null,
    hints = 0,
    canvas_epoch = 0,
    canvas_rev = 0,
    updated_at = now()
  where id = p_game;
end;
$$;

-- A fresh game from the lobby or the scores: everyone back to 0.
create function public._doodle_begin(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.doodle_players
    set score = 0, turn_points = 0, drew_round = 0
    where game_id = p_game;
  update public.doodle_games
    set round = 1, winner_ids = '{}', revealed_word = null
    where id = p_game;
  perform public._doodle_start_turn(p_game);
end;
$$;

create function public._doodle_choose(p_game uuid, p_index int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.doodle_games;
  v_word text;
begin
  select * into g from public.doodle_games where id = p_game;
  select coalesce(choices[p_index], choices[1]) into v_word
    from public.doodle_secrets where game_id = p_game;
  if v_word is null then
    perform public._doodle_start_turn(p_game);
    return;
  end if;
  update public.doodle_secrets set word = v_word where game_id = p_game;
  update public.doodle_games set
    status = 'drawing',
    word_mask = public._doodle_mask(v_word),
    hints = 0,
    phase_ends_at = now() + make_interval(secs => g.draw_seconds),
    updated_at = now()
  where id = p_game;
  insert into public.doodle_messages (game_id, sender_id, turn, drawer_id, kind, audience)
    values (p_game, g.drawer_id, g.turn, g.drawer_id, 'drawing', 'all');
end;
$$;

-- Time's up, or everyone guessed: show the word.
create function public._doodle_reveal(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.doodle_games;
  v_word text;
begin
  select * into g from public.doodle_games where id = p_game;
  select word into v_word from public.doodle_secrets where game_id = p_game;
  if v_word is null then
    perform public._doodle_start_turn(p_game);
    return;
  end if;
  update public.doodle_games set
    status = 'reveal',
    revealed_word = v_word,
    word_mask = null,
    phase_ends_at = now() + interval '6 seconds',
    updated_at = now()
  where id = p_game;
  insert into public.doodle_messages (game_id, sender_id, turn, drawer_id, kind, body, audience)
    values (p_game, g.drawer_id, g.turn, g.drawer_id, 'reveal', v_word, 'all');
end;
$$;

-- Moves the game on if a deadline has passed or someone it needs has gone.
create function public._doodle_advance(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.doodle_games;
  v_active int;
  v_waiting int;
  v_word text;
  v_elapsed double precision;
  v_spots int[];
  v_pick int;
  v_gone record;
begin
  select * into g from public.doodle_games where id = p_game;
  if g is null or g.status = 'closed' then return; end if;

  -- Players who stopped checking in have gone.
  for v_gone in
    update public.doodle_players p
      set left_at = now(), left_by_self = false
      from public.doodle_presence s
      where p.game_id = p_game and s.game_id = p_game and s.user_id = p.user_id
        and p.left_at is null and s.last_seen < now() - interval '40 seconds'
      returning p.user_id
  loop
    insert into public.doodle_messages (game_id, sender_id, turn, kind)
      values (p_game, v_gone.user_id, g.turn, 'left');
  end loop;

  v_active := public._doodle_active(p_game);
  if v_active = 0 then
    update public.doodle_games set status = 'closed', updated_at = now() where id = p_game;
    return;
  end if;

  if not exists (
    select 1 from public.doodle_players
      where game_id = p_game and user_id = g.host_id and left_at is null
  ) then
    update public.doodle_games set host_id = (
      select user_id from public.doodle_players
        where game_id = p_game and left_at is null order by join_seq limit 1
    ) where id = p_game;
  end if;

  if g.status = 'lobby' then
    if not g.is_public or v_active < 2 then
      if g.phase_ends_at is not null then
        update public.doodle_games set phase_ends_at = null where id = p_game;
      end if;
    elsif g.phase_ends_at is null then
      update public.doodle_games set phase_ends_at = now() + interval '10 seconds' where id = p_game;
    elsif now() >= g.phase_ends_at then
      perform public._doodle_begin(p_game);
    end if;
    return;
  end if;

  if g.status in ('choosing', 'drawing', 'reveal') and v_active < 2 then
    update public.doodle_games set
      status = 'lobby', drawer_id = null, word_mask = null, phase_ends_at = null,
      updated_at = now()
    where id = p_game;
    return;
  end if;

  if g.status = 'over' then
    if g.is_public and now() >= g.phase_ends_at then
      if v_active >= 2 then
        perform public._doodle_begin(p_game);
      else
        update public.doodle_games set status = 'lobby', phase_ends_at = null, updated_at = now()
          where id = p_game;
      end if;
    end if;
    return;
  end if;

  if g.status in ('choosing', 'drawing') and not exists (
    select 1 from public.doodle_players
      where game_id = p_game and user_id = g.drawer_id and left_at is null
  ) then
    if g.status = 'choosing' then
      perform public._doodle_start_turn(p_game);
    else
      perform public._doodle_reveal(p_game);
    end if;
    return;
  end if;

  if g.status = 'choosing' then
    if now() >= g.phase_ends_at then
      perform public._doodle_choose(p_game, 1 + floor(random() * 3)::int);
    end if;
    return;
  end if;

  if g.status = 'drawing' then
    select count(*) into v_waiting from public.doodle_players
      where game_id = p_game and left_at is null
        and user_id <> g.drawer_id and guessed_turn <> g.turn;
    if now() >= g.phase_ends_at or v_waiting = 0 then
      perform public._doodle_reveal(p_game);
      return;
    end if;
    -- A letter shown halfway through, and another at three quarters for
    -- longer words.
    v_elapsed := 1 - extract(epoch from (g.phase_ends_at - now())) / g.draw_seconds;
    select word into v_word from public.doodle_secrets where game_id = p_game;
    if v_word is not null and char_length(v_word) >= 4 and (
      (v_elapsed >= 0.5 and g.hints < 1)
      or (v_elapsed >= 0.75 and g.hints < 2 and char_length(v_word) >= 6)
    ) then
      v_spots := array(
        select i from generate_series(1, char_length(g.word_mask)) as i
          where substr(g.word_mask, i, 1) = '_'
      );
      if cardinality(v_spots) > 1 then
        v_pick := v_spots[1 + floor(random() * cardinality(v_spots))::int];
        update public.doodle_games set
          word_mask = overlay(word_mask placing substr(v_word, v_pick, 1) from v_pick for 1),
          hints = hints + 1,
          updated_at = now()
        where id = p_game;
      end if;
    end if;
    return;
  end if;

  if g.status = 'reveal' and now() >= g.phase_ends_at then
    perform public._doodle_start_turn(p_game);
  end if;
end;
$$;

create function public._doodle_add_player(p_game uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seq int;
begin
  select coalesce(max(join_seq), 0) + 1 into v_seq from public.doodle_players where game_id = p_game;
  insert into public.doodle_players (game_id, user_id, join_seq)
    values (p_game, p_user, v_seq)
    on conflict (game_id, user_id) do update
      set left_at = null, left_by_self = false, join_seq = excluded.join_seq;
  insert into public.doodle_presence (game_id, user_id)
    values (p_game, p_user)
    on conflict (game_id, user_id) do update set last_seen = now();
  insert into public.doodle_messages (game_id, sender_id, turn, kind)
    values (p_game, p_user, (select turn from public.doodle_games where id = p_game), 'joined');
  perform public._doodle_advance(p_game);
end;
$$;

-- Takes [p_user] out of every game they're playing but [p_except], so a
-- player is only ever in one.
create function public._doodle_leave_all(p_user uuid, p_except uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game uuid;
begin
  for v_game in
    select p.game_id from public.doodle_players p
      join public.doodle_games g on g.id = p.game_id
      where p.user_id = p_user and p.left_at is null and g.status <> 'closed'
        and (p_except is null or p.game_id <> p_except)
  loop
    perform 1 from public.doodle_games where id = v_game for update;
    update public.doodle_players set left_at = now(), left_by_self = true
      where game_id = v_game and user_id = p_user;
    insert into public.doodle_messages (game_id, sender_id, turn, kind)
      values (v_game, p_user, (select turn from public.doodle_games where id = v_game), 'left');
    perform public._doodle_advance(v_game);
  end loop;
end;
$$;

create function public._doodle_create(p_user uuid, p_public boolean, p_rounds int, p_draw_seconds int)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.doodle_games (code, is_public, host_id, rounds, draw_seconds)
    values (public._doodle_new_code(), p_public, p_user, p_rounds, p_draw_seconds)
    returning id into v_id;
  insert into public.doodle_secrets (game_id) values (v_id);
  perform public._doodle_add_player(v_id, p_user);
  return v_id;
end;
$$;

revoke all on function public._doodle_norm(text) from public;
revoke all on function public._doodle_distance(text, text) from public;
revoke all on function public._doodle_mask(text) from public;
revoke all on function public._doodle_new_code() from public;
revoke all on function public._doodle_active(uuid) from public;
revoke all on function public._doodle_finish(uuid) from public;
revoke all on function public._doodle_start_turn(uuid) from public;
revoke all on function public._doodle_begin(uuid) from public;
revoke all on function public._doodle_choose(uuid, int) from public;
revoke all on function public._doodle_reveal(uuid) from public;
revoke all on function public._doodle_advance(uuid) from public;
revoke all on function public._doodle_add_player(uuid, uuid) from public;
revoke all on function public._doodle_leave_all(uuid, uuid) from public;
revoke all on function public._doodle_create(uuid, boolean, int, int) from public;

-- ── what players can call ─────────────────────────────────────────────────

-- A private game to share by code, or (p_public) one strangers can join.
create function public.create_doodle_game(
  p_public boolean default false,
  p_rounds int default 3,
  p_draw_seconds int default 80
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_rounds not between 1 and 6 then raise exception 'rounds are 1 to 6'; end if;
  if p_draw_seconds not between 30 and 180 then raise exception 'drawing time is 30 to 180 seconds'; end if;
  perform public._doodle_leave_all(v_me, null);
  v_id := public._doodle_create(v_me, p_public, p_rounds, p_draw_seconds);
  return jsonb_build_object('id', v_id, 'code', (select code from public.doodle_games where id = v_id));
end;
$$;

create function public.join_doodle_game(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into g from public.doodle_games where code = upper(btrim(p_code)) for update;
  if g is null then raise exception 'no game with that code'; end if;
  if g.status = 'closed' then raise exception 'that game has ended'; end if;
  if exists (
    select 1 from public.doodle_players
      where game_id = g.id and user_id = v_me and left_at is null
  ) then
    return g.id;
  end if;
  if public._doodle_active(g.id) >= g.max_players then raise exception 'game is full'; end if;
  perform public._doodle_leave_all(v_me, g.id);
  perform public._doodle_add_player(g.id, v_me);
  return g.id;
end;
$$;

-- Drops the player into a public game that has room, busiest first, or
-- starts a new one for others to find.
create function public.quick_play_doodle()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_candidate record;
  g public.doodle_games;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  for v_candidate in
    select dg.id from public.doodle_games dg
      where dg.is_public and dg.status in ('lobby', 'choosing', 'drawing', 'reveal', 'over')
        and not exists (
          select 1 from public.doodle_players p
            where p.game_id = dg.id and p.user_id = v_me
              and p.left_by_self and p.left_at > now() - interval '2 minutes'
        )
      order by public._doodle_active(dg.id) desc, dg.created_at
      limit 5
  loop
    select * into g from public.doodle_games where id = v_candidate.id for update skip locked;
    continue when g is null or g.status = 'closed';
    if public._doodle_active(g.id) between 1 and g.max_players - 1 then
      if exists (
        select 1 from public.doodle_players
          where game_id = g.id and user_id = v_me and left_at is null
      ) then
        return g.id;
      end if;
      perform public._doodle_leave_all(v_me, g.id);
      perform public._doodle_add_player(g.id, v_me);
      return g.id;
    end if;
  end loop;
  perform public._doodle_leave_all(v_me, null);
  return public._doodle_create(v_me, true, 3, 80);
end;
$$;

create function public.leave_doodle_game(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  perform 1 from public.doodle_games where id = p_game for update;
  if not found then return; end if;
  if not exists (
    select 1 from public.doodle_players where game_id = p_game and user_id = v_me and left_at is null
  ) then
    return;
  end if;
  update public.doodle_players set left_at = now(), left_by_self = true
    where game_id = p_game and user_id = v_me;
  insert into public.doodle_messages (game_id, sender_id, turn, kind)
    values (p_game, v_me, (select turn from public.doodle_games where id = p_game), 'left');
  perform public._doodle_advance(p_game);
end;
$$;

-- The host starts a private game (or a rematch) once 2+ players are in.
create function public.start_doodle_game(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
begin
  select * into g from public.doodle_games where id = p_game for update;
  if g is null then raise exception 'game not found'; end if;
  if g.host_id <> v_me then raise exception 'only the host can start the game'; end if;
  if g.status not in ('lobby', 'over') then raise exception 'the game has already started'; end if;
  if public._doodle_active(p_game) < 2 then raise exception 'need at least 2 players'; end if;
  perform public._doodle_begin(p_game);
end;
$$;

create function public.choose_doodle_word(p_game uuid, p_index int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
begin
  select * into g from public.doodle_games where id = p_game for update;
  if g is null then raise exception 'game not found'; end if;
  if g.status <> 'choosing' or g.drawer_id is distinct from v_me then return; end if;
  if p_index not between 1 and 3 then raise exception 'pick one of the three words'; end if;
  perform public._doodle_choose(p_game, p_index);
end;
$$;

-- What only the drawer may know: the three words to pick from, then the
-- word. Empty for everyone else.
create function public.doodle_secret(p_game uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
  s public.doodle_secrets;
begin
  select * into g from public.doodle_games where id = p_game;
  if g is null or g.drawer_id is distinct from v_me then return '{}'::jsonb; end if;
  select * into s from public.doodle_secrets where game_id = p_game;
  if g.status = 'choosing' then
    return jsonb_build_object('turn', g.turn, 'choices', to_jsonb(s.choices));
  elsif g.status in ('drawing', 'reveal') then
    return jsonb_build_object('turn', g.turn, 'word', s.word);
  end if;
  return '{}'::jsonb;
end;
$$;

-- Checks in and moves the game on if it's due. Returns the server's clock,
-- so players' countdowns agree.
create function public.tick_doodle(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
  p public.doodle_players;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into g from public.doodle_games where id = p_game for update;
  if g is null then raise exception 'game not found'; end if;
  select * into p from public.doodle_players where game_id = p_game and user_id = v_me;
  if p is null then raise exception 'not in this game'; end if;

  if g.status <> 'closed' then
    insert into public.doodle_presence (game_id, user_id) values (p_game, v_me)
      on conflict (game_id, user_id) do update set last_seen = now();
    -- Dropped for going quiet (not for leaving): back in, if there's room.
    if p.left_at is not null and not p.left_by_self
      and public._doodle_active(p_game) < g.max_players then
      perform public._doodle_leave_all(v_me, p_game);
      perform public._doodle_add_player(p_game, v_me);
    else
      perform public._doodle_advance(p_game);
    end if;
  end if;
  return jsonb_build_object('now', now());
end;
$$;

-- A chat line, which is a guess while someone's drawing. Never shows the
-- word: a right guess becomes "X guessed it", a near miss is shown only to
-- the guesser, and once you've guessed (or while you draw) your messages
-- only reach the others who have.
create function public.guess_doodle(p_game uuid, p_text text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
  v_text text := btrim(regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g'));
  v_shown text;
  v_word text;
  v_norm text;
  v_answer text;
  v_left double precision;
  v_points int;
  v_audience text := 'all';
  v_recent int;
  v_distance int;
  v_allowed int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if char_length(v_text) = 0 then raise exception 'empty message'; end if;
  if char_length(v_text) > 100 then raise exception 'message too long'; end if;

  select * into g from public.doodle_games where id = p_game for update;
  if g is null then raise exception 'game not found'; end if;
  if not exists (
    select 1 from public.doodle_players where game_id = p_game and user_id = v_me and left_at is null
  ) then
    raise exception 'not in this game';
  end if;

  select count(*) into v_recent from public.doodle_messages
    where game_id = p_game and sender_id = v_me and kind in ('chat', 'close')
      and created_at > now() - interval '10 seconds';
  if v_recent >= 8 then raise exception 'slow down'; end if;

  v_shown := case when g.is_public then public.mask_offensive(v_text) else v_text end;

  if g.status in ('choosing', 'drawing') then
    if g.drawer_id = v_me
      or exists (
        select 1 from public.doodle_players
          where game_id = p_game and user_id = v_me and guessed_turn = g.turn
      ) then
      v_audience := 'guessed';
    elsif g.status = 'drawing' then
      select word into v_word from public.doodle_secrets where game_id = p_game;
      v_norm := public._doodle_norm(v_text);
      v_answer := public._doodle_norm(v_word);
      if v_answer <> '' and (
        v_norm = v_answer
        or replace(v_norm, ' ', '') = replace(v_answer, ' ', '')
        or strpos(' ' || v_norm || ' ', ' ' || v_answer || ' ') > 0
      ) then
        v_left := greatest(0, extract(epoch from (g.phase_ends_at - now())));
        v_points := 50 + (round(450 * v_left / g.draw_seconds / 5) * 5)::int
          + case when exists (
              select 1 from public.doodle_guesses where game_id = p_game and turn = g.turn
            ) then 0 else 50 end;
        insert into public.doodle_guesses (game_id, turn, user_id, points)
          values (p_game, g.turn, v_me, v_points);
        update public.doodle_players
          set score = score + v_points, turn_points = turn_points + v_points, guessed_turn = g.turn
          where game_id = p_game and user_id = v_me;
        update public.doodle_players
          set score = score + 50, turn_points = turn_points + 50
          where game_id = p_game and user_id = g.drawer_id;
        insert into public.doodle_messages (game_id, sender_id, turn, drawer_id, kind, audience)
          values (p_game, v_me, g.turn, g.drawer_id, 'guessed', 'all');
        perform public._doodle_advance(p_game);
        return jsonb_build_object('result', 'correct', 'points', v_points);
      end if;
      v_distance := least(
        public._doodle_distance(v_norm, v_answer),
        public._doodle_distance(replace(v_norm, ' ', ''), replace(v_answer, ' ', ''))
      );
      v_allowed := 1;
      if char_length(v_answer) >= 8 then v_allowed := 2; end if;
      if char_length(v_answer) >= 4 and v_distance <= v_allowed then
        insert into public.doodle_messages (game_id, sender_id, turn, drawer_id, kind, body, audience)
          values (p_game, v_me, g.turn, g.drawer_id, 'close', v_shown, 'self');
        return jsonb_build_object('result', 'close');
      end if;
    end if;
  end if;

  insert into public.doodle_messages (game_id, sender_id, turn, drawer_id, kind, body, audience)
    values (p_game, v_me, g.turn, g.drawer_id, 'chat', v_shown, v_audience);
  return jsonb_build_object('result', 'chat');
end;
$$;

-- The drawer saves a finished stroke. Returns the canvas revision it made,
-- or -1 if the turn or canvas has moved on (the stroke is dropped).
create function public.add_doodle_stroke(p_game uuid, p_turn int, p_epoch int, p_op jsonb)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
  v_rev int;
begin
  select * into g from public.doodle_games where id = p_game for update;
  if g is null then raise exception 'game not found'; end if;
  if g.status <> 'drawing' or g.drawer_id is distinct from v_me
    or g.turn <> p_turn or g.canvas_epoch <> p_epoch then
    return -1;
  end if;
  if pg_column_size(p_op) > 60000 then raise exception 'stroke too big'; end if;
  if (select count(*) from public.doodle_strokes where game_id = p_game and turn = p_turn) >= 3000 then
    raise exception 'too many strokes';
  end if;
  insert into public.doodle_strokes (game_id, turn, epoch, op) values (p_game, p_turn, p_epoch, p_op);
  update public.doodle_games set canvas_rev = canvas_rev + 1, updated_at = now()
    where id = p_game returning canvas_rev into v_rev;
  return v_rev;
end;
$$;

create function public.undo_doodle_stroke(p_game uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
  v_rev int;
begin
  select * into g from public.doodle_games where id = p_game for update;
  if g is null then raise exception 'game not found'; end if;
  if g.status <> 'drawing' or g.drawer_id is distinct from v_me then return -1; end if;
  update public.doodle_strokes set undone = true
    where id = (
      select max(id) from public.doodle_strokes
        where game_id = p_game and turn = g.turn and epoch = g.canvas_epoch and not undone
    );
  if not found then return g.canvas_rev; end if;
  update public.doodle_games set canvas_rev = canvas_rev + 1, updated_at = now()
    where id = p_game returning canvas_rev into v_rev;
  return v_rev;
end;
$$;

create function public.clear_doodle_canvas(p_game uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
  v_rev int;
begin
  select * into g from public.doodle_games where id = p_game for update;
  if g is null then raise exception 'game not found'; end if;
  if g.status <> 'drawing' or g.drawer_id is distinct from v_me then return -1; end if;
  update public.doodle_games
    set canvas_epoch = canvas_epoch + 1, canvas_rev = canvas_rev + 1, updated_at = now()
    where id = p_game returning canvas_rev into v_rev;
  return v_rev;
end;
$$;

-- The game the player is in right now, if any (to get back to it after the
-- app closes).
create function public.my_doodle_game()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.game_id from public.doodle_players p
    join public.doodle_games g on g.id = p.game_id
    where p.user_id = auth.uid() and p.left_at is null and g.status <> 'closed'
    order by p.joined_at desc
    limit 1;
$$;

revoke all on function public.create_doodle_game(boolean, int, int) from public;
revoke all on function public.join_doodle_game(text) from public;
revoke all on function public.quick_play_doodle() from public;
revoke all on function public.leave_doodle_game(uuid) from public;
revoke all on function public.start_doodle_game(uuid) from public;
revoke all on function public.choose_doodle_word(uuid, int) from public;
revoke all on function public.doodle_secret(uuid) from public;
revoke all on function public.tick_doodle(uuid) from public;
revoke all on function public.guess_doodle(uuid, text) from public;
revoke all on function public.add_doodle_stroke(uuid, int, int, jsonb) from public;
revoke all on function public.undo_doodle_stroke(uuid) from public;
revoke all on function public.clear_doodle_canvas(uuid) from public;
revoke all on function public.my_doodle_game() from public;

grant execute on function public.create_doodle_game(boolean, int, int) to authenticated;
grant execute on function public.join_doodle_game(text) to authenticated;
grant execute on function public.quick_play_doodle() to authenticated;
grant execute on function public.leave_doodle_game(uuid) to authenticated;
grant execute on function public.start_doodle_game(uuid) to authenticated;
grant execute on function public.choose_doodle_word(uuid, int) to authenticated;
grant execute on function public.doodle_secret(uuid) to authenticated;
grant execute on function public.tick_doodle(uuid) to authenticated;
grant execute on function public.guess_doodle(uuid, text) to authenticated;
grant execute on function public.add_doodle_stroke(uuid, int, int, jsonb) to authenticated;
grant execute on function public.undo_doodle_stroke(uuid) to authenticated;
grant execute on function public.clear_doodle_canvas(uuid) to authenticated;
grant execute on function public.my_doodle_game() to authenticated;

-- ── housekeeping ──────────────────────────────────────────────────────────

-- Every 10 minutes: games nobody has checked in to for 10 minutes end,
-- drawings from finished turns go (doodle_strokes isn't streamed, so this
-- is quiet), and ended games go after a day.
create function public.cleanup_doodle_games()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.doodle_games g set status = 'closed', updated_at = now()
    where g.status <> 'closed' and not exists (
      select 1 from public.doodle_presence s
        where s.game_id = g.id and s.last_seen > now() - interval '10 minutes'
    );
  delete from public.doodle_strokes s
    using public.doodle_games g
    where s.game_id = g.id and (s.turn < g.turn or g.status = 'closed');
  delete from public.doodle_games
    where status = 'closed' and updated_at < now() - interval '1 day';
end;
$$;

revoke all on function public.cleanup_doodle_games() from public, authenticated, anon;

select cron.schedule(
  'cleanup-doodle-games',
  '*/10 * * * *',
  $$select public.cleanup_doodle_games();$$
);

alter publication supabase_realtime add table public.doodle_games;
alter publication supabase_realtime add table public.doodle_players;
alter publication supabase_realtime add table public.doodle_messages;

-- ── words ─────────────────────────────────────────────────────────────────

insert into public.doodle_words (word, level) values
  -- animals
  ('cat', 1), ('dog', 1), ('fish', 1), ('bird', 1), ('cow', 1), ('pig', 1),
  ('horse', 1), ('sheep', 1), ('goat', 1), ('chicken', 1), ('duck', 1),
  ('rabbit', 1), ('mouse', 1), ('lion', 1), ('tiger', 1), ('elephant', 1),
  ('giraffe', 1), ('zebra', 1), ('monkey', 1), ('snake', 1), ('frog', 1),
  ('turtle', 1), ('shark', 1), ('whale', 1), ('dolphin', 1), ('octopus', 2),
  ('crab', 1), ('snail', 1), ('butterfly', 1), ('bee', 1), ('spider', 1),
  ('ant', 1), ('owl', 1), ('penguin', 1), ('parrot', 1), ('camel', 1),
  ('crocodile', 2), ('kangaroo', 2), ('panda', 1), ('bear', 1), ('fox', 1),
  ('wolf', 2), ('deer', 2), ('hedgehog', 2), ('bat', 1), ('jellyfish', 2),
  ('peacock', 2), ('flamingo', 2), ('lizard', 2), ('worm', 1), ('ladybug', 2),
  ('unicorn', 1), ('dragon', 1), ('dinosaur', 1), ('mosquito', 2), ('lobster', 2),
  -- food and drink
  ('apple', 1), ('banana', 1), ('orange', 1), ('mango', 1), ('pineapple', 1),
  ('watermelon', 1), ('grapes', 1), ('strawberry', 1), ('cherry', 1), ('lemon', 1),
  ('coconut', 1), ('avocado', 2), ('carrot', 1), ('tomato', 1), ('onion', 2),
  ('corn', 1), ('pepper', 2), ('egg', 1), ('bread', 1), ('cheese', 1),
  ('pizza', 1), ('burger', 1), ('hot dog', 1), ('fries', 1), ('sandwich', 1),
  ('cake', 1), ('cupcake', 1), ('cookie', 1), ('donut', 1), ('ice cream', 1),
  ('popcorn', 1), ('candy', 1), ('lollipop', 1), ('chocolate', 1), ('honey', 2),
  ('soup', 2), ('noodles', 2), ('rice', 1), ('sushi', 2), ('taco', 2),
  ('pancake', 2), ('milk', 1), ('juice', 1), ('coffee', 1), ('tea', 1),
  ('jollof', 2), ('suya', 3), ('puff-puff', 3), ('plantain', 2), ('yam', 2),
  ('akara', 3), ('chin chin', 3), ('meat pie', 2), ('pepper soup', 3), ('fufu', 3),
  ('zobo', 3), ('sugarcane', 2), ('groundnut', 2), ('cashew', 2), ('agege bread', 3),
  -- at home
  ('house', 1), ('door', 1), ('window', 1), ('chair', 1), ('table', 1),
  ('bed', 1), ('sofa', 1), ('lamp', 1), ('clock', 1), ('mirror', 1),
  ('television', 1), ('fridge', 1), ('kettle', 1), ('cup', 1), ('plate', 1),
  ('spoon', 1), ('fork', 1), ('knife', 1), ('pot', 1), ('pan', 1),
  ('broom', 1), ('bucket', 1), ('toilet', 1), ('bathtub', 2), ('shower', 2),
  ('toothbrush', 1), ('soap', 1), ('towel', 1), ('pillow', 1), ('blanket', 2),
  ('candle', 1), ('key', 1), ('lock', 2), ('stairs', 2), ('fan', 1),
  ('generator', 2), ('ladder', 1), ('umbrella', 1), ('basket', 1), ('scissors', 1),
  ('mortar', 3), ('lantern', 2), ('fence', 2), ('mailbox', 2), ('chimney', 2),
  -- things you carry and wear
  ('phone', 1), ('laptop', 1), ('camera', 1), ('headphones', 1), ('glasses', 1),
  ('sunglasses', 1), ('watch', 1), ('ring', 1), ('necklace', 1), ('crown', 1),
  ('hat', 1), ('cap', 1), ('shoe', 1), ('sock', 1), ('shirt', 1),
  ('dress', 1), ('trousers', 2), ('jacket', 2), ('scarf', 2), ('glove', 1),
  ('backpack', 1), ('wallet', 2), ('purse', 2), ('book', 1), ('pencil', 1),
  ('pen', 1), ('ruler', 1), ('paintbrush', 2), ('envelope', 2), ('gift', 1),
  ('balloon', 1), ('kite', 1), ('teddy bear', 1), ('doll', 1), ('robot', 1),
  ('agbada', 3), ('gele', 3), ('slippers', 2), ('bracelet', 2), ('tie', 1),
  -- getting around
  ('car', 1), ('bus', 1), ('bicycle', 1), ('motorcycle', 1), ('train', 1),
  ('airplane', 1), ('helicopter', 1), ('boat', 1), ('ship', 1), ('rocket', 1),
  ('truck', 1), ('taxi', 1), ('tractor', 2), ('ambulance', 2), ('fire truck', 1),
  ('submarine', 2), ('canoe', 2), ('skateboard', 1), ('scooter', 2), ('traffic light', 1),
  ('danfo', 3), ('okada', 3), ('keke', 3), ('road', 1), ('bridge', 1),
  ('parachute', 2), ('hot air balloon', 2), ('anchor', 2), ('wheel', 1), ('steering wheel', 2),
  -- places and nature
  ('sun', 1), ('moon', 1), ('star', 1), ('cloud', 1), ('rain', 1),
  ('rainbow', 1), ('snowman', 1), ('lightning', 1), ('tornado', 2), ('volcano', 1),
  ('mountain', 1), ('island', 1), ('beach', 1), ('river', 1), ('waterfall', 1),
  ('lake', 2), ('desert', 2), ('forest', 2), ('tree', 1), ('palm tree', 1),
  ('flower', 1), ('rose', 1), ('sunflower', 1), ('cactus', 1), ('mushroom', 1),
  ('leaf', 1), ('grass', 1), ('fire', 1), ('wave', 1), ('planet', 1),
  ('castle', 1), ('pyramid', 1), ('tent', 1), ('lighthouse', 2), ('church', 2),
  ('mosque', 2), ('school', 1), ('hospital', 2), ('market', 2), ('farm', 2),
  ('zoo', 2), ('stadium', 2), ('swimming pool', 2), ('playground', 2), ('igloo', 2),
  ('earth', 1), ('comet', 2), ('cave', 2), ('garden', 2), ('city', 2),
  -- people and stories
  ('baby', 1), ('king', 1), ('queen', 1), ('pirate', 1), ('ninja', 1),
  ('wizard', 1), ('witch', 1), ('ghost', 1), ('zombie', 1), ('vampire', 2),
  ('mermaid', 1), ('angel', 1), ('alien', 1), ('astronaut', 1), ('doctor', 1),
  ('nurse', 2), ('police', 1), ('firefighter', 2), ('chef', 1), ('farmer', 2),
  ('teacher', 2), ('clown', 1), ('superhero', 1), ('cowboy', 1), ('fairy', 1),
  ('skeleton', 1), ('giant', 2), ('princess', 1), ('knight', 2), ('soldier', 2),
  ('masquerade', 3), ('bride', 2), ('twins', 2), ('grandma', 2),
  -- doing things
  ('dancing', 1), ('running', 1), ('swimming', 1), ('sleeping', 1), ('crying', 1),
  ('laughing', 1), ('singing', 1), ('cooking', 1), ('reading', 1), ('jumping', 1),
  ('fishing', 2), ('painting', 2), ('climbing', 2), ('flying', 1), ('sneezing', 2),
  ('juggling', 2), ('skiing', 2), ('surfing', 2), ('boxing', 2), ('praying', 2),
  ('clapping', 2), ('waving', 2), ('yawning', 2), ('whistling', 3), ('hiding', 2),
  -- games and music
  ('football', 1), ('basketball', 1), ('tennis', 2), ('goal', 1), ('trophy', 1),
  ('medal', 1), ('chess', 1), ('dice', 1), ('cards', 2), ('ludo', 1),
  ('guitar', 1), ('piano', 1), ('drum', 1), ('trumpet', 2), ('violin', 2),
  ('microphone', 1), ('talking drum', 3), ('whistle', 2), ('saxophone', 3), ('speaker', 2),
  -- odds and ends
  ('heart', 1), ('smile', 1), ('eye', 1), ('nose', 1), ('ear', 1),
  ('mouth', 1), ('hand', 1), ('foot', 1), ('tooth', 1), ('brain', 2),
  ('bone', 1), ('skull', 2), ('beard', 2), ('moustache', 2), ('tattoo', 2),
  ('sword', 1), ('shield', 1), ('bow and arrow', 2), ('treasure', 1),
  ('map', 1), ('compass', 2), ('magnet', 2), ('battery', 2), ('light bulb', 1),
  ('flag', 1), ('bell', 1), ('money', 1), ('coin', 1),
  ('magic wand', 1), ('spaceship', 1), ('time machine', 3), ('snowflake', 1),
  ('wifi', 2), ('selfie', 2), ('emoji', 2), ('password', 3), ('birthday', 1),
  ('wedding', 2), ('christmas tree', 1), ('fireworks', 1), ('party', 1), ('holiday', 3)
on conflict (word) do nothing;
