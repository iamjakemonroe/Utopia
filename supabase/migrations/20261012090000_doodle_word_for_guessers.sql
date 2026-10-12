-- Guess My Doodle: once you've guessed the word, you can see it too (the
-- header shows it, as it does for the drawer).

create or replace function public.doodle_secret(p_game uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  g public.doodle_games;
  s public.doodle_secrets;
  v_guessed boolean;
begin
  select * into g from public.doodle_games where id = p_game;
  if g is null or v_me is null then return '{}'::jsonb; end if;
  select * into s from public.doodle_secrets where game_id = p_game;
  if g.drawer_id = v_me then
    if g.status = 'choosing' then
      return jsonb_build_object('turn', g.turn, 'choices', to_jsonb(s.choices));
    elsif g.status in ('drawing', 'reveal') then
      return jsonb_build_object('turn', g.turn, 'word', s.word);
    end if;
    return '{}'::jsonb;
  end if;
  select exists (
    select 1 from public.doodle_guesses
      where game_id = p_game and turn = g.turn and user_id = v_me
  ) into v_guessed;
  if v_guessed and g.status in ('drawing', 'reveal') then
    return jsonb_build_object('turn', g.turn, 'word', s.word);
  end if;
  return '{}'::jsonb;
end;
$$;

revoke all on function public.doodle_secret(uuid) from public;
grant execute on function public.doodle_secret(uuid) to authenticated;
