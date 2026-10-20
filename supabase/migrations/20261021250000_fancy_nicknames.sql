-- Fancy nicknames. A nickname (what everyone sees; the @username stays
-- 3-20 plain letters, numbers and underscores, for searching) can be
-- written any way a player likes: 𝓙𝓪𝓴𝓮, ᴊᴀᴋᴇ, Ｊａｋｅ, ꧁༺ Jake ༻꧂, ★彡,
-- any script, emoji (flags, skin tones, families). Only what breaks the
-- app or fools people is turned away:
--
--   * characters that hide or flip text (zero-width spaces, right-to-left
--     overrides, soft hyphens, control characters): a name could look
--     blank, or like someone else's;
--   * names with fewer than 2 characters you can see (all blank fillers,
--     all marks);
--   * glitch text: more than 3 marks stacked on one letter, which spills
--     over whatever's around it.
--
-- Any kind of space or line break becomes one plain space. The app counts
-- 24 characters as a person sees them (an emoji family is one); here,
-- where a character can be built of several, it's up to 64 visible code
-- points and 128 in all (the app checks the same).

create or replace function public.set_nickname(p_name text)
returns text -- the nickname as saved, or null when cleared
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_name text;
  v_seen text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  v_name := btrim(regexp_replace(
    coalesce(p_name, ''),
    '[\s\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+', ' ', 'g'));

  -- Empty clears it (the username is shown instead).
  if v_name = '' then
    update public.profiles set display_name = null, updated_at = now() where id = v_me;
    return null;
  end if;

  if v_name ~ '[\u0001-\u001F\u007F-\u009F\u00AD\u200B\u200E\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF\uFFF9-\uFFFB]' then
    raise exception 'nicknames can''t have hidden or text-flipping characters';
  end if;
  if v_name ~ '[\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]{4,}' then
    raise exception 'nicknames can''t stack more than 3 marks on a letter';
  end if;
  -- What you can see: less spaces, marks, joiners and blank fillers.
  v_seen := regexp_replace(
    v_name,
    '[\s\u200C\u200D\uFE00-\uFE0F\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F\u115F\u1160\u180E\u2800\u3164\uFFA0\U000E0000-\U000E007F]',
    '', 'g');
  if char_length(v_seen) < 2 then
    raise exception 'nicknames need at least 2 characters you can see';
  end if;
  if char_length(v_seen) > 64 or char_length(v_name) > 128 then
    raise exception 'nicknames are 2 to 24 characters';
  end if;

  update public.profiles set display_name = v_name, updated_at = now() where id = v_me;
  return v_name;
end;
$$;

revoke all on function public.set_nickname(text) from public;
grant execute on function public.set_nickname(text) to authenticated;
