-- PPM module foundation: configurable CR workflow, deliverable history,
-- controlled milestone re-baseline requests, and in-app notifications.
-- No external delivery provider is enabled by this migration.

create table public.ppm_workflow_templates (
  id uuid primary key default gen_random_uuid(),
  module_code text not null,
  template_name text not null,
  project_id uuid references public.projects(id) on delete restrict,
  is_global boolean not null default false,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ppm_workflow_template_scope_ck check (
    (is_global and project_id is null) or (not is_global and project_id is not null)
  ),
  constraint ppm_workflow_template_module_ck check (module_code in ('change_request','deliverable','milestone_rebaseline')),
  unique (module_code, project_id, template_name)
);

create table public.ppm_workflow_template_versions (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.ppm_workflow_templates(id) on delete restrict,
  version_no integer not null check (version_no > 0),
  status text not null default 'draft',
  effective_from timestamptz,
  effective_to timestamptz,
  published_by uuid references auth.users(id) on delete restrict,
  published_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint ppm_workflow_version_status_ck check (status in ('draft','published','retired')),
  constraint ppm_workflow_version_dates_ck check (effective_to is null or effective_from is null or effective_to > effective_from),
  unique (template_id, version_no),
  unique (id, template_id)
);

create table public.ppm_workflow_stages (
  id uuid primary key default gen_random_uuid(),
  workflow_version_id uuid not null references public.ppm_workflow_template_versions(id) on delete restrict,
  stage_code text not null,
  stage_name text not null,
  sequence_no integer not null,
  required_role_codes text[] not null default '{}',
  required_fields text[] not null default '{}',
  sla_hours integer check (sla_hours is null or sla_hours > 0),
  is_terminal boolean not null default false,
  created_at timestamptz not null default now(),
  unique (workflow_version_id, stage_code),
  unique (workflow_version_id, sequence_no),
  unique (id, workflow_version_id)
);

create table public.ppm_workflow_transitions (
  id uuid primary key default gen_random_uuid(),
  workflow_version_id uuid not null references public.ppm_workflow_template_versions(id) on delete restrict,
  from_stage_id uuid not null,
  to_stage_id uuid not null,
  action_code text not null,
  action_label text not null,
  allowed_role_codes text[] not null default '{}',
  requires_comment boolean not null default false,
  prevents_self_approval boolean not null default false,
  created_at timestamptz not null default now(),
  constraint ppm_workflow_transition_from_fk foreign key (from_stage_id, workflow_version_id)
    references public.ppm_workflow_stages(id, workflow_version_id) on delete restrict,
  constraint ppm_workflow_transition_to_fk foreign key (to_stage_id, workflow_version_id)
    references public.ppm_workflow_stages(id, workflow_version_id) on delete restrict,
  constraint ppm_workflow_transition_distinct_ck check (from_stage_id <> to_stage_id),
  unique (workflow_version_id, from_stage_id, action_code)
);

create table public.project_change_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  cr_reference text not null,
  title text not null,
  description text not null,
  justification text not null,
  request_type text,
  category text,
  priority text,
  status text not null default 'draft',
  current_stage_id uuid references public.ppm_workflow_stages(id) on delete restrict,
  workflow_version_id uuid references public.ppm_workflow_template_versions(id) on delete restrict,
  contract_id uuid,
  contract_variation_id uuid,
  requested_by uuid not null references auth.users(id) on delete restrict,
  assigned_to uuid references auth.users(id) on delete restrict,
  submitted_at timestamptz,
  target_decision_at timestamptz,
  decided_at timestamptz,
  closed_at timestamptz,
  decision_reason text,
  implementation_owner_id uuid references auth.users(id) on delete restrict,
  implementation_due_date date,
  implementation_status text,
  verified_by uuid references auth.users(id) on delete restrict,
  verified_at timestamptz,
  closure_evidence text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint project_change_requests_project_ref_uq unique (project_id, cr_reference),
  constraint project_change_requests_contract_fk foreign key (contract_id, project_id)
    references public.project_contracts(id, project_id) on delete restrict,
  constraint project_change_requests_variation_fk foreign key (contract_variation_id)
    references public.project_contract_variations(id) on delete restrict
);

alter table public.project_change_requests
  add constraint project_change_requests_id_project_uq unique (id, project_id);

create table public.project_change_request_impacts (
  id uuid primary key default gen_random_uuid(),
  change_request_id uuid not null references public.project_change_requests(id) on delete restrict,
  project_id uuid not null references public.projects(id) on delete restrict,
  impact_dimension text not null,
  assessment_status text not null default 'not_assessed',
  before_value jsonb,
  after_value jsonb,
  impact_summary text,
  cost_delta numeric(18,2),
  currency_code char(3),
  schedule_impact_days integer,
  resource_impact jsonb,
  risk_impact jsonb,
  assessed_by uuid references auth.users(id) on delete restrict,
  assessed_at timestamptz,
  not_applicable_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint project_cr_impact_dimension_uq unique (change_request_id, impact_dimension),
  constraint project_cr_impact_status_ck check (assessment_status in ('not_assessed','assessed','not_applicable')),
  constraint project_cr_impact_na_ck check (assessment_status <> 'not_applicable' or nullif(btrim(not_applicable_reason),'') is not null),
  constraint project_cr_impact_request_project_fk foreign key (change_request_id, project_id)
    references public.project_change_requests(id, project_id) on delete restrict
);

create table public.project_change_request_approvals (
  id uuid primary key default gen_random_uuid(),
  change_request_id uuid not null,
  project_id uuid not null,
  stage_id uuid not null references public.ppm_workflow_stages(id) on delete restrict,
  approval_sequence integer not null default 1,
  approver_user_id uuid references auth.users(id) on delete restrict,
  approver_role_code text,
  status text not null default 'pending',
  decision text,
  decision_reason text,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  constraint project_cr_approval_request_fk foreign key (change_request_id, project_id)
    references public.project_change_requests(id, project_id) on delete restrict,
  constraint project_cr_approval_status_ck check (status in ('pending','approved','rejected','returned','cancelled')),
  constraint project_cr_approval_decision_ck check (decision is null or decision in ('approved','rejected','returned')),
  constraint project_cr_approval_assignee_ck check (approver_user_id is not null or approver_role_code is not null)
);

create table public.project_change_request_history (
  id uuid primary key default gen_random_uuid(),
  change_request_id uuid not null,
  project_id uuid not null,
  event_code text not null,
  from_status text,
  to_status text,
  actor_user_id uuid references auth.users(id) on delete restrict,
  event_reason text,
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint project_cr_history_request_fk foreign key (change_request_id, project_id)
    references public.project_change_requests(id, project_id) on delete restrict
);

create table public.contract_deliverable_submissions (
  id uuid primary key default gen_random_uuid(),
  deliverable_id uuid not null references public.contract_deliverables(id) on delete restrict,
  project_id uuid not null references public.projects(id) on delete restrict,
  submission_no integer not null check (submission_no > 0),
  submitted_by uuid not null references auth.users(id) on delete restrict,
  submitted_at timestamptz not null default now(),
  document_id uuid references public.project_documents(id) on delete restrict,
  document_version_id uuid references public.project_document_versions(id) on delete restrict,
  submission_notes text,
  status text not null default 'submitted',
  created_at timestamptz not null default now(),
  unique (deliverable_id, submission_no),
  unique (id, deliverable_id, project_id)
);

create table public.contract_deliverable_reviews (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.contract_deliverable_submissions(id) on delete restrict,
  deliverable_id uuid not null references public.contract_deliverables(id) on delete restrict,
  project_id uuid not null references public.projects(id) on delete restrict,
  reviewer_user_id uuid not null references auth.users(id) on delete restrict,
  outcome text not null,
  comments text,
  rejection_reason text,
  reviewed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint contract_deliverable_review_outcome_ck check (outcome in ('accepted','changes_required','rejected')),
  constraint contract_deliverable_review_rejection_ck check (outcome <> 'rejected' or nullif(btrim(rejection_reason),'') is not null),
  constraint contract_deliverable_review_submission_fk foreign key (submission_id, deliverable_id, project_id)
    references public.contract_deliverable_submissions(id, deliverable_id, project_id) on delete restrict
);

alter table public.contract_deliverables
  add column deliverable_type text,
  add column is_contractual boolean not null default true,
  add column contract_reference text,
  add column owner_user_id uuid references auth.users(id) on delete restrict,
  add column reviewer_user_id uuid references auth.users(id) on delete restrict,
  add column accepting_authority text,
  add column baseline_submission_date date,
  add column approved_revised_submission_date date,
  add column forecast_submission_date date,
  add column actual_submission_date date,
  add column baseline_acceptance_date date,
  add column approved_revised_acceptance_date date,
  add column forecast_acceptance_date date,
  add column acceptance_status text not null default 'unaccepted',
  add constraint contract_deliverable_acceptance_status_ck
    check (acceptance_status in ('unaccepted','pending_review','accepted','rejected','waived')),
  add constraint contract_deliverable_pm_acceptance_ck
    check ((acceptance_status <> 'accepted') or (accepted_by is not null and accepted_at is not null and status = 'accepted'));

create table public.project_milestone_rebaseline_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  milestone_id uuid not null references public.project_milestones(id) on delete restrict,
  request_reference text not null,
  reason text not null,
  proposed_start_date date,
  proposed_due_date date,
  status text not null default 'submitted',
  requested_by uuid not null references auth.users(id) on delete restrict,
  requested_at timestamptz not null default now(),
  decided_by uuid references auth.users(id) on delete restrict,
  decided_at timestamptz,
  decision_reason text,
  applied_at timestamptz,
  created_at timestamptz not null default now(),
  constraint project_milestone_rebaseline_ref_uq unique (project_id, request_reference),
  constraint project_milestone_rebaseline_dates_ck check (proposed_start_date is null or proposed_due_date is null or proposed_start_date <= proposed_due_date),
  constraint project_milestone_rebaseline_status_ck check (status in ('submitted','approved','rejected','withdrawn','applied'))
);

create table public.project_milestone_baseline_history (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  milestone_id uuid not null references public.project_milestones(id) on delete restrict,
  rebaseline_request_id uuid not null references public.project_milestone_rebaseline_requests(id) on delete restrict,
  previous_start_date date,
  previous_due_date date,
  new_start_date date,
  new_due_date date,
  applied_by uuid not null references auth.users(id) on delete restrict,
  applied_at timestamptz not null default now(),
  reason text not null
);

create table public.ppm_notification_rules (
  id uuid primary key default gen_random_uuid(),
  rule_code text not null unique,
  rule_name text not null,
  module_code text not null,
  event_code text not null,
  is_enabled boolean not null default false,
  severity text not null default 'normal',
  trigger_conditions jsonb not null default '{}'::jsonb,
  recipient_rules jsonb not null default '{}'::jsonb,
  lead_time_minutes integer not null default 0 check (lead_time_minutes >= 0),
  repeat_interval_minutes integer check (repeat_interval_minutes is null or repeat_interval_minutes > 0),
  escalation_rules jsonb not null default '{}'::jsonb,
  timezone_mode text not null default 'project',
  quiet_hours jsonb not null default '{}'::jsonb,
  requires_acknowledgement boolean not null default false,
  effective_from timestamptz,
  effective_to timestamptz,
  version_no integer not null default 1 check (version_no > 0),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ppm_notification_rule_dates_ck check (effective_to is null or effective_from is null or effective_to > effective_from)
);

create table public.ppm_user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete restrict,
  project_id uuid references public.projects(id) on delete restrict,
  rule_id uuid references public.ppm_notification_rules(id) on delete restrict,
  event_code text not null,
  severity text not null default 'normal',
  title text not null,
  message text not null,
  source_table text,
  source_record_id uuid,
  deep_link text,
  is_read boolean not null default false,
  read_at timestamptz,
  requires_acknowledgement boolean not null default false,
  acknowledged_at timestamptz,
  expires_at timestamptz,
  deduplication_key text,
  created_at timestamptz not null default now(),
  constraint ppm_notification_ack_ck check (not requires_acknowledgement or acknowledged_at is null or acknowledged_at >= created_at)
);

create unique index ppm_user_notifications_dedupe_uq
  on public.ppm_user_notifications(recipient_user_id, deduplication_key)
  where deduplication_key is not null;
create index ppm_user_notifications_inbox_idx
  on public.ppm_user_notifications(recipient_user_id, is_read, created_at desc);
create index project_change_requests_project_status_idx
  on public.project_change_requests(project_id, status, created_at desc);
create index project_cr_approvals_assignee_idx
  on public.project_change_request_approvals(approver_user_id, status, created_at desc);
create index contract_deliverable_submissions_project_idx
  on public.contract_deliverable_submissions(project_id, deliverable_id, submission_no desc);
create index project_milestone_rebaseline_project_idx
  on public.project_milestone_rebaseline_requests(project_id, status, requested_at desc);

alter table public.ppm_workflow_templates enable row level security;
alter table public.ppm_workflow_template_versions enable row level security;
alter table public.ppm_workflow_stages enable row level security;
alter table public.ppm_workflow_transitions enable row level security;
alter table public.project_change_requests enable row level security;
alter table public.project_change_request_impacts enable row level security;
alter table public.project_change_request_approvals enable row level security;
alter table public.project_change_request_history enable row level security;
alter table public.contract_deliverable_submissions enable row level security;
alter table public.contract_deliverable_reviews enable row level security;
alter table public.project_milestone_rebaseline_requests enable row level security;
alter table public.project_milestone_baseline_history enable row level security;
alter table public.ppm_notification_rules enable row level security;
alter table public.ppm_user_notifications enable row level security;

-- Configuration is administered centrally; authenticated users may read active definitions.
create policy ppm_workflow_templates_read on public.ppm_workflow_templates
for select to authenticated using (
  is_active and (
    is_global or exists (
      select 1 from public.project_memberships pm
      where pm.project_id = ppm_workflow_templates.project_id
        and pm.user_id = (select auth.uid()) and pm.status = 'active'
        and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now())
    )
  )
  or exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code = 'platform_admin'
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
);
create policy ppm_workflow_versions_read on public.ppm_workflow_template_versions
for select to authenticated using (exists (
  select 1 from public.ppm_workflow_templates t where t.id = template_id
));
create policy ppm_workflow_stages_read on public.ppm_workflow_stages
for select to authenticated using (exists (
  select 1 from public.ppm_workflow_template_versions v
  join public.ppm_workflow_templates t on t.id = v.template_id where v.id = workflow_version_id
));
create policy ppm_workflow_transitions_read on public.ppm_workflow_transitions
for select to authenticated using (exists (
  select 1 from public.ppm_workflow_template_versions v
  join public.ppm_workflow_templates t on t.id = v.template_id where v.id = workflow_version_id
));

create policy ppm_workflow_templates_admin_write on public.ppm_workflow_templates
for all to authenticated using (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
)) with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));
create policy ppm_workflow_versions_admin_write on public.ppm_workflow_template_versions
for all to authenticated using (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
)) with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));
create policy ppm_workflow_stages_admin_write on public.ppm_workflow_stages
for all to authenticated using (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
)) with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));
create policy ppm_workflow_transitions_admin_write on public.ppm_workflow_transitions
for all to authenticated using (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
)) with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));

-- Project Managers and Platform Administrators own CR intake and administration.
create policy project_cr_read_project_members on public.project_change_requests
for select to authenticated using (
  exists (select 1 from public.project_memberships pm
    where pm.project_id = project_change_requests.project_id and pm.user_id = (select auth.uid()) and pm.status = 'active'
      and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code = 'platform_admin'
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
);
create policy project_cr_write_pm_admin on public.project_change_requests
for all to authenticated using (
  exists (select 1 from public.project_memberships pm
    where pm.project_id = project_change_requests.project_id and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
      and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code = 'platform_admin'
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
) with check (
  exists (select 1 from public.project_memberships pm
    where pm.project_id = project_change_requests.project_id and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
      and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code = 'platform_admin'
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
);

-- Financial impact details are more restricted than the base CR register.
create policy project_cr_impacts_finance_read on public.project_change_request_impacts
for select to authenticated using (
  exists (select 1 from public.project_memberships pm
    where pm.project_id = project_change_request_impacts.project_id and pm.user_id = (select auth.uid()) and pm.project_role in ('project_manager','finance')
      and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code in ('platform_admin','finance_admin')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
);
create policy project_cr_impacts_pm_finance_write on public.project_change_request_impacts
for all to authenticated using (
  exists (select 1 from public.project_memberships pm
    where pm.project_id = project_change_request_impacts.project_id and pm.user_id = (select auth.uid()) and pm.project_role in ('project_manager','finance')
      and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code in ('platform_admin','finance_admin')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
) with check (
  exists (select 1 from public.project_memberships pm
    where pm.project_id = project_change_request_impacts.project_id and pm.user_id = (select auth.uid()) and pm.project_role in ('project_manager','finance')
      and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code in ('platform_admin','finance_admin')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
);

create policy project_cr_approvals_read on public.project_change_request_approvals
for select to authenticated using (
  approver_user_id = (select auth.uid())
  or exists (select 1 from public.project_memberships pm where pm.project_id = project_change_request_approvals.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active' and ura.effective_from <= now()
    and (ura.effective_to is null or ura.effective_to > now()))
);
create policy project_cr_approvals_assignee_update on public.project_change_request_approvals
for update to authenticated using (
  approver_user_id = (select auth.uid())
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active' and ura.effective_from <= now()
    and (ura.effective_to is null or ura.effective_to > now()))
) with check (
  approver_user_id = (select auth.uid())
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active' and ura.effective_from <= now()
    and (ura.effective_to is null or ura.effective_to > now()))
);

create policy project_cr_history_read on public.project_change_request_history
for select to authenticated using (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_change_request_history.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active' and ura.effective_from <= now()
    and (ura.effective_to is null or ura.effective_to > now()))
);

-- Submission history is immutable from the client; PM/reviewer records are retained.
create policy deliverable_submissions_read on public.contract_deliverable_submissions
for select to authenticated using (
  exists (select 1 from public.project_memberships pm where pm.project_id = contract_deliverable_submissions.project_id
    and pm.user_id = (select auth.uid()) and pm.status = 'active'
    and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code in ('platform_admin','executive_viewer') and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);
create policy deliverable_reviews_read on public.contract_deliverable_reviews
for select to authenticated using (
  reviewer_user_id = (select auth.uid())
  or exists (select 1 from public.project_memberships pm where pm.project_id = project_milestone_baseline_history.project_id
    and pm.user_id = (select auth.uid()) and pm.project_role = 'project_manager'
    and pm.status = 'active' and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code in ('platform_admin','executive_viewer') and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);

create policy milestone_rebaseline_read on public.project_milestone_rebaseline_requests
for select to authenticated using (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_milestone_rebaseline_requests.project_id
    and pm.user_id = (select auth.uid()) and pm.status = 'active'
    and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code in ('platform_admin','executive_viewer') and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);
create policy milestone_rebaseline_pm_admin_write on public.project_milestone_rebaseline_requests
for all to authenticated using (
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
create policy milestone_baseline_history_read on public.project_milestone_baseline_history
for select to authenticated using (
  exists (select 1 from public.project_memberships pm where pm.project_id = project_milestone_rebaseline_requests.project_id
    and pm.user_id = (select auth.uid()) and pm.status = 'active'
    and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
  or exists (select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code in ('platform_admin','executive_viewer') and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now()))
);

-- Notification rules are admin-controlled; inbox rows are private to each recipient.
create policy ppm_notification_rules_admin_all on public.ppm_notification_rules
for all to authenticated using (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
)) with check (exists (
  select 1 from public.user_global_role_assignments ura where ura.user_id = (select auth.uid())
    and ura.role_code = 'platform_admin' and ura.status = 'active'
    and ura.effective_from <= now() and (ura.effective_to is null or ura.effective_to > now())
));
create policy ppm_user_notifications_read_own on public.ppm_user_notifications
for select to authenticated using (recipient_user_id = (select auth.uid()));
create policy ppm_user_notifications_update_own on public.ppm_user_notifications
for update to authenticated using (recipient_user_id = (select auth.uid()))
with check (recipient_user_id = (select auth.uid()));

grant select, insert, update, delete on
  public.ppm_workflow_templates, public.ppm_workflow_template_versions,
  public.ppm_workflow_stages, public.ppm_workflow_transitions,
  public.project_change_requests, public.project_change_request_impacts,
  public.project_change_request_approvals, public.project_change_request_history,
  public.contract_deliverable_submissions, public.contract_deliverable_reviews,
  public.project_milestone_rebaseline_requests, public.project_milestone_baseline_history,
  public.ppm_notification_rules, public.ppm_user_notifications
to authenticated;
grant all on
  public.ppm_workflow_templates, public.ppm_workflow_template_versions,
  public.ppm_workflow_stages, public.ppm_workflow_transitions,
  public.project_change_requests, public.project_change_request_impacts,
  public.project_change_request_approvals, public.project_change_request_history,
  public.contract_deliverable_submissions, public.contract_deliverable_reviews,
  public.project_milestone_rebaseline_requests, public.project_milestone_baseline_history,
  public.ppm_notification_rules, public.ppm_user_notifications
to service_role;

-- Preserve immutable history and restrict recipient edits to inbox state only.
revoke delete on
  public.ppm_workflow_templates, public.ppm_workflow_template_versions,
  public.ppm_workflow_stages, public.ppm_workflow_transitions,
  public.project_change_requests, public.project_change_request_impacts,
  public.project_change_request_approvals, public.project_change_request_history,
  public.contract_deliverable_submissions, public.contract_deliverable_reviews,
  public.project_milestone_rebaseline_requests, public.project_milestone_baseline_history,
  public.ppm_notification_rules, public.ppm_user_notifications
from authenticated;
revoke update on public.ppm_user_notifications from authenticated;
grant update (is_read, read_at, acknowledged_at)
  on public.ppm_user_notifications to authenticated;
revoke update on public.project_change_request_approvals from authenticated;
grant update (status, decision, decision_reason, decided_at)
  on public.project_change_request_approvals to authenticated;
