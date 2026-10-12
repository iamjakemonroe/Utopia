-- Generated placeholder avatars: every new account gets one automatically
-- (a kind + seed the client renders as vector art, not a stored image), so
-- nobody sees a bare initial letter before they've set anything. Uploading
-- a real photo overrides it; switching back to a generated one clears the
-- photo. Both setters live alongside set_username/set_avatar_url, same
-- SECURITY DEFINER pattern.

alter table public.profiles add column avatar_kind text check (avatar_kind in ('plant', 'animal', 'human'));
alter table public.profiles add column avatar_seed int;

comment on column public.profiles.avatar_kind is 'Which generated-avatar character family to render client-side (see GeneratedAvatar in the Flutter app) when avatar_url is null. Assigned randomly at signup by handle_new_user; null once/if a real photo is set.';
comment on column public.profiles.avatar_seed is 'Picks the color palette and minor shape variation within avatar_kind — purely cosmetic, no meaning beyond that.';

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
    values (new.id, v_kinds[1 + floor(random() * 3)::int], floor(random() * 1000)::int);
  perform public.grant_starting_balance(new.id, 1000);
  return new;
end;
$$;

create function public.set_generated_avatar(p_kind text, p_seed int)
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

  update public.profiles
    set avatar_url = null, avatar_kind = p_kind, avatar_seed = p_seed, updated_at = now()
    where id = v_me;
end;
$$;

comment on function public.set_generated_avatar is 'Switches back to (or between) a generated avatar, clearing any uploaded photo. Client-facing, same trust boundary as set_avatar_url/set_username.';

revoke all on function public.set_generated_avatar(text, int) from public;
grant execute on function public.set_generated_avatar(text, int) to authenticated;

-- Uploading a real photo now supersedes whatever generated avatar was
-- assigned — without this, a user who uploads a photo would still carry
-- a stale avatar_kind that nothing reads while avatar_url is set, but
-- would reappear (looking like a bug) the moment they cleared the photo.
create or replace function public.set_avatar_url(p_avatar_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  if p_avatar_url is not null
     and p_avatar_url !~ ('/storage/v1/object/public/avatars/' || v_me::text || '/') then
    raise exception 'avatar_url must point to your own uploaded avatar';
  end if;

  update public.profiles
    set avatar_url = p_avatar_url, avatar_kind = null, avatar_seed = null, updated_at = now()
    where id = v_me;
end;
$$;
