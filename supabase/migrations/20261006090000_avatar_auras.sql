-- Avatar auras: animated frames around a player's picture, bought with
-- coins for a limited time (3 days, 1 week or 1 month) and shown to
-- everyone, everywhere that player's avatar appears.
--
--   * aura_catalog holds the prices; the app never says what something
--     costs.
--   * buy_aura takes the coins and adds the time (buying again while it's
--     still active extends it), then wears it.
--   * equip_aura switches between owned, unexpired auras (or takes it off).
--     The worn aura and its end time live on the public profile, so other
--     players see it; once the time is up the app stops drawing it.

alter type public.ledger_entry_type add value if not exists 'aura_purchase';

create table public.aura_catalog (
  id         text primary key,
  tier       text not null check (tier in ('common', 'rare', 'legendary')),
  price_3d   bigint not null check (price_3d > 0),
  price_7d   bigint not null check (price_7d > 0),
  price_30d  bigint not null check (price_30d > 0),
  sort       int not null default 0
);

alter table public.aura_catalog enable row level security;
revoke insert, update, delete on public.aura_catalog from authenticated, anon;
create policy "anyone can read the aura catalog" on public.aura_catalog for select using (true);

insert into public.aura_catalog (id, tier, price_3d, price_7d, price_30d, sort) values
  ('bubbles',  'common',    3000,  9000, 35000, 1),
  ('sakura',   'common',    3000,  9000, 35000, 2),
  ('frost',    'common',    3000,  9000, 35000, 3),
  ('sunburst', 'rare',      4000, 12000, 45000, 4),
  ('prism',    'rare',      4000, 12000, 45000, 5),
  ('cosmic',   'rare',      4000, 12000, 45000, 6),
  ('flame',    'legendary', 5000, 15000, 60000, 7),
  ('storm',    'legendary', 5000, 15000, 60000, 8);

create table public.user_auras (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  aura_id    text not null references public.aura_catalog (id),
  expires_at timestamptz not null,
  primary key (user_id, aura_id)
);

alter table public.user_auras enable row level security;
revoke insert, update, delete on public.user_auras from authenticated, anon;
create policy "see your own auras" on public.user_auras for select using (user_id = auth.uid());

alter table public.profiles
  add column equipped_aura text references public.aura_catalog (id),
  add column aura_expires_at timestamptz;

comment on column public.profiles.equipped_aura is 'The aura this player wears, shown around their avatar until aura_expires_at.';

create function public.buy_aura(p_aura_id text, p_days int)
returns timestamptz -- when it now runs out
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_aura public.aura_catalog;
  v_price bigint;
  v_balance bigint;
  v_from timestamptz;
  v_expires timestamptz;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_aura from public.aura_catalog where id = p_aura_id;
  if v_aura is null then raise exception 'unknown aura'; end if;

  v_price := case p_days
    when 3 then v_aura.price_3d
    when 7 then v_aura.price_7d
    when 30 then v_aura.price_30d
  end;
  if v_price is null then raise exception 'auras come for 3, 7 or 30 days'; end if;

  select balance into v_balance from public.profiles where id = v_me for update;
  if v_balance < v_price then raise exception 'insufficient balance'; end if;

  -- Still wearing time left? The new days go on the end.
  select greatest(expires_at, now()) into v_from
    from public.user_auras where user_id = v_me and aura_id = p_aura_id;
  v_expires := coalesce(v_from, now()) + make_interval(days => p_days);

  perform public._ledger_move(
    v_me,
    'aura_purchase',
    -v_price,
    null,
    jsonb_build_object('aura', p_aura_id, 'days', p_days)
  );

  insert into public.user_auras (user_id, aura_id, expires_at)
    values (v_me, p_aura_id, v_expires)
    on conflict (user_id, aura_id) do update set expires_at = excluded.expires_at;

  update public.profiles
    set equipped_aura = p_aura_id, aura_expires_at = v_expires, updated_at = now()
    where id = v_me;

  return v_expires;
end;
$$;

revoke all on function public.buy_aura(text, int) from public;
grant execute on function public.buy_aura(text, int) to authenticated;

create function public.equip_aura(p_aura_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_expires timestamptz;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  if p_aura_id is null then
    update public.profiles set equipped_aura = null, aura_expires_at = null, updated_at = now()
      where id = v_me;
    return;
  end if;

  select expires_at into v_expires from public.user_auras
    where user_id = v_me and aura_id = p_aura_id and expires_at > now();
  if v_expires is null then raise exception 'that aura has run out'; end if;

  update public.profiles
    set equipped_aura = p_aura_id, aura_expires_at = v_expires, updated_at = now()
    where id = v_me;
end;
$$;

revoke all on function public.equip_aura(text) from public;
grant execute on function public.equip_aura(text) to authenticated;
