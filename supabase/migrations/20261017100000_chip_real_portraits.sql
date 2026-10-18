-- Real portraits: Chip has a photo-quality image model draw a coloring
-- page that looks just like the real person (from the player's photo, or a
-- famous person's name). Unlike Chip's own cartoon drawings these cost real
-- money to make, so they cost coins: 3,000 each, the first one free.
--
--   * coloring_pages.art: the page as line art (a PNG in the private
--     coloring-art bucket, at <owner>/<page id>.png) instead of outlines.
--     Portraits are always the payer's own (owner set), never shared.
--   * chip_portraits: every portrait paid for, so the first is free, a
--     failed one is refunded once, and there's a daily limit.
--   * chip_portrait_pay / chip_portrait_refund: the chip function's way to
--     charge and refund (service role only).

alter type public.ledger_entry_type add value if not exists 'chip_portrait';
alter type public.ledger_entry_type add value if not exists 'chip_portrait_refund';

alter table public.coloring_pages add column art text;
grant select (art) on public.coloring_pages to authenticated;

create table public.chip_portraits (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  page_id    uuid references public.coloring_pages (id) on delete set null,
  coins      int not null check (coins >= 0),
  refunded   boolean not null default false,
  created_at timestamptz not null default now()
);

create index chip_portraits_by_player on public.chip_portraits (user_id, created_at desc);

alter table public.chip_portraits enable row level security;
revoke all on public.chip_portraits from anon, authenticated;

-- Charges [p_user] for a portrait: free if they've never had one (that
-- wasn't refunded), else 3,000 coins. Raises 'insufficient balance' or
-- 'portrait limit'. Returns {id, coins, free}.
create function public.chip_portrait_pay(p_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  v_free boolean;
  v_price int;
  v_id bigint;
begin
  -- One at a time per player, so two taps can't both be the free one.
  perform 1 from public.profiles where id = p_user for update;

  if (select count(*) from public.chip_portraits
        where user_id = p_user and not refunded and created_at >= v_today) >= 10
     or (select count(*) from public.chip_portraits
        where not refunded and created_at >= v_today) >= 500 then
    raise exception 'portrait limit';
  end if;

  v_free := not exists (
    select 1 from public.chip_portraits where user_id = p_user and not refunded
  );
  v_price := case when v_free then 0 else 3000 end;

  if v_price > 0 then
    if (select balance from public.profiles where id = p_user) < v_price then
      raise exception 'insufficient balance';
    end if;
    perform public._ledger_move(
      p_user, 'chip_portrait', -v_price, null, jsonb_build_object('kind', 'portrait')
    );
  end if;

  insert into public.chip_portraits (user_id, coins) values (p_user, v_price)
    returning id into v_id;
  return jsonb_build_object('id', v_id, 'coins', v_price, 'free', v_free);
end;
$$;

-- A portrait that failed: its coins back (once), and a free one is free
-- again.
create function public.chip_portrait_refund(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.chip_portraits;
begin
  update public.chip_portraits set refunded = true
    where id = p_id and not refunded
    returning * into v_row;
  if not found then return; end if;
  if v_row.coins > 0 then
    perform public._ledger_move(
      v_row.user_id, 'chip_portrait_refund', v_row.coins, null,
      jsonb_build_object('portrait', v_row.id)
    );
  end if;
end;
$$;

-- What a portrait would cost this player: {price, free}.
create function public.chip_portrait_offer(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'price', 3000,
    'free', not exists (
      select 1 from public.chip_portraits where user_id = p_user and not refunded
    )
  );
$$;

revoke all on function public.chip_portrait_pay(uuid) from public, anon, authenticated;
revoke all on function public.chip_portrait_refund(bigint) from public, anon, authenticated;
revoke all on function public.chip_portrait_offer(uuid) from public, anon, authenticated;
grant execute on function public.chip_portrait_pay(uuid) to service_role;
grant execute on function public.chip_portrait_refund(bigint) to service_role;
grant execute on function public.chip_portrait_offer(uuid) to service_role;

-- The portraits' line art: private, each player reads their own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('coloring-art', 'coloring-art', false, 8388608, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "players read their own coloring art"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'coloring-art'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
