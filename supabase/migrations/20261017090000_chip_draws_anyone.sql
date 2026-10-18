-- Chip draws anyone, and colors pictures for players.
--
--   * coloring_pages.owner: a picture Chip drew from a player's photo is
--     theirs alone (null = the shared library, as before). Other players
--     never see it, in search or anywhere else.
--   * chip_usage.paints / chip_take('paint'): coloring a picture for a
--     player ("color it for me", black and white shading...), a number a
--     day each and a cap for everyone together, like drawings.

alter table public.coloring_pages
  add column owner uuid references public.profiles (id) on delete cascade;

create index coloring_pages_by_owner on public.coloring_pages (owner)
  where owner is not null;

grant select (owner) on public.coloring_pages to authenticated;

drop policy "ready pictures, and ones you asked for" on public.coloring_pages;

create policy "the library, your own pictures, and ones you asked for"
  on public.coloring_pages for select to authenticated
  using (
    (owner is null and status = 'ready')
    or owner = auth.uid()
    or exists (
      select 1 from public.coloring_asks a
      where a.page_id = coloring_pages.id and a.user_id = auth.uid()
    )
  );

alter table public.chip_usage add column paints int not null default 0;

-- Counts one use of p_kind ('chat', 'vibe', 'draw' or 'paint') for the
-- caller today and says whether it fits in the allowance. Drawings and
-- colorings also have a cap for all players together, so the bill can't
-- run away.
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
  if p_kind not in ('chat', 'vibe', 'draw', 'paint') then
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
  elsif p_kind = 'draw' then
    select coalesce(sum(draws), 0) into v_everyone
      from public.chip_usage where day = v_today;
    if v_everyone >= 300 then return false; end if;
    update public.chip_usage set draws = draws + 1
      where user_id = v_me and day = v_today and draws < 4
      returning draws into v_used;
  else
    select coalesce(sum(paints), 0) into v_everyone
      from public.chip_usage where day = v_today;
    if v_everyone >= 3000 then return false; end if;
    update public.chip_usage set paints = paints + 1
      where user_id = v_me and day = v_today and paints < 20
      returning paints into v_used;
  end if;

  return v_used is not null;
end;
$$;

revoke all on function public.chip_take(text) from public;
grant execute on function public.chip_take(text) to authenticated;
