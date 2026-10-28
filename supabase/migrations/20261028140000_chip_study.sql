-- Chip Study (study.kaivon.app): a calm place to study and really learn, with
-- Chip as a tutor: it guides the student to the answer, explains step by
-- step, checks their own work and says why, turns what they study into
-- practice, and helps with assignments without doing them for them. On the
-- student's Kaivon account (the same one as Utopia).
--
--   * Each student's study spaces: something they're learning (a topic) or
--     an assignment, and in each: what it's about (an assignment's brief and
--     rubric), the documents they write (a doc, code, or a small table),
--     notes, sources (with a reading's text, if they add one) and a task
--     checklist with dates. Only the owner sees or changes any of it.
--   * A review deck of flashcards (study_cards), spaced out by how well the
--     student knew each one, and their practice results (study_practice:
--     quizzes taken and review sessions), for the progress view.
--   * Chip's conversations (study_threads, study_messages) and the AI-use
--     record (study_ai_log) are written by the chip-study function. The
--     student reads them and can clear a conversation, but can't edit or
--     remove a line of the record, so the declaration it exports is honest.
--     When they put Chip's words into their document, or add the tasks or
--     sources Chip suggested, that's noted too (study_log_use).
--   * Focus sessions (the timer), added up on each assignment.
--   * Chip's allowance is counted in dollars of model time, so a quick
--     question goes further than a long draft (study_settings):
--       - free accounts: Chip Fast (the quick model), free_day_usd a day;
--       - Chip Study Pro ($4.99 a month, a web plan): Chip's best model up to
--         pro_best_day_usd a day and pro_best_period_usd a period, then Fast,
--         which has pro_fast_day_usd a day of its own; and web research.
--     study_allow holds an estimate before each call, and study_spend
--     settles it with what the call really cost (study_costs keeps each
--     day's totals). All free accounts together stop at daily_free_usd.
--   * Readings and uploads are limited per tier: free accounts 3 readings a
--     day of up to 60,000 characters and 3 uploads Chip reads (4 MB); Pro
--     30 readings of 400,000 characters and 25 uploads (20 MB).
--   * study_forget: everything of a student's here, gone (from Chip Study's
--     settings, and when a Kaivon account is deleted).
--
-- Change an allowance in the SQL editor, e.g.
--   update study_settings set free_day_usd = 0.04;
-- and the price in web_plan_prices (plan 'study.pro.monthly'; set
-- flw_plan_id = null on that row so a plan at the new price is made).

alter table public.web_plans drop constraint web_plans_product_check;
alter table public.web_plans add constraint web_plans_product_check
  check (product in ('maestro', 'rizz_pro', 'study_pro'));

insert into public.web_plans (id, product, title, period, days, reply_cap, learn_cap, sort) values
  ('study.pro.monthly', 'study_pro', 'Chip Study Pro', 'monthly', 30, null, null, 4);
insert into public.web_plan_prices (plan_id, currency, amount) values
  ('study.pro.monthly', 'USD', 4.99);

-- ── Settings, usage and costs (the server's own) ───────────────────────

create table public.study_settings (
  id                   boolean primary key default true check (id),
  free_day_usd         numeric(8, 4) not null default 0.03 check (free_day_usd >= 0),
  pro_fast_day_usd     numeric(8, 4) not null default 0.05 check (pro_fast_day_usd >= 0),
  pro_best_day_usd     numeric(8, 4) not null default 0.40 check (pro_best_day_usd >= 0),
  pro_best_period_usd  numeric(8, 4) not null default 3.00 check (pro_best_period_usd >= 0),
  daily_free_usd       numeric(10, 2) not null default 15 check (daily_free_usd >= 0),
  -- What a call is held at until it's settled (a typical one, a little over).
  hold_fast_usd        numeric(8, 4) not null default 0.002 check (hold_fast_usd >= 0),
  hold_best_usd        numeric(8, 4) not null default 0.05 check (hold_best_usd >= 0),
  free_readings_day    int not null default 3 check (free_readings_day >= 0),
  pro_readings_day     int not null default 30 check (pro_readings_day >= 0),
  free_reading_chars   int not null default 60000 check (free_reading_chars >= 0),
  pro_reading_chars    int not null default 400000 check (pro_reading_chars >= 0),
  free_uploads_day     int not null default 3 check (free_uploads_day >= 0),
  pro_uploads_day      int not null default 25 check (pro_uploads_day >= 0),
  free_upload_mb       int not null default 4 check (free_upload_mb >= 0),
  pro_upload_mb        int not null default 20 check (pro_upload_mb >= 0)
);
insert into public.study_settings default values;

create table public.study_usage (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  day        date not null,
  fast_usd   numeric(12, 5) not null default 0,
  best_usd   numeric(12, 5) not null default 0,
  asks       int not null default 0,
  best_asks  int not null default 0,
  uploads    int not null default 0,
  searches   int not null default 0,
  primary key (user_id, day)
);

create table public.study_costs (
  day                date not null,
  feature            text not null,
  model              text not null,
  tier               text not null check (tier in ('free', 'pro')),
  calls              int not null default 0,
  input_tokens       bigint not null default 0,
  output_tokens      bigint not null default 0,
  cache_read_tokens  bigint not null default 0,
  cache_write_tokens bigint not null default 0,
  searches           int not null default 0,
  usd                numeric(12, 5) not null default 0,
  primary key (day, feature, model, tier)
);

alter table public.study_settings enable row level security;
alter table public.study_usage enable row level security;
alter table public.study_costs enable row level security;
revoke all on public.study_settings, public.study_usage, public.study_costs from anon, authenticated;

create view public.study_spend with (security_invoker = true) as
select day,
       round(sum(usd), 2) as usd,
       round(coalesce(sum(usd) filter (where tier = 'pro'), 0), 2) as pro_usd,
       round(coalesce(sum(usd) filter (where tier = 'free'), 0), 2) as free_usd,
       sum(calls) as calls
  from public.study_costs
 group by day
 order by day desc;
revoke all on public.study_spend from anon, authenticated;

-- ── The student's work ─────────────────────────────────────────────────

create table public.study_assignments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title         text not null check (char_length(title) between 1 and 200),
  course        text not null default '' check (char_length(course) <= 120),
  brief         text not null default '' check (char_length(brief) <= 60000),
  rubric        text not null default '' check (char_length(rubric) <= 30000),
  due_at        timestamptz,
  word_target   int check (word_target between 1 and 200000),
  style         text not null default 'apa' check (style in ('apa', 'harvard')),
  status        text not null default 'active' check (status in ('active', 'submitted', 'archived')),
  color         text not null default 'sky' check (color in ('sky', 'lilac', 'mint', 'peach', 'rose', 'sand')),
  -- Something the student is learning, or an assignment to hand in.
  kind          text not null default 'assignment' check (kind in ('topic', 'assignment')),
  -- Kept for the dashboard: the main document's words, and focus minutes.
  words         int not null default 0 check (words >= 0),
  focus_minutes int not null default 0 check (focus_minutes >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index study_assignments_by_user on public.study_assignments (user_id, updated_at desc);

create table public.study_documents (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.study_assignments (id) on delete cascade,
  user_id       uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  kind          text not null default 'doc' check (kind in ('doc', 'code', 'sheet')),
  title         text not null default 'Draft' check (char_length(title) between 1 and 200),
  -- The editor's own form (a doc's nodes, code and its language, a table's cells).
  content       jsonb not null default '{}'::jsonb check (pg_column_size(content) <= 2000000),
  -- Plain text, for Chip and for search.
  text          text not null default '' check (char_length(text) <= 400000),
  words         int not null default 0 check (words >= 0),
  -- Words still in Chip's wording (text the student put in from Chip and hasn't rewritten).
  chip_words    int not null default 0 check (chip_words >= 0),
  version       int not null default 1,
  sort          int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index study_documents_by_assignment on public.study_documents (assignment_id, sort);

create table public.study_sources (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.study_assignments (id) on delete cascade,
  user_id       uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  kind          text not null default 'web'
                check (kind in ('book', 'chapter', 'article', 'web', 'report', 'video', 'other')),
  -- authors, year, title, container, publisher, place, edition, volume,
  -- issue, pages, doi, url, accessed (all optional).
  data          jsonb not null default '{}'::jsonb check (pg_column_size(data) <= 20000),
  note          text not null default '' check (char_length(note) <= 20000),
  -- A reading's text (from a PDF or DOCX the student added), for Chip.
  content       text not null default '',
  file_name     text check (char_length(file_name) <= 300),
  created_by    text not null default 'me' check (created_by in ('me', 'chip')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index study_sources_by_assignment on public.study_sources (assignment_id, created_at);
create index study_sources_readings_by_user on public.study_sources (user_id, created_at)
  where content <> '';

create table public.study_notes (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.study_assignments (id) on delete cascade,
  user_id       uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body          text not null default '' check (char_length(body) <= 20000),
  pinned        boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index study_notes_by_assignment on public.study_notes (assignment_id, created_at);

create table public.study_tasks (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.study_assignments (id) on delete cascade,
  user_id       uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title         text not null check (char_length(title) between 1 and 300),
  due_on        date,
  done          boolean not null default false,
  done_at       timestamptz,
  sort          int not null default 0,
  created_by    text not null default 'me' check (created_by in ('me', 'chip')),
  created_at    timestamptz not null default now()
);
create index study_tasks_by_assignment on public.study_tasks (assignment_id, sort);
create index study_tasks_by_user on public.study_tasks (user_id);

create table public.study_focus (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  assignment_id uuid references public.study_assignments (id) on delete set null,
  started_at    timestamptz not null default now()
                check (started_at <= now() + interval '5 minutes'),
  minutes       int not null check (minutes between 1 and 240),
  created_at    timestamptz not null default now()
);
create index study_focus_by_user on public.study_focus (user_id, started_at desc);

-- The review deck: flashcards, each due again after an interval that grows
-- as the student remembers it (the app moves it on as it's reviewed).
create table public.study_cards (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  -- Where it came from (a card outlives its study space).
  assignment_id uuid references public.study_assignments (id) on delete set null,
  front         text not null check (char_length(front) between 1 and 600),
  back          text not null check (char_length(back) between 1 and 2000),
  created_by    text not null default 'me' check (created_by in ('me', 'chip')),
  ease          numeric(4, 2) not null default 2.5 check (ease between 1.3 and 3.5),
  interval_days int not null default 0 check (interval_days between 0 and 3650),
  reps          int not null default 0 check (reps >= 0),
  lapses        int not null default 0 check (lapses >= 0),
  due_at        timestamptz not null default now(),
  reviewed_at   timestamptz,
  created_at    timestamptz not null default now()
);
create index study_cards_due on public.study_cards (user_id, due_at);

-- Practice results: a quiz taken, or a review session, as right out of total.
create table public.study_practice (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  assignment_id uuid references public.study_assignments (id) on delete set null,
  kind          text not null check (kind in ('quiz', 'review')),
  correct       int not null check (correct >= 0),
  total         int not null check (total between 1 and 500),
  at            timestamptz not null default now(),
  check (correct <= total)
);
create index study_practice_by_user on public.study_practice (user_id, at desc);

-- Chip's side (written by the chip-study function).
create table public.study_threads (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.study_assignments (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  title         text not null default '' check (char_length(title) <= 200),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index study_threads_by_assignment on public.study_threads (assignment_id, updated_at desc);

create table public.study_messages (
  id            uuid primary key default gen_random_uuid(),
  thread_id     uuid not null references public.study_threads (id) on delete cascade,
  assignment_id uuid not null references public.study_assignments (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  role          text not null check (role in ('user', 'chip')),
  mode          text not null check (mode in ('guide', 'explain', 'plan', 'write', 'check', 'cite', 'quiz')),
  content       text not null check (char_length(content) <= 120000),
  -- The selection asked about, the model, and so on.
  meta          jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);
create index study_messages_by_thread on public.study_messages (thread_id, created_at);

create table public.study_ai_log (
  id            uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.study_assignments (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  message_id    uuid references public.study_messages (id) on delete set null,
  at            timestamptz not null default now(),
  -- What Chip was asked to do (a mode, or 'setup' for reading the brief),
  -- or what the student did with it.
  action        text not null check (action in (
                  'guide', 'explain', 'plan', 'write', 'check', 'cite', 'quiz', 'setup',
                  'inserted', 'replaced', 'added_tasks', 'added_sources')),
  summary       text not null default '' check (char_length(summary) <= 600),
  prompt        text not null default '' check (char_length(prompt) <= 2000),
  output        text not null default '' check (char_length(output) <= 4000),
  words         int not null default 0 check (words >= 0),
  model         text not null default ''
);
create index study_ai_log_by_assignment on public.study_ai_log (assignment_id, at);

-- ── Who sees what ──────────────────────────────────────────────────────

alter table public.study_assignments enable row level security;
alter table public.study_documents enable row level security;
alter table public.study_sources enable row level security;
alter table public.study_notes enable row level security;
alter table public.study_tasks enable row level security;
alter table public.study_focus enable row level security;
alter table public.study_threads enable row level security;
alter table public.study_messages enable row level security;
alter table public.study_ai_log enable row level security;
alter table public.study_cards enable row level security;
alter table public.study_practice enable row level security;

revoke all on public.study_assignments, public.study_documents, public.study_sources,
  public.study_notes, public.study_tasks, public.study_focus, public.study_threads,
  public.study_messages, public.study_ai_log, public.study_cards, public.study_practice
  from anon, authenticated;

grant select, insert, update, delete on public.study_assignments, public.study_documents,
  public.study_sources, public.study_notes, public.study_tasks to authenticated;
grant select, insert, delete on public.study_focus to authenticated;
grant select, insert, update, delete on public.study_cards to authenticated;
grant select, insert on public.study_practice to authenticated;
grant select, delete on public.study_threads to authenticated;
grant select on public.study_messages, public.study_ai_log to authenticated;

/** Whether [p_assignment] is the signed-in student's. */
create function public._study_mine(p_assignment uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.study_assignments
                  where id = p_assignment and user_id = auth.uid());
$$;

revoke all on function public._study_mine(uuid) from public, anon;
grant execute on function public._study_mine(uuid) to authenticated;

create policy "study_assignments: own" on public.study_assignments for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "study_documents: own" on public.study_documents for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and public._study_mine(assignment_id));

create policy "study_sources: own" on public.study_sources for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and public._study_mine(assignment_id));

create policy "study_notes: own" on public.study_notes for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and public._study_mine(assignment_id));

create policy "study_tasks: own" on public.study_tasks for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and public._study_mine(assignment_id));

create policy "study_focus: own" on public.study_focus for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid()
              and (assignment_id is null or public._study_mine(assignment_id)));

create policy "study_cards: own" on public.study_cards for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid()
              and (assignment_id is null or public._study_mine(assignment_id)));

create policy "study_practice: own" on public.study_practice for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid()
              and (assignment_id is null or public._study_mine(assignment_id)));

create policy "study_threads: own" on public.study_threads for select to authenticated
  using (user_id = auth.uid());
create policy "study_threads: clear" on public.study_threads for delete to authenticated
  using (user_id = auth.uid());

create policy "study_messages: own" on public.study_messages for select to authenticated
  using (user_id = auth.uid());

create policy "study_ai_log: own" on public.study_ai_log for select to authenticated
  using (user_id = auth.uid());

-- ── Housekeeping triggers ──────────────────────────────────────────────

create function public._study_touch()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger study_assignments_touch before update on public.study_assignments
  for each row execute function public._study_touch();
create trigger study_documents_touch before update on public.study_documents
  for each row execute function public._study_touch();
create trigger study_sources_touch before update on public.study_sources
  for each row execute function public._study_touch();
create trigger study_notes_touch before update on public.study_notes
  for each row execute function public._study_touch();

/** A row's owner and assignment can't move once it's made. */
create function public._study_pinned()
returns trigger
language plpgsql
as $$
begin
  if new.user_id <> old.user_id
     or (to_jsonb(new) ? 'assignment_id' and to_jsonb(new) ->> 'assignment_id' is distinct from to_jsonb(old) ->> 'assignment_id') then
    raise exception 'can''t move this';
  end if;
  return new;
end;
$$;

create trigger study_assignments_pinned before update on public.study_assignments
  for each row execute function public._study_pinned();
create trigger study_documents_pinned before update on public.study_documents
  for each row execute function public._study_pinned();
create trigger study_sources_pinned before update on public.study_sources
  for each row execute function public._study_pinned();
create trigger study_notes_pinned before update on public.study_notes
  for each row execute function public._study_pinned();
create trigger study_tasks_pinned before update on public.study_tasks
  for each row execute function public._study_pinned();

/** A task ticked off notes when. */
create function public._study_task_done()
returns trigger
language plpgsql
as $$
begin
  if new.done and (tg_op = 'INSERT' or not old.done) then
    new.done_at := now();
  elsif not new.done then
    new.done_at := null;
  end if;
  return new;
end;
$$;

create trigger study_tasks_done before insert or update on public.study_tasks
  for each row execute function public._study_task_done();

/** A focus session adds to its assignment's minutes (and a deleted one
 * takes them back off). */
create function public._study_focus_minutes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.assignment_id is not null then
    update public.study_assignments set focus_minutes = focus_minutes + new.minutes
     where id = new.assignment_id;
  elsif tg_op = 'DELETE' and old.assignment_id is not null then
    update public.study_assignments set focus_minutes = greatest(focus_minutes - old.minutes, 0)
     where id = old.assignment_id;
  end if;
  return null;
end;
$$;

create trigger study_focus_minutes after insert or delete on public.study_focus
  for each row execute function public._study_focus_minutes();

-- ── Tiers and allowances ───────────────────────────────────────────────

/** Who's asking, for Chip Study: 'pro', 'free', or 'guest' (an anonymous
 * Utopia player, who has to save their account first). */
create function public._study_tier(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public._web_plan_until(p_user, 'study_pro') is not null then 'pro'
    when exists (select 1 from auth.users where id = p_user and coalesce(is_anonymous, false)) then 'guest'
    else 'free' end;
$$;

revoke all on function public._study_tier(uuid) from public, anon, authenticated;

/** What a Pro member has spent on Chip's best model this period. */
create function public._study_period_best(p_user uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  with plan as (
    select s.period_end, p.days
      from public.web_subscriptions s join public.web_plans p on p.id = s.plan_id
     where s.user_id = p_user and p.product = 'study_pro'
       and s.status in ('active', 'cancelled') and s.period_end > now()
     order by s.period_end desc limit 1
  )
  select coalesce((select sum(u.best_usd) from public.study_usage u
                    where u.user_id = p_user
                      and u.day > ((plan.period_end - make_interval(days => plan.days + 1)) at time zone 'utc')::date), 0)
    from plan;
$$;

revoke all on function public._study_period_best(uuid) from public, anon, authenticated;

/** Readings added today by [p_user]. */
create function public._study_readings_today(p_user uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int from public.study_sources
   where user_id = p_user and content <> ''
     and created_at >= ((now() at time zone 'utc')::date)::timestamp at time zone 'utc';
$$;

revoke all on function public._study_readings_today(uuid) from public, anon, authenticated;

/** A reading's text stays within what the student's tier allows, in
 * length and in how many can be added a day. */
create function public._study_source_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.study_settings;
  v_pro boolean;
begin
  if new.content = '' or (tg_op = 'UPDATE' and new.content = old.content) then
    return new;
  end if;
  select * into v_settings from public.study_settings;
  v_pro := public._study_tier(new.user_id) = 'pro';
  if char_length(new.content) > (case when v_pro then v_settings.pro_reading_chars else v_settings.free_reading_chars end) then
    raise exception 'reading too long';
  end if;
  if (tg_op = 'INSERT' or old.content = '')
     and public._study_readings_today(new.user_id)
         >= (case when v_pro then v_settings.pro_readings_day else v_settings.free_readings_day end) then
    raise exception 'readings limit';
  end if;
  return new;
end;
$$;

create trigger study_sources_guard before insert or update on public.study_sources
  for each row execute function public._study_source_guard();

/** Takes one call to Chip for the signed-in student, before it's made:
 * [p_model] is what they asked for ('best' or 'fast'), [p_kind] 'ask' (a
 * message) or 'upload' (a file Chip reads, [p_bytes] long). Answers
 * {ok, tier, model, day, hold, note} with the model to use (Pro's best
 * model falls back to Fast once its day or period is used: note
 * 'best_used'; a free account asking for it gets Fast: note 'pro'), or
 * {ok: false, why} with why: 'account' (a guest), 'limit' (today's is used,
 * resets_at), 'busy' (free accounts' shared budget is used), 'size' (the
 * file's too big, max_mb) or 'uploads' (today's are used). */
create function public.study_allow(p_model text default 'fast', p_kind text default 'ask', p_bytes int default 0)
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
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_kind not in ('ask', 'upload') then raise exception 'unknown kind'; end if;
  v_tier := public._study_tier(v_me);
  if v_tier = 'guest' then
    return jsonb_build_object('ok', false, 'tier', v_tier, 'why', 'account');
  end if;
  select * into v_settings from public.study_settings;

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
    if v_usage.best_usd >= v_settings.pro_best_day_usd
       or public._study_period_best(v_me) >= v_settings.pro_best_period_usd then
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

revoke all on function public.study_allow(text, text, int) from public, anon;
grant execute on function public.study_allow(text, text, int) to authenticated;

/** What a call to Chip really cost ([p_usd]), settling the [p_hold] that
 * study_allow took on [p_day], and added to the day's totals. */
create function public.study_spend(
  p_user uuid,
  p_day date,
  p_kind text,
  p_hold numeric,
  p_feature text,
  p_model text,
  p_input bigint,
  p_output bigint,
  p_cache_read bigint,
  p_cache_write bigint,
  p_searches int,
  p_usd numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier text := case when public._study_tier(p_user) = 'pro' then 'pro' else 'free' end;
begin
  insert into public.study_usage (user_id, day) values (p_user, p_day)
    on conflict (user_id, day) do nothing;
  update public.study_usage set
    fast_usd = greatest(fast_usd + case when p_kind = 'fast' then p_usd - p_hold else 0 end, 0),
    best_usd = greatest(best_usd + case when p_kind = 'best' then p_usd - p_hold else 0 end, 0),
    searches = searches + greatest(p_searches, 0)
   where user_id = p_user and day = p_day;
  insert into public.study_costs as c (
    day, feature, model, tier, calls, input_tokens, output_tokens,
    cache_read_tokens, cache_write_tokens, searches, usd
  )
  values ((now() at time zone 'utc')::date, p_feature, p_model, v_tier, 1,
          p_input, p_output, p_cache_read, p_cache_write, p_searches, p_usd)
  on conflict (day, feature, model, tier) do update set
    calls = c.calls + 1,
    input_tokens = c.input_tokens + excluded.input_tokens,
    output_tokens = c.output_tokens + excluded.output_tokens,
    cache_read_tokens = c.cache_read_tokens + excluded.cache_read_tokens,
    cache_write_tokens = c.cache_write_tokens + excluded.cache_write_tokens,
    searches = c.searches + excluded.searches,
    usd = c.usd + excluded.usd;
end;
$$;

revoke all on function public.study_spend(uuid, date, text, numeric, text, text, bigint, bigint, bigint, bigint, int, numeric)
  from public, anon, authenticated;
grant execute on function public.study_spend(uuid, date, text, numeric, text, text, bigint, bigint, bigint, bigint, int, numeric)
  to service_role;

/** The signed-in student, for Chip Study: their name, tier and Pro's end,
 * and what's left of today's allowance (and Pro's period) with what a
 * message has typically cost them on each model, for "about N left". */
create function public.study_me()
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
  v_usage public.study_usage;
  v_avg_fast numeric;
  v_avg_best numeric;
  v_name text;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_settings from public.study_settings;
  v_tier := public._study_tier(v_me);
  select * into v_usage from public.study_usage where user_id = v_me and day = v_today;
  select sum(fast_usd) / nullif(sum(asks - best_asks), 0), sum(best_usd) / nullif(sum(best_asks), 0)
    into v_avg_fast, v_avg_best
    from public.study_usage where user_id = v_me and day > v_today - 14;
  select coalesce(nullif(display_name, ''), username) into v_name from public.profiles where id = v_me;
  return jsonb_build_object(
    'tier', v_tier,
    'name', v_name,
    'pro_until', public._web_plan_until(v_me, 'study_pro'),
    'resets_at', ((now() at time zone 'utc')::date + 1)::timestamp at time zone 'utc',
    'fast', jsonb_build_object(
      'used', coalesce(v_usage.fast_usd, 0),
      'cap', case when v_tier = 'pro' then v_settings.pro_fast_day_usd else v_settings.free_day_usd end,
      'avg', coalesce(v_avg_fast, v_settings.hold_fast_usd / 2)),
    'best', case when v_tier = 'pro' then jsonb_build_object(
      'used', coalesce(v_usage.best_usd, 0),
      'cap', v_settings.pro_best_day_usd,
      'period_used', public._study_period_best(v_me),
      'period_cap', v_settings.pro_best_period_usd,
      'avg', coalesce(v_avg_best, v_settings.hold_best_usd * 0.6)) end,
    'uploads', jsonb_build_object(
      'used', coalesce(v_usage.uploads, 0),
      'cap', case when v_tier = 'pro' then v_settings.pro_uploads_day else v_settings.free_uploads_day end,
      'max_mb', case when v_tier = 'pro' then v_settings.pro_upload_mb else v_settings.free_upload_mb end),
    'readings', jsonb_build_object(
      'used', public._study_readings_today(v_me),
      'cap', case when v_tier = 'pro' then v_settings.pro_readings_day else v_settings.free_readings_day end,
      'max_chars', case when v_tier = 'pro' then v_settings.pro_reading_chars else v_settings.free_reading_chars end),
    'price', (select jsonb_build_object('amount', amount, 'currency', currency)
                from public.web_plan_prices where plan_id = 'study.pro.monthly' and currency = 'USD')
  );
end;
$$;

revoke all on function public.study_me() from public, anon;
grant execute on function public.study_me() to authenticated;

-- ── Saving, and the record ─────────────────────────────────────────────

/** Saves document [p_doc] over version [p_version]: {ok: true, version}
 * with the new version, or {ok: false, version} with the one that's there
 * when it was saved from somewhere else since. The main document's words
 * go on its assignment for the dashboard. */
create function public.study_save_doc(
  p_doc uuid,
  p_version int,
  p_content jsonb,
  p_text text,
  p_words int,
  p_chip_words int default 0,
  p_title text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_doc public.study_documents;
  v_first uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_doc from public.study_documents where id = p_doc and user_id = auth.uid() for update;
  if not found then raise exception 'unknown document'; end if;
  if v_doc.version <> p_version then
    return jsonb_build_object('ok', false, 'version', v_doc.version);
  end if;
  update public.study_documents set
    content = coalesce(p_content, content),
    text = coalesce(p_text, text),
    words = greatest(coalesce(p_words, 0), 0),
    chip_words = least(greatest(coalesce(p_chip_words, 0), 0), greatest(coalesce(p_words, 0), 0)),
    title = coalesce(nullif(btrim(p_title), ''), title),
    version = version + 1
   where id = p_doc;
  select id into v_first from public.study_documents
   where assignment_id = v_doc.assignment_id and kind = 'doc' order by sort, created_at limit 1;
  update public.study_assignments set
    words = case when v_first = p_doc then greatest(coalesce(p_words, 0), 0) else words end,
    updated_at = now()
   where id = v_doc.assignment_id;
  return jsonb_build_object('ok', true, 'version', v_doc.version + 1);
end;
$$;

revoke all on function public.study_save_doc(uuid, int, jsonb, text, int, int, text) from public, anon;
grant execute on function public.study_save_doc(uuid, int, jsonb, text, int, int, text) to authenticated;

/** Notes in the AI-use record what the student did with what Chip gave
 * them: put its words into their document ('inserted'), replaced their own
 * with Chip's rewrite ('replaced'), or added the tasks or sources it
 * suggested. [p_message] is Chip's message it came from. */
create function public.study_log_use(
  p_assignment uuid,
  p_action text,
  p_message uuid default null,
  p_words int default 0,
  p_excerpt text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_message public.study_messages;
  v_id uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if p_action not in ('inserted', 'replaced', 'added_tasks', 'added_sources') then
    raise exception 'unknown action';
  end if;
  if not public._study_mine(p_assignment) then raise exception 'unknown assignment'; end if;
  if p_message is not null then
    select * into v_message from public.study_messages
     where id = p_message and user_id = v_me and assignment_id = p_assignment and role = 'chip';
    if not found then raise exception 'unknown message'; end if;
  end if;
  insert into public.study_ai_log (assignment_id, user_id, message_id, action, summary, output, words, model)
  values (
    p_assignment, v_me, p_message, p_action,
    case p_action
      when 'inserted' then 'Put Chip''s words into the document'
      when 'replaced' then 'Replaced their own words with Chip''s rewrite'
      when 'added_tasks' then 'Added the tasks Chip suggested to the checklist'
      else 'Added the sources Chip suggested' end,
    left(coalesce(p_excerpt, ''), 4000),
    least(greatest(coalesce(p_words, 0), 0), 200000),
    coalesce(v_message.meta ->> 'model', '')
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.study_log_use(uuid, text, uuid, int, text) from public, anon;
grant execute on function public.study_log_use(uuid, text, uuid, int, text) to authenticated;

/** Everything [p_user] has in Chip Study, gone (their Kaivon account
 * stays). The delete-account function calls it with the account. What
 * they've used of today's allowance is only numbers, and stays (or
 * starting over would give a new day's worth). */
create function public.study_forget(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.study_focus where user_id = p_user;
  delete from public.study_cards where user_id = p_user;
  delete from public.study_practice where user_id = p_user;
  delete from public.study_assignments where user_id = p_user;
end;
$$;

revoke all on function public.study_forget(uuid) from public, anon, authenticated;
grant execute on function public.study_forget(uuid) to service_role;

/** The signed-in student's own study data, gone. */
create function public.study_forget_me()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  perform public.study_forget(auth.uid());
end;
$$;

revoke all on function public.study_forget_me() from public, anon;
grant execute on function public.study_forget_me() to authenticated;
