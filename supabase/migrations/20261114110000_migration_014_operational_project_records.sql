begin;

-- Operational project records: source-of-truth tables for future reporting.
create table public.project_contracts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  contract_reference text not null,
  contract_title text not null,
  contract_type text not null default 'services',
  status text not null default 'draft',
  signed_date date,
  commencement_date date,
  contractual_end_date date,
  duration_months integer check (duration_months is null or duration_months > 0),
  scope_summary text,
  obligations text,
  acceptance_criteria text,
  penalties_terms text,
  change_control_terms text,
  payment_terms text,
  currency_code char(3),
  original_contract_value numeric(18,2) check (original_contract_value is null or original_contract_value >= 0),
  tax_rate numeric(7,4) check (tax_rate is null or tax_rate between 0 and 100),
  retention_rate numeric(7,4) check (retention_rate is null or retention_rate between 0 and 100),
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,project_id),
  unique (project_id,contract_reference),
  check (commencement_date is null or contractual_end_date is null or commencement_date<=contractual_end_date)
);

create table public.contract_deliverables (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  contract_id uuid not null,
  deliverable_code text not null,
  name text not null,
  description text,
  due_date date,
  acceptance_criteria text,
  status text not null default 'planned',
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id) on delete restrict,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id,deliverable_code),
  foreign key (contract_id,project_id) references public.project_contracts(id,project_id) on delete restrict
);

create table public.project_financial_terms (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null unique references public.projects(id) on delete restrict,
  currency_code char(3) not null,
  original_contract_value numeric(18,2) not null default 0 check (original_contract_value>=0),
  approved_variations numeric(18,2) not null default 0,
  revised_contract_value numeric(18,2) generated always as (original_contract_value+approved_variations) stored,
  tax_rate numeric(7,4) check (tax_rate is null or tax_rate between 0 and 100),
  retention_rate numeric(7,4) check (retention_rate is null or retention_rate between 0 and 100),
  payment_terms text,
  billing_notes text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.project_milestones (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  milestone_code text not null,
  name text not null,
  description text,
  milestone_type text not null default 'delivery',
  sequence_no integer,
  weight numeric(9,6) check (weight is null or weight between 0 and 1),
  baseline_start_date date,
  baseline_due_date date,
  approved_revised_start_date date,
  approved_revised_due_date date,
  forecast_start_date date,
  forecast_due_date date,
  actual_start_date date,
  actual_due_date date,
  progress_percent numeric(5,2) not null default 0 check (progress_percent between 0 and 100),
  status text not null default 'planned',
  owner_user_id uuid references auth.users(id) on delete restrict,
  is_critical boolean not null default false,
  completion_evidence text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,project_id),
  unique (project_id,milestone_code),
  check (baseline_start_date is null or baseline_due_date is null or baseline_start_date<=baseline_due_date),
  check (approved_revised_start_date is null or approved_revised_due_date is null or approved_revised_start_date<=approved_revised_due_date),
  check (forecast_start_date is null or forecast_due_date is null or forecast_start_date<=forecast_due_date),
  check (actual_start_date is null or actual_due_date is null or actual_start_date<=actual_due_date)
);

create table public.project_activities (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  milestone_id uuid,
  activity_code text not null,
  name text not null,
  description text,
  workstream text,
  sequence_no integer,
  weight numeric(9,6) check (weight is null or weight between 0 and 1),
  baseline_start_date date,
  baseline_due_date date,
  approved_revised_start_date date,
  approved_revised_due_date date,
  forecast_start_date date,
  forecast_due_date date,
  actual_start_date date,
  actual_due_date date,
  progress_percent numeric(5,2) not null default 0 check (progress_percent between 0 and 100),
  status text not null default 'not_started',
  assigned_to_user_id uuid references auth.users(id) on delete restrict,
  verification_status text not null default 'unverified',
  verified_by uuid references auth.users(id) on delete restrict,
  verified_at timestamptz,
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,project_id),
  unique (project_id,activity_code),
  foreign key (milestone_id,project_id) references public.project_milestones(id,project_id) on delete restrict,
  check (baseline_start_date is null or baseline_due_date is null or baseline_start_date<=baseline_due_date),
  check (approved_revised_start_date is null or approved_revised_due_date is null or approved_revised_start_date<=approved_revised_due_date),
  check (forecast_start_date is null or forecast_due_date is null or forecast_start_date<=forecast_due_date),
  check (actual_start_date is null or actual_due_date is null or actual_start_date<=actual_due_date)
);

create table public.project_activity_dependencies (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  predecessor_activity_id uuid not null,
  successor_activity_id uuid not null,
  dependency_type text not null default 'finish_to_start',
  lag_days integer not null default 0,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (project_id,predecessor_activity_id,successor_activity_id),
  foreign key (predecessor_activity_id,project_id) references public.project_activities(id,project_id) on delete restrict,
  foreign key (successor_activity_id,project_id) references public.project_activities(id,project_id) on delete restrict,
  check (predecessor_activity_id<>successor_activity_id),
  check (dependency_type in ('finish_to_start','start_to_start','finish_to_finish','start_to_finish'))
);

create table public.project_invoices (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  contract_id uuid,
  invoice_reference text not null,
  invoice_type text not null default 'standard',
  status text not null default 'draft',
  issue_date date,
  submission_date date,
  due_date date,
  currency_code char(3) not null,
  subtotal_amount numeric(18,2) not null default 0 check (subtotal_amount>=0),
  tax_amount numeric(18,2) not null default 0 check (tax_amount>=0),
  retention_amount numeric(18,2) not null default 0 check (retention_amount>=0),
  total_amount numeric(18,2) not null check (total_amount>=0),
  description text,
  disputed_reason text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,project_id),
  unique (project_id,invoice_reference),
  foreign key (contract_id,project_id) references public.project_contracts(id,project_id) on delete restrict,
  check (invoice_type in ('standard','credit_note')),
  check (status in ('draft','submitted','approved','partially_paid','paid','disputed','rejected','overdue','cancelled'))
);

create table public.project_cash_transactions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  transaction_reference text not null,
  transaction_type text not null,
  status text not null default 'confirmed',
  transaction_date date not null,
  currency_code char(3) not null,
  amount numeric(18,2) not null check (amount>0),
  payer_payee text,
  bank_reference text,
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (id,project_id),
  unique (project_id,transaction_reference),
  check (transaction_type in ('payment','credit_note','refund','adjustment')),
  check (status in ('pending','confirmed','reversed','cancelled'))
);

create table public.invoice_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  invoice_id uuid not null,
  cash_transaction_id uuid not null,
  allocated_amount numeric(18,2) not null check (allocated_amount>0),
  allocation_date date not null default current_date,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (invoice_id,cash_transaction_id),
  foreign key (invoice_id,project_id) references public.project_invoices(id,project_id) on delete restrict,
  foreign key (cash_transaction_id,project_id) references public.project_cash_transactions(id,project_id) on delete restrict
);

create table public.project_risks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  risk_reference text not null,
  title text not null,
  description text not null,
  category text,
  cause text,
  consequence text,
  probability_level integer not null check (probability_level between 1 and 5),
  impact_level integer not null check (impact_level between 1 and 5),
  risk_score integer generated always as (probability_level*impact_level) stored,
  response_strategy text,
  mitigation_plan text,
  contingency_plan text,
  owner_user_id uuid references auth.users(id) on delete restrict,
  identified_date date not null default current_date,
  review_date date,
  target_resolution_date date,
  resolved_date date,
  status text not null default 'open',
  trend text not null default 'stable',
  is_escalated boolean not null default false,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id,risk_reference),
  check (trend in ('increasing','stable','decreasing')),
  check (resolved_date is null or resolved_date>=identified_date)
);

create table public.project_licenses (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  license_reference text not null,
  license_name text not null,
  license_type text,
  provider text,
  quantity numeric(14,3) check (quantity is null or quantity>=0),
  unit_of_measure text,
  start_date date,
  expiry_date date,
  renewal_notice_date date,
  renewal_cost numeric(18,2) check (renewal_cost is null or renewal_cost>=0),
  currency_code char(3),
  owner_user_id uuid references auth.users(id) on delete restrict,
  status text not null default 'active',
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id,license_reference),
  check (start_date is null or expiry_date is null or start_date<=expiry_date)
);

create table public.project_weekly_updates (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  week_start date not null,
  week_end date not null,
  status text not null default 'draft',
  overall_progress_percent numeric(5,2) check (overall_progress_percent is null or overall_progress_percent between 0 and 100),
  reported_health_status text,
  achievements text,
  work_completed text,
  upcoming_work_7_days text,
  upcoming_work_14_days text,
  upcoming_work_30_days text,
  issues_and_blockers text,
  decisions_required text,
  management_attention text,
  pm_outlook text,
  submitted_by uuid references auth.users(id) on delete restrict,
  submitted_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id,week_start),
  check (week_end>=week_start),
  check (status in ('draft','submitted','reviewed','returned'))
);

create table public.project_management_decisions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  decision_reference text not null,
  title text not null,
  description text,
  decision_type text not null default 'management',
  priority text not null default 'medium',
  status text not null default 'open',
  owner_user_id uuid references auth.users(id) on delete restrict,
  requested_by uuid references auth.users(id) on delete restrict,
  requested_date date not null default current_date,
  required_by_date date,
  decision_text text,
  decided_by uuid references auth.users(id) on delete restrict,
  decided_at timestamptz,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id,decision_reference),
  check (priority in ('low','medium','high','critical')),
  check (status in ('open','in_review','decided','deferred','closed'))
);

-- Baselines are immutable through ordinary application writes. A future governed
-- re-baseline operation must be implemented as a separately audited workflow.
create or replace function private.guard_project_baseline_dates()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if new.baseline_start_date is distinct from old.baseline_start_date
     or new.baseline_due_date is distinct from old.baseline_due_date then
    raise exception 'Baseline dates are immutable; use the approved re-baseline workflow';
  end if;
  return new;
end;
$function$;

create trigger project_milestones_baseline_immutable
before update on public.project_milestones
for each row execute function private.guard_project_baseline_dates();
create trigger project_activities_baseline_immutable
before update on public.project_activities
for each row execute function private.guard_project_baseline_dates();

create or replace function private.set_operational_updated_at()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

do $triggers$
declare t text;
begin
  foreach t in array array[
    'project_contracts','contract_deliverables','project_financial_terms',
    'project_milestones','project_activities','project_invoices',
    'project_risks','project_licenses','project_weekly_updates',
    'project_management_decisions'
  ] loop
    execute format('create trigger %I before update on public.%I for each row execute function private.set_operational_updated_at()',t||'_set_updated_at',t);
  end loop;
end;
$triggers$;

-- Indexes supporting project scoping, timeline retrieval and operational filters.
create index project_contracts_project_status_idx on public.project_contracts(project_id,status);
create index contract_deliverables_project_due_idx on public.contract_deliverables(project_id,due_date);
create index project_milestones_project_due_idx on public.project_milestones(project_id,forecast_due_date);
create index project_milestones_project_baseline_idx on public.project_milestones(project_id,baseline_due_date);
create index project_activities_project_due_idx on public.project_activities(project_id,forecast_due_date);
create index project_activities_assignee_status_idx on public.project_activities(assigned_to_user_id,status);
create index activity_dependencies_project_idx on public.project_activity_dependencies(project_id);
create index project_invoices_project_due_status_idx on public.project_invoices(project_id,due_date,status);
create index cash_transactions_project_date_idx on public.project_cash_transactions(project_id,transaction_date);
create index invoice_allocations_project_invoice_idx on public.invoice_payment_allocations(project_id,invoice_id);
create index project_risks_project_status_score_idx on public.project_risks(project_id,status,risk_score desc);
create index project_licenses_project_expiry_idx on public.project_licenses(project_id,expiry_date);
create index project_weekly_updates_project_week_idx on public.project_weekly_updates(project_id,week_start desc);
create index project_decisions_project_status_due_idx on public.project_management_decisions(project_id,status,required_by_date);

-- All exposed operational tables are RLS protected.
do $rls$
declare t text;
begin
  foreach t in array array[
    'project_contracts','contract_deliverables','project_financial_terms',
    'project_milestones','project_activities','project_activity_dependencies',
    'project_invoices','project_cash_transactions','invoice_payment_allocations',
    'project_risks','project_licenses','project_weekly_updates',
    'project_management_decisions'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('grant select,insert,update,delete on public.%I to authenticated,service_role',t);
  end loop;
end;
$rls$;

-- Read access is scoped to active project membership, or approved global roles.
do $policies$
declare t text;
begin
  foreach t in array array[
    'project_contracts','contract_deliverables','project_milestones',
    'project_activities','project_activity_dependencies','project_risks',
    'project_licenses','project_weekly_updates','project_management_decisions'
  ] loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (
        exists(select 1 from public.project_memberships pm
          where pm.project_id=%I.project_id and pm.user_id=(select auth.uid())
          and pm.status=''active'' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now()))
        or exists(select 1 from public.user_global_role_assignments ura
          where ura.user_id=(select auth.uid())
          and ura.role_code in (''platform_admin'',''executive_viewer'')
          and ura.status=''active'' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
      )',t||'_read_project_scope',t,t);
  end loop;
end;
$policies$;

-- Finance records are visible to project members and designated global finance roles.
do $policies$
declare t text;
begin
  foreach t in array array[
    'project_financial_terms','project_invoices','project_cash_transactions',
    'invoice_payment_allocations'
  ] loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (
        exists(select 1 from public.project_memberships pm
          where pm.project_id=%I.project_id and pm.user_id=(select auth.uid())
          and pm.status=''active'' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role in (''project_manager'',''finance''))
        or exists(select 1 from public.user_global_role_assignments ura
          where ura.user_id=(select auth.uid())
          and ura.role_code in (''platform_admin'',''executive_viewer'',''finance_admin'')
          and ura.status=''active'' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
      )',t||'_read_finance_scope',t,t);
  end loop;
end;
$policies$;

-- Project managers/admins manage delivery, contract and governance records.
do $policies$
declare t text;
begin
  foreach t in array array[
    'project_contracts','contract_deliverables','project_milestones',
    'project_risks','project_licenses','project_weekly_updates',
    'project_management_decisions'
  ] loop
    execute format(
      'create policy %I on public.%I for all to authenticated using (
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
      )',t||'_manage_pm_admin',t,t,t);
  end loop;
end;
$policies$;

-- Team leads can update only activities assigned to them; PM/admin can manage all.
create policy project_activities_manage_pm_admin
on public.project_activities for all to authenticated
using (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activities.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
)
with check (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activities.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
);
create policy project_activities_team_lead_update
on public.project_activities for update to authenticated
using (
  assigned_to_user_id=(select auth.uid())
  and exists(select 1 from public.project_memberships pm where pm.project_id=project_activities.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='team_lead')
)
with check (
  assigned_to_user_id=(select auth.uid())
  and exists(select 1 from public.project_memberships pm where pm.project_id=project_activities.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='team_lead')
);

-- Finance can manage finance records; project managers can read but not change them.
do $policies$
declare t text;
begin
  foreach t in array array[
    'project_financial_terms','project_invoices','project_cash_transactions',
    'invoice_payment_allocations'
  ] loop
    execute format(
      'create policy %I on public.%I for all to authenticated using (
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
      )',t||'_manage_finance',t,t,t);
  end loop;
end;
$policies$;

-- Activity dependencies are PM-managed and inherit project-member read access.
create policy project_activity_dependencies_manage_pm_admin
on public.project_activity_dependencies for all to authenticated
using (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activity_dependencies.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
)
with check (
  exists(select 1 from public.project_memberships pm where pm.project_id=project_activity_dependencies.project_id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
    and pm.project_role='project_manager')
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code='platform_admin' and ura.status='active'
    and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
);

-- Extend project profile read scope to executive and finance administrators.
drop policy if exists projects_read_member_or_platform_admin on public.projects;
create policy projects_read_member_or_global_reader on public.projects
for select to authenticated using (
  exists(select 1 from public.project_memberships pm where pm.project_id=projects.id
    and pm.user_id=(select auth.uid()) and pm.status='active'
    and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
  or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid())
    and ura.role_code in ('platform_admin','executive_viewer','finance_admin')
    and ura.status='active' and ura.effective_from<=now()
    and (ura.effective_to is null or ura.effective_to>now()))
);

commit;
