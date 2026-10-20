-- Guess My Doodle rooms hold up to 20 players (they held 8), online and
-- with friends: the size such games usually allow.
--
--   * Every room, new and already open, takes 20.
--   * Each player draws once a round, so a public room's rounds follow how
--     many are in as each game begins: 3 rounds for up to 6 players, 2 for
--     up to 12, 1 for more (20 players playing 3 rounds of 80 seconds each
--     would take nearly two hours; ranked games must be played to the end).
--     A room of friends plays the rounds its host picked.

alter table public.doodle_games drop constraint doodle_games_max_players_check;
alter table public.doodle_games add constraint doodle_games_max_players_check
  check (max_players between 2 and 20);
alter table public.doodle_games alter column max_players set default 20;
update public.doodle_games set max_players = 20 where status <> 'closed';

-- A fresh game from the lobby or the scores: everyone back to 0, and a
-- public room's rounds set by how many are in.
create or replace function public._doodle_begin(p_game uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_in int := public._doodle_active(p_game);
begin
  update public.doodle_players
    set score = 0, turn_points = 0, drew_round = 0
    where game_id = p_game;
  update public.doodle_games
    set round = 1, winner_ids = '{}', revealed_word = null,
        rounds = case when not is_public then rounds
                      when v_in <= 6 then 3
                      when v_in <= 12 then 2
                      else 1 end
    where id = p_game;
  perform public._doodle_start_turn(p_game);
end;
$$;

revoke all on function public._doodle_begin(uuid) from public, anon, authenticated;
