-- Names with a space in them.
--
-- A player can call themselves "Jake Monroe": up to three words of letters,
-- numbers or underscores, one space between each. That's the name everyone
-- sees (display_name, each word starting with a capital). Their username,
-- what friends search for, is the same words joined and lowercase
-- ("jakemonroe"), set here rather than typed separately, and it still has
-- to be free.

create function public.set_profile_name(p_name text)
returns text -- the username it set
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_name text := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
  v_username text;
  v_display text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if v_name !~ '^[A-Za-z0-9_]+( [A-Za-z0-9_]+){0,2}$' then
    raise exception 'names are up to three words of letters, numbers or underscores';
  end if;

  v_username := lower(replace(v_name, ' ', ''));
  if v_username !~ '^[a-z0-9_]{3,20}$' then
    raise exception 'username must be 3-20 lowercase letters, numbers, or underscores';
  end if;

  select string_agg(upper(left(w, 1)) || substr(w, 2), ' ' order by i)
    into v_display
    from unnest(string_to_array(v_name, ' ')) with ordinality as words (w, i);

  update public.profiles
    set username = v_username, display_name = v_display, updated_at = now()
    where id = v_me;
  return v_username;
exception
  when unique_violation then
    raise exception 'username already taken';
end;
$$;

revoke all on function public.set_profile_name(text) from public;
grant execute on function public.set_profile_name(text) to authenticated;
