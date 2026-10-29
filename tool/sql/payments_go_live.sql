-- Run once when Flutterwave's live keys go in (after tool/push_payment_keys.sh).
--
-- 1. Subscription prices forget the Flutterwave payment plans made with the
--    test keys: those plans don't exist on the live account, so the first
--    live subscription to each price makes a live plan instead.
-- 2. Subscriptions paid with Flutterwave's test card (environment 'sandbox')
--    end now: test payments never gave real access.
-- Coins bought with the test card stay where they are (shown in the result).
-- Free grants (give_study_pro.sql) are 'production' and aren't touched.
--
-- Run in the Supabase dashboard: SQL Editor > New query, paste, Run.
update public.web_plan_prices set flw_plan_id = null where flw_plan_id is not null;

update public.web_subscriptions
   set status = 'ended', period_end = least(coalesce(period_end, now()), now()), updated_at = now()
 where environment = 'sandbox' and status in ('pending', 'active', 'cancelled');

select
  (select count(*) from public.web_plan_prices where flw_plan_id is not null) as test_plans_left,
  (select count(*) from public.web_subscriptions where environment = 'sandbox' and status <> 'ended') as test_subscriptions_left,
  (select count(*) from public.web_subscriptions where environment = 'production' and status = 'active') as live_subscriptions;
