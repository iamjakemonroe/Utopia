-- Profiles: other players see public fields only, and coins on purpose.
--
-- Until now any signed-in player could read every column of every profile
-- (including the exact coin balance and lifetime_wagered) and stream their
-- changes live. Now:
--   * Reading profiles is limited to the public columns below. A column
--     added to profiles later stays private until it's granted here too.
--   * Coins are shown to everyone (the app rounds them, "2.4M"), unless the
--     player turns on "Hide my coins": get_public_coins leaves them out.
--   * A player's own balance comes from get_my_coins, and the app hears
--     about every change from their own coin ledger, which now streams.

alter table public.profiles
  add column show_coins boolean not null default true;

comment on column public.profiles.show_coins is 'Whether other players see this player''s coins (rounded) on their profile and player card.';

revoke select on public.profiles from anon, authenticated;
grant select (
  id,
  display_name,
  username,
  avatar_url,
  avatar_kind,
  avatar_seed,
  equipped_theme,
  equipped_ludo_pieces,
  equipped_chess_pieces,
  equipped_aura,
  aura_expires_at,
  show_coins,
  created_at,
  updated_at
) on public.profiles to anon, authenticated;

-- Your own coins.
create function public.get_my_coins()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select balance from public.profiles where id = auth.uid();
$$;

revoke all on function public.get_my_coins() from public;
grant execute on function public.get_my_coins() to authenticated;

-- Other players' coins, for those who show them (and always your own).
create function public.get_public_coins(p_ids uuid[])
returns table (id uuid, coins bigint)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.balance
    from public.profiles p
   where p.id = any (p_ids[1:100])
     and (p.show_coins or p.id = auth.uid());
$$;

revoke all on function public.get_public_coins(uuid[]) from public;
grant execute on function public.get_public_coins(uuid[]) to authenticated;

-- "Hide my coins".
create function public.set_show_coins(p_show boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.profiles
     set show_coins = coalesce(p_show, true), updated_at = now()
   where id = auth.uid();
end;
$$;

revoke all on function public.set_show_coins(boolean) from public;
grant execute on function public.set_show_coins(boolean) to authenticated;

-- Every coin change writes a ledger entry: streaming the player's own
-- entries tells the app the moment their balance moves.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'ledger_entries'
  ) then
    alter publication supabase_realtime add table public.ledger_entries;
  end if;
end;
$$;
