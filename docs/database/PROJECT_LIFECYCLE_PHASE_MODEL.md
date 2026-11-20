# Configurable Project Lifecycle & Phase Model

Updated: 21 November 2026

## Purpose

Project phase is a governed lifecycle dimension. It is deliberately separate from project lifecycle status, calculated project health, PM-reported health, and milestone progress. No default phase names or universal lifecycle template are seeded.

## Database objects

- `project_lifecycle_templates`: global templates (`project_id IS NULL`) or project-scoped templates; configurable code, name, description and active/archive state.
- `project_lifecycle_template_versions`: numbered draft/published/retired versions with effective dates, author, publisher and mandatory change reason.
- `project_lifecycle_phases`: configurable phase code, display name, description, order and active state within a specific version.
- `project_lifecycle_transition_rules`: explicitly allowed from/to transitions; starting phases use a NULL from-phase; each transition can require a documented reason.
- `project_lifecycle_assignments`: one active lifecycle assignment per project, with version lineage and current phase pointer.
- `project_phase_history`: appendable phase periods with entry/exit timestamps, planned start, forecast completion, actual completion, progress percentage, actor and reason.
- `project_current_phase`: security-invoker read view for current phase and phase dates/progress.

## Governance and security

- Only an active Platform Administrator can create/edit templates, versions, phase definitions and transition rules.
- Published and retired versions are immutable. Child phase/rule records can only be changed while their version is draft.
- Publishing requires at least one active phase and at least one configured starting-phase rule.
- Only Platform Administrators can assign a published lifecycle version to a project.
- Only an active Project Manager assigned to the project or a Platform Administrator can transition its phase or update the current phase dates/progress.
- Transitions must exist in the selected published version; inactive targets are rejected. Reasons are enforced per transition rule.
- RLS is enabled on all six tables. API grants are explicit; no service-role credential is used by the browser.
- Assignment and phase-history changes are written to the private security audit event stream.
- Global template scope is stored separately from the consuming project ID so a global lifecycle can be assigned to any project without weakening project-scoped foreign keys.

## RPC operations

- `assign_project_lifecycle`: administrator-only assignment of a published, effective template version and an allowed initial phase.
- `transition_project_phase`: PM/admin operation. A non-null target phase performs a configured transition; a null target updates the current phase dates/progress.

Both functions are SECURITY DEFINER because the browser is not granted direct write access to assignment/history tables. They use an empty search path, explicitly validate `auth.uid()`, active application profile and role/membership, and are executable only by authenticated users (not anon/PUBLIC). Supabase Security Advisor reports the expected authenticated SECURITY DEFINER warning for these two RPC endpoints; this is intentional and must remain subject to code review and role-based JWT tests.

## Verification and limitations

- Migrations 057 and 058 are applied to Supabase project `oihawkpbtgqxxliaamxs`.
- RLS enabled and policies present on all six lifecycle tables.
- Transactional fixture test successfully created a global draft template, two phases, and initial/forward transition rules, then rolled back all fixture data.
- Unauthenticated calls to both RPC functions were rejected with `Authentication required`.
- No projects or Auth users currently exist, so positive administrator assignment and Project Manager transition tests cannot yet be performed with real JWTs.
- No template or phase labels are seeded. The dashboard should continue to show Not configured / Not Reported until an administrator creates and publishes a lifecycle, assigns it to a project, and sets its initial phase.
- The existing project timeline read models have not yet been extended with phase history; that is a subsequent integration step.


## Migration source archive status

- Migration 058 source is committed at `supabase/migrations/20261120225145_migration_058_global_lifecycle_assignment_scope_fix.sql`.
- The matching migration 057 SQL source still needs to be archived. Do not claim clean-environment migration replay is verified until both files are reconciled and a clean replay succeeds.
