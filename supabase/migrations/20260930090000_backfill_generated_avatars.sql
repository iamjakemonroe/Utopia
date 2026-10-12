-- Two follow-ups to 20260929100000_generated_avatars.sql:
--
-- 1. Accounts created before that migration have neither a photo nor a
--    generated avatar, so they'd still show a bare initial. Give them one.
-- 2. Seeds were assigned in 0-999, but the profile picker offers 0-7
--    (kAvatarChoicesPerKind in the Flutter app), so it could never ring the
--    avatar a user currently has. Keep every seed in the picker's range.

update public.profiles
  set avatar_kind = (array['plant', 'animal', 'human'])[1 + floor(random() * 3)::int],
      avatar_seed = floor(random() * 8)::int
  where avatar_url is null and avatar_kind is null;

update public.profiles
  set avatar_seed = avatar_seed % 8
  where avatar_seed is not null and avatar_seed not between 0 and 7;

alter table public.profiles
  add constraint profiles_avatar_seed_range check (avatar_seed between 0 and 7);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_kinds text[] := array['plant', 'animal', 'human'];
begin
  insert into public.profiles (id, avatar_kind, avatar_seed)
    values (new.id, v_kinds[1 + floor(random() * 3)::int], floor(random() * 8)::int);
  perform public.grant_starting_balance(new.id, 1000);
  return new;
end;
$$;

create or replace function public.set_generated_avatar(p_kind text, p_seed int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('plant', 'animal', 'human') then
    raise exception 'invalid avatar kind';
  end if;
  if p_seed is null or p_seed not between 0 and 7 then
    raise exception 'invalid avatar seed';
  end if;

  update public.profiles
    set avatar_url = null, avatar_kind = p_kind, avatar_seed = p_seed, updated_at = now()
    where id = v_me;
end;
$$;
