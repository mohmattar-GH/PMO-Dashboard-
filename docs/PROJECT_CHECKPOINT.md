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
- At initial application this was the storage/governance foundation only. Cycle lifecycle, snapshot generation/finalization, scheduled processing and correction recording were added later in Migrations 010–012. KPI calculation and user-level positive JWT testing remain outstanding. Snapshot tables currently have no data.

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

### Migration 009 — reporting rule validation hardening
- Applied version: `20261114100642`; name: `migration_009_reporting_rule_validation_hardening`.
- SQL source committed at `supabase/migrations/20261114100642_migration_009_reporting_rule_validation_hardening.sql`.
- Added formula-template-specific required KPI parameter checks.
- KPI dimension references must resolve to active dimensions; weighted KPIs must belong to an active dimension.
- Parameter values are type-checked for number, integer, text, boolean, date and duration. Numeric parameters support configured minimum/maximum checks; enumerated allowed values are enforced when configured.
- Verification confirmed all four hardening checks in the database function definition; Security Advisor returned no findings.
- Positive authenticated action tests remain blocked because the project currently has no Auth users or role assignments.

### Migration 010 — weekly cycle lifecycle, snapshot generation and corrections
- Applied version: `20261114100957`; name: `migration_010_weekly_snapshot_generation_and_corrections`.
- Exact source committed at `supabase/migrations/20261114100957_migration_010_weekly_snapshot_generation_and_corrections.sql`.
- Added service-role-only SECURITY INVOKER RPCs for cycle creation, cycle closure, snapshot generation, snapshot finalization and correction recording. RPCs have empty search_path and are not executable by anon/authenticated roles.
- Cycle creation and closure require an active effective-dated platform_admin role; closure is blocked until cutoff. Snapshot correction requires platform_admin or configuration_approver and a reason.
- Snapshot generation requires a published global reporting configuration effective at the cycle cutoff, captures project records and records global/project configuration-version links.
- Finalization validates project capture counts, transitions the portfolio snapshot from building to finalized, and transitions the cycle from closed to snapshotted in one transaction.
- Correction records link a finalized replacement snapshot for the same period, as-of date and timezone; the original snapshot is not modified.

### Migration 011 — source cutoff integrity
- Applied version: `20261114101116`; name: `migration_011_snapshot_source_cutoff_integrity`.
- Source committed at `supabase/migrations/20261114101116_migration_011_snapshot_source_cutoff_integrity.sql`.
- Projects created on/before the cutoff are captured even if subsequently updated; each payload flags whether the captured project state is actually as of the cutoff. Portfolio summary reports when post-cutoff source changes are present. This avoids silently omitting projects but does not reconstruct historical project values.
- The snapshot configuration resolver was further hardened in Migration 012 to require versions to have been created and published by the cutoff.

### Migration 012 — scheduled weekly snapshot processing
- Applied version: `20261114101226`; name: `migration_012_scheduled_weekly_snapshot_processing`.
- Source committed at `supabase/migrations/20261114101226_migration_012_scheduled_weekly_snapshot_processing.sql`.
- Enabled `pg_cron` and scheduled `weekly-portfolio-snapshot-processor` every 15 minutes. It processes pre-created open cycles after their cutoff: close → build → finalize.
- Added private `reporting_snapshot_job_runs` for success/failure tracking. Each cycle attempt is isolated; failed attempts roll back the cycle changes and record the error for later retry.
- Processor is SECURITY INVOKER, empty search_path, EXECUTE granted only to PostgreSQL `postgres`; it is not a public API.
- Smoke test of the processor returned zero processed cycles (expected because no cycles exist). Cron job is active; no actual scheduled run record had appeared at verification time.
- Updated effective configuration selection to include only versions created/published by the cutoff and effective at that cutoff.

### Migration 013 — snapshot foreign-key indexes
- Applied version: `20261114101258`; name: `migration_013_snapshot_foreign_key_indexes`.
- Source committed at `supabase/migrations/20261114101258_migration_013_snapshot_foreign_key_indexes.sql`.
- Added five indexes for snapshot/job-run foreign keys identified by the performance advisor. Re-run Performance Advisor found no remaining unindexed foreign keys; 37 INFO-level unused-index notices remain because there is no representative workload.

### Weekly reporting Edge Function
- `weekly-reporting-snapshots` deployed ACTIVE at version 1 with JWT verification enabled.
- Source committed at `supabase/functions/weekly-reporting-snapshots/index.ts`.
- Exposes create_cycle, close_cycle, build_snapshot, finalize_snapshot and record_correction actions. It validates user JWTs and delegates privileged writes to the restricted database RPCs.
- Detailed implementation and limits: `docs/database/WEEKLY_REPORTING_SNAPSHOT_PIPELINE.md`.

### Migration 014 — operational project records
- Applied version: `20261114101917`; source: `supabase/migrations/20261114101917_migration_014_operational_project_records.sql`.
- Added 13 operational tables for contracts/deliverables, financial terms, milestones, activities/dependencies, invoices, cash transactions/payment allocations, risks, licenses, weekly updates and management decisions.
- Includes same-project composite foreign keys for contract/milestone/activity/invoice/payment relationships; separate baseline, approved revised, forecast and actual dates; progress bounds; risk data; payment allocations; and weekly management reporting fields.
- Enabled RLS on all operational tables. Added role-scoped project and finance read/write policies. Project managers/admins manage core records; finance roles manage financial records; assigned team leads update assigned activities.
- Executive viewers currently have read access to finance records in addition to portfolio/project reporting. This is a policy choice to review with the final data-classification requirements.

### Migration 015 — operational audit and FK indexes
- Applied version: `20261114101943`; source: `supabase/migrations/20261114101943_migration_015_operational_audit_and_fk_indexes.sql`.
- Added 30 indexes for operational foreign keys flagged by the performance advisor.
- Added private audit capture triggers to all 13 operational tables; before/after record JSON and actor/action/entity/project are recorded in `private.security_audit_events`.
- Revoked DELETE privilege from authenticated users for all operational tables.

### Migration 016 — operational RLS policy optimization
- Applied version: `20261114102007`; source: `supabase/migrations/20261114102007_migration_016_operational_policy_optimization.sql`.
- Split SELECT, INSERT and UPDATE policies to avoid overlapping permissive SELECT policies. Combined project activity update authorization for PM/admin and assigned team leads.
- Performance Advisor no longer reports unindexed foreign keys or multiple permissive policies. Remaining notices are INFO-level unused indexes because there is no representative workload.

### Migration 017 — configurable risk and invoice status rules
- Applied version: `20261114102027`; source: `supabase/migrations/20261114102027_migration_017_configurable_risk_and_invoice_status_rules.sql`.
- Removed the fixed 1–5 ceiling and generated probability×impact risk score. Probability/impact are positive integer inputs; risk score is nullable and only trusted backend/database roles can set it pending the governed calculation engine.
- Removed hard-coded invoice status CHECK list so future status mappings remain configuration-driven.
- Operational schema details and limitations: `docs/database/OPERATIONAL_PROJECT_DATA_MODEL.md`.

### Migrations 018–020 — transactional finance and contract variations
- Migration 018 applied: `20261114102719`; GitHub source: `supabase/migrations/20261114102719_migration_018_transactional_finance_and_contract_variations.sql` (initial file was created under the wrong version prefix and subsequently aligned to the applied version).
- Added `project_contract_variations` with draft → submitted → approved/rejected workflow. Project managers submit; finance roles decide with mandatory reason; actor/timestamps recorded.
- Approved variation deltas recalculate `project_financial_terms.approved_variations` within the same transaction; generated revised contract value reflects original + approved variations.
- Added `allocate_invoice_cash` and `reverse_invoice_cash_allocation` SECURITY INVOKER RPCs. Row locks, project/currency/type/status checks and outstanding-balance checks protect allocations. Reversals preserve the original allocation and audit trail.
- Added `project_invoice_balances` view with `security_invoker=true`, exposing total, applied, outstanding and settlement indicator under source-table RLS.
- Migration 019 applied: `20261114102819`; added allocation integrity trigger so direct table writes cannot bypass validation, one-way reversal controls, immutable original contract value, calculated-only approved variation aggregate and indexes for all new foreign keys. Removed duplicate allocation UPDATE policy.
- Migration 020 applied: `20261114102910`; submission timestamps are assigned by database clock rather than client-supplied values.
- Security Advisor and Health Advisor: no findings. Performance Advisor: no unindexed foreign keys or multiple permissive policies; remaining findings are INFO-level unused indexes due to no representative workload.
- Catalog verification: invoice allocation has exactly one UPDATE policy; variation RLS enabled; invoice balance view is security-invoker; all three new foreign keys have indexes; both RPCs are SECURITY INVOKER, callable by authenticated only, not anon.
- Detailed design and limitations: `docs/database/TRANSACTIONAL_FINANCE_AND_VARIATIONS.md`.

## Security and implementation limitations
- No actual end-to-end RLS/JWT authorization test has been run.
- No Auth users or role assignments have been provisioned.
- No configuration set, version, dimension, KPI or rule parameter has been seeded.
- The `reporting-config-governance` Edge Function is deployed at version 3 with JWT verification enabled. It delegates to the atomic service-role-only PostgreSQL RPC introduced in Migration 008 and hardened in Migration 009. Database validation and audit insertion are transactionally coupled; positive end-to-end tests still require real Auth users and role assignments.
- Weekly snapshot generation, finalization, correction recording and pg_cron scheduling are implemented through Migrations 010–012. KPI calculation and historical source-version reconstruction remain outstanding. Positive end-to-end role tests remain blocked by the absence of Auth users and role assignments.
- Secure document metadata, private Storage bucket and access policies are implemented in Migrations 021–022. Frontend document library and real-user upload/download tests remain outstanding.
- Timeline read-model views are implemented in Migration 023; timeline UI, custom event management, filters/zoom and exports remain outstanding.
- No application frontend exists. Backend foundations and selected Edge Functions/RPCs exist; operational CRUD workflows are not yet implemented.

## Next sequence
1. Implement the governed KPI/risk/financial calculation engine using only allowlisted calculation templates; calculate missing values as Not Reported rather than Green.
2. Add immutable operational source history so weekly snapshots can reconstruct true as-of-cutoff project values, not merely flag post-cutoff changes.
3. Provision controlled non-production Auth identities, effective-dated global roles, test projects and memberships; run positive/negative JWT/RLS tests across project, finance, document and executive roles.
4. Exercise a full test cycle: publish configuration → create/close reporting cycle → calculate metrics → build/finalize snapshot → record correction; verify scheduled processing and failure/retry.
5. Complete operational CRUD APIs and document upload/download flows, including signed URL expiry and audit-event tests.
6. Add timeline custom-event/category support, then validate event filtering, date-basis selection and drill-through against real test records.
7. Present UI direction, navigation, screen inventory and workflows to the user for review. Do not implement frontend until the user agrees; frontend framework/Lovable choice remains open.
8. Implement CEO dashboard, interactive timelines and exports only after UI approval; perform regression and security tests.
9. Reconcile migration source archive for early migrations 001–005 and maintain exact migration-to-repository parity.
10. Update this checkpoint after each verified milestone.

## Current verified state
The dedicated Supabase project now has migrations 001–023 applied. Configuration governance is transactional and deployed in Edge Function version 3. Weekly reporting cycle/snapshot RPCs and correction recording are deployed; the weekly-reporting-snapshots Edge Function is ACTIVE at version 1; pg_cron is scheduled every 15 minutes to process due cycles. The operational data model for contracts, schedule, finance, risks, licenses, weekly updates and management decisions is now deployed, with RLS and private audit triggers. The scheduler processor's direct smoke test returned zero processed cycles because no cycles exist. There are still zero Auth users, active global role assignments, projects, reporting configuration sets or reporting cycles. KPI evaluation, exact historical as-of reconstruction, positive end-to-end tests, full operational CRUD workflows, document UI, timeline UI/custom events, CEO dashboard, exports and frontend remain incomplete. CR Management is explicitly deferred to a future release. Existing Staff Time & Performance resources have not been intentionally modified.


### Migrations 021–022 — secure project document management foundation
- Migration 021 applied: `20261114110000_migration_021_secure_project_document_storage`; source committed at `supabase/migrations/20261114110000_migration_021_secure_project_document_storage.sql`.
- Added `project_documents` metadata and `project_document_versions` with immutable version identity, generated storage path, SHA-256 field, upload lifecycle (pending/uploaded/failed), and project-scoped foreign key integrity.
- Created private Supabase Storage bucket `project-documents`. Verified bucket is not public; maximum file size is 50 MiB. Allowed MIME types: PDF, Word, Excel, PowerPoint, JPEG, PNG, plain text and CSV.
- RLS enabled on both metadata tables. Storage object policies permit authenticated insert only for a matching pending version and authorized project writer; reads require an uploaded version and current classification access. No authenticated object update/delete policy is provided; uploads use unique immutable paths rather than upsert.
- Document classifications: project, management, finance and restricted. Access rules use effective-dated project memberships and trusted global role assignments. Executive viewers can read project and management-classified documents; finance documents are limited to project managers/finance members and platform/finance admins; restricted documents are limited to project managers/platform admins and the uploader only while the uploader retains active project membership.
- Document versions cannot be edited after finalization; upload completion is stamped by the database and requires the object to exist. Metadata and version changes are wired to the existing operational audit trigger.
- Added security-invoker view `project_document_current_versions` for latest uploaded version per active document.
- Migration 022 applied: `20261114110500_migration_022_document_access_hardening`; source committed at `supabase/migrations/20261114110500_migration_022_document_access_hardening.sql`. It corrected restricted-uploader access so it cannot outlive active project membership, made upload timestamps database-generated, and optimized RLS auth lookups and FK indexing.
- Verification: Supabase migration application succeeded; catalog confirms RLS enabled on both metadata tables, bucket private with configured limits/types, and the expected SELECT/INSERT/UPDATE metadata policies plus SELECT/INSERT Storage policies. Security Advisor: no findings. Health Advisor: no findings. Performance Advisor retains unused-index INFO notices because the application has no representative workload; review any remaining actionable warning before production.
- No authenticated users, projects, memberships or documents are provisioned yet. Positive/negative JWT upload/download tests, actual file upload/download, signed URL expiry, and audit-event end-to-end verification remain outstanding. Frontend document library/upload/download UI is not implemented. This is a backend foundation, not a complete user-facing document management feature.

### Scope decision — Change Request Management deferred
- CR Management remains out of the current release. Do not add CR module/screens/approval workflow or CR-specific re-baselining. Existing contract variation functionality remains distinct. Preserve immutable original baselines and revisit CR integration only in a future release.


### Migration 023 — secure timeline read models
- Applied version: `20261114104801`; name: `migration_023_timeline_read_models`.
- Source committed at `supabase/migrations/20261114104801_migration_023_timeline_read_models.sql`.
- Added `public.project_master_schedule_timeline`, a read-only `security_invoker` view projecting activity and milestone baseline, approved-revised, forecast and actual date scenarios as separate event rows, plus contract commencement/end, license renewal/expiry and management decision due dates.
- Added `public.project_payment_risk_timeline`, a read-only `security_invoker` view projecting invoice issue/due events, actual cash transactions and risk exposure intervals with severity/escalation and source metadata.
- Both views are granted SELECT to authenticated users only. They do not store duplicate timeline records; source operational tables remain authoritative and their RLS continues to govern rows.
- Verification: migration 023 appears in Supabase migration history; both views exist and execute successfully. Current row counts are zero because no projects or operational records have been provisioned. Security Advisor returned no findings. The views have not yet been tested with real JWT identities/role combinations.
- Not included yet: custom timeline events/categories, timeline UI, interactive filters/zoom, export, KPI evaluation, dashboard roll-ups, or exact historical as-of reconstruction.

### UI governance decision
- The user explicitly wants to participate in UI/UX decisions. Before frontend implementation, present the proposed visual direction, navigation, dashboard composition, screens and workflows for user review and agreement. Do not select a frontend framework or finalize significant UI/UX decisions unilaterally.
- No frontend implementation or production deployment is authorized by this checkpoint update.

### KPI calculation engine — design contract recorded (14 November 2026)
- Repository design contract committed at `docs/design/CONFIGURABLE_KPI_CALCULATION_ENGINE.md` (commit `a3ab94f51206af655051046319783dead69dc013`).
- Verified current Supabase state before design: migrations 001–023 are present in database history; reporting configuration tables and snapshot tables exist; six active formula-template families are registered (`count_v1`, `date_variance_v1`, `manual_input_v1`, `ratio_v1`, `threshold_status_v1`, `weighted_sum_v1`).
- Verified `build_weekly_portfolio_snapshot` still sets `kpi_calculation_status='not_implemented'` and inserts no KPI metric rows. This is the primary implementation gap.
- Design contract requires a finite allowlist, static source/field registry, validated operands/thresholds/weights, deterministic calculations, source lineage, exact configuration-version links, missing-data states that never default to Green, and transactional snapshot build/finalization.
- Important historical limitation: current snapshots flag post-cutoff project updates but do not reconstruct historical source values. Until immutable operational source history is implemented, calculations must flag values that cannot be proven as-of-cutoff rather than represent current values as historical truth.
- No KPI engine migration, evaluator function, Edge Function, or runtime calculation has been implemented in this design step. No schema changes were applied. No users, projects, configuration sets or cycles exist, so end-to-end tests remain unavailable.
- Next implementation step: implement the allowlisted evaluator and integrate it transactionally with snapshot building; add synthetic test fixtures and calculation/security tests; then apply reviewed migration(s), verify outputs and advisors, and commit exact SQL/source plus tests. Follow with immutable source history and full JWT/RLS tests.
