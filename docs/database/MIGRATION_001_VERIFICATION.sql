-- Executive PPM Platform — Migration 001 verification queries
-- Run after applying migration 001. These are read-only checks.

-- 1. Expected tables and RLS state.
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where (n.nspname = 'public' and c.relname in (
  'app_role_definitions',
  'user_profiles',
  'user_global_role_assignments',
  'clients',
  'portfolios',
  'projects',
  'project_memberships'
))
or (n.nspname = 'private' and c.relname = 'security_audit_events')
order by n.nspname, c.relname;

-- 2. Policies must exist on all eight tables.
select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where (schemaname = 'public' and tablename in (
  'app_role_definitions',
  'user_profiles',
  'user_global_role_assignments',
  'clients',
  'portfolios',
  'projects',
  'project_memberships'
))
or (schemaname = 'private' and tablename = 'security_audit_events')
order by schemaname, tablename, policyname;

-- 3. Confirm no anonymous table privileges.
select table_schema, table_name, privilege_type
from information_schema.role_table_grants
where grantee = 'anon'
  and table_schema in ('public', 'private')
order by table_schema, table_name, privilege_type;

-- 4. Confirm the intended authenticated read grants.
select table_schema, table_name, privilege_type
from information_schema.role_table_grants
where grantee = 'authenticated'
  and table_schema = 'public'
order by table_name, privilege_type;

-- 5. Confirm global role catalogue seed rows.
select code, name, is_global
from public.app_role_definitions
order by is_global desc, code;

-- 6. Confirm the project remains empty after foundation setup.
select count(*) as project_count from public.projects;
