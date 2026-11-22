
-- 059: Allow the Executive Viewer role to read non-financial lifecycle phase data.
-- This is read-only and does not grant access to any financial tables.

drop policy lifecycle_templates_select on public.project_lifecycle_templates;
create policy lifecycle_templates_select on public.project_lifecycle_templates
for select to authenticated using (
 project_id is null
 or exists(select 1 from public.project_memberships m where m.project_id=project_lifecycle_templates.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code in ('platform_admin','executive_viewer') and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);

drop policy lifecycle_versions_select on public.project_lifecycle_template_versions;
create policy lifecycle_versions_select on public.project_lifecycle_template_versions
for select to authenticated using (
 exists(select 1 from public.project_lifecycle_templates t where t.id=project_lifecycle_template_versions.template_id and (t.project_id is null or exists(select 1 from public.project_memberships m where m.project_id=t.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code in ('platform_admin','executive_viewer') and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);

drop policy lifecycle_phases_select on public.project_lifecycle_phases;
create policy lifecycle_phases_select on public.project_lifecycle_phases
for select to authenticated using (
 exists(select 1 from public.project_lifecycle_template_versions v join public.project_lifecycle_templates t on t.id=v.template_id where v.id=project_lifecycle_phases.version_id and (t.project_id is null or exists(select 1 from public.project_memberships m where m.project_id=t.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code in ('platform_admin','executive_viewer') and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);

drop policy lifecycle_rules_select on public.project_lifecycle_transition_rules;
create policy lifecycle_rules_select on public.project_lifecycle_transition_rules
for select to authenticated using (
 exists(select 1 from public.project_lifecycle_template_versions v join public.project_lifecycle_templates t on t.id=v.template_id where v.id=project_lifecycle_transition_rules.version_id and (t.project_id is null or exists(select 1 from public.project_memberships m where m.project_id=t.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code in ('platform_admin','executive_viewer') and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);

drop policy lifecycle_assignments_select on public.project_lifecycle_assignments;
create policy lifecycle_assignments_select on public.project_lifecycle_assignments
for select to authenticated using (
 exists(select 1 from public.project_memberships m where m.project_id=project_lifecycle_assignments.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code in ('platform_admin','executive_viewer') and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);

drop policy phase_history_select on public.project_phase_history;
create policy phase_history_select on public.project_phase_history
for select to authenticated using (
 exists(select 1 from public.project_memberships m where m.project_id=project_phase_history.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code in ('platform_admin','executive_viewer') and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);
