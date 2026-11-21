-- Reduce permissive SELECT policy overlap and cover module foreign keys.

drop policy ppm_workflow_templates_admin_write on public.ppm_workflow_templates;
create policy ppm_workflow_templates_admin_insert on public.ppm_workflow_templates
for insert to authenticated with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));
create policy ppm_workflow_templates_admin_update on public.ppm_workflow_templates
for update to authenticated using (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
)) with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));

drop policy ppm_workflow_versions_admin_write on public.ppm_workflow_template_versions;
create policy ppm_workflow_versions_admin_insert on public.ppm_workflow_template_versions
for insert to authenticated with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));
create policy ppm_workflow_versions_admin_update on public.ppm_workflow_template_versions
for update to authenticated using (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
)) with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));

drop policy ppm_workflow_stages_admin_write on public.ppm_workflow_stages;
create policy ppm_workflow_stages_admin_insert on public.ppm_workflow_stages
for insert to authenticated with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));
create policy ppm_workflow_stages_admin_update on public.ppm_workflow_stages
for update to authenticated using (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
)) with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));

drop policy ppm_workflow_transitions_admin_write on public.ppm_workflow_transitions;
create policy ppm_workflow_transitions_admin_insert on public.ppm_workflow_transitions
for insert to authenticated with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));
create policy ppm_workflow_transitions_admin_update on public.ppm_workflow_transitions
for update to authenticated using (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
)) with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));

drop policy project_cr_write_pm_admin on public.project_change_requests;
create policy project_cr_insert_pm_admin on public.project_change_requests
for insert to authenticated with check (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_change_requests.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);
create policy project_cr_update_pm_admin on public.project_change_requests
for update to authenticated using (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_change_requests.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
) with check (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_change_requests.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);

drop policy project_cr_impacts_pm_finance_write on public.project_change_request_impacts;
create policy project_cr_impacts_insert on public.project_change_request_impacts
for insert to authenticated with check (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_change_request_impacts.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role in ('project_manager','finance')
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code in ('platform_admin','finance_admin') and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);
create policy project_cr_impacts_update on public.project_change_request_impacts
for update to authenticated using (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_change_request_impacts.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role in ('project_manager','finance')
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code in ('platform_admin','finance_admin') and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
) with check (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_change_request_impacts.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role in ('project_manager','finance')
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code in ('platform_admin','finance_admin') and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);

drop policy milestone_rebaseline_pm_admin_write on public.project_milestone_rebaseline_requests;
create policy milestone_rebaseline_insert_pm_admin on public.project_milestone_rebaseline_requests
for insert to authenticated with check (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_milestone_rebaseline_requests.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);
create policy milestone_rebaseline_update_pm_admin on public.project_milestone_rebaseline_requests
for update to authenticated using (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_milestone_rebaseline_requests.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
) with check (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_milestone_rebaseline_requests.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);

create index ppm_workflow_templates_project_idx on public.ppm_workflow_templates(project_id);
create index ppm_workflow_templates_created_by_idx on public.ppm_workflow_templates(created_by);
create index ppm_workflow_versions_template_idx on public.ppm_workflow_template_versions(template_id);
create index ppm_workflow_versions_published_by_idx on public.ppm_workflow_template_versions(published_by);
create index ppm_workflow_versions_created_by_idx on public.ppm_workflow_template_versions(created_by);
create index ppm_workflow_stages_version_idx on public.ppm_workflow_stages(workflow_version_id);
create index ppm_workflow_transitions_version_idx on public.ppm_workflow_transitions(workflow_version_id);
create index ppm_workflow_transitions_from_idx on public.ppm_workflow_transitions(from_stage_id, workflow_version_id);
create index ppm_workflow_transitions_to_idx on public.ppm_workflow_transitions(to_stage_id, workflow_version_id);
create index project_cr_project_idx on public.project_change_requests(project_id);
create index project_cr_stage_idx on public.project_change_requests(current_stage_id);
create index project_cr_workflow_version_idx on public.project_change_requests(workflow_version_id);
create index project_cr_contract_idx on public.project_change_requests(contract_id, project_id);
create index project_cr_variation_idx on public.project_change_requests(contract_variation_id);
create index project_cr_requested_by_idx on public.project_change_requests(requested_by);
create index project_cr_assigned_to_idx on public.project_change_requests(assigned_to);
create index project_cr_implementation_owner_idx on public.project_change_requests(implementation_owner_id);
create index project_cr_verified_by_idx on public.project_change_requests(verified_by);
create index project_cr_impacts_request_project_idx on public.project_change_request_impacts(change_request_id, project_id);
create index project_cr_impacts_project_idx on public.project_change_request_impacts(project_id);
create index project_cr_impacts_assessed_by_idx on public.project_change_request_impacts(assessed_by);
create index project_cr_approvals_stage_idx on public.project_change_request_approvals(stage_id);
create index project_cr_approvals_request_project_idx on public.project_change_request_approvals(change_request_id, project_id);
create index project_cr_approvals_user_idx on public.project_change_request_approvals(approver_user_id);
create index project_cr_history_request_project_idx on public.project_change_request_history(change_request_id, project_id);
create index project_cr_history_actor_idx on public.project_change_request_history(actor_user_id);
create index deliverable_submissions_deliverable_idx on public.contract_deliverable_submissions(deliverable_id);
create index deliverable_submissions_project_idx on public.contract_deliverable_submissions(project_id);
create index deliverable_submissions_submitter_idx on public.contract_deliverable_submissions(submitted_by);
create index deliverable_submissions_document_idx on public.contract_deliverable_submissions(document_id);
create index deliverable_submissions_document_version_idx on public.contract_deliverable_submissions(document_version_id);
create index deliverable_reviews_submission_idx on public.contract_deliverable_reviews(submission_id);
create index deliverable_reviews_deliverable_idx on public.contract_deliverable_reviews(deliverable_id);
create index deliverable_reviews_project_idx on public.contract_deliverable_reviews(project_id);
create index deliverable_reviews_reviewer_idx on public.contract_deliverable_reviews(reviewer_user_id);
create index deliverable_owner_idx on public.contract_deliverables(owner_user_id);
create index deliverable_reviewer_idx on public.contract_deliverables(reviewer_user_id);
create index milestone_rebaseline_milestone_idx on public.project_milestone_rebaseline_requests(milestone_id);
create index milestone_rebaseline_requester_idx on public.project_milestone_rebaseline_requests(requested_by);
create index milestone_rebaseline_decider_idx on public.project_milestone_rebaseline_requests(decided_by);
create index milestone_baseline_history_project_idx on public.project_milestone_baseline_history(project_id);
create index milestone_baseline_history_milestone_idx on public.project_milestone_baseline_history(milestone_id);
create index milestone_baseline_history_request_idx on public.project_milestone_baseline_history(rebaseline_request_id);
create index milestone_baseline_history_applier_idx on public.project_milestone_baseline_history(applied_by);
create index ppm_notification_rules_creator_idx on public.ppm_notification_rules(created_by);
create index ppm_user_notifications_project_idx on public.ppm_user_notifications(project_id);
create index ppm_user_notifications_rule_idx on public.ppm_user_notifications(rule_id);
