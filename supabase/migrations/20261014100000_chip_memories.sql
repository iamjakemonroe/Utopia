-- Chip's memory: short notes Chip keeps about a player from their chats
-- (their name for things, plans, what they like), so he can follow up next
-- time, even after "New chat". Only the chip function writes them; the
-- player can read their own. Deleting the account deletes them.

create table public.chip_memories (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  note       text not null check (char_length(note) between 1 and 200),
  created_at timestamptz not null default now()
);

create index chip_memories_by_player on public.chip_memories (user_id, created_at desc);

alter table public.chip_memories enable row level security;
revoke all on public.chip_memories from anon, authenticated;
grant select on public.chip_memories to authenticated;

create policy "see what Chip remembers about you"
  on public.chip_memories for select to authenticated
  using (user_id = auth.uid());
