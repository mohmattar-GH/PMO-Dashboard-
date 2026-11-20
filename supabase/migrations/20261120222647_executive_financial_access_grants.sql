
create table public.executive_financial_access_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  project_id uuid null references public.projects(id) on delete restrict,
  reason text not null check (length(btrim(reason)) between 8 and 1000),
  granted_by uuid not null references auth.users(id) on delete restrict,
  granted_at timestamptz not null default now(),
  expires_at timestamptz null,
  revoked_by uuid null references auth.users(id) on delete restrict,
  revoked_at timestamptz null,
  revocation_reason text null,
  constraint executive_financial_grant_revocation_consistency check (
    (revoked_at is null and revoked_by is null and revocation_reason is null)
    or
    (revoked_at is not null and revoked_by is not null and revocation_reason is not null
      and length(btrim(revocation_reason)) between 8 and 1000)
  ),
  constraint executive_financial_grant_expiry check (expires_at is null or expires_at > granted_at)
);

create index executive_financial_grants_user_project_active_idx
  on public.executive_financial_access_grants(user_id, project_id, expires_at)
  where revoked_at is null;

create unique index executive_financial_grants_active_global_unique
  on public.executive_financial_access_grants(user_id)
  where project_id is null and revoked_at is null;

create unique index executive_financial_grants_active_project_unique
  on public.executive_financial_access_grants(user_id, project_id)
  where project_id is not null and revoked_at is null;

alter table public.executive_financial_access_grants enable row level security;

create policy executive_financial_grants_read_self_or_admin
on public.executive_financial_access_grants
for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

create policy executive_financial_grants_insert_admin
on public.executive_financial_access_grants
for insert to authenticated
with check (
  granted_by = (select auth.uid())
  and exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

create policy executive_financial_grants_revoke_admin
on public.executive_financial_access_grants
for update to authenticated
using (
  revoked_at is null
  and exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
)
with check (
  revoked_at is not null
  and revoked_by = (select auth.uid())
  and exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

create or replace function public.guard_executive_financial_grant_update()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if old.revoked_at is not null
     or new.id is distinct from old.id
     or new.user_id is distinct from old.user_id
     or new.project_id is distinct from old.project_id
     or new.reason is distinct from old.reason
     or new.granted_by is distinct from old.granted_by
     or new.granted_at is distinct from old.granted_at
     or new.expires_at is distinct from old.expires_at
     or new.revoked_at is null
     or new.revoked_by is null
     or new.revocation_reason is null
     or length(btrim(new.revocation_reason)) not between 8 and 1000 then
    raise exception 'Financial access grants are immutable; only one-time revocation is permitted';
  end if;
  return new;
end;
$$;

create trigger guard_executive_financial_grant_update
before update on public.executive_financial_access_grants
for each row execute function public.guard_executive_financial_grant_update();

grant select, insert, update on public.executive_financial_access_grants to authenticated;
revoke delete on public.executive_financial_access_grants from authenticated;

drop policy if exists project_financial_terms_read_finance_scope on public.project_financial_terms;
create policy project_financial_terms_read_finance_scope
on public.project_financial_terms for select to authenticated
using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id = project_financial_terms.project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active' and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
      and pm.project_role in ('project_manager','finance')
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
  or (
    exists (
      select 1 from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid()) and ura.role_code = 'executive_viewer'
        and ura.status = 'active' and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
    and exists (
      select 1 from public.executive_financial_access_grants g
      where g.user_id = (select auth.uid())
        and (g.project_id is null or g.project_id = project_financial_terms.project_id)
        and g.revoked_at is null and (g.expires_at is null or g.expires_at > now())
    )
  )
);

drop policy if exists project_invoices_read_finance_scope on public.project_invoices;
create policy project_invoices_read_finance_scope
on public.project_invoices for select to authenticated
using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id = project_invoices.project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active' and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
      and pm.project_role in ('project_manager','finance')
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
  or (
    exists (
      select 1 from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid()) and ura.role_code = 'executive_viewer'
        and ura.status = 'active' and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
    and exists (
      select 1 from public.executive_financial_access_grants g
      where g.user_id = (select auth.uid())
        and (g.project_id is null or g.project_id = project_invoices.project_id)
        and g.revoked_at is null and (g.expires_at is null or g.expires_at > now())
    )
  )
);

drop policy if exists project_cash_transactions_read_finance_scope on public.project_cash_transactions;
create policy project_cash_transactions_read_finance_scope
on public.project_cash_transactions for select to authenticated
using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id = project_cash_transactions.project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active' and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
      and pm.project_role in ('project_manager','finance')
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
  or (
    exists (
      select 1 from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid()) and ura.role_code = 'executive_viewer'
        and ura.status = 'active' and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
    and exists (
      select 1 from public.executive_financial_access_grants g
      where g.user_id = (select auth.uid())
        and (g.project_id is null or g.project_id = project_cash_transactions.project_id)
        and g.revoked_at is null and (g.expires_at is null or g.expires_at > now())
    )
  )
);

drop policy if exists invoice_payment_allocations_read_finance_scope on public.invoice_payment_allocations;
create policy invoice_payment_allocations_read_finance_scope
on public.invoice_payment_allocations for select to authenticated
using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id = invoice_payment_allocations.project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active' and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
      and pm.project_role in ('project_manager','finance')
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
  or (
    exists (
      select 1 from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid()) and ura.role_code = 'executive_viewer'
        and ura.status = 'active' and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
    and exists (
      select 1 from public.executive_financial_access_grants g
      where g.user_id = (select auth.uid())
        and (g.project_id is null or g.project_id = invoice_payment_allocations.project_id)
        and g.revoked_at is null and (g.expires_at is null or g.expires_at > now())
    )
  )
);

drop policy if exists project_variations_read_authorized on public.project_contract_variations;
create policy project_variations_read_authorized
on public.project_contract_variations for select to authenticated
using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id = project_contract_variations.project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active' and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
      and pm.project_role in ('project_manager','finance')
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
  or (
    exists (
      select 1 from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid()) and ura.role_code = 'executive_viewer'
        and ura.status = 'active' and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
    and exists (
      select 1 from public.executive_financial_access_grants g
      where g.user_id = (select auth.uid())
        and (g.project_id is null or g.project_id = project_contract_variations.project_id)
        and g.revoked_at is null and (g.expires_at is null or g.expires_at > now())
    )
  )
);

drop policy if exists project_contracts_read_project_scope on public.project_contracts;
create policy project_contracts_read_project_scope
on public.project_contracts for select to authenticated
using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id = project_contracts.project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active' and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code = 'platform_admin'
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
  or (
    exists (
      select 1 from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid()) and ura.role_code = 'executive_viewer'
        and ura.status = 'active' and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
    and exists (
      select 1 from public.executive_financial_access_grants g
      where g.user_id = (select auth.uid())
        and (g.project_id is null or g.project_id = project_contracts.project_id)
        and g.revoked_at is null and (g.expires_at is null or g.expires_at > now())
    )
  )
);

alter view public.project_invoice_balances set (security_invoker = true);
