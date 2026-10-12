-- Nickname and username are two different things.
--
--   * username: the unique @handle friends search for (set_username,
--     unchanged: 3-20 lowercase letters, numbers or underscores).
--   * display_name: the nickname everyone sees at the table. It can have
--     spaces ("Jake Monroe") and doesn't have to be unique.
--
-- This replaces set_profile_name (from 20261008110000), which derived the
-- username from the name; nothing uses it.

drop function if exists public.set_profile_name(text);

create function public.set_nickname(p_name text)
returns text -- the nickname as saved, or null when cleared
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_name text := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  -- Empty clears it (the username is shown instead).
  if v_name = '' then
    update public.profiles set display_name = null, updated_at = now() where id = v_me;
    return null;
  end if;

  if char_length(v_name) < 2 or char_length(v_name) > 24 then
    raise exception 'nicknames are 2 to 24 characters';
  end if;
  if v_name !~ '^[[:alpha:][:digit:]][[:alpha:][:digit:] _.''-]*$' then
    raise exception 'nicknames use letters, numbers, spaces and . _ '' -';
  end if;

  update public.profiles set display_name = v_name, updated_at = now() where id = v_me;
  return v_name;
end;
$$;

revoke all on function public.set_nickname(text) from public;
grant execute on function public.set_nickname(text) to authenticated;
