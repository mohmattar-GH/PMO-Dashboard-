begin;

-- Keep SELECT policies separate from write policies to avoid permissive-policy
-- duplication. DELETE remains revoked for authenticated users.
do $policies$
declare t text;
begin
  foreach t in array array[
    'project_contracts','contract_deliverables','project_milestones',
    'project_risks','project_licenses','project_weekly_updates',
    'project_management_decisions'
  ] loop
    execute format('drop policy if exists %I on public.%I',t||'_manage_pm_admin',t);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (
        exists(select 1 from public.project_memberships pm
          where pm.project_id=%I.project_id and pm.user_id=(select auth.uid())
          and pm.status=''active'' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role=''project_manager'')
        or exists(select 1 from public.user_global_role_assignments ura
          where ura.user_id=(select auth.uid()) and ura.role_code=''platform_admin''
          and ura.status=''active'' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
      )',t||'_insert_pm_admin',t,t);
    execute format(
      'create policy %I on public.%I for update to authenticated using (
        exists(select 1 from public.project_memberships pm
          where pm.project_id=%I.project_id and pm.user_id=(select auth.uid())
          and pm.status=''active'' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role=''project_manager'')
        or exists(select 1 from public.user_global_role_assignments ura
          where ura.user_id=(select auth.uid()) and ura.role_code=''platform_admin''
          and ura.status=''active'' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
      ) with check (
        exists(select 1 from public.project_memberships pm
          where pm.project_id=%I.project_id and pm.user_id=(select auth.uid())
          and pm.status=''active'' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role=''project_manager'')
        or exists(select 1 from public.user_global_role_assignments ura
          where ura.user_id=(select auth.uid()) and ura.role_code=''platform_admin''
          and ura.status=''active'' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
      )',t||'_update_pm_admin',t,t,t);
  end loop;
end;
$policies$;

-- Project activities: one UPDATE policy combining PM/admin and assigned team lead.
drop policy if exists project_activities_manage_pm_admin on public.project_activities;
drop policy if exists project_activities_team_lead_update on public.project_activities;
create policy project_activities_insert_pm_admin on public.project_activities
for insert to authenticated with check (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activities.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
);
create policy project_activities_update_authorized on public.project_activities
for update to authenticated using (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activities.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
  or (assigned_to_user_id=(select auth.uid())
    and exists(select 1 from public.project_memberships pm where pm.project_id=project_activities.project_id
      and pm.user_id=(select auth.uid()) and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='team_lead'))
) with check (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activities.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
  or (assigned_to_user_id=(select auth.uid())
    and exists(select 1 from public.project_memberships pm where pm.project_id=project_activities.project_id
      and pm.user_id=(select auth.uid()) and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='team_lead'))
);

-- Activity dependencies: PM/admin insert/update only.
drop policy if exists project_activity_dependencies_manage_pm_admin on public.project_activity_dependencies;
create policy project_activity_dependencies_insert_pm_admin on public.project_activity_dependencies
for insert to authenticated with check (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activity_dependencies.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
);
create policy project_activity_dependencies_update_pm_admin on public.project_activity_dependencies
for update to authenticated using (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activity_dependencies.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
) with check (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activity_dependencies.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
);

-- Finance: separate read, insert and update policies.
do $policies$
declare t text;
begin
  foreach t in array array[
    'project_financial_terms','project_invoices','project_cash_transactions',
    'invoice_payment_allocations'
  ] loop
    execute format('drop policy if exists %I on public.%I',t||'_manage_finance',t);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (
        exists(select 1 from public.project_memberships pm
          where pm.project_id=%I.project_id and pm.user_id=(select auth.uid())
          and pm.status=''active'' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role=''finance'')
        or exists(select 1 from public.user_global_role_assignments ura
          where ura.user_id=(select auth.uid())
          and ura.role_code in (''platform_admin'',''finance_admin'')
          and ura.status=''active'' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
      )',t||'_insert_finance',t,t);
    execute format(
      'create policy %I on public.%I for update to authenticated using (
        exists(select 1 from public.project_memberships pm
          where pm.project_id=%I.project_id and pm.user_id=(select auth.uid())
          and pm.status=''active'' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role=''finance'')
        or exists(select 1 from public.user_global_role_assignments ura
          where ura.user_id=(select auth.uid())
          and ura.role_code in (''platform_admin'',''finance_admin'')
          and ura.status=''active'' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
      ) with check (
        exists(select 1 from public.project_memberships pm
          where pm.project_id=%I.project_id and pm.user_id=(select auth.uid())
          and pm.status=''active'' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role=''finance'')
        or exists(select 1 from public.user_global_role_assignments ura
          where ura.user_id=(select auth.uid())
          and ura.role_code in (''platform_admin'',''finance_admin'')
          and ura.status=''active'' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
      )',t||'_update_finance',t,t,t);
  end loop;
end;
$policies$;

commit;