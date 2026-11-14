begin;

-- Close direct-write paths: allocation integrity is enforced even when a
-- finance client writes the table directly rather than calling the RPC.
drop policy if exists invoice_allocations_update_finance on public.invoice_payment_allocations;

create or replace function private.guard_invoice_allocation_integrity()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_invoice public.project_invoices%rowtype;
  v_cash public.project_cash_transactions%rowtype;
  v_invoice_used numeric(18,2);
  v_cash_used numeric(18,2);
  v_authorized boolean;
begin
  if auth.uid() is null then
    raise exception 'Authenticated finance user required';
  end if;

  select exists(
    select 1 from public.project_memberships pm
    where pm.project_id=new.project_id and pm.user_id=auth.uid()
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

  if tg_op='INSERT' then
    if new.created_by is distinct from auth.uid()
       or new.status<>'active'
       or new.reversed_at is not null
       or new.reversed_by is not null
       or new.reversal_reason is not null
       or new.allocated_amount<=0
       or new.allocation_reason is null
       or length(btrim(new.allocation_reason))<8 then
      raise exception 'Invalid initial allocation values';
    end if;

    select * into v_cash from public.project_cash_transactions
    where id=new.cash_transaction_id and project_id=new.project_id
    for update;
    if not found then raise exception 'Cash transaction not found in this project'; end if;

    select * into v_invoice from public.project_invoices
    where id=new.invoice_id and project_id=new.project_id
    for update;
    if not found then raise exception 'Invoice not found in this project'; end if;

    if v_cash.status<>'confirmed' or v_cash.transaction_type not in ('payment','credit_note') then
      raise exception 'Only confirmed payment or credit-note transactions can be allocated';
    end if;
    if v_invoice.invoice_type<>'standard' then raise exception 'Only standard invoices can receive allocations'; end if;
    if upper(btrim(v_cash.currency_code))<>upper(btrim(v_invoice.currency_code)) then
      raise exception 'Invoice and cash transaction currencies must match';
    end if;

    select coalesce(sum(a.allocated_amount),0) into v_invoice_used
    from public.invoice_payment_allocations a
    where a.invoice_id=new.invoice_id and a.status='active';
    select coalesce(sum(a.allocated_amount),0) into v_cash_used
    from public.invoice_payment_allocations a
    where a.cash_transaction_id=new.cash_transaction_id and a.status='active';

    if v_invoice_used+new.allocated_amount>v_invoice.total_amount then
      raise exception 'Allocation exceeds invoice outstanding balance';
    end if;
    if v_cash_used+new.allocated_amount>v_cash.amount then
      raise exception 'Allocation exceeds unallocated cash transaction amount';
    end if;
    return new;
  end if;

  -- The only allowed update is a one-way reversal with an authenticated actor
  -- and a meaningful reason. Financial identity and amount are immutable.
  if old.status<>'active' or new.status<>'reversed'
     or new.id is distinct from old.id
     or new.project_id is distinct from old.project_id
     or new.invoice_id is distinct from old.invoice_id
     or new.cash_transaction_id is distinct from old.cash_transaction_id
     or new.allocated_amount is distinct from old.allocated_amount
     or new.allocation_date is distinct from old.allocation_date
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at
     or new.allocation_reason is distinct from old.allocation_reason
     or new.reversed_by is distinct from auth.uid()
     or new.reversed_at is null
     or new.reversal_reason is null
     or length(btrim(new.reversal_reason))<8 then
    raise exception 'Only an authorized one-way allocation reversal is permitted';
  end if;

  return new;
end;
$function$;

create trigger invoice_allocations_guard_integrity
before insert or update on public.invoice_payment_allocations
for each row execute function private.guard_invoice_allocation_integrity();

-- Approved variations are the sole source for the aggregate. Prevent manual
-- edits to the aggregate or original baseline value.
create or replace function private.guard_project_financial_terms_integrity()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_approved_total numeric(18,2);
  v_currency_mismatch boolean;
begin
  if tg_op='UPDATE' and new.original_contract_value is distinct from old.original_contract_value then
    raise exception 'Original contract value is immutable; use an approved contract variation';
  end if;

  if tg_op='UPDATE' and new.currency_code is distinct from old.currency_code
     and (
       exists(select 1 from public.project_contract_variations v where v.project_id=old.project_id)
       or exists(select 1 from public.project_invoices i where i.project_id=old.project_id)
       or exists(select 1 from public.project_cash_transactions c where c.project_id=old.project_id)
     ) then
    raise exception 'Project currency cannot change after variations, invoices or cash transactions exist';
  end if;

  select coalesce(sum(v.amount_delta),0),
         coalesce(bool_or(upper(btrim(v.currency_code))<>upper(btrim(new.currency_code))),false)
    into v_approved_total,v_currency_mismatch
  from public.project_contract_variations v
  where v.project_id=new.project_id and v.status='approved';

  if v_currency_mismatch then
    raise exception 'Approved variation currency does not match project financial terms';
  end if;
  if new.approved_variations is distinct from v_approved_total then
    raise exception 'Approved variations total is calculated from approved variation records';
  end if;

  return new;
end;
$function$;

create trigger project_financial_terms_guard_integrity
before insert or update of original_contract_value,approved_variations,currency_code
on public.project_financial_terms
for each row execute function private.guard_project_financial_terms_integrity();

-- Indexes for all foreign keys introduced by Migration 018.
create index invoice_allocations_reversed_by_fk_idx
  on public.invoice_payment_allocations(reversed_by);
create index project_variations_decided_by_fk_idx
  on public.project_contract_variations(decided_by);
create index project_variations_requested_by_fk_idx
  on public.project_contract_variations(requested_by);

commit;