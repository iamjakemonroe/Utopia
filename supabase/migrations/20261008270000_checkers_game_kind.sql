-- Checkers joins chess on the shared board-game tables (matches,
-- match_moves, invites, the queue, chess clocks and chat). Its own file:
-- a new enum value can't be used in the transaction that adds it.

alter type public.game_kind add value if not exists 'checkers';
