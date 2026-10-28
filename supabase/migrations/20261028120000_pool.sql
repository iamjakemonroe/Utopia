-- 8-ball pool: cues, and the coin tables where you play Chip.
--
--   * Cues are store items: store_coin_prices sells them, and the classic
--     cue is free for everyone. Each has a tier. Regular cues climb to
--     level 5 and animated ones (rare, epic, legendary, mythic) to 10;
--     upgrade_pool_cue takes a cue you've bought up a level for coins, the
--     rarer the dearer. Levels are in user_pool_cues; the cue a player
--     plays with is profiles.equipped_pool_cue (equip_item 'pool_cue').
--   * The coin tables: a game against Chip costs the table's entry, and
--     the winner takes the pot (twice the entry, less the house's 5%, as
--     in any staked game). The pool-table function plays every shot with
--     the app's own physics on the table the server holds
--     (pool_games.state), plays Chip's turns, and saves them with
--     pool_record; pool_open starts a game, pool_resign gives one up.
--
-- What each cue's stats are at each level is in
-- lib/features/pool/domain/pool_cues.dart (the referee plays with it; a
-- test checks the tiers, prices and upgrade costs here against it).

alter type public.ledger_entry_type add value if not exists 'pool_entry';
alter type public.ledger_entry_type add value if not exists 'pool_prize';
alter type public.ledger_entry_type add value if not exists 'pool_cue_upgrade';

-- ── Cues ────────────────────────────────────────────────────────────────

create table public.pool_cues (
  id   text primary key,
  tier text not null check (tier in ('regular', 'rare', 'epic', 'legendary', 'mythic')),
  sort int not null
);

comment on table public.pool_cues is 'Every pool cue and its tier (regular cues go to level 5, animated ones to 10). Stats per level: lib/features/pool/domain/pool_cues.dart.';

alter table public.pool_cues enable row level security;
revoke insert, update, delete on public.pool_cues from anon, authenticated;
create policy "anyone can read the cues" on public.pool_cues for select using (true);

insert into public.pool_cues (id, tier, sort) values
  ('cue_classic', 'regular', 1),
  ('cue_oak', 'regular', 2),
  ('cue_carbon', 'regular', 3),
  ('cue_ivory', 'regular', 4),
  ('cue_neon', 'rare', 5),
  ('cue_frost', 'rare', 6),
  ('cue_inferno', 'epic', 7),
  ('cue_thunder', 'epic', 8),
  ('cue_galaxy', 'legendary', 9),
  ('cue_phoenix', 'legendary', 10),
  ('cue_prism', 'mythic', 11),
  ('cue_dragon', 'mythic', 12);

insert into public.store_coin_prices (product_id, item_ids, coins, sort) values
  ('utopia.cue.oak', array['cue_oak'], 20000, 40),
  ('utopia.cue.carbon', array['cue_carbon'], 30000, 41),
  ('utopia.cue.ivory', array['cue_ivory'], 40000, 42),
  ('utopia.cue.neon', array['cue_neon'], 50000, 43),
  ('utopia.cue.frost', array['cue_frost'], 50000, 44),
  ('utopia.cue.inferno', array['cue_inferno'], 80000, 45),
  ('utopia.cue.thunder', array['cue_thunder'], 80000, 46),
  ('utopia.cue.galaxy', array['cue_galaxy'], 120000, 47),
  ('utopia.cue.phoenix', array['cue_phoenix'], 120000, 48),
  ('utopia.cue.prism', array['cue_prism'], 200000, 49),
  ('utopia.cue.dragon', array['cue_dragon'], 200000, 50);

-- The classic cue is everyone's, like the classic piece sets.
create or replace function public._free_item(p_item_id text)
returns boolean
language sql
immutable
as $$
  select p_item_id in (
    'utopia_calm', 'utopia_warm', 'utopia_adventure',
    'azure_dusk', 'noir', 'classic', 'bubble', 'cue_classic'
  );
$$;

create function public._pool_cue_max_level(p_tier text)
returns int
language sql
immutable
as $$
  select case when p_tier = 'regular' then 5 else 10 end;
$$;

-- What taking a cue of [p_tier] from [p_level] to the next costs, or null
-- at its top level (cueUpgradeCost in pool_cues.dart agrees).
create function public._pool_cue_upgrade_cost(p_tier text, p_level int)
returns bigint
language sql
immutable
as $$
  select case
    when p_level < 1 or p_level >= public._pool_cue_max_level(p_tier) then null
    when p_tier = 'regular' then (array[2000, 4000, 7000, 12000])[p_level]
    else (array[3000, 5000, 8000, 12000, 17000, 23000, 30000, 40000, 50000])[p_level]
         * (case p_tier when 'rare' then 4 when 'epic' then 5 when 'legendary' then 6 else 8 end)
         / 4
  end::bigint;
$$;

alter table public.profiles
  add column equipped_pool_cue text not null default 'cue_classic';

comment on column public.profiles.equipped_pool_cue is 'The pool cue this player plays with (one they own; the server checks when a game starts).';

-- Others see the cue someone plays with, as they see their piece sets.
grant select (equipped_pool_cue) on public.profiles to anon, authenticated;

create table public.user_pool_cues (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  cue_id     text not null references public.pool_cues (id),
  level      int not null check (level >= 1),
  updated_at timestamptz not null default now(),
  primary key (user_id, cue_id)
);

comment on table public.user_pool_cues is 'The level each player has taken each cue to (level 1 when there''s no row). Written by upgrade_pool_cue only.';

alter table public.user_pool_cues enable row level security;
revoke insert, update, delete on public.user_pool_cues from anon, authenticated;
create policy "players read their own cue levels" on public.user_pool_cues
  for select using (user_id = auth.uid());

-- Whether [p_user] may play with [p_cue] now: theirs for good, free, or
-- lent to them (the welcome pass).
create function public._pool_has_cue(p_user uuid, p_cue text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public._free_item(p_cue)
      or exists (select 1 from public.user_entitlements e
                  where e.user_id = p_user and e.item_id = p_cue)
      or exists (select 1 from public.world_rentals r
                  where r.user_id = p_user and r.world_id = p_cue and r.expires_at > now());
$$;

revoke all on function public._pool_has_cue(uuid, text) from public, anon, authenticated;

-- Takes a cue the player owns for good up a level, for coins. Returns its
-- new level.
create function public.upgrade_pool_cue(p_cue_id text)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_tier text;
  v_level int;
  v_cost bigint;
  v_balance bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select tier into v_tier from public.pool_cues where id = p_cue_id;
  if v_tier is null then raise exception 'unknown cue'; end if;
  -- A cue only lent for a while isn't upgraded: the coins would go with it.
  if not public._free_item(p_cue_id) and not exists (
    select 1 from public.user_entitlements where user_id = v_me and item_id = p_cue_id
  ) then
    raise exception 'buy the cue to upgrade it';
  end if;

  select balance into v_balance from public.profiles where id = v_me for update;
  select level into v_level from public.user_pool_cues
   where user_id = v_me and cue_id = p_cue_id;
  v_level := coalesce(v_level, 1);
  v_cost := public._pool_cue_upgrade_cost(v_tier, v_level);
  if v_cost is null then raise exception 'that cue is at its top level'; end if;
  if v_balance < v_cost then raise exception 'insufficient balance'; end if;

  perform public._ledger_move(
    v_me,
    'pool_cue_upgrade',
    -v_cost,
    null,
    jsonb_build_object('cue', p_cue_id, 'level', v_level + 1)
  );
  insert into public.user_pool_cues (user_id, cue_id, level)
    values (v_me, p_cue_id, v_level + 1)
    on conflict (user_id, cue_id)
      do update set level = excluded.level, updated_at = now();
  return v_level + 1;
end;
$$;

revoke all on function public.upgrade_pool_cue(text) from public, anon;
grant execute on function public.upgrade_pool_cue(text) to authenticated;

-- Equipping: as before, plus the pool cue.
create or replace function public.equip_item(p_kind text, p_item_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not public._free_item(p_item_id)
     and not exists (
       select 1 from public.user_entitlements where user_id = v_me and item_id = p_item_id
     )
     and not exists (
       select 1 from public.world_rentals
       where user_id = v_me and world_id = p_item_id and expires_at > now()
     ) then
    raise exception 'you don''t own that yet';
  end if;

  case p_kind
    when 'theme' then update public.profiles set equipped_theme = p_item_id where id = v_me;
    when 'ludo_pieces' then update public.profiles set equipped_ludo_pieces = p_item_id where id = v_me;
    when 'chess_pieces' then update public.profiles set equipped_chess_pieces = p_item_id where id = v_me;
    when 'pool_cue' then
      if not exists (select 1 from public.pool_cues where id = p_item_id) then
        raise exception 'unknown cue';
      end if;
      update public.profiles set equipped_pool_cue = p_item_id where id = v_me;
    else raise exception 'invalid item kind';
  end case;
end;
$$;

-- ── The coin tables ─────────────────────────────────────────────────────

create table public.pool_tables (
  id            text primary key,
  entry         bigint not null check (entry > 0),
  prize         bigint not null check (prize > entry),
  bot           text not null check (bot in ('easy', 'normal', 'hard')),
  bot_cue       text not null references public.pool_cues (id),
  bot_cue_level int not null check (bot_cue_level >= 1),
  sort          int not null
);

comment on table public.pool_tables is 'The pool tables where you play Chip for coins: the entry, the pot the winner takes (twice the entry, less 5%), and Chip''s level and cue there.';

alter table public.pool_tables enable row level security;
revoke insert, update, delete on public.pool_tables from anon, authenticated;
create policy "anyone can read the tables" on public.pool_tables for select using (true);

insert into public.pool_tables (id, entry, prize, bot, bot_cue, bot_cue_level, sort) values
  ('lagoon', 200, 380, 'easy', 'cue_classic', 1, 1),
  ('dunes', 1000, 1900, 'normal', 'cue_oak', 3, 2),
  ('neon', 5000, 9500, 'hard', 'cue_carbon', 4, 3),
  ('summit', 25000, 47500, 'hard', 'cue_inferno', 6, 4);

create table public.pool_games (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  table_id      text not null references public.pool_tables (id),
  entry         bigint not null,
  prize         bigint not null,
  bot           text not null,
  bot_cue       text not null,
  bot_cue_level int not null,
  cue_id        text not null,
  cue_level     int not null,
  state         jsonb not null,
  shots         int not null default 0,
  status        text not null default 'active' check (status in ('active', 'won', 'lost')),
  result        text,
  last_play     jsonb,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  ended_at      timestamptz
);

comment on table public.pool_games is 'A game against Chip at a pool coin table. state is the table as the server holds it (PoolGame JSON, the player is 0 and Chip 1); the cues are fixed when it starts. Written by the pool-table function (pool_open, pool_record) and pool_resign only.';
comment on column public.pool_games.last_play is 'The last shot played ({by, shot, place, called}), for an app catching up.';

create unique index pool_games_one_active on public.pool_games (user_id) where status = 'active';
create index pool_games_user_idx on public.pool_games (user_id, created_at desc);

alter table public.pool_games enable row level security;
revoke insert, update, delete on public.pool_games from anon, authenticated;
create policy "players read their own pool games" on public.pool_games
  for select using (user_id = auth.uid());

-- A new game for [p_user] at [p_table], racked as [p_state] (by the
-- referee): the entry paid, a game they'd left unfinished lost, and their
-- cue (one they may play with, else the classic) fixed for the game.
create function public.pool_open(p_user uuid, p_table text, p_state jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_table public.pool_tables;
  v_balance bigint;
  v_cue text;
  v_level int;
  v_id uuid;
begin
  select * into v_table from public.pool_tables where id = p_table;
  if v_table is null then raise exception 'unknown table'; end if;
  select balance, equipped_pool_cue into v_balance, v_cue
    from public.profiles where id = p_user for update;
  if v_balance is null then raise exception 'no profile'; end if;

  -- One game at a time: one left unfinished is lost (its entry went in
  -- when it began).
  update public.pool_games
     set status = 'lost', result = 'abandoned', ended_at = now(), updated_at = now()
   where user_id = p_user and status = 'active';

  if v_balance < v_table.entry then raise exception 'insufficient balance'; end if;

  if v_cue is null
     or not exists (select 1 from public.pool_cues where id = v_cue)
     or not public._pool_has_cue(p_user, v_cue) then
    v_cue := 'cue_classic';
  end if;
  select least(coalesce(u.level, 1), public._pool_cue_max_level(c.tier))
    into v_level
    from public.pool_cues c
    left join public.user_pool_cues u on u.user_id = p_user and u.cue_id = c.id
   where c.id = v_cue;

  perform public._ledger_move(
    p_user,
    'pool_entry',
    -v_table.entry,
    null,
    jsonb_build_object('table', p_table)
  );
  insert into public.pool_games (
    user_id, table_id, entry, prize, bot, bot_cue, bot_cue_level,
    cue_id, cue_level, state
  ) values (
    p_user, p_table, v_table.entry, v_table.prize, v_table.bot,
    v_table.bot_cue, v_table.bot_cue_level, v_cue, v_level, p_state
  ) returning id into v_id;
  return v_id;
end;
$$;

-- A shot the referee played on game [p_game] at shot [p_shots] (the table
-- it judged is still the game's): the table after it, what was played,
-- and, when it ended the game, who won (0 the player, 1 Chip) and how.
-- The winner's pot is paid here. Returns {status, prize, shots}.
create function public.pool_record(
  p_game uuid,
  p_shots int,
  p_state jsonb,
  p_play jsonb,
  p_winner int,
  p_win text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game public.pool_games;
  v_status text;
begin
  select * into v_game from public.pool_games where id = p_game for update;
  if v_game is null then raise exception 'game not found'; end if;
  if v_game.status <> 'active' then raise exception 'game is over'; end if;
  if v_game.shots <> p_shots then raise exception 'out of sync'; end if;

  v_status := case when p_winner is null then 'active'
                   when p_winner = 0 then 'won'
                   else 'lost' end;
  update public.pool_games
     set state = p_state,
         shots = shots + 1,
         last_play = p_play,
         status = v_status,
         result = case when p_winner is null then null else p_win end,
         ended_at = case when p_winner is null then null else now() end,
         updated_at = now()
   where id = p_game;

  if v_status = 'won' then
    perform public._ledger_move(
      v_game.user_id,
      'pool_prize',
      v_game.prize,
      null,
      jsonb_build_object('table', v_game.table_id, 'game', p_game)
    );
  end if;
  return jsonb_build_object(
    'status', v_status,
    'prize', case when v_status = 'won' then v_game.prize else 0 end,
    'shots', p_shots + 1
  );
end;
$$;

revoke all on function public.pool_open(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.pool_open(uuid, text, jsonb) to service_role;
revoke all on function public.pool_record(uuid, int, jsonb, jsonb, int, text) from public, anon, authenticated;
grant execute on function public.pool_record(uuid, int, jsonb, jsonb, int, text) to service_role;

-- The player gives their game up: Chip wins it.
create function public.pool_resign(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.pool_games
     set status = 'lost', result = 'resign', ended_at = now(), updated_at = now()
   where id = p_game and user_id = auth.uid() and status = 'active';
end;
$$;

revoke all on function public.pool_resign(uuid) from public, anon;
grant execute on function public.pool_resign(uuid) to authenticated;
