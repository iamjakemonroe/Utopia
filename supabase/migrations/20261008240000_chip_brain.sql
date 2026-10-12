-- Chip's brain: the bits the chip Edge Function needs.
--
--   * chip_vibe_cache: what Chip made of a song or video, by a hash of its
--     clues, so the same track is only ever read once. Written by the
--     function with the service key; nobody else can read or write it.
--   * chip_usage + chip_take: a daily allowance per player, so a runaway
--     client can't run up the AI bill. The function calls chip_take before
--     every request to the model.

create table public.chip_vibe_cache (
  key        text primary key,
  result     jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.chip_vibe_cache enable row level security;
revoke all on public.chip_vibe_cache from anon, authenticated;

create table public.chip_usage (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day     date not null default (now() at time zone 'utc')::date,
  chats   int not null default 0,
  vibes   int not null default 0,
  primary key (user_id, day)
);

alter table public.chip_usage enable row level security;
revoke insert, update, delete on public.chip_usage from anon, authenticated;
create policy "see your own chip usage" on public.chip_usage
  for select using (user_id = auth.uid());

-- Counts one use of p_kind ('chat' or 'vibe') for the caller today and says
-- whether it fits in the allowance.
create function public.chip_take(p_kind text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_used int;
  v_limit int;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('chat', 'vibe') then raise exception 'unknown kind'; end if;
  v_limit := case when p_kind = 'chat' then 40 else 150 end;

  insert into public.chip_usage (user_id, day) values (v_me, v_today)
    on conflict (user_id, day) do nothing;

  if p_kind = 'chat' then
    update public.chip_usage set chats = chats + 1
      where user_id = v_me and day = v_today and chats < v_limit
      returning chats into v_used;
  else
    update public.chip_usage set vibes = vibes + 1
      where user_id = v_me and day = v_today and vibes < v_limit
      returning vibes into v_used;
  end if;

  return v_used is not null;
end;
$$;

revoke all on function public.chip_take(text) from public;
grant execute on function public.chip_take(text) to authenticated;
