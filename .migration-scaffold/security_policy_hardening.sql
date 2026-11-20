-- Contract records contain legal and commercial terms. Restrict reads to project managers and finance roles,
-- with platform/finance administrators and explicitly granted executive viewers.
drop policy if exists project_contracts_read_project_scope on public.project_contracts;

create policy project_contracts_read_authorized
on public.project_contracts
for select
to authenticated
using (
  exists (
    select 1
    from public.project_memberships pm
    where pm.project_id = project_contracts.project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
      and pm.project_role in ('project_manager', 'finance')
  )
  or exists (
    select 1
    from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code in ('platform_admin', 'finance_admin')
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
  or (
    exists (
      select 1
      from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid())
        and ura.role_code = 'executive_viewer'
        and ura.status = 'active'
        and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
    and exists (
      select 1
      from public.executive_financial_access_grants g
      where g.user_id = (select auth.uid())
        and (g.project_id is null or g.project_id = project_contracts.project_id)
        and g.revoked_at is null
        and (g.expires_at is null or g.expires_at > now())
    )
  )
);
