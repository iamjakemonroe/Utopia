-- A player hears back about their report. When the team marks a bug report
-- (or an idea) fixed or not to be done (tool/reports.sh mark), the player
-- gets a notification, from Chip, with the team's note: they needn't go
-- back to "Report a bug" to find out.

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('friend_request', 'friend_accepted', 'game_invite',
                  'friend_birthday', 'birthday_wish', 'coin_gift',
                  'report_update'));

create function public._notify_report_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id is null or new.status not in ('fixed', 'wontfix')
     or new.status is not distinct from old.status then
    return null;
  end if;
  insert into public.notifications (user_id, kind, ref_id, data)
    values (new.user_id, 'report_update', new.id, jsonb_build_object(
      'status', new.status,
      'idea', new.category = 'idea',
      'note', new.resolution
    ));
  return null;
end;
$$;

revoke all on function public._notify_report_update() from public, anon, authenticated;

create trigger bug_reports_notify
  after update of status on public.bug_reports
  for each row execute function public._notify_report_update();
