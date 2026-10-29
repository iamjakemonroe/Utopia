-- Chip Study's pricing, set for profit at the limit and fairness to students.
--
-- Every call to Chip is counted in dollars of model time (study_allow holds,
-- study_spend settles), so a plan's allowance is the most a member can cost.
-- After Flutterwave's worst-case fee (international cards, 4.8% + VAT =
-- 5.16%), each plan keeps a margin even when its member uses every cent:
--
--   Chip Study Pro       $7.99/month, keeps $7.58. Best model $0.60/day and
--                        $4.50/month (about 20 a day, 150 a month, at ~3c an
--                        in-depth message); Fast $0.06/day (about 48 a day).
--                        At the limit: $4.50 + 31 x $0.06 = $6.36, +$1.22.
--   Chip Study Pro       $5.99/month (25% off) for a confirmed school email,
--   (student)            keeps $5.68. Best model $0.45/day and $3.30/month
--                        (about 15 a day, 110 a month); Fast as Pro. At the
--                        limit: $3.30 + $1.86 = $5.16, +$0.52.
--
-- Typical members use far less than the limit (most margins are well over
-- half). Pro was $4.99 with $3.00 a month of the best model (about 100
-- messages); both plans now give more, and nobody had paid the old price.
-- The numbers live in study_settings and web_plan_prices: change them there
-- (a new price also needs flw_plan_id = null, so Flutterwave gets a plan at
-- the new price).
--
-- A school email: a confirmed email under .edu, .edu.xx or .ac.xx, or under
-- a domain in study_school_domains (universities that use neither; add more
-- with an insert).

-- ── The allowances ─────────────────────────────────────────────────────────

alter table public.study_settings
  add column student_best_day_usd numeric(8, 4) not null default 0.45 check (student_best_day_usd >= 0),
  add column student_best_period_usd numeric(8, 4) not null default 3.30 check (student_best_period_usd >= 0);

update public.study_settings
   set pro_fast_day_usd = 0.06, pro_best_day_usd = 0.60, pro_best_period_usd = 4.50;

-- ── The prices ─────────────────────────────────────────────────────────────

update public.web_plan_prices set amount = 7.99, flw_plan_id = null
 where plan_id = 'study.pro.monthly';

insert into public.web_plans (id, product, title, period, days, reply_cap, learn_cap, sort) values
  ('study.pro.student.monthly', 'study_pro', 'Chip Study Pro (student)', 'monthly', 30, null, null, 5)
on conflict (id) do nothing;

insert into public.web_plan_prices (plan_id, currency, amount) values
  ('study.pro.student.monthly', 'USD', 5.99)
on conflict (plan_id, currency) do nothing;

-- ── School emails ──────────────────────────────────────────────────────────

/** Universities whose email domains end in neither .edu nor .ac.xx (a
 * subdomain counts too: mail.utoronto.ca is under utoronto.ca). */
create table public.study_school_domains (
  domain text primary key check (domain = lower(domain) and domain ~ '^[a-z0-9.-]+\.[a-z]{2,}$')
);

alter table public.study_school_domains enable row level security;

insert into public.study_school_domains (domain) values
  -- Canada
  ('utoronto.ca'), ('mcgill.ca'), ('ubc.ca'), ('ualberta.ca'), ('uwaterloo.ca'), ('queensu.ca'),
  ('uottawa.ca'), ('yorku.ca'), ('mcmaster.ca'), ('ucalgary.ca'), ('dal.ca'), ('umontreal.ca'),
  ('sfu.ca'), ('carleton.ca'), ('uwo.ca'),
  -- Germany, Switzerland, the Netherlands
  ('tum.de'), ('lmu.de'), ('uni-heidelberg.de'), ('fu-berlin.de'), ('hu-berlin.de'), ('tu-berlin.de'),
  ('rwth-aachen.de'), ('ethz.ch'), ('epfl.ch'), ('uzh.ch'), ('unibas.ch'), ('uva.nl'), ('tudelft.nl'),
  ('leidenuniv.nl'), ('uu.nl'), ('rug.nl'), ('eur.nl'), ('vu.nl'),
  -- The Nordics and Ireland
  ('kth.se'), ('uu.se'), ('lu.se'), ('su.se'), ('ku.dk'), ('au.dk'), ('dtu.dk'), ('helsinki.fi'),
  ('aalto.fi'), ('uio.no'), ('ntnu.no'), ('tcd.ie'), ('ucd.ie'), ('ucdconnect.ie'), ('ucc.ie'),
  ('universityofgalway.ie'),
  -- France, Italy, Spain
  ('sorbonne-universite.fr'), ('universite-paris-saclay.fr'), ('sciencespo.fr'), ('unimi.it'),
  ('polimi.it'), ('unibo.it'), ('uniroma1.it'), ('ucm.es'), ('uam.es'),
  -- Latin America
  ('unam.mx'), ('usp.br'), ('uba.ar')
on conflict (domain) do nothing;

/** Whether [p_email] is a school's: under .edu, .edu.xx or .ac.xx, or under
 * a domain in study_school_domains. */
create function public._study_school_email(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with d as (select lower(split_part(coalesce(p_email, ''), '@', 2)) as domain)
  select d.domain <> '' and (
           d.domain ~ '(^|\.)edu$'
        or d.domain ~ '\.edu\.[a-z]{2}$'
        or d.domain ~ '\.ac\.[a-z]{2}$'
        or exists (select 1 from public.study_school_domains s
                    where d.domain = s.domain or d.domain like '%.' || s.domain))
    from d;
$$;

revoke all on function public._study_school_email(text) from public, anon, authenticated;

/** Whether [p_user] signs in with a confirmed school email (the student price). */
create function public._study_is_student(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select u.email_confirmed_at is not null and not coalesce(u.is_anonymous, false)
                          and public._study_school_email(u.email)
                     from auth.users u where u.id = p_user), false);
$$;

revoke all on function public._study_is_student(uuid) from public, anon, authenticated;

/** Whether [p_user]'s Chip Study Pro is the student plan (and not also the
 * full one): the student allowances apply. */
create function public._study_on_student_plan(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.web_subscriptions s
                  where s.user_id = p_user and s.plan_id = 'study.pro.student.monthly'
                    and s.status in ('active', 'cancelled') and s.period_end > now())
     and not exists (select 1 from public.web_subscriptions s
                      where s.user_id = p_user and s.plan_id = 'study.pro.monthly'
                        and s.status in ('active', 'cancelled') and s.period_end > now());
$$;

revoke all on function public._study_on_student_plan(uuid) from public, anon, authenticated;

-- ── Subscribing: the student plan is for school emails ─────────────────────

/** Starts subscribing to [p_plan] (accounts only, and not while already a
 * member of it): the checkout's reference, price and Flutterwave plan (null
 * until the web-pay function has made it, see web_plan_flw). Chip Study's
 * student plan needs a confirmed school email. */
create or replace function public.web_subscribe_start(p_plan text, p_currency text default 'USD')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_plan public.web_plans;
  v_price public.web_plan_prices;
  v_email text;
  v_name text;
  v_ref text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select email into v_email from auth.users where id = v_me and not coalesce(is_anonymous, false);
  if v_email is null then raise exception 'save your account first'; end if;
  select * into v_plan from public.web_plans where id = p_plan;
  if not found then raise exception 'unknown plan'; end if;
  if p_plan = 'study.pro.student.monthly' and not public._study_is_student(v_me) then
    raise exception 'not a school email';
  end if;
  if (v_plan.product = 'maestro' and public._maestro_until(v_me) is not null)
     or (v_plan.product <> 'maestro' and public._web_plan_until(v_me, v_plan.product) is not null) then
    raise exception 'already a member';
  end if;
  select * into v_price from public.web_plan_prices
   where plan_id = p_plan and currency = upper(coalesce(p_currency, 'USD'));
  if not found then
    select * into v_price from public.web_plan_prices where plan_id = p_plan and currency = 'USD';
  end if;

  v_ref := 'kaivon-sub-' || replace(gen_random_uuid()::text, '-', '');
  insert into public.web_subscriptions (user_id, plan_id, currency, amount, ref, email, flw_plan_id)
  values (v_me, p_plan, v_price.currency, v_price.amount, v_ref, v_email, v_price.flw_plan_id);
  select coalesce(display_name, username) into v_name from public.profiles where id = v_me;
  return jsonb_build_object(
    'ref', v_ref,
    'plan', p_plan,
    'product', v_plan.product,
    'title', v_plan.title,
    'period', v_plan.period,
    'amount', v_price.amount,
    'currency', v_price.currency,
    'flw_plan_id', v_price.flw_plan_id,
    'email', v_email,
    'name', v_name
  );
end;
$$;

-- ── The allowance: the student plan's best-model limits ────────────────────

/** Holds one call to Chip against [auth.uid()]'s allowance before it's made.
 * [p_model] is what they asked for ('best' or 'fast'), [p_kind] 'ask' (a
 * message) or 'upload' (a file Chip reads, [p_bytes] long). Answers
 * {ok, tier, model, day, hold, note} with the model to use (Pro's best
 * model falls back to Fast once its day or period is used: note
 * 'best_used'; a free account asking for it gets Fast: note 'pro'), or
 * {ok: false, why} with why: 'account' (a guest), 'limit' (today's is used,
 * resets_at), 'busy' (free accounts' shared budget is used), 'size' (the
 * file's too big, max_mb) or 'uploads' (today's are used). The student
 * plan's best model has its own day and period. */
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
  v_student boolean;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('ask', 'upload') then raise exception 'unknown kind'; end if;
  v_tier := public._study_tier(v_me);
  if v_tier = 'guest' then
    return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'account');
  end if;
  select * into v_settings from public.study_settings;
  v_student := v_tier = 'pro' and public._study_on_student_plan(v_me);

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
    if v_usage.best_usd >= (case when v_student then v_settings.student_best_day_usd else v_settings.pro_best_day_usd end)
       or public._study_period_best(v_me) >= (case when v_student then v_settings.student_best_period_usd else v_settings.pro_best_period_usd end) then
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
    if v_usage.fast_usd >= (case when v_tier = 'pro' then v_settings.pro_fast_day_usd else v_settings.free_day_usd end) then
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

-- ── The account, for the app: the plan, the student price, both prices ─────

/** The signed-in student, for Chip Study: their name, tier, plan ('pro',
 * 'student', or null) and Pro's end, what's left of today's allowance (and
 * Pro's period) with what a message has typically cost them on each model,
 * for "about N left", whether their email gets the student price, and both
 * prices. */
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
                        from public.web_plan_prices where plan_id = 'study.pro.student.monthly' and currency = 'USD')
  );
end;
$$;
