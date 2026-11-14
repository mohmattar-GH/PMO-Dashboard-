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

### Migration 006 — weekly reporting snapshot foundation
- Version: `20261114100135`; name: `migration_006_weekly_reporting_snapshots`.
- Applied successfully to the dedicated PPM Supabase project and SQL source committed at `supabase/migrations/20261114100135_migration_006_weekly_reporting_snapshots.sql`.
- Added six public tables: `reporting_cycles`, `portfolio_snapshots`, `project_snapshots`, `snapshot_metric_values`, `snapshot_config_links`, and `snapshot_corrections`.
- RLS enabled on all six tables. Authenticated users receive read-only access; portfolio-level snapshot access is limited to effective-dated platform_admin/executive_viewer roles, while project snapshots and metrics also permit active project members. Service role has backend write privileges.
- Snapshot lifecycle is append-only: portfolio snapshots can transition from building to finalized once; child project snapshots, metric values and configuration links can only be inserted while the parent is building and cannot be updated/deleted. Corrections are separate records with reason and approver.
- Reporting-cycle rows linked to a snapshot cannot be changed or deleted. Configuration-version links retain the exact rule versions used by a snapshot.
- Verification: migration history confirms version 006; catalog query confirms RLS enabled on all six tables and one scoped SELECT policy each; Supabase Security and Health advisors returned no findings.
- Important limitation: this is the storage/governance foundation only. No cycle-generation service, data extraction, KPI calculation engine, automatic snapshot finalization, scheduler, correction workflow or user-level JWT test has been implemented. The snapshot tables currently have no data.

### Migration 007 — reporting read-policy corrections
- Version: `20261114100228`; name: `migration_007_reporting_read_policy_corrections`.
- Applied successfully and SQL source committed at `supabase/migrations/20261114100228_migration_007_reporting_read_policy_corrections.sql`.
- Corrected a global configuration-set SELECT policy correlation that previously compared the version's configuration_set_id to the version row's own id rather than the parent set id.
- Tightened project-scoped snapshot configuration-lineage reads so project membership must match a project snapshot within the same portfolio snapshot.
- Verified the corrected policy definition in PostgreSQL; Security advisor returned no findings after the migration.

### Migration 008 — atomic reporting configuration governance
- Applied version: `20261114100526`; name: `migration_008_atomic_reporting_configuration_governance`.
- Exact source committed as `supabase/migrations/20261114100526_migration_008_atomic_reporting_configuration_governance.sql`. An initial filename timestamp mismatch was corrected in GitHub; the superseded incorrectly named file was deleted. The committed filename now matches Supabase migration history.
- Added private `reporting_formula_templates` registry with six initial allowlisted calculation templates; this is a controlled metadata registry, not a KPI evaluator.
- Added `public.manage_reporting_configuration`, a SECURITY INVOKER PostgreSQL RPC with an empty search_path, callable only by service_role. The Edge Function now delegates each operation to this single RPC rather than issuing separate database writes.
- Draft creation/version allocation, draft rule replacement, lifecycle transitions and audit insertion now execute transactionally. Row locks serialize version allocation and state transitions. Failed validation or audit insertion rolls back all changes.
- Validates actor role assignments and effective dates, project membership for project-scoped creation, payload limits, active dimension weights, per-dimension KPI weights, allowlisted calculation-method/template pairings, dimension references and JSON object shapes.
- The Edge Function `reporting-config-governance` is ACTIVE at version 3 with JWT verification enabled and source committed at `supabase/functions/reporting-config-governance/index.ts`.
- Verification: migration 008 is in Supabase history; PostgreSQL catalog confirms SECURITY INVOKER, empty search_path and EXECUTE granted only to service_role (not authenticated); negative actor authorization test rejected a UUID with no role assignment; Security and Health advisors returned no findings.
- Current project contains zero Auth users, zero active global role assignments and zero configuration sets. Positive end-to-end JWT/approval tests cannot yet be run. Explicit parameter value/domain validation and formula-template required-parameter enforcement remain hardening items.

## Security and implementation limitations
- No actual end-to-end RLS/JWT authorization test has been run.
- No Auth users or role assignments have been provisioned.
- No configuration set, version, dimension, KPI or rule parameter has been seeded.
- The `reporting-config-governance` Edge Function is deployed (JWT verification enabled) and supports create-draft, save-rules, submit, approve, publish and supersede actions with reason-required audit calls. Migration 005 provides the private audit RPC. However, the Edge Function currently uses multiple independent database requests per action; transactional atomicity, full validation, concurrency-safe version numbering and robust rollback are not yet complete.
- Weekly snapshot storage and database immutability controls exist after Migration 006; generation pipeline, KPI calculations, scheduler, correction workflow and end-to-end role tests remain outstanding.
- Supabase Storage buckets/policies are not implemented.
- No application frontend/backend code exists.

## Next sequence
1. Reconcile exact SQL source files for migrations 001–007 in the version-controlled migration directory; exact source files for migrations 001–004 still need to be archived/committed if not already present.
2. Complete configuration governance hardening: parameter-domain validation, template-specific required parameter checks, KPI dimension-assignment rules, and positive/negative JWT tests using provisioned users.
3. Add transactional weekly snapshot generation, exact configuration resolution, immutable finalization and correction-chain service; do not calculate official KPIs until the governed calculation engine is validated.
4. Provision test Auth identities and execute positive/negative JWT/RLS tests, including cross-project isolation and executive access.
5. Build project operational schema: contracts, activities, milestones, invoices/payments, risks, licenses, updates and document metadata.
6. Implement actual Auth test users and cross-project positive/negative RLS tests.
7. Select frontend framework only after user discussion; then implement UI, timelines, CEO dashboard and exports.
8. Update this checkpoint after every verified milestone.

## Current verified state
The dedicated Supabase project now has migrations 001–007 applied. The configuration data model and transactional governance RPC now exist, and the governance Edge Function is deployed at version 3. Full parameter-domain validation, positive end-to-end user tests, the KPI calculation engine, weekly snapshot generation pipeline, operational modules and UI remain incomplete. Existing Staff Time & Performance resources have not been intentionally modified.
