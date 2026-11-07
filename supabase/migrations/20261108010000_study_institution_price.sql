-- Chip Study for institutions: its price, and what a student's AI use can
-- cost under it (2026-11-08).
--
-- The price: per student per year, billed yearly, from 50 students, after a
-- free pilot (study_institution_prices; staff invoices start from it).
-- Students who have Pro only through their institution get every Pro
-- feature with a little less of Chip's best model (like the student plan),
-- so the most one student can cost stays well under what they pay for:
-- at most $0.04 of the fast model a day and $0.30 of the best a day, up to
-- $1.50 of it a month (about $2.70 a month in all, against about $3.75).
-- Anyone with Pro of their own keeps their own plan's allowance.

alter table public.study_settings
  add column inst_fast_day_usd numeric(8, 4) not null default 0.04 check (inst_fast_day_usd >= 0),
  add column inst_best_day_usd numeric(8, 4) not null default 0.30 check (inst_best_day_usd >= 0),
  add column inst_best_period_usd numeric(8, 4) not null default 1.50 check (inst_best_period_usd >= 0);

create table public.study_institution_prices (
  currency         text primary key check (currency ~ '^[A-Z]{3}$'),
  per_student_year numeric(12, 2) not null check (per_student_year > 0),
  min_students     int not null default 50 check (min_students > 0)
);
alter table public.study_institution_prices enable row level security;
insert into public.study_institution_prices (currency, per_student_year) values
  ('GBP', 36), ('USD', 45), ('EUR', 42), ('NGN', 45000);

/** The price for institutions, for the public page and staff invoices. */
create function public.study_institution_prices()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(currency, jsonb_build_object('per_student_year', per_student_year,
                                                                'min_students', min_students)), '{}'::jsonb)
    from public.study_institution_prices;
$$;
grant execute on function public.study_institution_prices() to anon, authenticated;

/** Which allowance someone has: 'pro' or 'student' (a plan of their own),
 * 'institution' (Pro only through an institution), 'guest' or 'free'. */
create function public._study_plan(p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when public._web_plan_until(p_user, 'study_pro') is not null then
      case when public._study_on_student_plan(p_user) then 'student' else 'pro' end
    when public._study_institution_pro(p_user) then 'institution'
    when exists (select 1 from auth.users where id = p_user and coalesce(is_anonymous, false)) then 'guest'
    else 'free' end;
$$;

/** That allowance's caps, in dollars: fast model a day, best model a day,
 * best model a period. */
create function public._study_caps(p_plan text, s public.study_settings)
returns jsonb language sql immutable as $$
  select case p_plan
    when 'pro' then jsonb_build_object('fast_day', s.pro_fast_day_usd, 'best_day', s.pro_best_day_usd,
                                       'best_period', s.pro_best_period_usd)
    when 'student' then jsonb_build_object('fast_day', s.pro_fast_day_usd, 'best_day', s.student_best_day_usd,
                                           'best_period', s.student_best_period_usd)
    when 'institution' then jsonb_build_object('fast_day', s.inst_fast_day_usd, 'best_day', s.inst_best_day_usd,
                                               'best_period', s.inst_best_period_usd)
    else jsonb_build_object('fast_day', s.free_day_usd, 'best_day', 0, 'best_period', 0) end;
$$;
revoke all on function public._study_plan(uuid), public._study_caps(text, public.study_settings) from public, anon, authenticated;

create or replace function public.study_allow(p_model text default 'fast', p_kind text default 'ask', p_bytes int default 0)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_resets timestamptz := ((now() at time zone 'utc')::date + 1)::timestamp at time zone 'utc';
  v_settings public.study_settings;
  v_tier text;
  v_usage public.study_usage;
  v_model text;
  v_note text;
  v_hold numeric;
  v_spent numeric;
  v_plan text;
  v_caps jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('ask', 'upload') then raise exception 'unknown kind'; end if;
  v_tier := public._study_tier(v_me);
  if v_tier = 'guest' then
    return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'account');
  end if;
  select * into v_settings from public.study_settings;
  v_plan := public._study_plan(v_me);
  v_caps := public._study_caps(v_plan, v_settings);

  insert into public.study_usage (user_id, day) values (v_me, v_today)
    on conflict (user_id, day) do nothing;
  select * into v_usage from public.study_usage where user_id = v_me and day = v_today for update;

  if p_kind = 'upload' then
    if coalesce(p_bytes, 0) > (case when v_tier = 'pro' then v_settings.pro_upload_mb else v_settings.free_upload_mb end)::bigint * 1048576 then
      return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'size',
        'max_mb', case when v_tier = 'pro' then v_settings.pro_upload_mb else v_settings.free_upload_mb end);
    end if;
    if v_usage.uploads >= (case when v_tier = 'pro' then v_settings.pro_uploads_day else v_settings.free_uploads_day end) then
      return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'uploads', 'resets_at', v_resets);
    end if;
  end if;

  if p_model = 'best' and v_tier = 'pro' then
    if v_usage.best_usd >= (v_caps ->> 'best_day')::numeric
       or public._study_period_best(v_me) >= (v_caps ->> 'best_period')::numeric then
      v_model := 'fast';
      v_note := 'best_used';
    else
      v_model := 'best';
    end if;
  else
    v_model := 'fast';
    if p_model = 'best' then v_note := 'pro'; end if;
  end if;

  if v_model = 'fast' then
    if v_usage.fast_usd >= (v_caps ->> 'fast_day')::numeric then
      return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'limit', 'resets_at', v_resets);
    end if;
    if v_tier = 'free' then
      select coalesce(sum(usd), 0) into v_spent from public.study_costs where day = v_today and tier = 'free';
      if v_spent >= v_settings.daily_free_usd then
        return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'busy', 'resets_at', v_resets);
      end if;
    end if;
  end if;

  v_hold := case when v_model = 'best' then v_settings.hold_best_usd else v_settings.hold_fast_usd end;
  update public.study_usage set
    fast_usd = fast_usd + case when v_model = 'fast' then v_hold else 0 end,
    best_usd = best_usd + case when v_model = 'best' then v_hold else 0 end,
    asks = asks + case when p_kind = 'ask' then 1 else 0 end,
    best_asks = best_asks + case when p_kind = 'ask' and v_model = 'best' then 1 else 0 end,
    uploads = uploads + case when p_kind = 'upload' then 1 else 0 end
   where user_id = v_me and day = v_today;
  return jsonb_build_object('ok', true, 'tier', v_tier, 'model', v_model, 'day', v_today,
                            'hold', v_hold, 'note', v_note);
end;
$$;

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
  v_plan text;
  v_caps jsonb;
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
  v_plan := public._study_plan(v_me);
  v_caps := public._study_caps(v_plan, v_settings);
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
    -- Pro through an institution, without a plan of their own.
    'via_institution', v_plan = 'institution',
    'pro_until', public._web_plan_until(v_me, 'study_pro'),
    'resets_at', ((now() at time zone 'utc')::date + 1)::timestamp at time zone 'utc',
    'fast', jsonb_build_object(
      'used', coalesce(v_usage.fast_usd, 0),
      'cap', (v_caps ->> 'fast_day')::numeric,
      'avg', coalesce(v_avg_fast, v_settings.hold_fast_usd / 2)),
    'best', case when v_tier = 'pro' then jsonb_build_object(
      'used', coalesce(v_usage.best_usd, 0),
      'cap', (v_caps ->> 'best_day')::numeric,
      'period_used', public._study_period_best(v_me),
      'period_cap', (v_caps ->> 'best_period')::numeric,
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
