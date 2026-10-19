-- A report's screenshot as a link that opens it. The bucket stays private
-- (a screenshot can show names, chats and coins), so the link is a signed
-- one: made by the report-shot function with the secret key right after
-- the report is sent, good for a year, and only ever written there (or by
-- tool/reports.sh links, for older reports). screenshot_path stays, for
-- tool/reports.sh shot and account deletion.
alter table public.bug_reports
  add column screenshot_url text check (char_length(screenshot_url) <= 2000);

comment on column public.bug_reports.screenshot_url is
  'A signed link that opens the screenshot (a year from the report), made by the report-shot function.';
