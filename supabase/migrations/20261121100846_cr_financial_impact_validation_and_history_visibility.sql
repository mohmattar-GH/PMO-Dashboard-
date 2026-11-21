alter table public.project_change_request_impacts
  add constraint project_cr_impact_non_assessed_values_ck
  check (
    assessment_status='assessed'
    or (coalesce(cost_delta,0)=0 and coalesce(schedule_impact_days,0)=0)
  ),
  add constraint project_cr_impact_currency_required_ck
  check (coalesce(cost_delta,0)=0 or currency_code is not null);

drop policy if exists project_cr_history_read on public.project_change_request_history;
create policy project_cr_history_read on public.project_change_request_history
for select to authenticated using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id=project_change_request_history.project_id
      and pm.user_id=(select auth.uid())
      and pm.project_role in ('project_manager','finance')
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  )
);
