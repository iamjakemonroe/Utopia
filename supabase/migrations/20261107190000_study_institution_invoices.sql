-- Paying for an institution's seats, 2026-11-07.
--
-- After a pilot, Kaivon staff agree a price with the institution and issue
-- an invoice here (seats, months, currency, amount). The institution's
-- admin pays it in Chip Study through Flutterwave's checkout (web-pay,
-- references "kaivon-inv-"), and once Flutterwave says it's paid in full,
-- the institution moves to paid: those seats, until the paid date.

create table public.study_institution_invoices (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.study_institutions (id) on delete cascade,
  ref            text not null unique check (ref ~ '^kaivon-inv-[a-f0-9]{24}$'),
  label          text not null check (char_length(btrim(label)) between 1 and 160),
  seats          int not null check (seats between 1 and 1000000),
  months         int not null check (months between 1 and 36),
  currency       text not null check (currency in ('USD', 'NGN')),
  amount         numeric(14, 2) not null check (amount >= 1),
  status         text not null default 'open' check (status in ('open', 'paid', 'void')),
  created_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now(),
  paid_at        timestamptz,
  provider_id    text,
  environment    text check (environment in ('production', 'sandbox'))
);
create index study_institution_invoices_inst on public.study_institution_invoices (institution_id);
alter table public.study_institution_invoices enable row level security;

create function public.study_staff_invoice_create(
  p_inst uuid, p_label text, p_seats int, p_months int, p_currency text, p_amount numeric)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_inv public.study_institution_invoices;
begin
  if not public._study_is_staff(auth.uid()) then raise exception 'not allowed'; end if;
  if not exists (select 1 from public.study_institutions where id = p_inst and status = 'approved') then
    raise exception 'institution not approved';
  end if;
  insert into public.study_institution_invoices (institution_id, ref, label, seats, months, currency, amount, created_by)
  values (p_inst, 'kaivon-inv-' || left(replace(gen_random_uuid()::text, '-', ''), 24), btrim(p_label),
          p_seats, p_months, upper(p_currency), round(p_amount, 2), auth.uid())
  returning * into v_inv;
  return to_jsonb(v_inv);
end;
$$;

create function public.study_staff_invoice_void(p_invoice uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public._study_is_staff(auth.uid()) then raise exception 'not allowed'; end if;
  update public.study_institution_invoices set status = 'void' where id = p_invoice and status = 'open';
  if not found then raise exception 'not open'; end if;
end;
$$;

/** An institution's invoices, for its admins and Kaivon staff. */
create function public.study_institution_invoices(p_inst uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if public._study_inst_role(p_inst, auth.uid()) is distinct from 'admin' and not public._study_is_staff(auth.uid()) then
    raise exception 'not allowed';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', id, 'label', label, 'seats', seats, 'months', months, 'currency', currency, 'amount', amount,
      'status', status, 'created_at', created_at, 'paid_at', paid_at) order by created_at desc)
      from public.study_institution_invoices where institution_id = p_inst), '[]'::jsonb);
end;
$$;

/** For web-pay: an open invoice the caller may pay (an admin of its institution). */
create function public.study_invoice_checkout_start(p_invoice uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_inv public.study_institution_invoices;
begin
  select * into v_inv from public.study_institution_invoices where id = p_invoice;
  if v_inv.id is null or public._study_inst_role(v_inv.institution_id, auth.uid()) is distinct from 'admin' then
    raise exception 'not allowed';
  end if;
  if v_inv.status <> 'open' then raise exception 'not open'; end if;
  return jsonb_build_object('ref', v_inv.ref, 'amount', v_inv.amount, 'currency', v_inv.currency,
    'label', v_inv.label, 'institution_id', v_inv.institution_id,
    'institution', (select name from public.study_institutions where id = v_inv.institution_id));
end;
$$;

/** Called by web-pay and web-pay-hook (service role) once Flutterwave says
 * the invoice's payment succeeded: paid in full and in its currency, once. */
create function public.credit_institution_invoice(
  p_ref text, p_provider_id text, p_amount numeric, p_currency text, p_environment text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_inv public.study_institution_invoices;
  v_until date;
begin
  select * into v_inv from public.study_institution_invoices where ref = p_ref for update;
  if v_inv.id is null then raise exception 'no such invoice'; end if;
  if v_inv.status = 'paid' then
    return jsonb_build_object('institution_id', v_inv.institution_id, 'already', true,
                              'paid_until', (select paid_until from public.study_institutions where id = v_inv.institution_id));
  end if;
  if v_inv.status <> 'open' then raise exception 'invoice not open'; end if;
  if upper(p_currency) <> v_inv.currency or p_amount < v_inv.amount then raise exception 'not paid in full'; end if;
  update public.study_institution_invoices
     set status = 'paid', paid_at = now(), provider_id = p_provider_id, environment = p_environment
   where id = v_inv.id;
  update public.study_institutions
     set plan = 'paid',
         seats = greatest(seats, v_inv.seats),
         paid_until = greatest(coalesce(paid_until, current_date), current_date) + make_interval(months => v_inv.months)
   where id = v_inv.institution_id
  returning paid_until into v_until;
  return jsonb_build_object('institution_id', v_inv.institution_id, 'paid_until', v_until);
end;
$$;

revoke all on function public.study_staff_invoice_create(uuid, text, int, int, text, numeric),
  public.study_staff_invoice_void(uuid), public.study_institution_invoices(uuid),
  public.study_invoice_checkout_start(uuid) from public, anon;
grant execute on function public.study_staff_invoice_create(uuid, text, int, int, text, numeric),
  public.study_staff_invoice_void(uuid), public.study_institution_invoices(uuid),
  public.study_invoice_checkout_start(uuid) to authenticated;
revoke all on function public.credit_institution_invoice(text, text, numeric, text, text) from public, anon, authenticated;
grant execute on function public.credit_institution_invoice(text, text, numeric, text, text) to service_role;
