-- The daily reward: open the app each day and claim coins, more the longer
-- the streak runs (500, 750, 1,000, 1,250, 1,500, 2,000, then 3,000 on day
-- seven and every day after). Miss a day and it starts again at 500.
-- Days run on Lagos time. One claim a day, checked here.

alter type public.ledger_entry_type add value if not exists 'daily_reward';

create table public.daily_rewards (
  user_id  uuid primary key references public.profiles (id) on delete cascade,
  last_day date not null,
  streak   int not null check (streak >= 1)
);

alter table public.daily_rewards enable row level security;
revoke insert, update, delete on public.daily_rewards from authenticated, anon;
create policy "see your own daily reward" on public.daily_rewards
  for select using (user_id = auth.uid());

create function public._daily_reward_amount(p_streak int)
returns bigint
language sql
immutable
as $$
  select case least(greatest(p_streak, 1), 7)
    when 1 then 500
    when 2 then 750
    when 3 then 1000
    when 4 then 1250
    when 5 then 1500
    when 6 then 2000
    else 3000
  end;
$$;

-- Where the caller stands today: whether there's a reward to claim, the
-- streak it would make (or made, once claimed) and what it's worth.
create function public.daily_reward_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Africa/Lagos')::date;
  v_row public.daily_rewards;
  v_streak int;
  v_claimable boolean;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_row from public.daily_rewards where user_id = auth.uid();
  if v_row.user_id is null then
    v_claimable := true;
    v_streak := 1;
  elsif v_row.last_day = v_today then
    v_claimable := false;
    v_streak := v_row.streak;
  else
    v_claimable := true;
    v_streak := case when v_row.last_day = v_today - 1 then v_row.streak + 1 else 1 end;
  end if;
  return jsonb_build_object(
    'claimable', v_claimable,
    'streak', v_streak,
    'coins', public._daily_reward_amount(v_streak)
  );
end;
$$;

revoke all on function public.daily_reward_status() from public;
grant execute on function public.daily_reward_status() to authenticated;

-- Claims today's reward: adds the coins and moves the streak on.
create function public.claim_daily_reward()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'Africa/Lagos')::date;
  v_row public.daily_rewards;
  v_streak int;
  v_coins bigint;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  select * into v_row from public.daily_rewards where user_id = v_me for update;
  if v_row.user_id is not null and v_row.last_day = v_today then
    raise exception 'already claimed today';
  end if;
  v_streak := case
    when v_row.user_id is not null and v_row.last_day = v_today - 1 then v_row.streak + 1
    else 1
  end;
  v_coins := public._daily_reward_amount(v_streak);

  insert into public.daily_rewards (user_id, last_day, streak)
    values (v_me, v_today, v_streak)
    on conflict (user_id) do update set last_day = excluded.last_day, streak = excluded.streak;

  perform public._ledger_move(
    v_me,
    'daily_reward',
    v_coins,
    null,
    jsonb_build_object('streak', v_streak)
  );

  return jsonb_build_object('coins', v_coins, 'streak', v_streak);
end;
$$;

revoke all on function public.claim_daily_reward() from public;
grant execute on function public.claim_daily_reward() to authenticated;
