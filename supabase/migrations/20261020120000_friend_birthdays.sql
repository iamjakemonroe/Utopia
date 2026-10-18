-- Friends' birthdays.
--
--   * On a player's birthday (the first time their party starts that
--     year), their friends get a notification: "It's Ada's birthday!".
--     Players who'd rather keep it quiet turn tell_friends off
--     (set_birthday_sharing, any time, even once the date is locked).
--   * A friend can answer with a wish (wish_happy_birthday): "Jake wished
--     you a happy birthday!". Only friends, only on the day, once each.

alter table public.user_birthdays
  add column tell_friends boolean not null default true,
  add column told_year int;

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('friend_request', 'friend_accepted', 'game_invite',
                  'friend_birthday', 'birthday_wish'));

create function public.set_birthday_sharing(p_on boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.user_birthdays set tell_friends = coalesce(p_on, true)
    where user_id = auth.uid();
end;
$$;

revoke all on function public.set_birthday_sharing(boolean) from public;
grant execute on function public.set_birthday_sharing(boolean) to authenticated;

/** Whether [p_a] and [p_b] are friends. */
create function public._are_friends(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.friendships
    where user_low = least(p_a, p_b) and user_high = greatest(p_a, p_b)
  );
$$;

revoke all on function public._are_friends(uuid, uuid) from public, anon, authenticated;

-- start_birthday as before, and the first time each year, tell friends.
create or replace function public.start_birthday(p_until timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_bday public.user_birthdays;
  v_ends timestamptz;
  v_until timestamptz;
  v_year int := extract(year from now() at time zone 'utc')::int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_bday from public.user_birthdays where user_id = v_me;
  if not found then return jsonb_build_object('birthday', false); end if;
  v_ends := public._birthday_ends(v_bday.month, v_bday.day);
  if v_ends is null then return jsonb_build_object('birthday', false); end if;

  v_until := least(greatest(coalesce(p_until, v_ends), now() + interval '1 hour'), v_ends);

  insert into public.world_rentals (user_id, world_id, expires_at)
    values (v_me, 'utopia_birthday', v_until)
    on conflict (user_id, world_id)
      do update set expires_at = greatest(world_rentals.expires_at, excluded.expires_at);
  insert into public.user_auras (user_id, aura_id, expires_at)
    values (v_me, 'birthday', v_until)
    on conflict (user_id, aura_id)
      do update set expires_at = greatest(user_auras.expires_at, excluded.expires_at);
  update public.profiles
    set equipped_theme = 'utopia_birthday', equipped_aura = 'birthday',
        aura_expires_at = (select expires_at from public.user_auras
                           where user_id = v_me and aura_id = 'birthday'),
        updated_at = now()
    where id = v_me;

  if v_bday.tell_friends and v_bday.told_year is distinct from v_year then
    update public.user_birthdays set told_year = v_year where user_id = v_me;
    insert into public.notifications (user_id, kind, actor_id)
    select case when f.user_low = v_me then f.user_high else f.user_low end,
           'friend_birthday', v_me
    from public.friendships f
    where f.user_low = v_me or f.user_high = v_me;
  end if;

  return jsonb_build_object(
    'birthday', true,
    'until', (select expires_at from public.world_rentals
              where user_id = v_me and world_id = 'utopia_birthday')
  );
end;
$$;

/** A friend's birthday wish to [p_friend], on their birthday. */
create function public.wish_happy_birthday(p_friend uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_bday public.user_birthdays;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not public._are_friends(v_me, p_friend) then raise exception 'not friends'; end if;
  select * into v_bday from public.user_birthdays where user_id = p_friend;
  if not found or public._birthday_ends(v_bday.month, v_bday.day) is null then
    raise exception 'not their birthday';
  end if;
  if exists (
    select 1 from public.notifications
    where user_id = p_friend and actor_id = v_me and kind = 'birthday_wish'
      and created_at > now() - interval '2 days'
  ) then
    return;
  end if;
  insert into public.notifications (user_id, kind, actor_id)
    values (p_friend, 'birthday_wish', v_me);
end;
$$;

revoke all on function public.wish_happy_birthday(uuid) from public;
grant execute on function public.wish_happy_birthday(uuid) to authenticated;
