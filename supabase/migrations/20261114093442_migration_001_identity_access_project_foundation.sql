-- Executive PPM Platform
-- Migration 001: identity, access control, project registry foundation
-- Target project ref: oihawkpbtgqxxliaamxs
-- PostgreSQL 17 / Supabase
--
-- REVIEW STATUS: executable draft committed for review; NOT applied.
-- All writes to identity, role assignments, memberships and project master
-- data are intentionally server-side (service role only) in this foundation.
-- Never expose a service-role/secret key to a browser.

begin;

-- Internal schema is not intended for Data API exposure.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

-- Opt out of broad automatic grants for future objects created by postgres.
-- Each future migration must add deliberate grants together with RLS.
alter default privileges for role postgres in schema public
  revoke all on tables from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated, service_role;

-- Controlled application role catalogue.
create table public.app_role_definitions (
  code text primary key,
  name text not null,
  description text not null,
  is_global boolean not null,
  is_system_role boolean not null default true,
  created_at timestamptz not null default now(),
  constraint app_role_definitions_code_format
    check (code ~ '^[a-z][a-z0-9_]{1,63}$')
);

insert into public.app_role_definitions
  (code, name, description, is_global)
values
  ('platform_admin', 'Platform Admin', 'Trusted platform administration.', true),
  ('executive_viewer', 'Executive Viewer', 'Portfolio-wide read-only reporting and authorized exports.', true),
  ('configuration_steward', 'Configuration Steward', 'Drafts reporting configuration changes.', true),
  ('configuration_approver', 'Configuration Approver', 'Approves and publishes governed configuration versions.', true),
  ('finance_admin', 'Finance Admin', 'Cross-project finance administration where explicitly assigned.', true),
  ('project_manager', 'Project Manager', 'Manages delivery records for assigned projects.', false),
  ('finance', 'Finance', 'Manages financial records for assigned projects.', false),
  ('team_lead', 'Team Lead', 'Manages assigned delivery activities.', false),
  ('project_viewer', 'Project Viewer', 'Read-only access to permitted records in assigned projects.', false)
on conflict (code) do nothing;

-- User profile is descriptive only; it is never an authorization source.
create table public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete restrict,
  display_name text,
  job_title text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Global role assignments are written only by trusted server-side workflows.
create table public.user_global_role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  role_code text not null references public.app_role_definitions(code),
  status text not null default 'active'
    check (status in ('active', 'revoked')),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  assigned_by uuid references auth.users(id) on delete set null,
  reason text not null,
  created_at timestamptz not null default now(),
  constraint global_role_assignment_global_only
    check (role_code in (
      'platform_admin',
      'executive_viewer',
      'configuration_steward',
      'configuration_approver',
      'finance_admin'
    )),
  constraint global_role_assignment_valid_period
    check (effective_to is null or effective_to > effective_from)
);

create unique index user_global_role_assignments_one_active_idx
  on public.user_global_role_assignments (user_id, role_code)
  where status = 'active';

create index user_global_role_assignments_user_status_idx
  on public.user_global_role_assignments (user_id, status, effective_from, effective_to);

-- Basic portfolio and client reference data.
create table public.clients (
  id uuid primary key default gen_random_uuid(),
  client_code text not null unique,
  name text not null,
  status text not null default 'active'
    check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clients_code_not_blank check (length(btrim(client_code)) > 0),
  constraint clients_name_not_blank check (length(btrim(name)) > 0)
);

create table public.portfolios (
  id uuid primary key default gen_random_uuid(),
  portfolio_code text not null unique,
  name text not null,
  owner_user_id uuid references auth.users(id) on delete set null,
  status text not null default 'active'
    check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint portfolios_code_not_blank check (length(btrim(portfolio_code)) > 0),
  constraint portfolios_name_not_blank check (length(btrim(name)) > 0)
);

-- Project master registry. Membership rows are the source of project-scoped
-- authorization; PM/team-lead fields are assignments, not grants by themselves.
create table public.projects (
  id uuid primary key default gen_random_uuid(),
  project_code text not null unique,
  name text not null,
  client_id uuid references public.clients(id) on delete restrict,
  portfolio_id uuid references public.portfolios(id) on delete restrict,
  project_manager_id uuid references auth.users(id) on delete set null,
  team_lead_id uuid references auth.users(id) on delete set null,
  lifecycle_status text not null default 'draft'
    check (lifecycle_status in ('draft', 'active', 'on_hold', 'completed', 'cancelled', 'archived')),
  start_date date,
  target_end_date date,
  timezone text not null default 'UTC',
  currency_code char(3),
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint projects_code_not_blank check (length(btrim(project_code)) > 0),
  constraint projects_name_not_blank check (length(btrim(name)) > 0),
  constraint projects_date_order
    check (target_end_date is null or start_date is null or target_end_date >= start_date),
  constraint projects_currency_format
    check (currency_code is null or currency_code ~ '^[A-Z]{3}$')
);

create index projects_client_id_idx on public.projects (client_id);
create index projects_portfolio_id_idx on public.projects (portfolio_id);
create index projects_project_manager_id_idx on public.projects (project_manager_id);
create index projects_lifecycle_status_idx on public.projects (lifecycle_status);

-- Project-scoped access. Memberships are managed only by trusted server-side
-- workflows; a user's PM/team-lead assignment alone does not grant access.
create table public.project_memberships (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  project_role text not null
    check (project_role in ('project_manager', 'finance', 'team_lead', 'project_viewer')),
  status text not null default 'active'
    check (status in ('active', 'revoked')),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  assigned_by uuid references auth.users(id) on delete set null,
  reason text not null,
  created_at timestamptz not null default now(),
  constraint project_membership_valid_period
    check (effective_to is null or effective_to > effective_from)
);

create unique index project_memberships_one_active_role_idx
  on public.project_memberships (project_id, user_id, project_role)
  where status = 'active';

create index project_memberships_user_project_status_idx
  on public.project_memberships (user_id, project_id, status, effective_from, effective_to);

create index project_memberships_project_status_idx
  on public.project_memberships (project_id, status);

-- Append-only audit event store. The application roles have no direct access.
-- Trusted server-side workflows insert events after verifying the actor.
create table private.security_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_schema text not null,
  entity_table text not null,
  entity_id uuid,
  project_id uuid references public.projects(id) on delete set null,
  reason text,
  before_data jsonb,
  after_data jsonb,
  correlation_id text,
  created_at timestamptz not null default now()
);

create index security_audit_events_project_created_idx
  on private.security_audit_events (project_id, created_at desc);
create index security_audit_events_actor_created_idx
  on private.security_audit_events (actor_user_id, created_at desc);

-- RLS on every table in the exposed public schema and the private audit table.
alter table public.app_role_definitions enable row level security;
alter table public.user_profiles enable row level security;
alter table public.user_global_role_assignments enable row level security;
alter table public.clients enable row level security;
alter table public.portfolios enable row level security;
alter table public.projects enable row level security;
alter table public.project_memberships enable row level security;
alter table private.security_audit_events enable row level security;

-- Application role definitions are safe to read after authentication.
create policy app_role_definitions_authenticated_read
  on public.app_role_definitions
  for select to authenticated
  using (true);

-- Users can read their own profile. Platform admins can read profiles for
-- administration. No client can create/reactivate profiles or change roles.
create policy user_profiles_read_self_or_platform_admin
  on public.user_profiles
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid())
        and ura.role_code = 'platform_admin'
        and ura.status = 'active'
        and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
  );

create policy user_profiles_update_own_active_profile
  on public.user_profiles
  for update to authenticated
  using (user_id = (select auth.uid()) and is_active = true)
  with check (user_id = (select auth.uid()) and is_active = true);

-- A user can see only their own global role assignments. Role assignments
-- cannot be created, changed or revoked through the client Data API.
create policy user_global_roles_read_self
  on public.user_global_role_assignments
  for select to authenticated
  using (user_id = (select auth.uid()));

-- Project rows are visible to active, in-period members or a current platform
-- admin. Membership RLS is self/admin only and does not query projects,
-- avoiding recursive policy evaluation.
create policy projects_read_member_or_platform_admin
  on public.projects
  for select to authenticated
  using (
    exists (
      select 1
      from public.project_memberships pm
      where pm.project_id = projects.id
        and pm.user_id = (select auth.uid())
        and pm.status = 'active'
        and pm.effective_from <= now()
        and (pm.effective_to is null or pm.effective_to > now())
    )
    or exists (
      select 1
      from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid())
        and ura.role_code = 'platform_admin'
        and ura.status = 'active'
        and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
  );

create policy project_memberships_read_self_or_platform_admin
  on public.project_memberships
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid())
        and ura.role_code = 'platform_admin'
        and ura.status = 'active'
        and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
  );

-- Client and portfolio reference rows are visible only when the user can see
-- at least one linked project, or is a current platform admin.
create policy clients_read_via_visible_project_or_admin
  on public.clients
  for select to authenticated
  using (
    exists (
      select 1 from public.projects p
      where p.client_id = clients.id
    )
    or exists (
      select 1
      from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid())
        and ura.role_code = 'platform_admin'
        and ura.status = 'active'
        and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
  );

create policy portfolios_read_via_visible_project_or_admin
  on public.portfolios
  for select to authenticated
  using (
    exists (
      select 1 from public.projects p
      where p.portfolio_id = portfolios.id
    )
    or exists (
      select 1
      from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid())
        and ura.role_code = 'platform_admin'
        and ura.status = 'active'
        and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
  );

-- Explicit least-privilege Data API grants. No anonymous grants.
revoke all on table
  public.app_role_definitions,
  public.user_profiles,
  public.user_global_role_assignments,
  public.clients,
  public.portfolios,
  public.projects,
  public.project_memberships
from public, anon, authenticated;

grant usage on schema public to authenticated, service_role;
revoke all on schema public from anon;

grant select on table
  public.app_role_definitions,
  public.user_profiles,
  public.user_global_role_assignments,
  public.clients,
  public.portfolios,
  public.projects,
  public.project_memberships
to authenticated;

-- Only non-sensitive descriptive profile fields are self-editable.
grant update (display_name, job_title)
  on public.user_profiles to authenticated;

-- Server-side service role is used only in trusted backend code, never in
-- browser clients. It manages provisioning, roles, memberships and master data.
grant all on table
  public.app_role_definitions,
  public.user_profiles,
  public.user_global_role_assignments,
  public.clients,
  public.portfolios,
  public.projects,
  public.project_memberships
to service_role;

revoke all on table private.security_audit_events from public, anon, authenticated;
grant select, insert on table private.security_audit_events to service_role;

commit;
