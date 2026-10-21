-- Crazy Eights, Utopia's first card game: 2 to 6 players, online (quick
-- match for 2, 3 or 4), in a friend room joined by code, with the same
-- chat, voice notes, turn timers and coin entries as Ludo.
--
-- Unlike Ludo, the server keeps the game: a card game has hidden hands, so
-- the deck lives in eights_decks (no client can read it) and each hand in
-- eights_hands (only its owner can read it). Players act through the
-- functions below, which check every move; the match row's state is what
-- everyone sees (see EightsTable in lib/features/eights/domain):
--
--   counts  cards in each seat's hand      turn   seat on turn (0-based)
--   top     top card of the pile ("QS")    suit   suit to follow (S/H/D/C)
--   draw    cards left to draw             drawn  the player on turn drew
--   seq     goes up with every action      last   {seat, kind, card, suit}
--   left    seats that are out             winner seat that went out first
--
-- Rules: match the suit or rank on top, or play an eight (wild) and name a
-- suit. Can't, or won't? Draw one, then play or pass. First out wins the
-- pot. Two players get seven cards each, more get five.

-- ── matches, hands and the deck ───────────────────────────────────────────

create table public.eights_matches (
  id             uuid primary key default gen_random_uuid(),
  status         public.match_status not null default 'active',
  stake          bigint not null default 0 check (stake >= 0),
  commission_bps int not null default 0,
  players        uuid[] not null check (cardinality(players) between 2 and 6),
  mode           text not null default 'public' check (mode in ('public', 'friends')),
  state          jsonb not null,
  turn_count     int not null default 0,
  missed_turns   jsonb not null default '{}'::jsonb,
  winner_id      uuid references public.profiles (id),
  result         text,
  created_at     timestamptz not null default now(),
  started_at     timestamptz not null default now(),
  ended_at       timestamptz,
  updated_at     timestamptz not null default now()
);

comment on table public.eights_matches is 'One Crazy Eights game. state is what every player sees (EightsTable); hands and the deck are kept apart (eights_hands, eights_decks). players[i] sits in seat i.';
comment on column public.eights_matches.missed_turns is 'Turns each seat has let run out in a row ({"1": 2}); reset when they act, three and they are out.';

create index eights_matches_players_idx on public.eights_matches using gin (players);

create table public.eights_hands (
  match_id uuid not null references public.eights_matches (id) on delete cascade,
  user_id  uuid not null references public.profiles (id) on delete cascade,
  seat     int not null,
  cards    text[] not null default '{}',
  primary key (match_id, user_id)
);

comment on table public.eights_hands is 'Each player''s cards, readable only by that player.';

create table public.eights_decks (
  match_id  uuid primary key references public.eights_matches (id) on delete cascade,
  draw_pile text[] not null default '{}',
  discard   text[] not null default '{}'
);

comment on table public.eights_decks is 'The cards no one may see: what''s left to draw (drawn from the end) and the played cards under the top one. No client access at all.';

alter table public.eights_matches enable row level security;
alter table public.eights_hands enable row level security;
alter table public.eights_decks enable row level security;
revoke insert, update, delete on public.eights_matches from authenticated, anon;
revoke insert, update, delete on public.eights_hands from authenticated, anon;
revoke all on public.eights_decks from authenticated, anon;

create policy "select own eights matches" on public.eights_matches
  for select using (auth.uid() = any (players));
create policy "select own eights hand" on public.eights_hands
  for select using (user_id = auth.uid());

create function public._is_eights_player(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.eights_matches where id = p_match_id and auth.uid() = any (players)
  );
$$;

revoke all on function public._is_eights_player(uuid) from public, anon;
grant execute on function public._is_eights_player(uuid) to authenticated;

-- ── cards ─────────────────────────────────────────────────────────────────

-- A fresh deck, shuffled: "AS", "2S" ... "TS" (ten), "JS", "QS", "KS", and
-- the same for H, D and C.
create function public._eights_shuffled_deck()
returns text[]
language sql
volatile
as $$
  select array_agg(r || s order by random())
  from unnest(array['A','2','3','4','5','6','7','8','9','T','J','Q','K']) as r,
       unnest(array['S','H','D','C']) as s;
$$;

-- The next seat after p_from that's still in the game.
create function public._eights_next_seat(p_seats int, p_left jsonb, p_from int)
returns int
language plpgsql
immutable
as $$
declare
  v_next int;
begin
  for i in 1..p_seats loop
    v_next := (p_from + i) % p_seats;
    exit when not coalesce(p_left, '[]'::jsonb) @> jsonb_build_array(v_next);
  end loop;
  return v_next;
end;
$$;

-- The state with seat p_seat holding p_count cards.
create function public._eights_count(p_state jsonb, p_seat int, p_count int)
returns jsonb
language sql
immutable
as $$
  select jsonb_set(p_state, array['counts', p_seat::text], to_jsonb(p_count));
$$;

-- Takes the card off the top of the draw pile (shuffling the played cards
-- back in when it's empty). Null when there's nothing at all to draw.
create function public._eights_take_card(p_match_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deck public.eights_decks;
  v_pile text[];
  v_card text;
begin
  select * into v_deck from public.eights_decks where match_id = p_match_id for update;
  v_pile := v_deck.draw_pile;
  if coalesce(cardinality(v_pile), 0) = 0 then
    select coalesce(array_agg(c order by random()), '{}') into v_pile
      from unnest(v_deck.discard) as c;
    update public.eights_decks set discard = '{}' where match_id = p_match_id;
  end if;
  if coalesce(cardinality(v_pile), 0) = 0 then
    update public.eights_decks set draw_pile = '{}' where match_id = p_match_id;
    return null;
  end if;
  v_card := v_pile[cardinality(v_pile)];
  update public.eights_decks
    set draw_pile = v_pile[1:cardinality(v_pile) - 1]
    where match_id = p_match_id;
  return v_card;
end;
$$;

create function public._eights_draw_count(p_match_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(cardinality(draw_pile), 0) from public.eights_decks where match_id = p_match_id;
$$;

-- Deals a new game for p_players (seat order) and takes their entries.
create function public._eights_create_match(p_players uuid[], p_stake bigint, p_mode text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int := cardinality(p_players);
  v_size int := case when cardinality(p_players) = 2 then 7 else 5 end;
  v_deck text[] := public._eights_shuffled_deck();
  v_rest text[];
  v_top text;
  v_first int := floor(random() * cardinality(p_players))::int;
  v_match_id uuid;
  v_player uuid;
begin
  if v_n not between 2 and 6 then raise exception 'crazy eights is 2-6 players'; end if;

  -- What isn't dealt is the draw pile; the last card that isn't an eight
  -- starts the discard pile.
  v_rest := v_deck[v_n * v_size + 1 : 52];
  for i in reverse cardinality(v_rest)..1 loop
    if left(v_rest[i], 1) <> '8' then
      v_top := v_rest[i];
      v_rest := v_rest[1 : i - 1] || v_rest[i + 1 :];
      exit;
    end if;
  end loop;

  insert into public.eights_matches (players, mode, stake, state)
  values (
    p_players, p_mode, p_stake,
    jsonb_build_object(
      'counts', (select jsonb_agg(v_size) from generate_series(1, v_n)),
      'turn', v_first,
      'top', v_top,
      'suit', right(v_top, 1),
      'draw', cardinality(v_rest),
      'drawn', false,
      'seq', 0,
      'last', jsonb_build_object('seat', v_first, 'kind', 'deal', 'card', null, 'suit', null),
      'left', '[]'::jsonb,
      'winner', null
    )
  ) returning id into v_match_id;

  for i in 1..v_n loop
    insert into public.eights_hands (match_id, user_id, seat, cards)
      values (v_match_id, p_players[i], i - 1, v_deck[(i - 1) * v_size + 1 : i * v_size]);
  end loop;
  insert into public.eights_decks (match_id, draw_pile) values (v_match_id, v_rest);

  if p_stake > 0 then
    foreach v_player in array p_players loop
      perform public._ledger_move(v_player, 'match_stake', -p_stake, v_match_id);
    end loop;
    update public.profiles set lifetime_wagered = lifetime_wagered + p_stake
      where id = any (p_players);
  end if;

  return v_match_id;
end;
$$;

-- ── settling and leaving ──────────────────────────────────────────────────

-- Pays the pot to the winner (or refunds everyone) and ends the game.
create function public._settle_eights(p_match_id uuid, p_winner_id uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.eights_matches;
  v_pot bigint;
  v_commission bigint;
  v_player uuid;
begin
  select * into v_match from public.eights_matches where id = p_match_id for update;
  if v_match.status <> 'active' then return; end if;

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

  update public.eights_matches
    set status = 'completed', winner_id = p_winner_id, result = p_result,
        ended_at = now(), updated_at = now(),
        state = state || jsonb_build_object(
          'winner', array_position(players, p_winner_id) - 1)
    where id = p_match_id;
end;
$$;

-- A player out of the game (they left, or ran out of time three times):
-- their cards go back under the draw pile and play goes on without them;
-- with one player left, that player wins.
create function public._eights_remove_player(p_match_id uuid, p_user uuid, p_result text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.eights_matches;
  v_seat int;
  v_state jsonb;
  v_left jsonb;
  v_hand text[];
  v_active int[];
  v_n int;
begin
  select * into v_match from public.eights_matches where id = p_match_id for update;
  if v_match is null or v_match.status <> 'active' then return; end if;
  v_seat := array_position(v_match.players, p_user) - 1;
  if v_seat is null then raise exception 'not a player in this match'; end if;
  v_state := v_match.state;
  v_left := coalesce(v_state -> 'left', '[]'::jsonb);
  if v_left @> jsonb_build_array(v_seat) then return; end if;
  v_left := v_left || to_jsonb(v_seat);
  v_n := cardinality(v_match.players);

  select cards into v_hand from public.eights_hands
    where match_id = p_match_id and user_id = p_user for update;
  update public.eights_hands set cards = '{}' where match_id = p_match_id and user_id = p_user;
  update public.eights_decks set draw_pile = coalesce(v_hand, '{}') || draw_pile
    where match_id = p_match_id;

  v_state := public._eights_count(v_state, v_seat, 0) || jsonb_build_object(
    'left', v_left,
    'draw', public._eights_draw_count(p_match_id),
    'seq', coalesce((v_state ->> 'seq')::int, 0) + 1,
    'last', jsonb_build_object('seat', v_seat, 'kind', 'left', 'card', null, 'suit', null)
  );
  if (v_state ->> 'turn')::int = v_seat then
    v_state := v_state || jsonb_build_object(
      'turn', public._eights_next_seat(v_n, v_left, v_seat), 'drawn', false);
  end if;

  select array_agg(s) into v_active from generate_series(0, v_n - 1) as s
    where not v_left @> jsonb_build_array(s);

  update public.eights_matches
    set state = v_state, updated_at = now(), turn_count = turn_count + 1
    where id = p_match_id;

  if coalesce(cardinality(v_active), 0) <= 1 then
    perform public._settle_eights(
      p_match_id, v_match.players[v_active[1] + 1], p_result);
  end if;
end;
$$;

revoke all on function public._eights_shuffled_deck() from public, anon, authenticated;
revoke all on function public._eights_take_card(uuid) from public, anon, authenticated;
revoke all on function public._eights_draw_count(uuid) from public, anon, authenticated;
revoke all on function public._eights_create_match(uuid[], bigint, text) from public, anon, authenticated;
revoke all on function public._settle_eights(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public._eights_remove_player(uuid, uuid, text) from public, anon, authenticated;

-- ── playing ───────────────────────────────────────────────────────────────

-- The caller's seat at p_match (locked by the caller), checking it's
-- theirs to act on now.
create function public._eights_my_seat(p_match public.eights_matches)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_seat int;
begin
  if p_match.id is null then raise exception 'match not found'; end if;
  if not (auth.uid() = any (p_match.players)) then raise exception 'not a player in this match'; end if;
  if p_match.status <> 'active' then raise exception 'match is not active'; end if;
  v_seat := array_position(p_match.players, auth.uid()) - 1;
  if (p_match.state ->> 'turn')::int <> v_seat then raise exception 'not your turn'; end if;
  return v_seat;
end;
$$;

revoke all on function public._eights_my_seat(public.eights_matches) from public, anon, authenticated;

-- Plays p_card from your hand (naming p_suit for an eight). Returns your
-- hand afterwards.
create function public.play_eights_card(p_match_id uuid, p_card text, p_suit text default null)
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.eights_matches;
  v_seat int;
  v_state jsonb;
  v_hand text[];
  v_top text;
  v_eight boolean := left(p_card, 1) = '8';
  v_out boolean;
begin
  select * into v_match from public.eights_matches where id = p_match_id for update;
  v_seat := public._eights_my_seat(v_match);
  v_state := v_match.state;

  select cards into v_hand from public.eights_hands
    where match_id = p_match_id and user_id = v_me for update;
  if not (p_card = any (v_hand)) then raise exception 'not in your hand'; end if;

  v_top := v_state ->> 'top';
  if not v_eight and right(p_card, 1) <> v_state ->> 'suit'
     and left(p_card, 1) <> left(v_top, 1) then
    raise exception 'that card doesn''t go';
  end if;
  if v_eight and (p_suit is null or p_suit not in ('S', 'H', 'D', 'C')) then
    raise exception 'name a suit for the eight';
  end if;

  v_hand := array_remove(v_hand, p_card);
  v_out := cardinality(v_hand) = 0;
  update public.eights_hands set cards = v_hand where match_id = p_match_id and user_id = v_me;
  update public.eights_decks set discard = discard || v_top where match_id = p_match_id;

  v_state := public._eights_count(v_state, v_seat, cardinality(v_hand)) || jsonb_build_object(
    'top', p_card,
    'suit', case when v_eight then p_suit else right(p_card, 1) end,
    'turn', case when v_out then v_seat
                 else public._eights_next_seat(cardinality(v_match.players), v_state -> 'left', v_seat) end,
    'drawn', false,
    'seq', coalesce((v_state ->> 'seq')::int, 0) + 1,
    'last', jsonb_build_object('seat', v_seat, 'kind', 'play', 'card', p_card,
                               'suit', case when v_eight then p_suit end),
    'winner', case when v_out then v_seat end
  );
  update public.eights_matches
    set state = v_state, turn_count = turn_count + 1, updated_at = now(),
        missed_turns = missed_turns - v_seat::text
    where id = p_match_id;

  if v_out then perform public._settle_eights(p_match_id, v_me, 'win'); end if;
  return v_hand;
end;
$$;

-- Draws a card (once a turn). Returns your hand afterwards. With nothing
-- left to draw at all, the turn passes.
create function public.draw_eights_card(p_match_id uuid)
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.eights_matches;
  v_seat int;
  v_state jsonb;
  v_card text;
  v_hand text[];
begin
  select * into v_match from public.eights_matches where id = p_match_id for update;
  v_seat := public._eights_my_seat(v_match);
  v_state := v_match.state;
  if coalesce((v_state ->> 'drawn')::boolean, false) then raise exception 'you already drew'; end if;

  v_card := public._eights_take_card(p_match_id);
  if v_card is null then
    v_state := v_state || jsonb_build_object(
      'turn', public._eights_next_seat(cardinality(v_match.players), v_state -> 'left', v_seat),
      'drawn', false, 'draw', 0,
      'seq', coalesce((v_state ->> 'seq')::int, 0) + 1,
      'last', jsonb_build_object('seat', v_seat, 'kind', 'pass', 'card', null, 'suit', null));
    update public.eights_matches
      set state = v_state, turn_count = turn_count + 1, updated_at = now(),
          missed_turns = missed_turns - v_seat::text
      where id = p_match_id;
    select cards into v_hand from public.eights_hands where match_id = p_match_id and user_id = v_me;
    return v_hand;
  end if;

  update public.eights_hands set cards = cards || v_card
    where match_id = p_match_id and user_id = v_me
    returning cards into v_hand;
  v_state := public._eights_count(v_state, v_seat, cardinality(v_hand)) || jsonb_build_object(
    'draw', public._eights_draw_count(p_match_id),
    'drawn', true,
    'seq', coalesce((v_state ->> 'seq')::int, 0) + 1,
    'last', jsonb_build_object('seat', v_seat, 'kind', 'draw', 'card', null, 'suit', null));
  update public.eights_matches
    set state = v_state, updated_at = now(), missed_turns = missed_turns - v_seat::text
    where id = p_match_id;
  return v_hand;
end;
$$;

-- Having drawn, passes the turn on.
create function public.pass_eights_turn(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.eights_matches;
  v_seat int;
  v_state jsonb;
begin
  select * into v_match from public.eights_matches where id = p_match_id for update;
  v_seat := public._eights_my_seat(v_match);
  v_state := v_match.state;
  if not coalesce((v_state ->> 'drawn')::boolean, false) then
    raise exception 'draw a card first';
  end if;
  v_state := v_state || jsonb_build_object(
    'turn', public._eights_next_seat(cardinality(v_match.players), v_state -> 'left', v_seat),
    'drawn', false,
    'seq', coalesce((v_state ->> 'seq')::int, 0) + 1,
    'last', jsonb_build_object('seat', v_seat, 'kind', 'pass', 'card', null, 'suit', null));
  update public.eights_matches
    set state = v_state, turn_count = turn_count + 1, updated_at = now(),
        missed_turns = missed_turns - v_seat::text
    where id = p_match_id;
end;
$$;

-- The player on turn ran out of time (20 seconds a go; 40 among friends):
-- they draw a card, if they hadn't, and the turn passes. Three in a row
-- and they're out. Anyone at the table can call it; p_seq names the action
-- that timed out, so a late call can't skip the next one.
create function public.skip_eights_turn(p_match_id uuid, p_seq int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.eights_matches;
  v_state jsonb;
  v_seat int;
  v_user uuid;
  v_missed int;
  v_card text;
  v_hand text[];
  v_turn interval;
begin
  select * into v_match from public.eights_matches where id = p_match_id for update;
  if v_match is null then raise exception 'match not found'; end if;
  if not (auth.uid() = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then return true; end if;
  v_state := v_match.state;
  if coalesce((v_state ->> 'seq')::int, 0) <> p_seq then return true; end if;
  v_turn := case when v_match.mode = 'friends' then interval '40 seconds'
                 else interval '20 seconds' end;
  if v_match.updated_at > now() - v_turn then return false; end if;

  v_seat := (v_state ->> 'turn')::int;
  v_user := v_match.players[v_seat + 1];
  v_missed := coalesce((v_match.missed_turns ->> v_seat::text)::int, 0) + 1;
  update public.eights_matches
    set missed_turns = missed_turns || jsonb_build_object(v_seat::text, v_missed)
    where id = p_match_id;

  if v_missed >= 3 then
    perform public._eights_remove_player(p_match_id, v_user, 'timeout');
    return true;
  end if;

  if not coalesce((v_state ->> 'drawn')::boolean, false) then
    v_card := public._eights_take_card(p_match_id);
    if v_card is not null then
      update public.eights_hands set cards = cards || v_card
        where match_id = p_match_id and user_id = v_user
        returning cards into v_hand;
      v_state := public._eights_count(v_state, v_seat, cardinality(v_hand));
    end if;
  end if;
  v_state := v_state || jsonb_build_object(
    'turn', public._eights_next_seat(cardinality(v_match.players), v_state -> 'left', v_seat),
    'drawn', false,
    'draw', public._eights_draw_count(p_match_id),
    'seq', coalesce((v_state ->> 'seq')::int, 0) + 1,
    'last', jsonb_build_object('seat', v_seat, 'kind', 'timeout', 'card', null, 'suit', null));
  update public.eights_matches
    set state = v_state, turn_count = turn_count + 1, updated_at = now()
    where id = p_match_id;
  return true;
end;
$$;

-- Leaves the game for good: a forfeit.
create function public.resign_eights_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.eights_matches;
begin
  select * into v_match from public.eights_matches where id = p_match_id;
  if v_match is null then raise exception 'match not found'; end if;
  if not (auth.uid() = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if v_match.status <> 'active' then return; end if;
  perform public._eights_remove_player(p_match_id, auth.uid(), 'resignation');
end;
$$;

revoke all on function public.play_eights_card(uuid, text, text) from public, anon;
revoke all on function public.draw_eights_card(uuid) from public, anon;
revoke all on function public.pass_eights_turn(uuid) from public, anon;
revoke all on function public.skip_eights_turn(uuid, int) from public, anon;
revoke all on function public.resign_eights_match(uuid) from public, anon;
grant execute on function public.play_eights_card(uuid, text, text) to authenticated;
grant execute on function public.draw_eights_card(uuid) to authenticated;
grant execute on function public.pass_eights_turn(uuid) to authenticated;
grant execute on function public.skip_eights_turn(uuid, int) to authenticated;
grant execute on function public.resign_eights_match(uuid) to authenticated;

-- Games gone quiet for ten minutes: whoever's on turn is out.
create function public.forfeit_abandoned_eights_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match record;
begin
  for v_match in
    select * from public.eights_matches
      where status = 'active' and updated_at < now() - interval '10 minutes'
  loop
    perform public._eights_remove_player(
      v_match.id,
      v_match.players[(v_match.state ->> 'turn')::int + 1],
      'timeout');
  end loop;
end;
$$;

revoke all on function public.forfeit_abandoned_eights_matches() from public, anon, authenticated;

select cron.schedule(
  'forfeit-abandoned-eights-matches',
  '*/5 * * * *',
  $$select public.forfeit_abandoned_eights_matches();$$
);

-- ── quick match: 2, 3 or 4 players ────────────────────────────────────────

create table public.eights_matchmaking_queue (
  user_id   uuid primary key references public.profiles (id) on delete cascade,
  stake     bigint not null check (stake >= 0),
  size      int not null default 2 check (size between 2 and 4),
  queued_at timestamptz not null default now()
);

alter table public.eights_matchmaking_queue enable row level security;
revoke all on public.eights_matchmaking_queue from authenticated, anon;

-- Joins quick match. Returns the new match id if this join filled a
-- table, else null (the other players' joins will; watch for the match).
create function public.join_eights_matchmaking_queue(p_stake bigint, p_size int default 2)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_balance bigint;
  v_group uuid[];
  v_match_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_size not between 2 and 4 then raise exception 'quick match is 2 to 4 players'; end if;
  if p_stake < 0 then raise exception 'invalid stake'; end if;

  select balance into v_balance from public.profiles where id = v_me;
  if v_balance is null or v_balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  insert into public.eights_matchmaking_queue (user_id, stake, size)
    values (v_me, p_stake, p_size)
    on conflict (user_id) do update
      set stake = excluded.stake, size = excluded.size, queued_at = now();

  select array_agg(user_id order by queued_at) into v_group
    from (
      select user_id, queued_at
        from public.eights_matchmaking_queue
        where stake = p_stake and size = p_size
        order by queued_at
        limit p_size
        for update skip locked
    ) waiting;

  if coalesce(cardinality(v_group), 0) < p_size then
    return null;
  end if;

  delete from public.eights_matchmaking_queue where user_id = any (v_group);
  v_match_id := public._eights_create_match(v_group, p_stake, 'public');
  return case when v_me = any (v_group) then v_match_id else null end;
end;
$$;

create function public.leave_eights_matchmaking_queue()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.eights_matchmaking_queue where user_id = auth.uid();
$$;

revoke all on function public.join_eights_matchmaking_queue(bigint, int) from public, anon;
revoke all on function public.leave_eights_matchmaking_queue() from public, anon;
grant execute on function public.join_eights_matchmaking_queue(bigint, int) to authenticated;
grant execute on function public.leave_eights_matchmaking_queue() to authenticated;

-- ── friend rooms ──────────────────────────────────────────────────────────

create table public.eights_rooms (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique check (code ~ '^[A-Z0-9]{6}$'),
  host_id     uuid not null references public.profiles (id) on delete cascade,
  stake       bigint not null default 0 check (stake >= 0),
  max_players int not null check (max_players between 2 and 6),
  status      text not null default 'open' check (status in ('open', 'started', 'closed')),
  match_id    uuid references public.eights_matches (id),
  created_at  timestamptz not null default now()
);

create table public.eights_room_members (
  room_id   uuid not null references public.eights_rooms (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  seat      int not null check (seat between 0 and 5),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id),
  unique (room_id, seat)
);

create index eights_room_members_user_idx on public.eights_room_members (user_id);

create function public._is_eights_room_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.eights_room_members where room_id = p_room_id and user_id = auth.uid()
  );
$$;

revoke all on function public._is_eights_room_member(uuid) from public, anon;
grant execute on function public._is_eights_room_member(uuid) to authenticated;

alter table public.eights_rooms enable row level security;
alter table public.eights_room_members enable row level security;
revoke insert, update, delete on public.eights_rooms from authenticated, anon;
revoke insert, update, delete on public.eights_room_members from authenticated, anon;

create policy "select eights rooms you are in" on public.eights_rooms
  for select using (public._is_eights_room_member(id));
create policy "select members of eights rooms you are in" on public.eights_room_members
  for select using (public._is_eights_room_member(room_id));

-- Leaves every open room the player is in (closing one they host alone, or
-- handing the host on), so they're only ever in one card-table lobby.
create function public._leave_open_eights_rooms(p_user uuid, p_except uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room record;
  v_next_host uuid;
begin
  for v_room in
    select r.* from public.eights_rooms r
      join public.eights_room_members m on m.room_id = r.id
      where m.user_id = p_user and r.status = 'open'
        and (p_except is null or r.id <> p_except)
      for update of r
  loop
    delete from public.eights_room_members where room_id = v_room.id and user_id = p_user;
    if v_room.host_id = p_user then
      select user_id into v_next_host from public.eights_room_members
        where room_id = v_room.id order by joined_at limit 1;
      if v_next_host is null then
        update public.eights_rooms set status = 'closed' where id = v_room.id;
      else
        update public.eights_rooms set host_id = v_next_host where id = v_room.id;
      end if;
    end if;
  end loop;
end;
$$;

revoke all on function public._leave_open_eights_rooms(uuid, uuid) from public, anon, authenticated;

create function public.create_eights_room(p_max_players int, p_stake bigint default 0)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_balance bigint;
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
  v_room_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_max_players not between 2 and 6 then raise exception 'rooms are 2-6 players'; end if;
  if p_stake < 0 then raise exception 'invalid stake'; end if;

  select balance into v_balance from public.profiles where id = v_me;
  if v_balance is null or v_balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  perform public._leave_open_eights_rooms(v_me);

  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.eights_rooms where code = v_code);
  end loop;

  insert into public.eights_rooms (code, host_id, stake, max_players)
    values (v_code, v_me, p_stake, p_max_players)
    returning id into v_room_id;
  insert into public.eights_room_members (room_id, user_id, seat) values (v_room_id, v_me, 0);

  return jsonb_build_object('id', v_room_id, 'code', v_code);
end;
$$;

create function public.join_eights_room(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room public.eights_rooms;
  v_count int;
  v_seat int;
  v_balance bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  select * into v_room from public.eights_rooms
    where code = upper(trim(p_code))
    for update;
  if v_room is null then raise exception 'no room with that code'; end if;

  if exists (select 1 from public.eights_room_members where room_id = v_room.id and user_id = v_me) then
    return v_room.id;
  end if;
  if v_room.status <> 'open' then raise exception 'that game has already started'; end if;

  select count(*) into v_count from public.eights_room_members where room_id = v_room.id;
  if v_count >= v_room.max_players then raise exception 'room is full'; end if;

  select balance into v_balance from public.profiles where id = v_me;
  if v_balance is null or v_balance < v_room.stake then
    raise exception 'insufficient balance';
  end if;

  perform public._leave_open_eights_rooms(v_me, v_room.id);

  select min(s) into v_seat from generate_series(0, v_room.max_players - 1) as s
    where s not in (select seat from public.eights_room_members where room_id = v_room.id);

  insert into public.eights_room_members (room_id, user_id, seat) values (v_room.id, v_me, v_seat);
  return v_room.id;
end;
$$;

create function public.leave_eights_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  perform public._leave_open_eights_rooms(auth.uid());
end;
$$;

create function public.start_eights_room(p_room_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_room public.eights_rooms;
  v_players uuid[];
  v_short text;
  v_match_id uuid;
begin
  select * into v_room from public.eights_rooms where id = p_room_id for update;
  if v_room is null then raise exception 'room not found'; end if;
  if v_room.host_id <> v_me then raise exception 'only the host can start the game'; end if;
  if v_room.status <> 'open' then raise exception 'that game has already started'; end if;

  select array_agg(user_id order by seat) into v_players
    from public.eights_room_members where room_id = p_room_id;
  if coalesce(cardinality(v_players), 0) < 2 then
    raise exception 'need at least 2 players';
  end if;

  if v_room.stake > 0 then
    select coalesce(username, display_name, 'a player') into v_short
      from public.profiles
      where id = any (v_players) and balance < v_room.stake
      limit 1;
    if v_short is not null then
      raise exception 'insufficient balance: %', v_short;
    end if;
  end if;

  v_match_id := public._eights_create_match(v_players, v_room.stake, 'friends');
  update public.eights_rooms set status = 'started', match_id = v_match_id where id = p_room_id;
  return v_match_id;
end;
$$;

revoke all on function public.create_eights_room(int, bigint) from public, anon;
revoke all on function public.join_eights_room(text) from public, anon;
revoke all on function public.leave_eights_room(uuid) from public, anon;
revoke all on function public.start_eights_room(uuid) from public, anon;
grant execute on function public.create_eights_room(int, bigint) to authenticated;
grant execute on function public.join_eights_room(text) to authenticated;
grant execute on function public.leave_eights_room(uuid) to authenticated;
grant execute on function public.start_eights_room(uuid) to authenticated;

-- ── chat ──────────────────────────────────────────────────────────────────

create table public.eights_chat_messages (
  id         bigint generated always as identity primary key,
  match_id   uuid not null references public.eights_matches (id) on delete cascade,
  sender_id  uuid not null references public.profiles (id) on delete cascade,
  kind       text not null default 'text' check (kind in ('text', 'quick', 'emote', 'voice')),
  body       text not null,
  created_at timestamptz not null default now()
);

create index eights_chat_messages_match_idx on public.eights_chat_messages (match_id, id);

alter table public.eights_chat_messages enable row level security;
revoke insert, update, delete on public.eights_chat_messages from authenticated, anon;
create policy "select chat of own eights matches" on public.eights_chat_messages
  for select using (public._is_eights_player(match_id));

-- Same as Ludo's: public games mask offensive words, friends' don't.
create function public.send_eights_chat(p_match_id uuid, p_kind text, p_body text)
returns public.eights_chat_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_match public.eights_matches;
  v_body text := btrim(p_body);
  v_recent int;
  v_row public.eights_chat_messages;
begin
  select * into v_match from public.eights_matches where id = p_match_id;
  if v_match is null then raise exception 'match not found'; end if;
  if not (v_me = any (v_match.players)) then raise exception 'not a player in this match'; end if;
  if p_kind not in ('text', 'quick', 'emote', 'voice') then raise exception 'invalid message kind'; end if;
  if v_body is null or char_length(v_body) = 0 then raise exception 'empty message'; end if;
  if char_length(v_body) > 200 then raise exception 'message too long'; end if;
  if p_kind = 'voice' and v_body !~ (
    '^voice:' || p_match_id::text || '/[0-9a-f-]{36}\.(m4a|wav)\|[0-9]{1,6}\|[0-9]{0,40}$'
  ) then
    raise exception 'invalid voice note';
  end if;

  select count(*) into v_recent from public.eights_chat_messages
    where match_id = p_match_id and sender_id = v_me
      and created_at > now() - interval '10 seconds';
  if v_recent >= 6 then raise exception 'slow down'; end if;

  if v_match.mode = 'public' and p_kind in ('text', 'quick') then
    v_body := public.mask_offensive(v_body);
  end if;

  insert into public.eights_chat_messages (match_id, sender_id, kind, body)
    values (p_match_id, v_me, p_kind, v_body)
    returning * into v_row;
  return v_row;
end;
$$;

revoke all on function public.send_eights_chat(uuid, text, text) from public, anon;
grant execute on function public.send_eights_chat(uuid, text, text) to authenticated;

-- Voice notes: a card game's players can use its folder too.
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
      or public._is_eights_player(p_folder::uuid);
end;
$$;

-- ── events and quests: a card game counts too ─────────────────────────────

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
  if p_game not in ('chess', 'checkers', 'ludo', 'doodle', 'eights') then
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
      when 'eights' then exists (
        select 1 from public.eights_matches
        where id = p_match and status = 'completed' and v_me = any (players))
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

-- ── realtime ──────────────────────────────────────────────────────────────

alter publication supabase_realtime add table public.eights_matches;
alter publication supabase_realtime add table public.eights_rooms;
alter publication supabase_realtime add table public.eights_room_members;
alter publication supabase_realtime add table public.eights_chat_messages;

-- ── player stats: card games too ──────────────────────────────────────────

create or replace function public.get_player_stats(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'ludo_played', (select count(*) from public.ludo_matches
                      where p_user = any (players) and status = 'completed'),
    'ludo_won', (select count(*) from public.ludo_matches
                   where winner_id = p_user and status = 'completed'),
    'eights_played', (select count(*) from public.eights_matches
                        where p_user = any (players) and status = 'completed'),
    'eights_won', (select count(*) from public.eights_matches
                     where winner_id = p_user and status = 'completed'),
    'chess_played', (select count(*) from public.matches
                       where game::text = 'chess' and status = 'completed'
                         and (player_white = p_user or player_black = p_user))
                    + coalesce(h.chess_played, 0),
    'chess_won', (select count(*) from public.matches
                    where game::text = 'chess' and winner_id = p_user and status = 'completed')
                 + coalesce(h.chess_won, 0),
    'checkers_played', (select count(*) from public.matches
                          where game::text = 'checkers' and status = 'completed'
                            and (player_white = p_user or player_black = p_user))
                       + coalesce(h.checkers_played, 0),
    'checkers_won', (select count(*) from public.matches
                       where game::text = 'checkers' and winner_id = p_user and status = 'completed')
                    + coalesce(h.checkers_won, 0),
    'chess_rating', (select rating from public.player_ratings
                       where user_id = p_user and game = 'chess'),
    'chess_rated', (select games from public.player_ratings
                      where user_id = p_user and game = 'chess'),
    'checkers_rating', (select rating from public.player_ratings
                          where user_id = p_user and game = 'checkers'),
    'checkers_rated', (select games from public.player_ratings
                         where user_id = p_user and game = 'checkers'),
    'doodle_rating', (select rating from public.player_ratings
                        where user_id = p_user and game = 'doodle'),
    'doodle_rated', (select games from public.player_ratings
                       where user_id = p_user and game = 'doodle'),
    'member_since', (select created_at from public.profiles where id = p_user)
  )
  from (select 1) one
  left join public.house_players h on h.id = p_user;
$$;
