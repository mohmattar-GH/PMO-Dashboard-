-- Executive PPM Platform
-- Migration 002: index foreign-key lookup columns identified by advisor.
-- Target: oihawkpbtgqxxliaamxs
-- RLS remains enabled; no access policy or data behavior is changed.

create index if not exists portfolios_owner_user_id_idx
  on public.portfolios (owner_user_id);

create index if not exists project_memberships_assigned_by_idx
  on public.project_memberships (assigned_by);

create index if not exists projects_created_by_idx
  on public.projects (created_by);

create index if not exists projects_team_lead_id_idx
  on public.projects (team_lead_id);

create index if not exists user_global_role_assignments_assigned_by_idx
  on public.user_global_role_assignments (assigned_by);

create index if not exists user_global_role_assignments_role_code_idx
  on public.user_global_role_assignments (role_code);
