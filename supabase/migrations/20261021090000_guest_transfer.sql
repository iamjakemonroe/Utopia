-- A guest who saves their progress with an email that already has an
-- account: everything the guest had moves into that account as they sign
-- in to it. (A new email needs none of this: the guest account itself
-- takes the email, so everything stays where it is.)
--
--   * guest_transfer_start(): as the guest, before the code is sent. A
--     one-time ticket to the guest's things, kept on their device.
--   * guest_transfer_finish(ticket): as the account, once signed in.
--     Moves it all over (_merge_guest) and retires the guest, the way a
--     deleted account is retired: its sessions end, and an empty
--     "Deleted player" stays for the coin ledger (which is append-only,
--     so the guest's sign-in and profile can't be deleted) and any game
--     the guest played against the account itself.
--
-- What moves: coins (all but the 1,000 every new player starts with, so
-- new guests can't be farmed for them), store purchases and receipts,
-- Maestro, everything owned or rented (not the welcome week's free
-- worlds and halo: the account had its own), season items and event
-- progress, the daily streak, birthday, rankings (whichever has more
-- games), games and their moves, chats and guesses, friends and friend
-- requests, notifications, reports, Chip's notes, portraits and pictures,
-- and analytics. The account keeps its own name, username and picture,
-- taking the guest's only where it has none.

alter type public.ledger_entry_type add value if not exists 'guest_transfer';

create table public.guest_transfers (
  ticket     uuid primary key default gen_random_uuid(),
  guest_id   uuid not null,
  created_at timestamptz not null default now(),
  done_at    timestamptz,
  -- Who it moved to (null when there was nothing to move).
  done_by    uuid
);

alter table public.guest_transfers enable row level security;
revoke all on public.guest_transfers from anon, authenticated;

create function public._merge_guest(p_from uuid, p_to uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guest public.profiles;
  v_bonus bigint;
  v_coins bigint;
  v_chess uuid[];
  v_ludo uuid[];
  v_doodle uuid[];
  v_name text;
  v_username text;
begin
  select * into v_guest from public.profiles where id = p_from for update;
  if not found then
    return jsonb_build_object('moved', false);
  end if;
  perform 1 from public.profiles where id = p_to for update;

  -- Coins: what they won, earned and bought.
  select coalesce(sum(amount), 0) into v_bonus
    from public.ledger_entries where user_id = p_from and entry_type = 'signup_bonus';
  v_coins := greatest(v_guest.balance - v_bonus, 0);
  if v_coins > 0 then
    perform public._ledger_move(p_from, 'guest_transfer', -v_coins, null,
                                jsonb_build_object('to', p_to));
    perform public._ledger_move(p_to, 'guest_transfer', v_coins, null,
                                jsonb_build_object('from', p_from));
  end if;
  update public.profiles
     set lifetime_wagered = lifetime_wagered + v_guest.lifetime_wagered
   where id = p_to;

  -- Store purchases, so they can be found and restored on the account.
  update public.purchase_receipts set user_id = p_to where user_id = p_from;
  update public.coin_purchases set user_id = p_to where user_id = p_from;

  -- Maestro: whichever plan runs longer.
  if exists (select 1 from public.maestro_subscriptions g
             where g.user_id = p_from
               and g.expires_at > coalesce((select a.expires_at from public.maestro_subscriptions a
                                            where a.user_id = p_to), '-infinity')) then
    delete from public.maestro_subscriptions where user_id = p_to;
    update public.maestro_subscriptions set user_id = p_to, updated_at = now()
     where user_id = p_from;
  end if;

  -- Owned for good, and what's rented or earned for a while (longest
  -- wins). The welcome week's free worlds and halo end with it: skipped.
  update public.user_entitlements e set user_id = p_to
   where e.user_id = p_from
     and not exists (select 1 from public.user_entitlements a
                     where a.user_id = p_to and a.item_id = e.item_id);
  update public.world_rentals a set expires_at = g.expires_at
    from public.world_rentals g
   where a.user_id = p_to and g.user_id = p_from and g.world_id = a.world_id
     and g.expires_at > a.expires_at
     and g.expires_at is distinct from v_guest.welcome_until;
  update public.world_rentals r set user_id = p_to
   where r.user_id = p_from and r.expires_at > now()
     and r.expires_at is distinct from v_guest.welcome_until
     and not exists (select 1 from public.world_rentals a
                     where a.user_id = p_to and a.world_id = r.world_id);
  update public.user_auras a set expires_at = g.expires_at
    from public.user_auras g
   where a.user_id = p_to and g.user_id = p_from and g.aura_id = a.aura_id
     and g.expires_at > a.expires_at
     and g.expires_at is distinct from v_guest.welcome_until;
  update public.user_auras r set user_id = p_to
   where r.user_id = p_from and r.expires_at > now()
     and r.expires_at is distinct from v_guest.welcome_until
     and not exists (select 1 from public.user_auras a
                     where a.user_id = p_to and a.aura_id = r.aura_id);
  update public.season_items s set user_id = p_to
   where s.user_id = p_from
     and not exists (select 1 from public.season_items a
                     where a.user_id = p_to and a.item_id = s.item_id);
  update public.event_claims c set user_id = p_to
   where c.user_id = p_from
     and not exists (select 1 from public.event_claims a
                     where a.user_id = p_to and a.event_id = c.event_id and a.item_id = c.item_id);
  -- The worn frame keeps going as long as the account's copy now does.
  update public.profiles p set aura_expires_at = a.expires_at
    from public.user_auras a
   where p.id = p_to and a.user_id = p_to and a.aura_id = p.equipped_aura
     and a.expires_at > coalesce(p.aura_expires_at, '-infinity');

  -- Progress: the further along of the two.
  insert into public.event_progress as a
    (user_id, event_id, games, days, last_day, offline_day, offline_today, last_offline_at)
  select p_to, event_id, games, days, last_day, offline_day, offline_today, last_offline_at
    from public.event_progress where user_id = p_from
  on conflict (user_id, event_id) do update set
    games = greatest(a.games, excluded.games),
    days = greatest(a.days, excluded.days),
    last_day = greatest(a.last_day, excluded.last_day),
    offline_today = case
      when excluded.offline_day > coalesce(a.offline_day, '-infinity') then excluded.offline_today
      when excluded.offline_day = a.offline_day then greatest(a.offline_today, excluded.offline_today)
      else a.offline_today end,
    offline_day = greatest(a.offline_day, excluded.offline_day),
    last_offline_at = greatest(a.last_offline_at, excluded.last_offline_at);
  update public.event_counted c set user_id = p_to
   where c.user_id = p_from
     and not exists (select 1 from public.event_counted a
                     where a.user_id = p_to and a.match_id = c.match_id);
  insert into public.daily_rewards as a (user_id, last_day, streak)
  select p_to, last_day, streak from public.daily_rewards where user_id = p_from
  on conflict (user_id) do update set
    streak = case
      when excluded.last_day > a.last_day then excluded.streak
      when excluded.last_day = a.last_day then greatest(a.streak, excluded.streak)
      else a.streak end,
    last_day = greatest(a.last_day, excluded.last_day);
  update public.user_birthdays set user_id = p_to
   where user_id = p_from
     and not exists (select 1 from public.user_birthdays where user_id = p_to);

  -- Rankings: per game, the record with more games behind it.
  delete from public.player_ratings a
   using public.player_ratings g
   where a.user_id = p_to and g.user_id = p_from and g.game = a.game and g.games > a.games;
  update public.player_ratings r set user_id = p_to
   where r.user_id = p_from
     and not exists (select 1 from public.player_ratings a
                     where a.user_id = p_to and a.game = r.game);

  -- Games, unless the guest played the account itself: those stay with
  -- the retired guest, so no game has the same player on both sides.
  select coalesce(array_agg(id), '{}') into v_chess from public.matches
   where p_from in (player_white, player_black)
     and p_to is distinct from player_white and p_to is distinct from player_black;
  update public.matches set
    player_white = case when player_white = p_from then p_to else player_white end,
    player_black = case when player_black = p_from then p_to else player_black end,
    winner_id = case when winner_id = p_from then p_to else winner_id end
   where id = any(v_chess);
  update public.match_moves set player_id = p_to
   where player_id = p_from and match_id = any(v_chess);
  update public.match_result_reports set
    reporter_id = case when reporter_id = p_from then p_to else reporter_id end,
    winner_id = case when winner_id = p_from then p_to else winner_id end
   where match_id = any(v_chess);
  update public.chess_chat_messages set sender_id = p_to
   where sender_id = p_from and match_id = any(v_chess);
  update public.match_invites set from_user = p_to
   where from_user = p_from and to_user <> p_to;
  update public.match_invites set to_user = p_to
   where to_user = p_from and from_user <> p_to;

  select coalesce(array_agg(id), '{}') into v_ludo from public.ludo_matches
   where (p_from = any(coalesce(players, '{}')) or p_from in (player_red, player_yellow))
     and not (p_to = any(coalesce(players, '{}')))
     and p_to is distinct from player_red and p_to is distinct from player_yellow;
  update public.ludo_matches set
    players = array_replace(players, p_from, p_to),
    player_red = case when player_red = p_from then p_to else player_red end,
    player_yellow = case when player_yellow = p_from then p_to else player_yellow end,
    winner_id = case when winner_id = p_from then p_to else winner_id end
   where id = any(v_ludo);
  update public.ludo_moves set player_id = p_to
   where player_id = p_from and match_id = any(v_ludo);
  update public.ludo_match_result_reports set
    reporter_id = case when reporter_id = p_from then p_to else reporter_id end,
    winner_id = case when winner_id = p_from then p_to else winner_id end
   where match_id = any(v_ludo);
  update public.ludo_chat_messages set sender_id = p_to
   where sender_id = p_from and match_id = any(v_ludo);

  select coalesce(array_agg(game_id), '{}') into v_doodle from public.doodle_players g
   where g.user_id = p_from
     and not exists (select 1 from public.doodle_players a
                     where a.game_id = g.game_id and a.user_id = p_to);
  update public.doodle_players set user_id = p_to
   where user_id = p_from and game_id = any(v_doodle);
  update public.doodle_games set
    host_id = case when host_id = p_from then p_to else host_id end,
    drawer_id = case when drawer_id = p_from then p_to else drawer_id end,
    winner_ids = array_replace(winner_ids, p_from, p_to)
   where id = any(v_doodle);
  update public.doodle_guesses set user_id = p_to
   where user_id = p_from and game_id = any(v_doodle);
  update public.doodle_messages set
    sender_id = case when sender_id = p_from then p_to else sender_id end,
    drawer_id = case when drawer_id = p_from then p_to else drawer_id end
   where game_id = any(v_doodle) and p_from in (sender_id, drawer_id);
  -- Rating changes, for the games that moved (chess, checkers and doodle).
  update public.rating_changes r set user_id = p_to
   where r.user_id = p_from and r.match_id = any(v_chess || v_doodle)
     and not exists (select 1 from public.rating_changes a
                     where a.user_id = p_to and a.match_id = r.match_id);

  -- Friends, and friend requests still waiting (unless they'd be the
  -- account's own, or it already has one with that player).
  insert into public.friendships (user_low, user_high, created_at)
  select least(p_to, o), greatest(p_to, o), created_at
    from (select case when user_low = p_from then user_high else user_low end as o, created_at
            from public.friendships where p_from in (user_low, user_high)) f
   where o <> p_to
  on conflict do nothing;
  update public.friend_requests r set
    from_user = case when from_user = p_from then p_to else from_user end,
    to_user = case when to_user = p_from then p_to else to_user end
   where p_from in (r.from_user, r.to_user)
     and p_to not in (r.from_user, r.to_user)
     and not exists (
       select 1 from public.friend_requests x
        where (x.from_user = p_to and x.to_user in (r.from_user, r.to_user))
           or (x.to_user = p_to and x.from_user in (r.from_user, r.to_user)))
     and not exists (
       select 1 from public.friendships f
        where (f.user_low = p_to or f.user_high = p_to)
          and (f.user_low in (r.from_user, r.to_user) and f.user_high in (r.from_user, r.to_user)));

  update public.notifications set user_id = p_to
   where user_id = p_from and actor_id is distinct from p_to;
  update public.notifications set actor_id = p_to
   where actor_id = p_from and user_id <> p_to;
  update public.player_reports set reporter_id = p_to
   where reporter_id = p_from and reported_id <> p_to;
  update public.player_reports set reported_id = p_to
   where reported_id = p_from and reporter_id <> p_to;
  update public.bug_reports set user_id = p_to where user_id = p_from;
  update public.app_events set user_id = p_to where user_id = p_from;

  -- Chip: notes, portraits, the pictures drawn for them, and what's been
  -- drawn and asked for (today's use counts too, against the day's limit).
  update public.chip_memories set user_id = p_to where user_id = p_from;
  update public.chip_portraits set user_id = p_to where user_id = p_from;
  update public.coloring_pages set owner = p_to where owner = p_from;
  update public.coloring_asks c set user_id = p_to
   where c.user_id = p_from
     and not exists (select 1 from public.coloring_asks a
                     where a.user_id = p_to and a.page_id = c.page_id);
  update public.chip_doodle_seen s set user_id = p_to
   where s.user_id = p_from
     and not exists (select 1 from public.chip_doodle_seen a
                     where a.user_id = p_to and a.word = s.word);
  insert into public.chip_usage as a (user_id, day, chats, vibes, draws, paints, doodles)
  select p_to, day, chats, vibes, draws, paints, doodles
    from public.chip_usage where user_id = p_from
  on conflict (user_id, day) do update set
    chats = a.chats + excluded.chats,
    vibes = a.vibes + excluded.vibes,
    draws = a.draws + excluded.draws,
    paints = a.paints + excluded.paints,
    doodles = a.doodles + excluded.doodles;

  -- The account's name, username and picture stay; where it has none,
  -- it takes the guest's (the username freed from the guest first).
  v_name := v_guest.display_name;
  v_username := v_guest.username;
  perform public.anonymize_account(p_from);
  update public.profiles set
    display_name = coalesce(display_name, v_name),
    username = coalesce(username, v_username),
    avatar_url = case when avatar_url is null then v_guest.avatar_url else avatar_url end,
    avatar_kind = case when avatar_url is null and v_guest.avatar_url is not null
                       then v_guest.avatar_kind else avatar_kind end,
    updated_at = now()
   where id = p_to;

  -- The guest's sessions end, so it can't be used again. (Where there's
  -- no auth.sessions, as in the test database, there's nothing to end.)
  begin
    execute 'delete from auth.sessions where user_id = $1' using p_from;
  exception when undefined_table then null;
  end;

  return jsonb_build_object('moved', true, 'coins', v_coins);
end;
$$;

revoke all on function public._merge_guest(uuid, uuid) from public, anon, authenticated;

create function public.guest_transfer_start()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_ticket uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from auth.users where id = v_me and is_anonymous) then
    raise exception 'not a guest';
  end if;
  insert into public.guest_transfers (guest_id) values (v_me) returning ticket into v_ticket;
  return v_ticket;
end;
$$;

revoke all on function public.guest_transfer_start() from public, anon;
grant execute on function public.guest_transfer_start() to authenticated;

create function public.guest_transfer_finish(p_ticket uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_ticket public.guest_transfers;
  v_result jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from auth.users where id = v_me and is_anonymous) then
    raise exception 'sign in first';
  end if;
  select * into v_ticket from public.guest_transfers where ticket = p_ticket for update;
  -- Used, a week old, the guest that became this account (nothing to
  -- move: it's all here already), or a guest already moved somewhere.
  if not found or v_ticket.done_at is not null
     or v_ticket.created_at < now() - interval '7 days'
     or v_ticket.guest_id = v_me
     or exists (select 1 from public.guest_transfers
                where guest_id = v_ticket.guest_id and done_by is not null) then
    return jsonb_build_object('moved', false);
  end if;
  -- The guest must still be a guest (not since saved to an email of its own).
  if not exists (select 1 from auth.users where id = v_ticket.guest_id and is_anonymous) then
    update public.guest_transfers set done_at = now() where ticket = p_ticket;
    return jsonb_build_object('moved', false);
  end if;
  v_result := public._merge_guest(v_ticket.guest_id, v_me);
  update public.guest_transfers set done_at = now(), done_by = v_me where ticket = p_ticket;
  return v_result;
end;
$$;

revoke all on function public.guest_transfer_finish(uuid) from public, anon;
grant execute on function public.guest_transfer_finish(uuid) to authenticated;

-- Pictures Chip drew from a guest's photo stay in the guest's folder:
-- whoever owns a picture now can read its art.
create policy "players read the art of pictures they own"
  on storage.objects for select
  using (
    bucket_id = 'coloring-art'
    and exists (select 1 from public.coloring_pages p
                where p.owner = auth.uid() and p.art = objects.name)
  );
