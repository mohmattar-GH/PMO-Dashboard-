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
