# Project Checkpoint — 14 November 2026 (updated)

## Confirmed infrastructure
- GitHub repository: `mohmattar-GH/PMO-Dashboard-`, default branch `main`.
- Dedicated Supabase project: `Executive PPM Platform`, ref `oihawkpbtgqxxliaamxs`, organization `My Own`, region `eu-central-1`, PostgreSQL 17.
- Existing Staff Time & Performance repository `mohmattar-GH/project-draft` and Supabase project `nwxwszwcdnczaurhjqke` are separate and must not be modified.
- Frontend framework and Lovable decision intentionally remains open until the user discusses it.
- User handles publishing; do not deploy production without explicit approval.

## Product non-negotiables
- Standalone enterprise PPM platform with operational project management and CEO weekly portfolio reporting.
- All reporting dimensions, KPIs, formulas/calculation methods, weights, thresholds, status mappings, date/calendar logic, risk and financial rules, progress methods and reporting cadence must be configurable, not hardcoded.
- Global defaults, project overrides and governed versioning/effective dates/approvals/audit are required.
- Weekly snapshots must retain the exact reporting configuration version and source values used; historical reports must not silently recalculate.
- Original baseline, approved revised baseline, forecast and actual dates remain distinct.
- Missing data is Not Reported/Insufficient Data, never Green.
- Calculated health and PM-reported/approved health remain separate; overrides require reason and audit.
- Operational records are source of truth; timelines and dashboards must not duplicate those records.
- No arbitrary SQL or untrusted user-code execution for KPI formulas. Use validated, governed calculation templates.

## GitHub documentation baseline
Existing project charter, PRD, architecture, data model, database design, security model, permission matrix, migration designs and checkpoint documents are committed. Key files:
- `README.md`
- `docs/requirements/PRD.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATABASE_SCHEMA_DESIGN.md`
- `docs/architecture/SECURITY_MODEL.md`
- `docs/security/PERMISSION_MATRIX.md`
- `docs/database/MIGRATION_001_DESIGN.md`
- `docs/PROJECT_CHECKPOINT.md`

## Supabase migrations applied and verified

### Migration 001 — identity, access control and project registry foundation
- Version: `20261114093442`
- Name: `migration_001_identity_access_project_foundation`
- Public tables: `app_role_definitions`, `user_profiles`, `user_global_role_assignments`, `clients`, `portfolios`, `projects`, `project_memberships`.
- Private table: `private.security_audit_events`.
- Nine application role definitions seeded. No real user profiles, projects or memberships provisioned.
- RLS enabled on all eight tables. Authenticated client grants are read-focused; profile updates limited to display_name/job_title. Authorization does not use user-editable user_metadata.

### Migration 002 — foreign-key indexes
- Version: `20261114093557`
- Name: `migration_002_foreign_key_indexes`
- Added six foreign-key lookup indexes to the identity/project foundation.

### Migration 003 — reporting rules and configuration center
- Applied successfully to the dedicated project.
- Creates five public tables: `reporting_configuration_sets`, `reporting_configuration_versions`, `reporting_dimensions`, `kpi_definitions`, `reporting_rule_parameters`.
- Creates private table `private.reporting_configuration_audit`.
- Supports global and project-scoped configuration sets, numbered versions, lifecycle states (draft/submitted/approved/published/rejected/superseded), effective periods, configurable dimensions/KPIs/formula templates/source mappings/parameters, and JSONB validation metadata.
- RLS enabled on all six tables. Authenticated users have SELECT only, controlled by published-global/project-membership/configuration-role policies. Writes are service-role/backend only; never expose service-role credentials in a frontend.
- Published versions and their child rule rows are protected by database triggers from mutation; a published version may only transition to superseded without changing other header fields.
- Formula templates are metadata only at this stage: no formula evaluator or arbitrary SQL execution has been implemented.
- Audit table exists but automatic audit-event capture and governed approval/publish service workflows are NOT yet implemented. Do not claim end-to-end configuration governance complete.

### Migration 004 — configuration FK indexes and private audit policies
- Applied successfully.
- Added seven FK indexes for configuration/audit relationships.
- Added explicit deny policies for client roles on private audit tables. Private audit access remains service-role/backend only.

### Current advisor results
- Security advisor: no findings after Migration 004.
- Health advisor: no findings.
- Performance advisor: INFO-level unused-index findings remain. There is no realistic application workload yet, so do not remove these indexes solely on current advisor output.
- Structural verification confirmed migration operations succeeded. Actual JWT-based positive/negative authorization tests with separate Auth users and projects remain outstanding.
- Migration history must be rechecked before future schema changes. Applied migrations are not a substitute for committing matching SQL source files into the repository; reconcile the migration source/archive workflow before handing the project to another developer.

## Security and implementation limitations
- No actual end-to-end RLS/JWT authorization test has been run.
- No Auth users or role assignments have been provisioned.
- No configuration set, version, dimension, KPI or rule parameter has been seeded.
- No automatic audit triggers/service workflow, approval workflow, configuration validation engine or KPI evaluator exists yet.
- No weekly snapshot table or immutable snapshot pipeline exists yet.
- Supabase Storage buckets/policies are not implemented.
- No application frontend/backend code exists.

## Next sequence
1. Commit and reconcile exact SQL source files for applied migrations 001–004 into a proper version-controlled migration directory.
2. Implement backend-controlled configuration authoring, validation, submit/approve/publish workflow and append-only audit capture.
3. Add dimension/KPI weight-total validation and formula-template allowlisting; prohibit arbitrary SQL evaluation.
4. Add snapshot tables and immutable weekly reporting snapshots referencing exact configuration versions.
5. Build project operational schema: contracts, activities, milestones, invoices/payments, risks, licenses, updates and document metadata.
6. Implement actual Auth test users and cross-project positive/negative RLS tests.
7. Select frontend framework only after user discussion; then implement UI, timelines, CEO dashboard and exports.
8. Update this checkpoint after every verified milestone.

## Current verified state
The dedicated Supabase project now has migrations 001–004 applied. The configuration data model and access controls exist at database level, but the end-to-end configuration workflow, automatic audit capture, formula engine, snapshots, operational modules, UI and user-level security tests remain incomplete. Existing Staff Time & Performance resources have not been intentionally modified.
