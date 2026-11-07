-- Naira prices for buyers in Nigeria, 2026-11-07.
--
-- Every web payment so far was in US dollars, and none went through:
-- Flutterwave's log shows dollar cards from US and Puerto Rican banks
-- refused with "Restricted Card: bank restrictions", and a Verve card,
-- which can't pay in dollars. Buyers in Nigeria now pay in naira.
--
-- Each naira price is the dollar price's digits times 1,000: $7.99 is
-- N7,990 and $0.99 is N990. The apps pick naira for Nigeria; everyone else
-- still pays in dollars. Flutterwave payment plans for naira are made on
-- first use, as the dollar ones were.

insert into public.web_coin_prices (product_id, currency, amount)
select product_id, 'NGN', round(amount * 1000)
  from public.web_coin_prices where currency = 'USD'
on conflict (product_id, currency) do update set amount = excluded.amount;

insert into public.web_plan_prices (plan_id, currency, amount)
select plan_id, 'NGN', round(amount * 1000)
  from public.web_plan_prices where currency = 'USD'
on conflict (plan_id, currency) do update set amount = excluded.amount;

-- Chip Study's account summary also lists the plans' prices in each currency.
create or replace function public.study_me()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_settings public.study_settings;
  v_tier text;
  v_student_plan boolean;
  v_usage public.study_usage;
  v_avg_fast numeric;
  v_avg_best numeric;
  v_name text;
  v_email text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_settings from public.study_settings;
  v_tier := public._study_tier(v_me);
  v_student_plan := v_tier = 'pro' and public._study_on_student_plan(v_me);
  select * into v_usage from public.study_usage where user_id = v_me and day = v_today;
  select sum(fast_usd) / nullif(sum(asks - best_asks), 0), sum(best_usd) / nullif(sum(best_asks), 0)
    into v_avg_fast, v_avg_best
    from public.study_usage where user_id = v_me and day > v_today - 14;
  select coalesce(nullif(display_name, ''), username) into v_name from public.profiles where id = v_me;
  select email into v_email from auth.users where id = v_me;
  return jsonb_build_object(
    'tier', v_tier,
    'plan', case when v_tier <> 'pro' then null when v_student_plan then 'student' else 'pro' end,
    'name', v_name,
    'pro_until', public._web_plan_until(v_me, 'study_pro'),
    'resets_at', ((now() at time zone 'utc')::date + 1)::timestamp at time zone 'utc',
    'fast', jsonb_build_object(
      'used', coalesce(v_usage.fast_usd, 0),
      'cap', case when v_tier = 'pro' then v_settings.pro_fast_day_usd else v_settings.free_day_usd end,
      'avg', coalesce(v_avg_fast, v_settings.hold_fast_usd / 2)),
    'best', case when v_tier = 'pro' then jsonb_build_object(
      'used', coalesce(v_usage.best_usd, 0),
      'cap', case when v_student_plan then v_settings.student_best_day_usd else v_settings.pro_best_day_usd end,
      'period_used', public._study_period_best(v_me),
      'period_cap', case when v_student_plan then v_settings.student_best_period_usd else v_settings.pro_best_period_usd end,
      'avg', coalesce(v_avg_best, v_settings.hold_best_usd * 0.6)) end,
    'uploads', jsonb_build_object(
      'used', coalesce(v_usage.uploads, 0),
      'cap', case when v_tier = 'pro' then v_settings.pro_uploads_day else v_settings.free_uploads_day end,
      'max_mb', case when v_tier = 'pro' then v_settings.pro_upload_mb else v_settings.free_upload_mb end),
    'readings', jsonb_build_object(
      'used', public._study_readings_today(v_me),
      'cap', case when v_tier = 'pro' then v_settings.pro_readings_day else v_settings.free_readings_day end,
      'max_chars', case when v_tier = 'pro' then v_settings.pro_reading_chars else v_settings.free_reading_chars end),
    'student', jsonb_build_object(
      'eligible', public._study_is_student(v_me),
      'domain', nullif(lower(split_part(coalesce(v_email, ''), '@', 2)), '')),
    'price', (select jsonb_build_object('amount', amount, 'currency', currency)
                from public.web_plan_prices where plan_id = 'study.pro.monthly' and currency = 'USD'),
    'student_price', (select jsonb_build_object('amount', amount, 'currency', currency)
                        from public.web_plan_prices where plan_id = 'study.pro.student.monthly' and currency = 'USD'),
    -- Every currency each plan has a price in, so buyers in Nigeria see naira.
    'prices', (select jsonb_object_agg(currency, amount)
                 from public.web_plan_prices where plan_id = 'study.pro.monthly'),
    'student_prices', (select jsonb_object_agg(currency, amount)
                         from public.web_plan_prices where plan_id = 'study.pro.student.monthly')
  );
end;
$$;
