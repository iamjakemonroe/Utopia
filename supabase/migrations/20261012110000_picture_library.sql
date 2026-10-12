-- The picture library: coloring pages Chip draws when a player asks for
-- one (by searching the Sketchbook or by asking Chip), shared with every
-- player, so each subject is only ever drawn once.
--
--   * coloring_pages: one per subject (key: the subject, lowercased and
--     tidied). 'drawing' while Chip works on it, 'ready' to color,
--     'refused' when the subject isn't for a children's coloring book,
--     'failed' when the drawing went wrong (asking again retries). Only
--     the chip function writes it.
--   * coloring_asks: who asked for which page, so a player can follow one
--     being drawn and finds the ones they asked for first.
--   * chip_usage.draws: new drawings a player has asked for today; with
--     chip_take('draw'), a few a day each and a cap for everyone together.

create table public.coloring_pages (
  id         uuid primary key default gen_random_uuid(),
  key        text not null unique,
  status     text not null default 'drawing'
             check (status in ('drawing', 'ready', 'refused', 'failed')),
  title      text not null default '',
  search     text not null default '',
  paths      jsonb not null default '[]'::jsonb,
  asks       int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index coloring_pages_popular on public.coloring_pages
  (asks desc, created_at desc) where status = 'ready';

create table public.coloring_asks (
  user_id  uuid not null references public.profiles (id) on delete cascade,
  page_id  uuid not null references public.coloring_pages (id) on delete cascade,
  asked_at timestamptz not null default now(),
  primary key (user_id, page_id)
);

create index coloring_asks_page on public.coloring_asks (page_id);

alter table public.coloring_pages enable row level security;
alter table public.coloring_asks enable row level security;
revoke all on public.coloring_pages from anon, authenticated;
revoke all on public.coloring_asks from anon, authenticated;
grant select (id, status, title, search, paths, asks, created_at)
  on public.coloring_pages to authenticated;
grant select on public.coloring_asks to authenticated;

create policy "ready pictures, and ones you asked for"
  on public.coloring_pages for select to authenticated
  using (
    status = 'ready'
    or exists (
      select 1 from public.coloring_asks a
      where a.page_id = coloring_pages.id and a.user_id = auth.uid()
    )
  );

create policy "your own asks"
  on public.coloring_asks for select to authenticated
  using (user_id = auth.uid());

alter table public.chip_usage add column draws int not null default 0;

-- Counts one use of p_kind ('chat', 'vibe' or 'draw') for the caller
-- today and says whether it fits in the allowance. New drawings also have
-- a cap for all players together, so the bill can't run away.
create or replace function public.chip_take(p_kind text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_used int;
  v_everyone int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('chat', 'vibe', 'draw') then
    raise exception 'unknown kind';
  end if;

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
  else
    select coalesce(sum(draws), 0) into v_everyone
      from public.chip_usage where day = v_today;
    if v_everyone >= 300 then return false; end if;
    update public.chip_usage set draws = draws + 1
      where user_id = v_me and day = v_today and draws < 4
      returning draws into v_used;
  end if;

  return v_used is not null;
end;
$$;

revoke all on function public.chip_take(text) from public;
grant execute on function public.chip_take(text) to authenticated;
