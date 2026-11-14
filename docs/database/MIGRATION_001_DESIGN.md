# Migration 001 — Identity, Access Control and Project Registry

Status: design and SQL draft only. Not applied to Supabase.
Target: `oihawkpbtgqxxliaamxs` (Executive PPM Platform) only.
Proposed migration name: `001_identity_access_project_foundation`.

## 1. Scope

This migration should establish only the minimum secure foundation:
- private schema for authorization helpers;
- application role catalogue;
- user profile linked to Supabase Auth;
- global role assignments;
- client and portfolio master records;
- project registry;
- project memberships;
- append-only security/administrative audit events;
- foundational indexes, constraints and RLS.

It deliberately does not yet create finance, schedule, risk, reporting configuration, snapshots, documents or timeline tables. Those should follow in separately reviewed migrations.

## 2. Important design choice: trusted authorization

Application roles are database records, not arbitrary values supplied by the browser. The authenticated user identity comes from `auth.uid()`. Role assignment and membership changes are performed only by trusted administrative operations.

The RLS design needs a narrow authorization lookup function to check global admin status and project membership without creating recursive RLS policies. If a SECURITY DEFINER helper is used, it must:
- live in a non-exposed `private` schema;
- be owned by a trusted database role;
- use a fixed safe `search_path` (prefer `pg_catalog`);
- fully qualify all referenced tables and functions;
- derive the caller from `auth.uid()`, never accept a caller-supplied user ID;
- have EXECUTE revoked from PUBLIC and granted only to `authenticated`;
- return only a boolean decision and expose no role/membership rows;
- be tested against cross-project and revoked-membership cases.

If this narrow helper cannot be made safe, use direct RLS subqueries with a non-recursive membership policy instead. Do not broaden privileges to make a policy work.

## 3. Proposed table definitions

### `public.app_role_definitions`
- `code text primary key`
- `name text not null`
- `description text`
- `is_global boolean not null`
- `is_system_role boolean not null default true`
- `created_at timestamptz not null default now()`

Seed controlled role codes: platform_admin, executive_viewer, configuration_steward, configuration_approver, finance_admin, project_manager, finance, team_lead, project_viewer.

### `public.user_profiles`
- `user_id uuid primary key references auth.users(id) on delete restrict`
- `display_name text`
- `job_title text`
- `is_active boolean not null default true`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

No client-side self-promotion or self-reactivation. Profile creation/update is controlled; only explicitly safe display fields may be writable by the user.

### `public.user_global_role_assignments`
- `id uuid primary key default gen_random_uuid()`
- `user_id uuid not null references auth.users(id) on delete restrict`
- `role_code text not null references public.app_role_definitions(code)`
- `status text not null check (status in ('active','revoked'))`
- `effective_from timestamptz not null default now()`
- `effective_to timestamptz`
- `assigned_by uuid references auth.users(id)`
- `reason text not null`
- `created_at timestamptz not null default now()`
- unique active assignment strategy enforced by a partial unique index on (user_id, role_code) where status='active'.

### `public.clients`
- `id uuid primary key default gen_random_uuid()`
- `client_code text not null unique`
- `name text not null`
- `status text not null check (status in ('active','inactive')) default 'active'`
- `created_at`, `updated_at` timestamptz not null default now()

### `public.portfolios`
- `id uuid primary key default gen_random_uuid()`
- `portfolio_code text not null unique`
- `name text not null`
- `owner_user_id uuid references auth.users(id)`
- `status text not null check (status in ('active','archived')) default 'active'`
- `created_at`, `updated_at` timestamptz not null default now()

### `public.projects`
- `id uuid primary key default gen_random_uuid()`
- `project_code text not null unique`
- `name text not null`
- `client_id uuid references public.clients(id)`
- `portfolio_id uuid references public.portfolios(id)`
- `project_manager_id uuid references auth.users(id)`
- `team_lead_id uuid references auth.users(id)`
- `lifecycle_status text not null check (lifecycle_status in ('draft','active','on_hold','completed','cancelled','archived')) default 'draft'`
- `start_date date`
- `target_end_date date`
- `timezone text not null default 'UTC'`
- `currency_code char(3)`
- `created_by uuid references auth.users(id)`
- `created_at`, `updated_at` timestamptz not null default now()
- Check target_end_date is null or start_date is null or target_end_date >= start_date.

### `public.project_memberships`
- `id uuid primary key default gen_random_uuid()`
- `project_id uuid not null references public.projects(id) on delete restrict`
- `user_id uuid not null references auth.users(id) on delete restrict`
- `project_role text not null check (project_role in ('project_manager','finance','team_lead','project_viewer'))`
- `status text not null check (status in ('active','revoked')) default 'active'`
- `effective_from timestamptz not null default now()`
- `effective_to timestamptz`
- `assigned_by uuid references auth.users(id)`
- `reason text not null`
- `created_at timestamptz not null default now()`
- unique active membership strategy enforced by a partial unique index on (project_id,user_id,project_role) where status='active'.

### `private.security_audit_events`
- `id uuid primary key default gen_random_uuid()`
- `actor_user_id uuid references auth.users(id)`
- `action text not null`
- `entity_schema text not null`
- `entity_table text not null`
- `entity_id uuid`
- `project_id uuid references public.projects(id)`
- `reason text`
- `before_data jsonb`
- `after_data jsonb`
- `created_at timestamptz not null default now()`
- Append-only for application roles; sensitive values must be redacted before writing.

## 4. RLS and grants plan

- Enable RLS on all `public` business tables in this migration.
- No privileges for `anon`.
- Grant only the required table privileges to `authenticated`; RLS then narrows rows.
- Profile SELECT is self-only, with platform-admin access through a trusted helper.
- Global role assignments are not directly writable by application clients; changes go through a privileged workflow that verifies the actor and writes audit events.
- Membership SELECT is limited to the current user and authorized project administrators; membership writes are privileged and audited.
- Project SELECT is allowed to active project members and platform admins; project INSERT/UPDATE requires platform admin or explicitly delegated project-management permission.
- Client/portfolio reads are limited to users with access to at least one related project or authorized admins; create/update is admin-only in the first migration.
- Audit schema is not exposed through PostgREST and has no direct authenticated write grant.
- Do not create broad default grants on future tables. Each subsequent migration adds explicit grants and policies.

## 5. SQL implementation outline

The actual SQL must be generated and reviewed from this design before applying. The outline below is intentionally not a deployable migration yet:

```sql
create schema if not exists private;

create table public.app_role_definitions (...);
create table public.user_profiles (...);
create table public.user_global_role_assignments (...);
create table public.clients (...);
create table public.portfolios (...);
create table public.projects (...);
create table public.project_memberships (...);
create table private.security_audit_events (...);

create index ...;

alter table public.app_role_definitions enable row level security;
alter table public.user_profiles enable row level security;
alter table public.user_global_role_assignments enable row level security;
alter table public.clients enable row level security;
alter table public.portfolios enable row level security;
alter table public.projects enable row level security;
alter table public.project_memberships enable row level security;
alter table private.security_audit_events enable row level security;

-- Explicit grants and per-action policies follow only after helper functions
-- and policy recursion have been reviewed.
```

## 6. Migration acceptance criteria

- Migration applies cleanly to the dedicated empty PPM database.
- All expected tables, constraints, indexes and schema privileges are verified.
- Every exposed table has RLS enabled and explicit grants/policies.
- No anonymous role can read or mutate project data.
- A user with no membership sees no project rows.
- Project A membership cannot expose Project B.
- Revoked membership stops granting access.
- Role assignment cannot be self-created or self-escalated.
- Audit events cannot be modified/deleted by application roles.
- No service-role key or secret is used by a client.
- Supabase security advisor is reviewed after migration.

## 7. Not included in Migration 001

Reporting configuration, calculation templates, KPI definitions, project activities, milestones, financial records, risk registers, snapshots, storage buckets and timeline projections are intentionally deferred. Migration 002 should establish configuration versioning, approval, audit and scope precedence before KPI calculation or dashboard work begins.
