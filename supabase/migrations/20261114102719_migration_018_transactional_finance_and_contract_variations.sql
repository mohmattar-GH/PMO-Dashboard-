begin;

-- Contract variations: submitted changes require an explicit finance approval.
create table public.project_contract_variations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  contract_id uuid not null,
  variation_reference text not null,
  title text not null,
  description text not null,
  amount_delta numeric(18,2) not null,
  currency_code char(3) not null,
  status text not null default 'draft',
  requested_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  submitted_at timestamptz,
  decided_by uuid references auth.users(id) on delete restrict,
  decided_at timestamptz,
  decision_reason text,
  effective_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id,variation_reference),
  foreign key (contract_id,project_id)
    references public.project_contracts(id,project_id) on delete restrict,
  check (amount_delta<>0),
  check (status in ('draft','submitted','approved','rejected'))
);

alter table public.invoice_payment_allocations
  add column status text not null default 'active',
  add column reversed_at timestamptz,
  add column reversed_by uuid references auth.users(id) on delete restrict,
  add column reversal_reason text,
  add column allocation_reason text,
  add constraint invoice_payment_allocations_status_check
    check (status in ('active','reversed')),
  add constraint invoice_payment_allocations_reversal_fields_check
    check (
      (status='active' and reversed_at is null and reversed_by is null and reversal_reason is null)
      or
      (status='reversed' and reversed_at is not null and reversed_by is not null
        and reversal_reason is not null and length(btrim(reversal_reason))>=8)
    );

alter table public.invoice_payment_allocations
  drop constraint if exists invoice_payment_allocations_invoice_id_cash_transaction_id_key;
create unique index invoice_payment_allocations_one_active_pair_idx
  on public.invoice_payment_allocations(invoice_id,cash_transaction_id)
  where status='active';

create index project_variations_project_status_idx
  on public.project_contract_variations(project_id,status,created_at desc);
create index project_variations_contract_idx
  on public.project_contract_variations(contract_id,project_id);

alter table public.project_contract_variations enable row level security;
grant select,insert,update on public.project_contract_variations to authenticated;
grant select,insert,update,delete on public.project_contract_variations to service_role;
revoke delete on public.project_contract_variations from authenticated;

create policy project_variations_read_authorized
on public.project_contract_variations for select to authenticated
using (
  exists(select 1 from public.project_memberships pm
    where pm.project_id=project_contract_variations.project_id
      and pm.user_id=(select auth.uid()) and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role in ('project_manager','finance'))
  or exists(select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin','executive_viewer')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now()))
);

create policy project_variations_insert_pm_admin
on public.project_contract_variations for insert to authenticated
with check (
  requested_by=(select auth.uid())
  and status='draft'
  and exists(select 1 from public.project_memberships pm
    where pm.project_id=project_contract_variations.project_id
      and pm.user_id=(select auth.uid()) and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='project_manager')
  or
  (requested_by=(select auth.uid()) and status='draft'
    and exists(select 1 from public.user_global_role_assignments ura
      where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
        and ura.status='active' and ura.effective_from<=now()
        and (ura.effective_to is null or ura.effective_to>now())))
);

create policy project_variations_update_workflow
on public.project_contract_variations for update to authenticated
using (
  exists(select 1 from public.project_memberships pm
    where pm.project_id=project_contract_variations.project_id
      and pm.user_id=(select auth.uid()) and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role in ('project_manager','finance'))
  or exists(select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now()))
)
with check (
  exists(select 1 from public.project_memberships pm
    where pm.project_id=project_contract_variations.project_id
      and pm.user_id=(select auth.uid()) and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role in ('project_manager','finance'))
  or exists(select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now()))
);

-- Enforce role-specific, one-way variation workflow. Approval updates the
-- project aggregate in the same transaction as the approval.
create or replace function private.enforce_contract_variation_workflow()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_is_pm boolean;
  v_is_finance boolean;
  v_terms_currency char(3);
begin
  select exists(
    select 1 from public.project_memberships pm
    where pm.project_id=new.project_id and pm.user_id=(select auth.uid())
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='project_manager'
  ) or exists(
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) into v_is_pm;

  select exists(
    select 1 from public.project_memberships pm
    where pm.project_id=new.project_id and pm.user_id=(select auth.uid())
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='finance'
  ) or exists(
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) into v_is_finance;

  if tg_op='INSERT' then
    if not v_is_pm or new.status<>'draft' or new.requested_by is distinct from auth.uid() then
      raise exception 'Only an authorized project manager may create a draft variation';
    end if;
    return new;
  end if;

  if old.status='draft' and new.status='submitted' then
    if not v_is_pm
       or (to_jsonb(new)-array['status','submitted_at','updated_at'])
          is distinct from (to_jsonb(old)-array['status','submitted_at','updated_at']) then
      raise exception 'Only a project manager may submit an unchanged draft variation';
    end if;
    new.submitted_at:=coalesce(new.submitted_at,now());
    return new;
  end if;

  if old.status='submitted' and new.status in ('approved','rejected') then
    if not v_is_finance
       or (to_jsonb(new)-array['status','decided_by','decided_at','decision_reason','updated_at'])
          is distinct from (to_jsonb(old)-array['status','decided_by','decided_at','decision_reason','updated_at'])
       or new.decision_reason is null or length(btrim(new.decision_reason))<8 then
      raise exception 'Only finance approvers may decide a submitted variation with a reason';
    end if;
    new.decided_by:=auth.uid();
    new.decided_at:=now();
    return new;
  end if;

  raise exception 'Invalid contract variation state transition';
end;
$function$;

create trigger project_variations_enforce_workflow
before insert or update on public.project_contract_variations
for each row execute function private.enforce_contract_variation_workflow();

create or replace function private.apply_approved_contract_variation()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_currency char(3);
  v_total numeric(18,2);
begin
  if new.status='approved' and old.status is distinct from 'approved' then
    select currency_code into v_currency
    from public.project_financial_terms
    where project_id=new.project_id
    for update;

    if not found then
      raise exception 'Create project financial terms before approving a contract variation';
    end if;

    if upper(btrim(v_currency))<>upper(btrim(new.currency_code)) then
      raise exception 'Variation currency must match project financial terms currency';
    end if;

    select coalesce(sum(amount_delta),0) into v_total
    from public.project_contract_variations
    where project_id=new.project_id and status='approved';

    update public.project_financial_terms
      set approved_variations=v_total
    where project_id=new.project_id;
  end if;
  return new;
end;
$function$;

create trigger project_variations_apply_approved_total
after update of status on public.project_contract_variations
for each row execute function private.apply_approved_contract_variation();

create trigger project_variations_set_updated_at
before update on public.project_contract_variations
for each row execute function private.set_operational_updated_at();

create trigger project_variations_audit_changes
after insert or update or delete on public.project_contract_variations
for each row execute function private.audit_project_operational_change();

-- Only finance-authorized callers may create/reverse allocations. Row locks
-- serialize competing allocations against both the invoice and cash receipt.
create policy invoice_allocations_update_finance
on public.invoice_payment_allocations for update to authenticated
using (
  exists(select 1 from public.project_memberships pm
    where pm.project_id=invoice_payment_allocations.project_id
      and pm.user_id=(select auth.uid()) and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='finance')
  or exists(select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now()))
)
with check (
  exists(select 1 from public.project_memberships pm
    where pm.project_id=invoice_payment_allocations.project_id
      and pm.user_id=(select auth.uid()) and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='finance')
  or exists(select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now()))
);

alter table public.invoice_payment_allocations
  add constraint invoice_allocations_reversal_reason_length
  check (reversal_reason is null or length(btrim(reversal_reason))>=8);

create or replace function public.allocate_invoice_cash(
  p_project_id uuid,
  p_invoice_id uuid,
  p_cash_transaction_id uuid,
  p_amount numeric,
  p_allocation_date date default current_date,
  p_reason text default null
)
returns uuid
language plpgsql
security invoker
set search_path=''
as $function$
declare
  v_invoice public.project_invoices%rowtype;
  v_cash public.project_cash_transactions%rowtype;
  v_invoice_used numeric(18,2);
  v_cash_used numeric(18,2);
  v_id uuid;
  v_authorized boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Allocation amount must be positive'; end if;
  if p_reason is null or length(btrim(p_reason))<8 then raise exception 'Allocation reason must contain at least 8 characters'; end if;

  select exists(
    select 1 from public.project_memberships pm
    where pm.project_id=p_project_id and pm.user_id=auth.uid()
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='finance'
  ) or exists(
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=auth.uid() and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) into v_authorized;
  if not v_authorized then raise exception 'Finance permission required'; end if;

  select * into v_cash from public.project_cash_transactions
  where id=p_cash_transaction_id and project_id=p_project_id
  for update;
  if not found then raise exception 'Cash transaction not found in this project'; end if;

  select * into v_invoice from public.project_invoices
  where id=p_invoice_id and project_id=p_project_id
  for update;
  if not found then raise exception 'Invoice not found in this project'; end if;

  if v_cash.status<>'confirmed' then raise exception 'Only confirmed cash transactions can be allocated'; end if;
  if v_cash.transaction_type not in ('payment','credit_note') then
    raise exception 'Only payment and credit-note transactions can be allocated';
  end if;
  if upper(btrim(v_cash.currency_code))<>upper(btrim(v_invoice.currency_code)) then
    raise exception 'Invoice and cash transaction currencies must match';
  end if;
  if v_invoice.invoice_type<>'standard' then
    raise exception 'Allocations must target a standard invoice';
  end if;

  select coalesce(sum(allocated_amount),0) into v_invoice_used
  from public.invoice_payment_allocations
  where invoice_id=p_invoice_id and status='active';

  select coalesce(sum(allocated_amount),0) into v_cash_used
  from public.invoice_payment_allocations
  where cash_transaction_id=p_cash_transaction_id and status='active';

  if v_invoice_used+p_amount>v_invoice.total_amount then
    raise exception 'Allocation exceeds the invoice outstanding balance';
  end if;
  if v_cash_used+p_amount>v_cash.amount then
    raise exception 'Allocation exceeds the unallocated cash transaction amount';
  end if;

  insert into public.invoice_payment_allocations(
    project_id,invoice_id,cash_transaction_id,allocated_amount,
    allocation_date,created_by,allocation_reason
  ) values (
    p_project_id,p_invoice_id,p_cash_transaction_id,p_amount,
    coalesce(p_allocation_date,current_date),auth.uid(),btrim(p_reason)
  ) returning id into v_id;

  return v_id;
end;
$function$;

create or replace function public.reverse_invoice_cash_allocation(
  p_allocation_id uuid,
  p_reason text
)
returns uuid
language plpgsql
security invoker
set search_path=''
as $function$
declare
  v_allocation public.invoice_payment_allocations%rowtype;
  v_authorized boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_reason is null or length(btrim(p_reason))<8 then raise exception 'Reversal reason must contain at least 8 characters'; end if;

  select * into v_allocation from public.invoice_payment_allocations
  where id=p_allocation_id for update;
  if not found then raise exception 'Allocation not found'; end if;

  select exists(
    select 1 from public.project_memberships pm
    where pm.project_id=v_allocation.project_id and pm.user_id=auth.uid()
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='finance'
  ) or exists(
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=auth.uid() and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) into v_authorized;
  if not v_authorized then raise exception 'Finance permission required'; end if;
  if v_allocation.status<>'active' then raise exception 'Only active allocations can be reversed'; end if;

  update public.invoice_payment_allocations
  set status='reversed',reversed_at=now(),reversed_by=auth.uid(),
      reversal_reason=btrim(p_reason)
  where id=p_allocation_id;

  return p_allocation_id;
end;
$function$;

revoke all on function public.allocate_invoice_cash(uuid,uuid,uuid,numeric,date,text) from public,anon;
revoke all on function public.reverse_invoice_cash_allocation(uuid,text) from public,anon;
grant execute on function public.allocate_invoice_cash(uuid,uuid,uuid,numeric,date,text) to authenticated;
grant execute on function public.reverse_invoice_cash_allocation(uuid,text) to authenticated;

-- Prevent changing an invoice/cash transaction's financial identity while
-- active allocations exist. Corrections require reversal first.
create or replace function private.guard_allocated_financial_source()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if tg_table_name='project_invoices' then
    if (new.project_id is distinct from old.project_id
        or new.currency_code is distinct from old.currency_code
        or new.total_amount is distinct from old.total_amount)
       and exists(select 1 from public.invoice_payment_allocations a
         where a.invoice_id=old.id and a.status='active') then
      raise exception 'Reverse active allocations before changing invoice amount, currency or project';
    end if;
  elsif tg_table_name='project_cash_transactions' then
    if (new.project_id is distinct from old.project_id
        or new.currency_code is distinct from old.currency_code
        or new.amount is distinct from old.amount
        or new.transaction_type is distinct from old.transaction_type
        or new.status is distinct from old.status)
       and exists(select 1 from public.invoice_payment_allocations a
         where a.cash_transaction_id=old.id and a.status='active') then
      raise exception 'Reverse active allocations before changing the cash transaction financial fields';
    end if;
  end if;
  return new;
end;
$function$;

create trigger invoices_guard_allocated_source
before update on public.project_invoices
for each row execute function private.guard_allocated_financial_source();
create trigger cash_transactions_guard_allocated_source
before update on public.project_cash_transactions
for each row execute function private.guard_allocated_financial_source();

-- RLS-invoker view: balances are calculated from active allocation records,
-- without hard-coding invoice workflow status labels.
create or replace view public.project_invoice_balances
with (security_invoker=true)
as
select
  i.id as invoice_id,
  i.project_id,
  i.invoice_reference,
  i.currency_code,
  i.total_amount,
  coalesce(sum(a.allocated_amount) filter (where a.status='active'),0)::numeric(18,2) as applied_amount,
  greatest(i.total_amount-coalesce(sum(a.allocated_amount) filter (where a.status='active'),0),0)::numeric(18,2) as outstanding_amount,
  (coalesce(sum(a.allocated_amount) filter (where a.status='active'),0)>=i.total_amount) as is_settled
from public.project_invoices i
left join public.invoice_payment_allocations a on a.invoice_id=i.id and a.project_id=i.project_id
group by i.id,i.project_id,i.invoice_reference,i.currency_code,i.total_amount;

grant select on public.project_invoice_balances to authenticated,service_role;

commit;