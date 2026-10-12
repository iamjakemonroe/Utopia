-- Deleting an account (Settings > Delete account, which the App Store
-- requires). The delete-account Edge Function calls anonymize_account and
-- then removes the sign-in (a soft delete: the email and sign-in are gone
-- for good, and nobody can log in to it again).
--
-- What goes: the player's name, username, picture and worn aura; their
-- friends and friend requests; queue spots, room seats and presence; their
-- chat messages; their notifications and Chip usage; pending invites; their
-- contact details on bug reports. What stays, anonymous: the coin ledger
-- (append-only money records), purchase receipts, and finished games, which
-- other players' histories point at; those now show "Deleted player".

create function public.anonymize_account(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set display_name = 'Deleted player',
         username = null,
         avatar_url = null,
         avatar_kind = null,
         avatar_seed = null,
         equipped_aura = null,
         aura_expires_at = null,
         show_coins = false,
         updated_at = now()
   where id = p_user;

  delete from public.friendships where user_low = p_user or user_high = p_user;
  delete from public.friend_requests where from_user = p_user or to_user = p_user;
  delete from public.match_invites
   where (from_user = p_user or to_user = p_user) and match_id is null;
  delete from public.matchmaking_queue where user_id = p_user;
  delete from public.ludo_matchmaking_queue where user_id = p_user;
  delete from public.ludo_room_members where user_id = p_user;
  delete from public.chess_presence where user_id = p_user;
  delete from public.chess_chat_messages where sender_id = p_user;
  delete from public.ludo_chat_messages where sender_id = p_user;
  delete from public.notifications where user_id = p_user or actor_id = p_user;
  delete from public.chip_usage where user_id = p_user;
  update public.bug_reports set user_id = null, contact = null where user_id = p_user;
end;
$$;

revoke all on function public.anonymize_account(uuid) from public, anon, authenticated;
grant execute on function public.anonymize_account(uuid) to service_role;
