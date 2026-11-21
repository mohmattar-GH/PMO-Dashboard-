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

### KPI evaluator primitive — migrations 024–026 (14 November 2026)
- Migration 024 applied: `20261114150452_migration_024_allowlisted_kpi_evaluator`.
- Migrations 025 and 026 applied as corrective migrations: `20261114150511_migration_025_kpi_threshold_boundary_fix` and `20261114150523_migration_026_kpi_missing_input_status_fix`.
- Added private immutable PostgreSQL function `private.evaluate_kpi_template_v1(text,jsonb,jsonb)`. It supports the six registered template families: count, calendar-day date variance, manual input, ratio, threshold-to-status, and weighted sum.
- The evaluator accepts pre-resolved values only; it does not access operational tables, construct dynamic SQL, or accept executable expressions/table/column names. The source resolver is not yet implemented.
- Missing required input returns `not_reported`; zero ratio denominator returns `insufficient_data`. Thresholds must be strictly ordered with a final unbounded band. Weighted inputs must have numeric weights in [0,1] summing to 1.
- EXECUTE granted only to service_role; privilege checks verified service_role=true, authenticated=false, anon=false.
- Synthetic SQL assertions passed for all six templates, threshold band selection and overflow, weighted progress example (55), zero denominator and missing values.
- Security Advisor: no findings. Health Advisor: no findings. Performance Advisor: 91 INFO-level unused-index notices because there is no representative workload; no indexes removed.
- GitHub source and artifacts committed:
  - `supabase/migrations/20261114150452_migration_024_allowlisted_kpi_evaluator.sql`
  - `supabase/migrations/20261114150511_migration_025_kpi_threshold_boundary_fix.sql`
  - `supabase/migrations/20261114150523_migration_026_kpi_missing_input_status_fix.sql`
  - `supabase/tests/kpi_template_evaluator.sql`
  - `docs/database/KPI_CALCULATION_ENGINE.md`
- **Scope limitation:** this is an isolated calculation primitive, not a complete KPI engine. `build_weekly_portfolio_snapshot` remains `not_implemented` for KPI calculation and inserts no metric rows. Static source adapters, configuration-driven resolution, metric lineage, dimension/project/portfolio aggregation, health logic and transactional snapshot integration remain outstanding. Date variance supports calendar days only. True historical as-of calculations remain blocked by missing immutable operational source history. No real users/projects/configurations exist for end-to-end tests.

### Migration 027 — align evaluator contract with configuration templates
- Applied migration `20261114150610_migration_027_align_evaluator_with_config_schema`.
- Corrected the evaluator contract to use the same required parameter names already enforced by `private.reporting_formula_templates`: count source, date input keys/day basis, manual input key, ratio operand keys, threshold input key/bands, and weighted input keys/weights.
- Count source values are checked against a fixed allowlist; no dynamic table/column execution is introduced. Other templates consume pre-resolved JSON input keys. Source mapping resolution remains a separate pending backend component.
- Re-ran synthetic assertions against all six configuration-compatible parameter shapes, including weighted example 55, threshold selection, missing count and zero denominator; assertions passed.
- GitHub migration source committed at `supabase/migrations/20261114150610_migration_027_align_evaluator_with_config_schema.sql`; test file and KPI engine documentation updated.
- Evaluator remains a primitive only. Weekly snapshot generation still does not invoke it or populate `snapshot_metric_values`. Static source adapters, metric lineage, aggregation, health calculation and transactional snapshot integration remain pending.

### KPI source resolution and snapshot integration — migrations 028–032 (14 November 2026)
- Applied Supabase migrations:
  - `20261114161625 migration_028_static_kpi_source_adapters`
  - `20261114161652 migration_029_snapshot_kpi_source_resolution_and_capture`
  - `20261114161804 migration_030_kpi_source_and_portfolio_rollup_hardening`
  - `20261114161818 migration_031_snapshot_metric_configuration_index`
  - `20261114161831 migration_032_payment_allocation_cutoff_reconstruction`
- Implemented private static source field allowlists and source row adapters for projects, activities, milestones, invoices, cash transactions, payment allocations, risks, licenses, weekly updates, management decisions, contract deliverables, contracts and financial terms.
- Supported mapping shape is `source_mapping.inputs.<input_key> = { source, field, aggregate }`. Supported aggregates are count, sum, avg, min, max and value (value is returned only for exactly one source row). No dynamic SQL/table/column identifiers or arbitrary expressions.
- Count source allowlist now includes contracts and financial terms as well as payment allocations.
- Historical cutoff guard: records created after cutoff are excluded. If a source record created on/before cutoff has a later `updated_at`, affected KPI is marked not reported / not reconstructable rather than using current state as historical truth. Cash transactions are treated as immutable; payment allocations are reconstructed by created/reversed timestamps.
- Resolver limits each source input to 5,000 rows and retains up to 100 source record IDs in lineage.
- Added metric metadata: `configuration_version_id`, `formula_template_code`, `source_cutoff`. Added the FK index for `configuration_version_id`.
- Snapshot integration: an `AFTER INSERT` trigger on `project_snapshots` runs KPI resolution/evaluation and inserts metric rows in the same transaction as snapshot building. Calculation errors roll back the build. Project-level configuration definitions override global definitions by matching KPI code; ambiguous duplicate definitions within same scope are rejected.
- Project snapshot payload records KPI counts/status, per-dimension weighted values/statuses and explicitly leaves overall calculated health as Not Reported until configurable health aggregation is implemented. Portfolio summary rolls up KPI coverage/status.
- Dimension weighted values are produced only when all KPI weights are configured, sum to 1, and all numeric inputs exist; otherwise status is `weights_not_configured` or `insufficient_data`.
- Payment allocations are now a supported source; their historical reversal state is derived from timestamps. Migration 032 corrected the cutoff guard so a known reversal timestamp is used to reconstruct state at cutoff rather than falsely marking it unavailable.
- Verification: synthetic SQL assertions passed for resolver behavior on an empty project, missing inputs, payment allocation field allowlist, count source allowlist, weighted progress example (55) and threshold status. Function privilege checks: service_role=true, authenticated=false, anon=false. Trigger exists; snapshot metric RLS is enabled.
- Advisors after migration 031/032: Security no findings; Health no findings; no unindexed-FK finding; remaining Performance notices are INFO-level unused indexes because there is no representative workload.
- GitHub commits for migrations 030–032 and updated KPI engine documentation are committed. **Source reconciliation outstanding:** exact SQL source files for migrations 028 and 029 have not yet been committed. Do not treat repository migration history as fully replayable until these two files are reconstructed and checked.
- **End-to-end limitations:** no Auth users, projects, published configs or weekly cycles exist in this dedicated database, so a full snapshot build/finalize and real JWT/RLS tests were not possible. No overall project health aggregation or PM override workflow. Immutable operational source history is still required for true as-of historical reconstruction.

### Current next steps
1. Reconstruct and commit exact migration SQL sources for 028 and 029; validate a clean migration replay/source archive.
2. Provision controlled test identities and synthetic project/configuration data, then run full snapshot build/finalize and role-specific JWT/RLS tests.
3. Implement immutable operational source history.
4. Implement configurable dimension-to-project-health aggregation, status thresholds, critical overrides and reasoned PM override handling.
5. Continue with KPI coverage/portfolio metrics, then operational CRUD and UI only after the user's UI/UX proposal review.

CR Management remains explicitly deferred to a future release. Do not build its module/workflow/UI in this release.

### Migration source reconciliation and full synthetic snapshot test — migrations 028–039 (14 November 2026)
- Reconstructed and committed migration source files 028 and 029 from the live applied database definitions and schema. They are source reconstructions, not recovery of the original local SQL files; clean replay remains to be independently validated.
- Corrected migration 032 filename in GitHub to match applied Supabase version `20261114161839`.
- Applied migration 033 so weekly snapshot build/finalize RPC responses expose actual KPI status instead of stale `not_implemented`.
- Applied migrations 034–039 to resolve the append-only snapshot guard conflict with the KPI snapshot trigger:
  - Service-role build workflow may update only explicitly allowed project KPI payload keys during calculation.
  - Service-role build workflow may update only approved source-capture/KPI summary keys on a portfolio snapshot while it is building.
  - Project snapshot fields outside the KPI payload allowlist remain immutable.
  - Snapshot metric rows remain immutable.
  - Finalized snapshots remain immutable except for the controlled building-to-finalized transition.
  - Migration 037 is a temporary diagnostic revision; migration 038 supersedes it with the final allowlisted payload guard. Both are retained in repository migration history for replay.
- **Full synthetic database snapshot test passed:** created a temporary Auth identity, platform-admin role assignment, synthetic project/activity, published global config, dimension, KPI and closed reporting cycle inside one transaction; invoked actual weekly build and finalize RPCs; asserted KPI metric = 1/status calculated, dimension = calculated, and finalization = finalized/status calculated.
- Test transaction was rolled back. Follow-up verification confirmed zero persisted synthetic projects, cycles, Auth users or KPI metric rows.
- This is a SQL/database integration test under a simulated service-role database session, not a real Edge Function/JWT E2E test.
- Supabase advisors after migrations 033–039: Security no findings; Health no findings; Performance has 87 INFO-level unused-index notices. No indexes were removed.
- GitHub now contains migrations 028–039 and updated `docs/database/KPI_CALCULATION_ENGINE.md`.

### Updated next steps
1. Validate clean migration replay from the committed repository in an isolated database/branch when an approved/cost-free environment is available.
2. Run real Edge Function/JWT and role-specific RLS tests using controlled Auth identities.
3. Implement immutable operational source history for true historical as-of reporting.
4. Implement configurable dimension-to-project-health aggregation, thresholds, critical overrides and reasoned PM override handling.
5. Continue portfolio KPI rollups and data completeness, then operational CRUD.
6. Before frontend work, present the UI direction/navigation/screens/workflows for user review and approval.

CR Management remains explicitly deferred to a future release. Existing Staff Time & Performance resources remain untouched.

- Migration 040 handles the empty-portfolio edge case: build/finalize status is `not_reported` when no projects exist. A transaction-scoped synthetic empty-portfolio snapshot build/finalize test passed and was rolled back.

### Immutable operational source history — migrations 041–042 (14 November 2026)
- Applied `20261114163106 migration_041_immutable_operational_source_history` and `20261114163134 migration_042_operational_history_service_read_policy`.
- Added private append-only history and coverage tables. Triggers cover 14 tables: projects, activities, milestones, invoices, cash transactions, payment allocations, risks, licenses, weekly updates, management decisions, contract deliverables, contracts, financial terms and contract variations.
- History stores baseline/insert/update/delete row images with source, project, record, event timestamp, transaction ID and actor ID where available.
- KPI source adapters now read the latest historical row image at or before the reporting cutoff; deleted records are excluded after their deletion event. A cutoff before source coverage is explicitly not reconstructable.
- History coverage began at `2026-11-14 16:31:06.635565+00`. All 14 source tables were empty at rollout; backfilled row count = 0.
- Private history tables have RLS enabled and service-role-only read policies. The capture trigger is private SECURITY DEFINER with a fixed empty search path and no direct execute grants.
- Synthetic history tests passed for insert/update/delete as-of behavior and the pre-coverage guard. A full history-backed weekly snapshot build/finalize test also passed with activity count KPI = 1/status calculated.
- Test transactions were rolled back. Verification found zero persisted test users, projects, cycles or history rows.
- Advisors after migration 042: Security no findings; Health no findings; Performance 85 INFO-level unused-index notices.
- **Known limitation:** event time is captured by the trigger, not transaction commit time. A transaction that straddles a reporting cutoff can require stronger commit-time ordering before the history model can be called audit-grade.

### Next priorities
1. Configurable dimension-to-project-health aggregation, thresholds, critical overrides and reasoned PM override handling.
2. Real Edge Function/JWT role-specific RLS tests.
3. Clean migration replay validation in an isolated database/branch.
4. KPI portfolio completeness/rollups and then operational CRUD.
5. UI/UX proposal review before frontend implementation.

### Configurable project and portfolio health — migrations 043–047 (15 November 2026)
- Applied migrations 043–047 to `Executive PPM Platform` (`oihawkpbtgqxxliaamxs`).
- Added PM-reported health reason (8–1000 characters required for a reported status) to weekly updates. PM-reported status is stored separately from calculated health.
- Added a private service-role-only configurable project health calculation using snapshot-linked configuration: score range, Green/Amber/Red thresholds, dimension weights, KPI weights and critical-dimension Red overrides.
- Project-level health parameters fall back to the global configuration where omitted.
- Incomplete or missing dimensions/KPIs/weights produce Not Reported rather than Green.
- KPI snapshot calculation writes calculated health, score, reason, configuration version and latest PM-reported health/reason into the immutable snapshot through the existing trusted build-time path.
- Added portfolio rollup with health status counts and Not Reported-safe portfolio status.
- Verified migrations 043–047 are applied; KPI calculator calls project health and portfolio rollup; snapshot guard permits only the required build-time health fields; authenticated and anon roles do not have EXECUTE on the private health helper/rollup.
- Security Advisor: no findings. Health Advisor: no findings. Performance Advisor: 83 INFO unused-index notices; no indexes removed.
- Current PPM project has zero users, projects and configuration sets. Populated end-to-end snapshot and real JWT/RLS tests remain outstanding; health engine is not production-validated.
- PM reported health is separate from calculated health. A formal PM override workflow with actor/time/reason audit remains outstanding; no PM report can silently overwrite calculated health.

### Next priorities
1. Seed the reviewed global configuration through the governed workflow and test populated end-to-end snapshots.
2. Exercise Green/Amber/Red, missing-data, critical override, project-specific config fallback, PM reported status and portfolio rollup cases.
3. Run actual role JWT/RLS tests.
4. Finish formal PM override audit workflow, then proceed with the agreed UI/UX proposal for user review before frontend implementation.


## Health-engine audit continuation — 15 November 2026

### Migration 048 — portfolio health rollup completeness
- Applied migration version `20261115061519`, name `migration_048_finalize_health_rollup_completeness`.
- Snapshot build now explicitly refreshes the portfolio health rollup after all project snapshot insert/calculation triggers have completed.
- Snapshot finalization now rejects a snapshot if the portfolio health summary keys are absent or if any project snapshot lacks calculated-health/KPI calculation fields.
- This closes the empty-project-trigger gap: an empty portfolio receives an explicit Not Reported rollup rather than a missing health summary.
- SQL source committed at `supabase/migrations/20261115061519_migration_048_finalize_health_rollup_completeness.sql`.
- Verification: migration 048 appears in Supabase migration history; live function-definition checks confirm the build-time rollup call and finalization guard are present. Security Advisor and Health Advisor returned no findings.
- No user/project/configuration data was created or modified; the project remains empty.

### Health/KPI audit findings — open validation items
- The health calculation uses per-version KPI definitions joined to the effective dimension version. Project-scoped dimensions can override global dimensions by dimension code. Confirm that the configuration authoring workflow requires project-scoped KPI definitions to be complete for every overridden dimension; otherwise a project override can intentionally/accidentally result in insufficient data.
- Threshold evaluation and critical-dimension override logic have been inspected statically but not exercised against populated fixtures. Specifically test score boundary inclusivity, the configured Red boundary, threshold ordering and critical-dimension behavior.
- Portfolio health status is intentionally Not Reported if any project is Not Reported; validate whether this conservative portfolio policy is the desired management rule before seeding production defaults.
- Snapshot build/finalize functions remain SECURITY INVOKER, fixed empty search_path, service_role-only EXECUTE. The private health helper and portfolio rollup are not executable by anon/authenticated. Security and Health Advisors currently return no findings.
- A transaction-rolled-back populated test with all health cases and real Auth/JWT/RLS tests is still outstanding. Do not mark this engine production-validated.


## Health/KPI audit continuation — 15 November 2026 (migration 049)

### Critical-dimension threshold defect fixed
- Static inspection found that critical-dimension override logic searched for a numeric upper bound on the Red threshold. The required final Red band uses `upper_bound: null`, so the lookup returned NULL and the fallback cutoff (`score_min - 1`) prevented a critical dimension from triggering Red.
- Applied Supabase migration `20261115061840 migration_049_critical_dimension_threshold_classification`.
- The revised function now classifies each configured critical dimension against the same ordered threshold bands used for overall health; a critical dimension classified Red forces overall calculated health to Red.
- Migration source committed at `supabase/migrations/20261115091700_migration_049_critical_dimension_threshold_classification.sql` (GitHub commit `5b453a7b2f84fa746787178be88c1a63a03c9128`).
- Verified the deployed function contains the revised loop; the helper remains SECURITY INVOKER with empty search_path and EXECUTE restricted to service_role (anon/authenticated false).
- Threshold boundary query using illustrative bands Green <=60, Amber <=80, Red >80 returned: 55/60 Green; 61/80 Amber; 81/100 Red. This tests the band classification expression, not a populated end-to-end project snapshot.
- Security Advisor: no findings. Health Advisor: no findings. Performance Advisor: 83 INFO unused-index notices; no indexes removed.

### Remaining validation — do not mark production-ready
1. Run a populated, transaction-rolled-back end-to-end snapshot test covering overall health, critical dimension Red override, missing data, global/project parameter fallback and PM-reported status separation.
2. Confirm project-scoped configuration override semantics when a project replaces a dimension but omits one or more KPIs; decide whether this should inherit global KPIs or produce insufficient data, then enforce that rule in validation.
3. Validate portfolio rollup policy: currently any project Not Reported makes the portfolio overall Not Reported, even if other projects are Red/Amber. Confirm this conservative rule against management requirements.
4. Execute actual Auth/JWT/RLS tests for platform admin, PM, finance, team lead and executive viewer.
5. Verify snapshot build/finalization functions, including migration 048 guards, against real fixture rows and empty portfolios.
6. Finish formal PM override workflow with actor/time/reason audit; current PM-reported status remains separate from calculated health.
7. Reconcile historical source capture coverage and cutoff/transaction ordering before claiming audit-grade historical reconstruction.


## Health engine validation — configuration inheritance finding (15 November 2026)

### Additional defect identified; correction not yet applied
- Code review of `private.calculate_project_health_v1` found that effective dimensions are selected by dimension code with project configuration preferred over global configuration.
- The subsequent dimension KPI aggregation joins `kpi_definitions` only to the selected dimension's `configuration_version_id`. If a project configuration overrides a dimension but does not redefine every KPI for that dimension, global KPI definitions selected by `calculate_project_snapshot_kpis_v1` may not be included in the health dimension score.
- This can cause an otherwise valid project dimension to be marked insufficient-data/not-reported. It is an implementation/configuration inheritance defect, not merely a missing test.
- No schema change was applied for this finding. Before fixing, define deterministic inheritance semantics for dimension-level overrides and KPI-level overrides, including how project-specific KPI definitions map to the effective dimension, and ensure the KPI result set and health aggregation use the same effective configuration resolution.
- Current database has zero projects, zero auth users and zero configuration sets. Therefore populated end-to-end and real JWT/RLS tests remain blocked until fixtures and test identities are provisioned.
- Next: implement and test a single effective-configuration resolution model shared by KPI selection and health aggregation; cover global-only, project-dimension-only, project-KPI-only, and combined overrides. Then run rolled-back integration fixtures and role/JWT tests.


## Health configuration inheritance correction — migration 050 (15 November 2026)
- Applied Supabase migration version `20261115062820`, name `migration_050_consistent_effective_kpi_inheritance_for_health`.
- Reworked the health aggregation CTE to resolve active KPI definitions across all configuration versions linked to the snapshot, selecting the project-scoped KPI by KPI code when present and otherwise inheriting the global KPI. Effective dimensions are still resolved by dimension code with project dimensions taking precedence.
- The health dimension calculation now joins snapshot metric rows using the selected KPI's configuration version and KPI code, aligning it with the effective KPI selection logic in the KPI snapshot calculator.
- This corrects the specific defect where a project dimension override could exclude inherited global KPIs from health scoring.
- GitHub migration source: `supabase/migrations/20261115062820_migration_050_consistent_effective_kpi_inheritance_for_health.sql`; commit `4c1689b7530e4690a026d31c6ea3bcf79be4de41`.
- Supabase Security and Health Advisors returned no findings after migration 050. Performance Advisor returned 83 INFO unused-index notices; no indexes removed.
- The live function definition was inspected and contains the new `effective_kpis` CTE. However, no populated project/configuration fixture exists, so the four inheritance combinations and full snapshot path have not yet been demonstrated end-to-end. Migration 050 is deployed but not production-validated.
- Next tests: global-only; project dimension override with inherited global KPIs; project KPI override; combined project dimension and KPI overrides; then transaction-rolled-back full snapshot build/finalize and role/JWT tests.


## KPI/health engine validation pass — 15 November 2026

### Environment and security checks
- Confirmed Supabase migration history contains all migrations through 20261115062820 migration_050_consistent_effective_kpi_inheritance_for_health.
- Inspected deployed function privileges and execution context for private.calculate_project_health_v1, private.calculate_project_snapshot_kpis_v1 and private.refresh_portfolio_health_rollup_v1.
- All three are SECURITY INVOKER, use an empty search_path, and have EXECUTE denied to anon and authenticated; EXECUTE is granted to service_role.
- Re-read current Supabase RLS documentation before validation.
- Latest Advisors: Security = no findings; Health = no findings; Performance = 83 INFO-level unused-index notices. These index notices are expected while the project has no representative workload; no indexes were removed.

### Migration 050 inheritance regression probe
- Executed a read-only SQL regression probe using the same effective-dimension and effective-KPI selection pattern introduced in migration 050.
- Four combinations returned complete, weighted dimension scores:
  1. Global configuration only: score 70.
  2. Project dimension override with inherited global KPIs: score 70.
  3. Project KPI override with global dimension: score 75.
  4. Combined project dimension and KPI overrides: score 75.
- The probe confirmed that inherited KPI metrics remain associated with their originating configuration version and that project KPI definitions take precedence by KPI code.
- Scope limitation: this was a SQL logic probe using isolated in-query fixtures, not a populated database fixture invoking the deployed health function or snapshot builder. It does not constitute end-to-end validation of migration 050.

### Remaining integration validation — still open
- The PPM database still has no provisioned application users, projects, or reporting configuration sets. Therefore, full snapshot build/finalization and real Auth/JWT/RLS tests have not been run.
- Next validation must create a transaction-rolled-back fixture through the real schema and invoke the deployed calculation/snapshot functions. Cover global-only, dimension override, KPI override, combined override, missing metrics, invalid weights, threshold boundaries, critical-dimension Red, PM-reported status separation, portfolio rollup, empty portfolio and snapshot finalization/immutability.
- Do not mark the KPI/health engine production-validated until those deployed-function tests and real role/JWT tests pass.
- No persistent test users, projects, configuration rows, or snapshots were created during this validation pass.


## Deployed KPI/health integration test results — 15 November 2026

A transaction-scoped fixture was run against the live Supabase database. All fixture writes were rolled back and post-test queries confirmed zero persisted test users, projects, reporting cycles, configuration sets or baseline history rows.

### Real deployed project-health resolver
- Project-level dimension override with inherited global KPI definitions/metrics: calculated score 75, status Amber; returned the project dimension label and project configuration version.
- Critical-dimension override: score 90, status Red, with reason identifying DELIVERY as the critical Red dimension.
- Missing KPI metric: returned null score and Not Reported, with dimension status insufficient_data. Missing data was not treated as Green.

### Portfolio rollup and finalization
- Amber, Red and Not Reported portfolio rollups returned the expected status and counts.
- Three transaction-scoped snapshot finalization calls succeeded after required KPI/health fields and rollups were populated.
- The health/rollup/finalization test used manually inserted snapshot metric fixtures after the project snapshot insert trigger had run with inactive KPI definitions. It validates the deployed health resolver, rollup and finalizer, but does not independently prove the KPI resolver produced those manually inserted metrics.

### Full deployed snapshot build → KPI trigger → finalize
- A separate transaction-scoped fixture invoked the actual public.build_weekly_portfolio_snapshot and public.finalize_weekly_portfolio_snapshot functions under a simulated service-role database claim.
- Used a published global configuration with a real active count_v1 KPI mapped to the projects source. A baseline history row was inserted at a cutoff-safe timestamp to represent a project already existing at the cutoff; the real project insert history trigger also fired during fixture creation.
- Snapshot build returned one project and KPI calculation status calculated.
- The metric row was PROJECT_COUNT = 1, status calculated, linked to the expected configuration version.
- Project dimension score was 1, calculated health Green, and source-state-as-of-cutoff was true.
- Snapshot finalization succeeded and returned status finalized with KPI status calculated.
- The test transaction was rolled back. Follow-up queries confirmed no fixture data persisted.

### Test boundaries
- These are database integration tests with a simulated service-role claim inside the SQL session, not a real Edge Function invocation using a signed JWT. Role-specific RLS tests remain outstanding.
- The fixture did not validate historical source capture at transaction commit-time; the existing history system timestamps row events with clock_timestamp(). Its documented transaction/cutoff edge case remains open.
- The health tests validate the deployed function against project/global configuration links, including migration 050 inheritance. They do not yet cover every configuration inheritance permutation or every formula template end-to-end.

### Current status
- KPI source resolution, project health calculation, portfolio health rollup, and weekly snapshot build/finalization now have a successful live database integration path under transaction-scoped test data.
- Do not label the platform production-ready. Remaining gates: real Auth/JWT and role-specific RLS tests, all inheritance combinations and invalid-configuration cases, source-history commit-time semantics, and clean migration replay from GitHub.


### Additional role-scoped RLS smoke test — 15 November 2026
- Ran a transaction-rolled-back RLS smoke test with two temporary Auth identities and two projects. User A was project_manager on project A; User B was team_lead on project A; neither was assigned to project B.
- Under SET LOCAL ROLE authenticated with per-user request.jwt.claims, both users saw exactly one of the two fixture projects (their assigned project only).
- Project Manager could read the project's financial terms (1 row); Team Lead could not (0 rows).
- The entire transaction rolled back. This tests PostgreSQL RLS behavior with simulated JWT claims, not signature verification or an actual Supabase Auth-issued token/Edge Function request. Real signed JWT tests remain a release gate.


## Follow-on security and historical-cutoff review — 15 November 2026

### Supabase auth review
- Re-read the current Supabase Edge Function authorization-header and Auth integration documentation. Both deployed functions, `reporting-config-governance` and `weekly-reporting-snapshots`, are ACTIVE and have `verify_jwt=true`.
- Inspected both deployed function sources. Each requires a Bearer token, calls `admin.auth.getUser(token)`, and derives the actor UUID from the verified Auth user. Neither function uses user-editable `user_metadata` for authorization. Privileged database operations are delegated to service-role RPCs which perform role checks.
- A direct signed-JWT Edge Function invocation could not be run through the currently available connected tools: there is no Edge Function invoke/HTTP request action, and the project has zero Auth users. No user credentials or tokens were requested or exposed.
- SQL RLS smoke tests with simulated `request.jwt.claims` passed for project scoping and Finance-vs-Team-Lead visibility. These do not verify JWT signatures, Auth session validity, or the gateway's `verify_jwt` check.
- Supabase current authorization docs: https://supabase.com/docs/guides/functions/auth-headers and https://supabase.com/docs/guides/functions/auth-legacy-jwt.

### Historical cutoff integrity — unresolved correctness issue
- Confirmed all 14 operational history source tables have active coverage beginning `2026-11-14 16:31:06.635565+00`; the current database has zero projects, users, cycles and configuration sets.
- Confirmed `track_commit_timestamp=off` in PostgreSQL.
- The history trigger writes `recorded_at=clock_timestamp()` and `transaction_id=pg_current_xact_id()::text`. Historical reconstruction currently selects the latest row image by `recorded_at <= cutoff`; it does not test whether the source transaction had committed by the cutoff.
- A transaction that begins before a cutoff, writes its history row before the cutoff, but commits after the cutoff can be incorrectly treated as visible in the historical report. The current implementation therefore cannot yet be described as audit-grade transaction-time reconstruction.
- PostgreSQL 17 provides `pg_current_snapshot()`, `pg_visible_in_snapshot(xid8, pg_snapshot)` and related snapshot functions. A possible correction is to capture a transaction-visibility snapshot when a reporting cycle is closed and use it consistently for project registry capture, KPI source reconstruction, and finalization. This requires a reviewed schema/function migration and explicit definition of the actual reporting cutoff time; it has not been implemented.
- Relevant PostgreSQL 17 reference: https://www.postgresql.org/docs/17/functions-info.html#FUNCTIONS-PG-SNAPSHOT-SYNCHRONIZATION.

### Supabase changelog review
- Reviewed the current Supabase breaking-change index. The November 10, 2026 TLS 1.2 CBC cipher removal is relevant only to obsolete clients; it does not require a database schema change for this project. The Supabase CLI v3 behavior change is not currently relevant because changes are being made through connected MCP tools.
- Changelog: https://supabase.com/changelog?types=breaking-change.

### Current gate
- Do not mark authentication/JWT integration or historical cutoff reconstruction complete.
- Do not claim production readiness.
- Before UI implementation, resolve the historical visibility boundary and obtain a way to run real Auth-issued JWT tests. The UI proposal can be prepared for user review separately; no frontend code has been started.


## 16 November 2026 — transaction-visibility historical reconstruction (migrations 051–053)

**Implemented and verified in the live Supabase project.** The reporting model now preserves the scheduled reporting cutoff while making the actual database closure boundary authoritative for reconstructing a weekly snapshot.

- Migration 051: adds immutable `reporting_cycles.closed_at` and serialized PostgreSQL `closure_snapshot`; guarded cycle closure captures both atomically. Operational history reads and project registry capture now use PostgreSQL transaction visibility (`pg_visible_in_snapshot`) plus the closure timestamp. Finalization validates against the closure-visible project set.
- Migration 052: adds `reporting_configuration_versions.published_transaction_id xid8`, captured by the database on the transition to published. Snapshot generation only includes configuration publication transactions visible at cycle closure.
- Migration 053: allows the new closure metadata keys in the protected portfolio snapshot summary mutation guard.
- Scheduled cutoff remains in snapshot metadata; reports identify `transaction_snapshot_at_closure`, actual close timestamp and whether scheduled cutoff equals closure.
- A live transaction-rolled-back integration test created a project and published config before closure, then created another project and updated the first project after closure. The generated snapshot included only the pre-closure project and its pre-closure row image; `PROJECT_COUNT=1`, KPI status calculated, project health Green, and snapshot finalization succeeded.
- Additional tests confirmed closure boundary capture/immutability, exclusion of post-closure config publication, and publication transaction ID immutability.
- Test users, projects, portfolios, cycles, snapshots, configuration fixtures and test history rows were removed; final cleanup checks returned zero.

Detailed design and test record: `docs/database/REPORTING_CYCLE_CLOSURE_VISIBILITY.md`.

### Remaining gates
- Exercise a long-running transaction started before closure but committed after closure using two independent database sessions.
- Exercise Edge Functions using real Supabase Auth-issued signed JWTs; available connected tools do not currently expose direct Edge Function invocation, and no permanent Auth user was provisioned for testing.
- Replay migrations 001–053 from GitHub in an isolated Supabase branch/database.
- Re-run role-specific RLS tests with actual signed JWTs.

Security and Health Advisors: no findings on the final scan. Performance Advisor: 15 informational unused-index notices; no index removals were made. The full platform is not yet production-ready.

### Next product phase
Backend closure-boundary safeguards are implemented. Prepare the UI/UX proposal for user review before any frontend implementation. Keep CR Management deferred and leave Staff Time & Performance untouched.


## UI/UX proposal prepared for user review — 16 November 2026

- Created `docs/UI_UX_PROPOSAL.md` in GitHub commit `2a02cd32edcbc92bb8f4fad10ef728d1b43673b9`.
- Proposal covers visual direction, primary navigation, Executive Overview, project workspace, Master Schedule, Payments & Risk Timeline, Reports & Snapshots, Configuration Center, role-based experience and interaction principles.
- This is a proposal only. No frontend code, framework selection, component-library selection or deployment has been started.
- Await user approval or requested revisions to the navigation, dashboard composition, project tabs and interaction approach before producing detailed wireframes or implementing UI.


## UI direction approved; detailed screen specifications drafted — 16 November 2026

- User approved the overall UI/UX direction and navigation proposal, including the visual concept sample.
- Created `docs/UI_SCREEN_SPECIFICATIONS.md` in commit 3fd02424aa4b30521bd20f6febaf256eca28d29a.
- Draft 1 specifies the global application shell, Executive Overview, Projects Register, Project Workspace shared header and its ten tabs, interactions, role behavior, empty/error/permission states and acceptance criteria.
- This is a design specification only. No frontend code, framework/component-library selection, or deployment has started.
- User review is now required for dashboard composition, project tabs, CEO finance visibility and presentation mode before proceeding to wireframes or implementation.
- CR Management remains deferred; Staff Time & Performance remains untouched.


## Executive Dashboard layout control — 16 November 2026

- User explicitly confirmed the requirement to control the dashboard layout.
- Added Screen E02, Executive Dashboard Layout Editor, to `docs/UI_SCREEN_SPECIFICATIONS.md`.
- Authorized administrators can add/remove/hide/restore/reorder/resize/reposition dashboard components, control grid columns and component widths, preview, save drafts, publish versioned layouts and reset to the approved default.
- Role-specific layouts are supported; personal layout editing remains administrator-controlled.
- Layout changes cannot grant access to underlying restricted data. Removing a dashboard component never deletes operational data or KPI definitions.
- KPI formulas and thresholds remain governed by the Configuration Center. Historical finalized reports remain unchanged.
- This remains a design specification only; no frontend implementation has started.


## Dashboard layout permissions decision — 16 November 2026

- User confirmed that **only administrators** may control dashboard layouts.
- Ordinary users (including CEO / Executive Viewer, Project Managers and Finance) have read-only dashboard layouts and cannot rearrange components or save personal layouts.
- Administrators manage the default and any role-specific shared layouts.
- Layout editing permissions do not grant access to underlying data; existing data authorization remains enforced.
- Updated `docs/UI_SCREEN_SPECIFICATIONS.md` accordingly. This is a specification decision; frontend implementation has not started.


## CEO financial visibility decision — 17 November 2026

- User selected **Option 3: Restricted access**.
- CEO / Executive Viewer has no financial-data visibility by default. An administrator must explicitly grant it.
- The restriction covers financial dashboard components and KPIs, contract values, invoices, payments, receivables and financial drill-downs.
- This must be enforced in backend authorization/RLS and field-level controls where applicable; hiding UI elements alone is insufficient.
- The decision is recorded in `docs/UI_SCREEN_SPECIFICATIONS.md`. No frontend implementation has started.


## CEO presentation mode decision — 17 November 2026

- User confirmed that the Executive Dashboard must include a dedicated Presentation Mode for weekly CEO meetings.
- Mode is read-only, meeting-oriented, and shows reporting period/snapshot status clearly, with executive-first sections and simplified navigation.
- Financial content remains hidden unless the CEO / Executive Viewer has explicit administrator-granted financial permission. Presentation Mode cannot bypass backend authorization.
- Presentation Mode does not allow layout editing or operational data changes; shared layout management remains administrator-only.
- Specification recorded in `docs/UI_SCREEN_SPECIFICATIONS.md`; frontend implementation remains pending completion and approval of the screen design.


## Executive Dashboard density decision — 17 November 2026

- User selected **Detailed** information density for the standard Executive Dashboard.
- The standard dashboard should show richer charts, KPI breakdowns, project-level operational information, trends, upcoming milestones, risks, decisions and weekly narrative, organized in scrollable sections.
- The CEO Presentation Mode remains a separate, simplified meeting experience.
- Administrator-only layout control remains in force.
- Decision recorded in `docs/UI_SCREEN_SPECIFICATIONS.md`; frontend implementation remains pending.


## Executive Dashboard — project phase visibility requirement — 17 November 2026
- User requested that the dashboard clearly identify each project's current phase.
- Add current phase to project cards and Projects Register; add a portfolio phase breakdown with project counts and drill-down; provide phase filters.
- Show phase progress and planned start / forecast completion / actual completion dates when available.
- Retain phase transition history and time-in-phase visibility for management reporting.
- Phase names, order, active state and permitted transitions must be configurable by administrators. Support lifecycle templates for projects with different delivery approaches; do not hardcode one lifecycle for all projects.
- Missing phase data is shown as Not Reported / Unassigned. Phase is not interchangeable with overall project health or milestone completion.
- Phase display follows existing dashboard layout permissions and data access rules.
- This is a UI/product requirement only. No frontend implementation or database schema change has been made as part of this update.


## Consolidated Executive Dashboard design decisions — 19 November 2026
- Consolidated the decisions made during dashboard design into the UI screen specification.
- Standard dashboard density is Detailed; sections may scroll.
- Only administrators can add/remove/hide/restore/reorder/resize/reposition dashboard components and publish shared layouts. Other roles are read-only and cannot save personal layouts.
- CEO / Executive Viewer financial visibility is restricted by default and requires explicit administrator authorization enforced by backend controls.
- A dedicated read-only CEO Presentation Mode is required for weekly meetings.
- Dashboard components are configurable without deleting or altering underlying operational data or KPI definitions.
- Current project phase must be prominent on project cards and the Projects Register. Add a portfolio phase breakdown and phase filters; show progress and phase dates/history where available.
- Phase lifecycle names, ordering, active states, templates and allowed transitions are administrator-configurable. Phase remains distinct from project health and milestone progress.
- Updated the review section in `docs/UI_SCREEN_SPECIFICATIONS.md` to distinguish confirmed decisions from remaining screen-specification approval.
- This is a documentation/design consolidation only. No frontend code, framework selection, database schema change or deployment was performed.
- Frontend implementation remains blocked pending explicit approval of the complete screen structure and interaction approach.


## Dashboard composition refinements approved — 20 November 2026

- User confirmed the detailed dashboard should be less crowded through clearer hierarchy and progressive disclosure, while retaining the Detailed information density and scrollable sections.
- Agreed hierarchy: (1) portfolio KPIs, project health and phase distribution; (2) projects requiring attention and upcoming priorities; (3) risks and management decisions; (4) further down, authorized financial position, milestone/schedule detail, weekly summary and phase history.
- Financial component inclusion and restricted-panel-versus-hidden behavior must be administrator-configurable. This is a layout setting only; backend authorization/RLS must continue to enforce financial access independently.
- User approved two separate, independently configurable phase components: Project Phase Distribution (counts/percentages and phase filter drill-down) and Recent Phase Changes (project, from/to phase, transition date, full history/time-in-phase).
- Hiding/removing a dashboard component must not delete its underlying operational data or phase history.
- This is a UI/product design decision only. No frontend code, framework/component-library choice, database schema change or deployment was performed.
- Frontend implementation remains blocked pending approval of the complete screen structure and interaction approach.


## Executive Dashboard wireframes drafted — 20 November 2026

- User approved proceeding to detailed dashboard wireframes.
- Created `docs/UI_DASHBOARD_WIREFRAMES.md` in commit `3f22d6c6cfcfe3f8c60d25f756505eea1ee98a25`.
- The draft covers the revised standard Executive Dashboard hierarchy, separate Project Phase Distribution and Recent Phase Changes components, administrator-only layout editor, financial restricted-panel/hidden behavior, CEO Presentation Mode sequence, empty/permission states, and implementation safeguards.
- A visual dashboard concept was generated in this conversation to illustrate the overall appearance. It uses illustrative sample content only and is not a functional screen or connected to live data.
- Product-owner review is still required for the proposed section order, layout editor controls, Presentation Mode sequence, and whether phase-transition reason should be mandatory or optional/configurable.
- No frontend code, framework/component-library selection, database schema change, or deployment has been performed. Do not begin frontend implementation until the user approves the wireframes and interaction approach.

## Scope expansion — CR Management, Deliverables, Milestones & Notifications — 20 November 2026

- User explicitly changed the prior scope decision and requested to include the complete Change Request management capability now, rather than defer it.
- Added `docs/CHANGE_REQUEST_DELIVERABLES_MILESTONES_NOTIFICATIONS_SCOPE.md` (commit `5c24ed95f2d39328cc38b06969c1e9d302d61e23`).
- Current release scope now includes end-to-end CR lifecycle and approvals, impact assessment, controlled application of approved changes, deliverables submission/review/acceptance tracking, milestone tracking/re-baselining, and configurable notification centre/rules.
- Existing `project_contract_variations`, `contract_deliverables`, `project_milestones`, activities, audit and document infrastructure must be assessed and reused/extended where appropriate. Contract variations are not a substitute for full CR management; avoid duplicate variation/financial records.
- Portfolio-level registers, project-level screens, KPIs, notification rules, role/approval matrix, audit, RLS, integration tests and historical snapshot behavior must be specified.
- This scope approval does not authorize immediate frontend implementation. Present the relevant detailed wireframes and interactions for user review and approval first.
- The earlier statements that CR Management is deferred are superseded by this decision. The separate Staff Time & Performance application remains untouched.

## CR, Deliverables, Milestones & Notification wireframes prepared — 20 November 2026

- User approved including all capabilities in the current release, superseding the earlier CR deferral.
- Created `docs/UI_CR_DELIVERABLES_MILESTONES_NOTIFICATION_WIREFRAMES.md` in commit `25af38667f7fe2f57cd6705b7424100a6531fb82`.
- Draft wireframes cover: portfolio CR register; detailed CR workspace with impact assessment, configurable approvals and implementation; portfolio deliverables register and versioned submission/review/acceptance; portfolio milestones register and controlled re-baselining; user Notification Centre; administrator notification-rules editor; permissions and cross-module behavior.
- Updated `docs/UI_SCREEN_SPECIFICATIONS.md` with the scope supersession and new navigation/workspace requirements (commit `9f3ccef2b911084db91aebbaa9a0f355ec8085ad`).
- This is design/documentation only. No frontend code, database migration, notification-provider integration or deployment was performed.
- Await product-owner review of the seven decisions in the wireframe document before frontend implementation or related schema changes.
- Keep Staff Time & Performance untouched.

## Product-owner decisions for CR, Deliverables, Milestones & Notifications — 20 November 2026

- CR approval routing is configurable and must support both sequential and parallel approval stages.
- Every CR requires an impact assessment outcome for each dimension; a dimension may be marked Not Applicable only with a documented reason.
- Deliverables remain **Unaccepted** until the Project Manager formally records acceptance. Submission or review activity alone must not mark a deliverable Accepted.
- Milestone re-baselining supports either an approved CR or a separate approved re-baseline request; reason, prior baseline preservation, approval and audit history are mandatory.
- Implement in-app notifications first. Email channel activation is conditional on provider integration and delivery testing.
- Reminder/escalation schedules use global defaults with project-level overrides.
- Notification acknowledgement is configurable by selected event types and severity. It is required only where the administrator designates it; it is not mandatory for every action-required notification.
- These are design decisions only. Frontend implementation, schema changes and deployment remain blocked until the user reviews and approves the complete wireframes and interaction approach.


## Executive financial access controls — 21 November 2026

- Applied Supabase migration 054, `executive_financial_access_grants`, to the separate Executive PPM Platform project.
- Added administrator-managed, project-scoped or global executive financial access grants. Grants require a reason, can expire, are revocable once, and retain grant/revocation actor and timestamps. Authenticated users cannot delete grant history.
- Updated SELECT RLS for project contracts, contract financial terms, invoices, cash transactions, invoice allocations and contract variations. Executive Viewer access now requires an active grant in addition to the active Executive Viewer role. Existing Project Manager, Finance, Finance Admin and Platform Admin access paths are retained.
- Changed `project_invoice_balances` to a security-invoker view so underlying invoice/allocation RLS applies.
- Supabase Security Advisor returned no findings immediately after migration.
- The migration source is committed as `supabase/migrations/20261121010000_migration_054_executive_financial_access_grants.sql`.
- Important remaining security work: historical `project_snapshots` expose a JSON payload and `snapshot_metric_values` are currently readable by Executive Viewer. KPI sensitivity classification and a safe snapshot data contract are still required before financial KPIs or snapshot payloads can be exposed to executive users. Real JWT tests are also pending because no application users are provisioned yet.
- The frontend build failure caused by literal escaped newline characters in `src/styles.css` was fixed in commit `13887dccc9bbdda957a77faf9bd87ca15565ff84`; GitHub Actions build run 29 completed successfully.
- PR #1 remains draft and unmerged. No deployment has been performed.


## Historical snapshot access hardening — 21 November 2026

- Applied migration 055 to the live Executive PPM Supabase project.
- Removed broad authenticated table-level SELECT from `project_snapshots` and `portfolio_snapshots`; granted only non-JSON metadata columns. Opaque `snapshot_payload` and `portfolio_summary` are not selectable by authenticated users.
- Removed Executive Viewer access to unclassified `snapshot_metric_values`. Platform Admin and active project members retain the existing read path.
- Applied migration 056: added `project_snapshot_index` and `portfolio_snapshot_index` views with `security_invoker=true`, exposing only safe metadata and preserving underlying RLS/column grants.
- Verified the views carry the `security_invoker=true` option. Supabase Security Advisor returned zero lints after the changes.
- Current database contains zero portfolio snapshots, zero project snapshots, zero snapshot metric rows and zero KPI definitions; therefore there is no existing historical dataset to classify or validate yet.
- Real authenticated-user tests remain outstanding because no application users have been provisioned. API consumers must use the new snapshot index views and explicit column selections; `select *` on the base snapshot tables is intentionally not supported for authenticated users.
- Current frontend CI for the latest migration commits was still running at the time of this checkpoint update.


## Executive Overview live project-register connection — 21 November 2026

- Added `src/LivePortfolioOverview.tsx` and connected the Executive Overview to `public.projects` through the authenticated Supabase browser client.
- The read-only query returns project code, name, lifecycle status, start date, target end date, project-manager assignment indicator and related client name. Access remains governed by the existing `projects` and `clients` SELECT grants and RLS policies; no service-role key is used.
- Added loading, query-error, empty-register and search-filter states. Summary counts derive only from rows returned to the signed-in user.
- Replaced fixed demo reporting period and finalized snapshot indicators with an explicit live operational view / no-finalized-snapshot status.
- Admin layout editor entry is now restricted to the database-derived `platform_admin` role. Layout persistence is not yet implemented; the editor remains preview-only.
- Important data-model distinction: `projects.lifecycle_status` is not the configurable project phase. The current database has no phase assignment/history tables in the inspected public schema. Project phase, calculated health, verified progress, milestone achievement, risk rollups and executive decisions remain Not Reported until the respective live data contracts are connected.
- Database currently contains zero project rows and zero Auth users. Therefore the frontend live query has not yet been verified using a real signed-in account; do not claim a complete end-to-end integration test.
- Latest known completed CI: run 42 succeeded for prior commit `e06f07f35155ba9a1f4e11622a9bdbede51cf69d`. The GitHub connector did not return push-triggered workflow runs for the latest commits, so this slice's build result remains unverified through the available run-list action.
- No schema changes, user provisioning, merge or deployment were performed in this slice.


## Snapshot-backed project health integration — 21 November 2026

- Added a read-only frontend integration to the existing `project_snapshot_index` view (migration 056). Query requests only safe metadata: project ID, calculated health and snapshot creation time.
- Snapshot query paginates at 1,000 rows and orders newest first; the latest visible calculated health is selected per project. Missing, unknown or absent snapshot status is classified as Not Reported, never Green.
- Project register displays calculated health separately from project lifecycle status. PM-reported health is not substituted for calculated health.
- Project Phase is explicitly shown as Not configured. Database inspection confirmed no lifecycle template, phase definition, project phase assignment or phase history tables exist yet; do not infer a phase from lifecycle status.
- KPI metric values remain disconnected. Executive Viewer access to unclassified `snapshot_metric_values` was deliberately removed in migration 055. The KPI calculation engine and health aggregation exist, but there are currently no KPI definitions/configuration versions or snapshot values. Design a safe, sensitivity-classified KPI read contract before exposing any KPI metrics.
- Security Advisor returned zero lints after this frontend-only change. No schema or RLS permissions were changed.
- Database currently has zero projects, zero project/portfolio snapshots, zero KPI configuration rows and zero Auth users. Therefore authenticated browser behavior and role-specific RLS still need real-user tests.
- Latest frontend slice commits: live register `27dc9f0e83bb4625141af0a29a58b0cbb3a3d8a8`, health integration `c1672a7b1f47140436f1ef97cfa71d40510cbf21`, styles `75a6a239d6b27d9d524f55f96cb9cb9a574ebd00`; documentation updated after these commits.
- PR #1 remains draft and unmerged; no deployment was performed.


## Latest frontend CI verification — 21 November 2026

- GitHub Actions run `44831475659` completed successfully for the latest frontend health-integration commit `ace40388a4e54ada500e96e6c10d3d5f2733f74d`.
- Dependency installation and TypeScript type-check/production build passed.
- The result verifies the frontend build, not live authenticated user behavior or role-specific RLS. The database still has no provisioned application users or project records.
- The next implementation slice is the configurable lifecycle-template / phase-definition / project-assignment / phase-transition-history model. No phase model has yet been applied; the frontend correctly continues to show Not configured until that governed data model exists.
- PR #1 remains draft and unmerged. No deployment has been performed.


## Configurable project lifecycle backend — 21 November 2026

- Applied Supabase migrations 057 (`migration_057_configurable_project_lifecycle_phases`) and 058 (`migration_058_global_lifecycle_assignment_scope_fix`) to project `oihawkpbtgqxxliaamxs`.
- New tables: `project_lifecycle_templates`, `project_lifecycle_template_versions`, `project_lifecycle_phases`, `project_lifecycle_transition_rules`, `project_lifecycle_assignments`, and `project_phase_history`. Added `project_current_phase` security-invoker view.
- Lifecycle templates support global and project-specific scope. Versions are numbered and governed through draft/published/retired states and effective dates. Phase names, order, active state and allowed transitions are configured by administrators; no universal phase names are hardcoded or seeded.
- Published/retired versions and child definitions are immutable. Project assignments are limited to one active assignment per project. A global template's scope is stored separately from the project using it, so global versions can be assigned to any project without invalid composite foreign keys.
- Platform Administrators assign a published/effective version and initial phase. Assigned Project Managers or Platform Administrators can update current phase dates/progress and move to an explicitly allowed target phase. Transition reasons follow per-transition configuration.
- RLS is enabled on all six tables; policies scope project data to active memberships and reserve configuration writes for Platform Administrators. Explicit Data API grants are applied. Lifecycle assignment and phase history writes create private audit events.
- Verification: all six tables have RLS enabled and scoped policies; global draft template + two phases + starting/forward rules passed a transaction-scoped fixture test and were rolled back; both RPCs rejected unauthenticated calls. No test fixtures were retained.
- Security Advisor reports two WARN findings for authenticated execution of SECURITY DEFINER RPCs. This is intentional for atomic writes while direct client writes to assignment/history tables remain unavailable. Functions use empty search_path, explicit auth/profile/role checks, and no anon/PUBLIC execution. The warnings remain open for review and real JWT tests.
- Current database has zero projects and zero Auth users. Therefore positive admin assignment, PM transitions, and actual dashboard read behavior cannot yet be tested.
- Existing project timeline views and frontend register have not yet been extended to consume phase history. The frontend must continue to show Not configured / Not Reported until lifecycle setup is completed.
- Design and implementation notes: `docs/database/PROJECT_LIFECYCLE_PHASE_MODEL.md`.
- Supabase migrations 057/058 are applied. The original SQL for migration 057 has now been restored from the exact `statements` array retained in `supabase_migrations.schema_migrations` and committed at `supabase/migrations/20261120225103_migration_057_configurable_project_lifecycle_phases.sql`. Migration 058 was also aligned to the exact applied SQL stored in Supabase migration history. The complete migration sequence still requires clean-environment replay before replay compatibility can be claimed.
- PR #1 remains draft and unmerged; no deployment or user provisioning was performed.


## Executive phase read integration — 21 November 2026

- Applied migration 059, `migration_059_executive_lifecycle_phase_read_access`: active Executive Viewer users can read non-financial lifecycle definitions, assignments and history. This does not grant access to finance data.
- Applied migration 060, `migration_060_executive_phase_change_read_model`: added `project_phase_change_log` with `security_invoker=true`; the existing `project_current_phase` view is also security-invoker.
- Connected the Executive Overview to current phase and phase history read models. Added the Project Phase Distribution component, ordered by configured phase order, the Recent Phase Changes component (latest 10), and current phase/progress/forecast date in the project register.
- Search now includes current phase names. No phase names or sample records are seeded.
- SQL read checks against both views succeeded and returned empty results as expected; there are currently zero projects, lifecycle templates, versions, phases, assignments, history rows and Auth users.
- Latest frontend commits: phase data integration `5aa5ff6806be1a1a7a1240a4172b4f06bb608018`, configured phase ordering `5621b16458b5440a45e4422275eee0c8c768a418`, styles `4f38344e355cd36a18284fb1dfaa81c54efde10c`.
- Latest frontend CI status is unverified. The available GitHub workflow-run connector returns only PR-triggered runs and found no run for the latest commits.
- Security Advisor reports two WARN findings for the authenticated SECURITY DEFINER lifecycle RPCs. They are intentionally used to perform atomic assignment/history writes without direct client table-write grants; both use an empty search_path, explicit auth/profile/role checks, and revoke anon/PUBLIC execution. Real JWT tests remain required.
- Migrations 057, 059 and 060 source files have now been restored from the exact SQL statements retained in `supabase_migrations.schema_migrations`; migration 058 source remains unchanged. Recovery details are in `docs/database/MIGRATION_SOURCE_RECOVERY.md`. Clean-environment replay remains unverified.
- PR #1 remains draft and unmerged. No deployment or user provisioning was performed.


## Private formula-template RLS hardening — 21 November 2026

- Applied migration `20261120225701_enable_rls_reporting_formula_templates` to the Executive PPM Supabase project.
- Enabled RLS on `private.reporting_formula_templates` as defense in depth.
- No client policies were added because `anon` and `authenticated` have neither `USAGE` on the `private` schema nor `SELECT` on this table. The existing server-side `service_role` SELECT grant remains; `service_role` bypasses RLS.
- Post-migration verification confirms RLS enabled, RLS not forced, client schema/table access still denied, and the service-role SELECT grant retained.
- Security Advisor now reports one INFO finding because the table has RLS enabled with no policies; this is intentional for a private server-only table with no client access. Two existing WARN findings remain for the authenticated SECURITY DEFINER lifecycle assignment/transition RPCs and require real JWT tests and security review.
- Matching SQL source committed at `supabase/migrations/20261120225701_enable_rls_reporting_formula_templates.sql`.
- No application data, user access, existing Staff Time & Performance assets, PR merge or deployment was changed.


## Lifecycle migration source archive reconciled — 21 November 2026

- Confirmed the live Supabase migration history stores the original SQL in `supabase_migrations.schema_migrations.statements`, not only migration version/name metadata.
- Restored exact original SQL for migrations 057, 059 and 060 from those authoritative applied-migration records into the matching `supabase/migrations` files on `feature/ppm-frontend-foundation`.
- Migration 059 and 060 files that had previously been reconstructed from catalog state were replaced with the exact recorded statements. Migration 058 was inspected and left unchanged.
- Added `docs/database/MIGRATION_SOURCE_RECOVERY.md` documenting provenance, verification and remaining replay gate.
- All four migrations 057–060 are present in live migration history and corresponding SQL files are now archived in GitHub.
- Clean-environment replay has not yet been run. No claim of replay compatibility or production readiness is made.
- No live database schema/data changes, user provisioning, merge or deployment occurred. Staff Time & Performance remains untouched.


## Exact migration source archive verification — 21 November 2026

- Retrieved the applied SQL statement arrays for migrations 057, 058, 059 and 060 directly from `supabase_migrations.schema_migrations` in the live PPM database.
- Restored migration 057 and replaced the earlier reconstructed 059/060 files with their exact recorded SQL. Also aligned migration 058 to the exact stored SQL; the previous repository copy had additional explanatory header comments not present in the applied statement.
- Re-fetched each GitHub migration file and compared its full text to the corresponding stored SQL statement. All four comparisons returned exact matches.
- GitHub Actions Frontend build run `44834250881` completed successfully for checkpoint commit `b01610681755f21730968f552bc62da51508dfc1`. This verifies the frontend build for that commit; subsequent changes in this pass are SQL-source/documentation-only.
- A clean-environment replay of the full migration chain remains unverified. No merge, deployment, live schema change, or Staff Time & Performance change occurred.


## Full applied migration archive reconciliation — 21 November 2026

- Queried the authoritative live PPM migration ledger, `supabase_migrations.schema_migrations`, and enumerated all 61 applied migrations.
- Found four missing repository sources: migrations 001–004. Restored their exact `statements[1]` SQL from the applied migration ledger into `supabase/migrations/` on `feature/ppm-frontend-foundation`.
- Re-fetched each of the four new GitHub files and compared the full file text with the stored applied SQL. All four matched exactly.
- Confirmed that all 61 applied migration names now have a corresponding SQL file in the repository. This check uses migration names because some existing filenames use a timestamp prefix that differs from the applied ledger version; the suffix/name mapping is complete.
- Previously restored migrations 057–060 were also checked against their stored applied SQL in this pass; all four matched exactly. No SQL content was changed in those four files during this check.
- This establishes source-archive completeness and exact-source matching for migrations 001–004 and 057–060. It does not establish that the entire chain replays successfully on a fresh database.
- Clean-environment replay remains an outstanding validation gate. No clean Supabase project/branch was created; no live schema/data changes, user provisioning, merge or deployment occurred. Staff Time & Performance remains untouched.


## Clean migration replay validation — 21 November 2026

The 61-migration source archive was restored from the exact SQL retained in the live Supabase migration ledger, and migration filename versions were aligned to the ledger. A clean local Supabase replay passed in GitHub Actions: `supabase start`, `supabase db reset`, and `supabase migration list` all succeeded; the final local migration history contained all 61 versions. The workflow uses a local PostgreSQL 17 stack and no hosted Supabase credentials. No hosted Supabase project or branch was created, and the live PPM database was not modified. Evidence: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/44836138953. Detailed record: `docs/database/MIGRATION_SOURCE_RECOVERY.md`. Dedicated checkpoint: `docs/checkpoints/2026-11-21-clean-migration-replay.md`.

Remaining backend validation is unchanged: provision test Auth users and memberships for JWT/RLS tests; review lifecycle SECURITY DEFINER RPCs, Team Lead contract access, invoice cash-allocation reversal, and the KPI safe-read contract/sensitivity classification. Clean replay does not establish production readiness.


## Backend security and authorization validation — 21 November 2026

- Migration 062 (`20261120232936_security_policy_hardening`) is applied in the Executive PPM Supabase project and committed in `supabase/migrations/20261120232936_security_policy_hardening.sql`.
- Corrected `project_contracts` SELECT policy: Team Lead and Project Viewer memberships no longer expose full contractual/commercial records. Project Manager and Finance project roles, Platform Administrator and Finance Administrator global roles, and Executive Viewer with an active explicit financial grant are authorized.
- Rollback-only SQL role tests passed for project scope and Executive Viewer grant scope. Finance allocation reversal passed; Team Lead reversal was denied.
- All 47 public/private tables have RLS enabled; private formula-template table has no client access; six key read-model views are security_invoker.
- Clean replay of all 62 migrations passed: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/44837247508
- Frontend build passed: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/44837247564
- Current Security Advisor findings: two WARN for authenticated SECURITY DEFINER lifecycle RPCs (intentional, with explicit checks) and one INFO for the server-only private formula-template table.
- Remaining: real signed JWT tests through Auth/Data API, Storage permission tests, and full frontend role journeys. The current SQL tests use simulated request claims, not cryptographically signed tokens.
- Detailed report: `docs/database/SECURITY_AUTHORIZATION_TEST_RESULTS.md`; checkpoint: `docs/checkpoints/2026-11-21-security-authorization-tests.md`.
- No real test users or data were retained. No deployment or merge; PR #1 remains draft. Staff Time & Performance untouched.


## Lifecycle transition authorization correction — 21 November 2026

- Deeper review found that `transition_project_phase` was missing effective-date checks for the Platform Administrator global assignment and Project Manager project membership, despite requiring each row's status to be active.
- Applied live migration `20261121082534_lifecycle_transition_effective_date_authorization`; replacement function now checks active profile, effective-from and effective-to dates for both authorization paths.
- Re-read the live function definition and verified the two effective-date predicates. Existing execution ACLs were preserved.
- Migration SQL committed to GitHub: `supabase/migrations/20261121082534_lifecycle_transition_effective_date_authorization.sql`.
- This is static source verification only. Fresh rollback-only tests for future-dated/expired assignments and real signed-JWT HTTP tests remain outstanding. Do not treat the earlier simulated negative-test note as proof that this missing check was previously enforced.
- Security Advisor remains at two intentional authenticated SECURITY DEFINER WARN findings plus one INFO for the server-only private formula-template table.
- No Auth users or persistent test fixtures created. No merge or deployment; PR #1 remains draft. Staff Time & Performance untouched.


## Post-fix lifecycle authorization verification — 21 November 2026

- Ran four rollback-only SQL tests after migration 063: future-dated and expired Project Manager memberships, plus future-dated and expired Platform Administrator assignments. All four were denied with the expected authorization error.
- Tests used simulated `request.jwt.claim.sub` values and temporary fixtures within one transaction; follow-up query confirmed zero test Auth users, profiles or projects remained.
- Confirmed function ACL: anon cannot execute `transition_project_phase`; authenticated retains the intended grant. Live function source includes effective-from and effective-to checks on both authorization paths.
- These tests are not signed-JWT HTTP tests; actual Auth/Data API/RPC testing and Storage tests remain outstanding.
- The migration source archive now contains 63 files matching all 63 live migration ledger entries, with no missing or extra filenames.
- Frontend build passed for current branch head `a3289bdda9f28a29abc8cc42d6f3f32dd51a0185`. Migration replay is still running; an earlier PR replay attempt failed before stack startup because GitHub rate-limited the action's lookup of the latest Supabase CLI release. The workflow is now pinned to Supabase CLI 3.2.0 and uses a guarded cleanup step.


## CR, Deliverables, Milestones and Notifications backend foundation — 21 November 2026

- Added and applied Supabase migration 064: 20261121110000_project_change_request_workflow_and_notifications.
- Added configurable workflow template/version/stage/transition schema; CR register, impact assessments, approval records and history; deliverable submission/review history; milestone re-baseline request/history; notification rules and per-user in-app inbox.
- Extended existing contract_deliverables rather than creating a duplicate deliverable register. New deliverables default to unaccepted; accepted status requires accepted_by and accepted_at and the existing status must be accepted. The existing table's write authorization remains PM / Platform Administrator controlled.
- Financial CR impact rows have narrower access than the base CR record. Workflow and notification rules are Platform Administrator controlled. Notification inbox rows are recipient-scoped, and client updates are limited to read/acknowledgement fields. Authenticated delete privileges are revoked on the new tables.
- RLS is enabled on all 14 new tables; catalog verification confirmed policies exist. Supabase migration application returned success.
- Security Advisor findings remain unchanged: two existing lifecycle SECURITY DEFINER WARNs and one intentional INFO for private server-only formula templates.
- The live PPM database currently has zero Auth users, projects, CRs, notifications and deliverables. Real signed-JWT tests and positive role-based journeys remain impossible until test accounts and project fixtures exist.
- Important: this is a backend schema foundation, not a completed module. CR transition/approval execution, separation-of-duties enforcement, impact completeness, atomic contract/schedule application, history population, deliverable submission/review/PM acceptance actions, milestone re-baseline approval/application, notification event evaluation/recipient resolution/retry processing and frontend screens remain outstanding.
- External email delivery is not enabled. No frontend files were changed in this slice.
- Detailed record: docs/database/CR_DELIVERABLES_MILESTONES_NOTIFICATIONS_BACKEND_FOUNDATION.md.
- No merge or deployment. Staff Time & Performance remains untouched.


## CR module policy/index hardening and migration ledger alignment — 21 November 2026

- Added migration 065, 20261121094854_cr_workflow_policy_and_index_hardening: split write policies from read policies to eliminate seven multiple-permissive SELECT warnings, and added indexes for new module foreign keys.
- Added migration 066, 20261121094908_contract_deliverable_review_fk_index: composite index covering the deliverable-review submission/project/deliverable FK.
- Re-ran Security Advisor: no new findings. Existing findings remain two authenticated lifecycle SECURITY DEFINER WARNs and one intentional private formula-template INFO.
- Re-ran Performance Advisor: zero unindexed foreign-key findings on the new module tables. Nineteen remaining unindexed-FK findings are on pre-existing financial/lifecycle tables. Unused-index INFOs are expected while the database contains no application data; do not remove indexes solely on that basis.
- Reconciled GitHub migration filenames to the exact live ledger versions: 064 = 20261121094748, 065 = 20261121094854, 066 = 20261121094908.
- Migration application and catalog checks succeeded. All 14 new tables have RLS enabled and policies. No new test users or sample business data were created.
- Clean-environment replay of the complete 66-migration chain is not yet verified. GitHub's available workflow-run fetch did not return a PR-triggered run for the latest branch commit, so no CI pass is claimed for these commits.
- The backend workflow engine and user-facing module actions remain incomplete as detailed in docs/database/CR_DELIVERABLES_MILESTONES_NOTIFICATIONS_BACKEND_FOUNDATION.md. No frontend changes, merge or deployment occurred. Staff Time & Performance remains untouched.


## PM-only deliverable acceptance enforcement — 21 November 2026

- Added and applied migration 067, 20261121095042_contract_deliverable_pm_acceptance_guard.
- Strengthened the deliverable acceptance constraint so status='accepted' and acceptance_status='accepted' must agree, with accepted_by and accepted_at required.
- Added a SECURITY INVOKER trigger with empty search_path. Only an active Project Manager with an active, effective project membership can transition a deliverable to accepted. The trigger stamps accepted_by and accepted_at from the authenticated actor and current database time; clients cannot supply or backdate those values.
- A recorded acceptance cannot be reversed or have its accepting actor/time rewritten. New deliverables cannot be inserted already accepted.
- Trigger function EXECUTE is revoked from anon, authenticated and service_role; it runs only through the table trigger.
- Catalog verification confirms the trigger, invoker mode, denied direct function execution, and strengthened check constraint. Positive signed-JWT acceptance testing remains pending because the PPM database has zero Auth users and zero project fixtures.
- Matching migration source is archived as supabase/migrations/20261121095042_contract_deliverable_pm_acceptance_guard.sql.
- Total live migration count is now 67. Clean-environment replay of all 67 migrations remains unverified. No frontend changes, merge or deployment. Staff Time & Performance remains untouched.


## Module migration archive final check — 21 November 2026

- Queried the live Supabase migration ledger: 67 migrations are applied.
- Compared the full SQL source of migrations 064, 065, 066 and 067 in GitHub with the corresponding statements[1] values in supabase_migrations.schema_migrations using PostgreSQL MD5 equality. All four exact-source comparisons returned true.
- The latest Security Advisor check remains unchanged: two existing lifecycle SECURITY DEFINER WARNs and one intentional INFO for the private server-only formula-template table. The new PM acceptance trigger is SECURITY INVOKER and direct execution is revoked from client roles.
- The PR description and backend foundation document reflect the current scope and implementation limits. PR #1 remains open, draft, unmerged. No deployment. The separate Staff Time & Performance app remains untouched.


## CR workflow engine implementation — 21 November 2026

- Added migrations 068–077 (versions 20261121095515 through 20261121100005) and archived the exact applied SQL sources under supabase/migrations.
- Added configurable sequential/parallel approval mode per workflow stage, ordered role-based approval assignments, approval rounds for stage re-entry, required impact-dimension definitions and metadata validation.
- Added Platform Administrator-only workflow publication RPC. Published workflow versions and their child stage/transition/impact-dimension configuration are immutable; new configuration requires a new draft version and publication.
- Added CR transition RPC for draft submission and configured stage actions. It validates active application profile and effective role assignments, checks the selected published/effective workflow, enforces completion of every required impact dimension, routes role-based approvals, blocks out-of-order sequential approvals, and records approval/history events atomically.
- Self-approval is rejected by both the transition path and approval trigger. Approval decisions and CR history are not writable directly by authenticated clients. Approver-role members can read their pending approval rows.
- CR creation is restricted to active PM / Platform Administrator and always starts as draft with requester stamped from auth.uid(). Direct lifecycle-field updates are blocked. Submitted identity/content is immutable. Workflow version can be selected while still draft and is locked after submission.
- Impact assessment rows can only be edited by active PM/Finance or authorized global administrators while the CR is draft; assessed_by/assessed_at are database-stamped. Impact row identity cannot be reassigned and rows cannot be deleted.
- Privileged implementations were moved to the non-exposed private schema behind public SECURITY INVOKER RPC wrappers. Security Advisor now reports only the two previously existing public lifecycle SECURITY DEFINER warnings and the intentional private formula-template INFO; no new warning was introduced by the CR engine.
- Rollback-only integration test passed with simulated Auth claim subjects and temporary fixtures: PM submitted; a later sequential approver was denied out of order; Finance approved; Team Lead approved; CR reached the configured terminal Approved stage; two approvals and three history events were recorded. The test transaction rolled back, and a follow-up query confirmed zero temporary Auth users, projects or CRs remained.
- This is not a signed-JWT HTTP test. Real Auth/JWT/API/Storage testing remains outstanding. The parallel path and self-approval denial need dedicated tests.
- Remaining CR work: atomic application to contract variations and schedule/milestone records, admin workflow authoring UI, CR screens/actions, SLA/escalation and notification event wiring.
- Total live migration count: 77. Clean-environment replay of all 77 migrations remains unverified. No merge or deployment. Staff Time & Performance remains untouched.
- Detailed implementation and test record: docs/database/CR_DELIVERABLES_MILESTONES_NOTIFICATIONS_BACKEND_FOUNDATION.md.


## CR workflow guard corrections and final validation — 21 November 2026

- Added migrations 078–079 (20261121100113 and 20261121100132) to correct workflow-field comparisons and make transaction-local authorization-context checks NULL-safe.
- Important security correction: the original guard comparison could fail to detect direct lifecycle field changes when the custom transaction setting was absent. The final guard compares the protected fields directly and treats a missing context as unauthorized. The workflow publication guard applies the same fail-closed rule.
- Rollback-only tests confirmed direct client status mutation is rejected and direct draft workflow publication is rejected. The end-to-end sequential approval test still passes after the creation and identity guards: PM submission, out-of-order Team Lead denial, Finance approval, Team Lead approval, final Approved state, two approval records and three history events.
- All rollback-only test users/projects/CR records were removed by transaction rollback; a follow-up count returned zero.
- Final Security Advisor check: no new findings. Two pre-existing public lifecycle SECURITY DEFINER warnings and the intentional private formula-template INFO remain. CR privileged implementations remain in private behind public SECURITY INVOKER wrappers.
- Final Performance Advisor check: 19 unindexed-FK findings remain on pre-existing lifecycle/financial tables; no new unindexed-FK finding on CR/workflow module tables. Unused-index notices are informational while the database has no operational data.
- Total applied migration count: 79. The last two migration files were compared against their live ledger SQL hashes and matched; all migration sources were archived directly from the live migration ledger.
- Full clean-environment replay and real signed-JWT/Storage tests remain pending. No merge or deployment. Staff Time & Performance remains untouched.


## Atomic CR application to contract variations and schedule — 21 November 2026

- Added migrations 080–084 (20261121100528 through 20261121100846). Exact SQL source for all five new migrations was hash-compared against the live Supabase ledger; all matched.
- Added configurable workflow decision outcome (approved/rejected) independently of terminal status. This allows the CR to enter an approved decision stage, apply approved changes, and continue through implementation/closure stages.
- Added CR decision actor and approval decision actor stamps.
- Financially impactful CRs now require a contract, matching CR-linked draft contract variation, one consistent currency matching contract/project financial terms, and a configured Finance/Finance Admin approval stage.
- Added public RPC create_change_request_contract_variation (SECURITY INVOKER wrapper over private implementation). It creates a single linked draft variation from the CR's assessed net financial impact.
- CR-linked variations cannot be independently submitted or approved. They are approved only inside the CR application transaction after all latest approval rounds complete and a Finance approval actor is recorded. Existing standalone variation workflow remains in place.
- Added typed CR schedule-change records targeting project activities or milestones. Proposed dates and reasons are locked after CR submission. Approved CR application updates only approved_revised_start_date / approved_revised_due_date; original baseline dates remain unchanged.
- Direct client updates to approved revised schedule dates are blocked. Only approved CR application or the separate milestone re-baseline context can update them.
- Added one application record per CR with actor/time, variation link, financial amount/currency, schedule count and audit payload. Application of the variation, financial rollup, schedule changes and history event occurs in one transaction; any failure rolls back the whole approval transition. Duplicate application is prevented.
- Finance can read CR decision history and financial application records. Team Leads can read schedule changes but not financial application records.
- Rollback-only end-to-end test passed: PM created CR and USD 100 variation, assessed required dimensions, submitted; out-of-order Team Lead approval denied; Finance then Team Lead approvals succeeded; CR entered Approved decision stage; variation became Approved with Finance as decision actor; financial terms reflected USD 100 approved variations; activity due date updated to 2026-12-05; milestone due date updated to 2026-12-15; one application record and two applied schedule records were created. All fixtures were rolled back and post-test counts returned zero temporary Auth users/projects/CRs.
- Test used simulated claim subjects, not signed-JWT HTTP. Parallel approval, rejection/return, real Auth/API and Storage tests remain outstanding.
- Total live migrations: 84. Security Advisor still shows only two pre-existing public lifecycle SECURITY DEFINER warnings and the intentional private formula-template INFO. Performance Advisor still shows 19 unindexed-FK notices on pre-existing lifecycle/financial tables; none on the new CR module tables. Clean replay of all 84 migrations remains outstanding.
- CR screens, schedule impact UI, linked variation UI, approval inbox, SLA/notification wiring, deliverable submission/review actions and milestone re-baseline execution remain outstanding. No merge or deployment. Staff Time & Performance remains untouched.
- Detailed record: docs/database/CR_DELIVERABLES_MILESTONES_NOTIFICATIONS_BACKEND_FOUNDATION.md.


## Deliverable submission, review and PM acceptance actions — 21 November 2026

- Added migrations 085–087 (20261121101154, 20261121101202, 20261121101233) and archived their exact applied SQL sources in GitHub.
- Added public SECURITY INVOKER RPC wrappers with private-schema implementations:
  - submit_contract_deliverable: assigned owner or active PM submits a numbered version with notes and optional document/version. Document references are checked for same-project scope, active status, uploaded version and the user's classification read permission.
  - review_contract_deliverable_submission: assigned reviewer or active PM records accepted, changes_required or rejected; rejection requires a reason. One review decision per submission.
  - accept_contract_deliverable: only active PM for the project may accept, and only after the latest submission receives an accepted review outcome.
- A reviewer outcome of accepted does not formally accept the deliverable. acceptance_status remains unaccepted until the separate PM acceptance action stamps accepted_by and accepted_at.
- Direct client writes to submission/review records are revoked. Direct client changes to deliverable submission/review/acceptance lifecycle fields are blocked. PM acceptance is enforced through a transaction-local action context and the existing database acceptance guard.
- Submission and review audit events are recorded; deliverable operational history captures state changes.
- Rollback-only test passed: Team Lead submitted version 1; assigned reviewer accepted the submission; deliverable remained unaccepted; direct PM table acceptance was rejected; PM acceptance RPC succeeded and stamped actor/time. Test transaction rolled back; no fixture records remain.
- This is SQL-level simulation, not signed-JWT HTTP/API or actual Storage upload/download testing. Document classification checks are implemented; document-linked submission and Storage E2E remain pending.
- Total live migration count: 87. Clean-environment replay of 84 migrations passed before migrations 085–087 were added; full replay of all 87 migrations must be rerun. Frontend build also passed at the earlier commit; rerun both pipelines at the latest branch head.
- Deliverable screens/actions, CR screens, approval inbox, workflow configuration UI and notification event processing remain outstanding. No merge or deployment. Staff Time & Performance remains untouched.
- Detailed implementation: docs/database/CR_DELIVERABLES_MILESTONES_NOTIFICATIONS_BACKEND_FOUNDATION.md.


## Event-driven in-app notifications — 21 November 2026

- Added migrations 088–090 (20261121101519, 20261121101556, 20261121101623) and archived the exact applied SQL sources.
- Added Platform Administrator-managed notification rules with supported recipient roles, target users, actor exclusion, severity, effective dates and acknowledgement requirement. Rule changes increment version_no and archive the prior configuration in ppm_notification_rule_history.
- Added private event delivery helper and database triggers for CR submitted, approval-needed, approved/rejected, deliverable submitted, review accepted/changes-required/rejected and formal PM acceptance events.
- Sequential CR approval notifications route only to the next actionable approver; the next person is notified after the prior approver completes. Parallel stages notify all pending approvers.
- Recipient resolution requires active profiles and effective project/global role assignments. Inbox rows are recipient-scoped and deduplicated by rule version, event instance, source and recipient.
- Read and acknowledgement actions stamp timestamps in the database; acknowledgement is permitted only where the rule requires it and is immutable once recorded.
- Rule configuration is validated for the supported immediate-event schema. Scheduled reminders, lead-time processing, repeats, quiet hours and escalations are explicitly not enabled; no email integration.
- Rollback-only notification test passed: PM received CR submitted notification; Finance received first sequential approval notification; Team Lead received it only after Finance approval; Finance marked read and acknowledged with timestamps stamped; updating a rule incremented its version and archived the previous snapshot. CR reached Approved stage; transaction rolled back.
- No test users/projects/CRs/rules/notifications persisted. Deliverable notification triggers are installed but require a separate event-specific integration test. Test used simulated claims, not signed-JWT HTTP.
- Security Advisor remains at two pre-existing public lifecycle SECURITY DEFINER warnings and one intentional private formula-template INFO. Performance Advisor returned to 19 unindexed-FK notices, all on pre-existing lifecycle/financial tables; no duplicate index warning remains. Unused-index notices are expected on the empty application database.
- Total live migration count: 90. The clean replay of 87 migrations and frontend build passed before migrations 088–090. Full replay and build must be rerun at the latest branch head.
- Notification inbox/rule screens, CR/deliverable screens, scheduled reminders/escalations, email, milestone re-baseline approval/application and real signed-JWT/API/Storage tests remain outstanding. No merge or deployment. Staff Time & Performance remains untouched.
- Detailed implementation: docs/database/CR_DELIVERABLES_MILESTONES_NOTIFICATIONS_BACKEND_FOUNDATION.md.


## PM-only Change Request decision model — 21 November 2026

- User decision confirmed: the assigned Project Manager is the sole CR decision-maker. No CR route approval, Finance approval, Team Lead approval, or sequential/parallel approval stages.
- Applied migrations 091–093: 20261121123154_cr_project_manager_only_decision_model, 20261121123213_remove_legacy_cr_finance_approval_gate, 20261121123320_cr_pm_only_variation_guard_and_assignment_lock.
- New RPCs: submit_project_change_request and decide_project_change_request. Submission validates required impact assessments and an active assigned PM. Only that assigned PM may accept/reject; requester self-decision is blocked; decision reason, actor and timestamp are recorded.
- Legacy CR transition RPC disabled; approval-assignment and self-approval triggers removed; approval table retained as historical-only with client writes revoked. Approval-needed routing removed from CR notifications.
- Finance/technical impact remain assessment information. Removed Finance approval requirement from CR submission and CR-linked contract variation application. Contract/currency/variation matching and atomic financial/schedule application remain enforced.
- Assigned PM is immutable after submission. PM acceptance applies linked variation and schedule changes atomically; original baseline remains preserved.
- Exact SQL source matched live ledger for migrations 091–093. Security Advisor introduced no new CR-related warnings; two pre-existing public lifecycle SECURITY DEFINER warnings and one intentional private formula-template INFO remain. Performance Advisor retains 19 pre-existing lifecycle/financial unindexed-FK notices.
- No Auth users, projects or CRs exist in the database, so signed-JWT role journey tests and real fixture-based positive/negative tests remain outstanding. Do not claim end-to-end verification.
- Full clean replay of all 93 migrations and latest frontend build remain outstanding. No merge, no deployment. Staff Time & Performance remains untouched.
- Detailed implementation: docs/database/CR_DELIVERABLES_MILESTONES_NOTIFICATIONS_BACKEND_FOUNDATION.md.


### Migration ledger correction — 21 November 2026

- A subsequent live-ledger count confirmed 95 applied migrations (including the already-applied milestone re-baseline migration and the four PM-only CR refactor migrations). This count supersedes earlier 93/94 references in this checkpoint sequence.
- Added migration 20261121123531_revoke_legacy_cr_approval_helpers to revoke authenticated/service-role execution of obsolete approval and Finance trigger helpers. Its SQL source matches the live migration ledger exactly.
- Catalog verification confirms the legacy CR transition RPC and obsolete approval helper functions are not executable by authenticated users. The only active CR submission/decision API wrappers are the new PM-only SECURITY INVOKER RPCs.
