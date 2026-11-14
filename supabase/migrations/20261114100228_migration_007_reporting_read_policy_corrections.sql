begin;

drop policy if exists reporting_configuration_sets_read_authorized on public.reporting_configuration_sets;
create policy reporting_configuration_sets_read_authorized on public.reporting_configuration_sets
for select to authenticated using (
  (scope_type = 'global' and exists (
    select 1 from public.reporting_configuration_versions v
    where v.configuration_set_id = reporting_configuration_sets.id and v.status = 'published'
  ))
  or (scope_type = 'project' and exists (
    select 1 from public.project_memberships pm
    where pm.project_id = reporting_configuration_sets.project_id
      and pm.user_id = (select auth.uid()) and pm.status = 'active'
      and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now())
  ))
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code in ('platform_admin','configuration_steward','configuration_approver')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

drop policy if exists snapshot_config_links_read_authorized on public.snapshot_config_links;
create policy snapshot_config_links_read_authorized on public.snapshot_config_links
for select to authenticated using (
  exists (
    select 1 from public.portfolio_snapshots ps
    join public.user_global_role_assignments ura on ura.user_id = (select auth.uid())
    where ps.id = snapshot_config_links.portfolio_snapshot_id
      and ura.role_code in ('platform_admin','executive_viewer')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
  or (
    scope_type = 'project'
    and exists (
      select 1 from public.project_snapshots pjs
      join public.project_memberships pm on pm.project_id = pjs.project_id
      where pjs.portfolio_snapshot_id = snapshot_config_links.portfolio_snapshot_id
        and pjs.project_id = snapshot_config_links.scope_entity_id
        and pm.user_id = (select auth.uid()) and pm.status = 'active'
        and pm.effective_from <= now()
        and (pm.effective_to is null or pm.effective_to > now())
    )
  )
);

commit;
