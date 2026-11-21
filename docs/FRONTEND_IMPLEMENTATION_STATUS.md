# Frontend Implementation Status

Updated: 21 November 2026

## Current verified state — 21 November 2026\n- Frontend build run 642 passed TypeScript and Vite production build.\n- Clean-environment replay run 305 passed all 112 archived migrations; live ledger also contains 112.\n- PR #1 remains draft/unmerged; no deployment.\n- No Auth users/projects/business records exist, so authenticated CRUD and role journeys are not yet tested.\n\n## Delivery slice 1 — React application foundation

- React 18, TypeScript, Vite and lucide-react application shell.
- Responsive Executive Overview, project register preview, health/phase distribution, management attention, risk exposure, restricted finance panel, layout editor preview and CEO presentation shell.
- Demo content is visibly marked and is not represented as live project data.
- GitHub Actions production build workflow is configured.

## Delivery slice 2 — Supabase authentication foundation

- Added pinned `@supabase/supabase-js` 2.119.2 and a browser client using the project URL and publishable key from environment variables.
- Added a sign-in gate using Supabase email/password authentication, persistent sessions, automatic token refresh and auth-state handling.
- On sign-in, the app reads the authenticated user's own active profile, global role assignments and project memberships through RLS-protected queries.
- Role names shown in the shell are derived from database assignments, not editable user metadata.
- Inactive/missing platform profiles are denied access.
- No service-role key is included in browser code.
- Added `.env.example` for local configuration.

## Important boundaries

- Authentication UI and identity loading are implemented; real-user sign-in, session expiry, password recovery and role-specific end-to-end tests remain to be run against provisioned Auth users.
- Executive Overview now reads the project register from Supabase using the authenticated browser session and existing project/client RLS policies. The overview does not use demo project rows.
- The local finance preview control is not an authorization mechanism. Existing database policies require a dedicated audit and adjustment before financial information can be exposed to executive users. A review found executive-viewer role access in several finance-related SELECT policies; this must be corrected with explicit administrator-granted visibility before connecting finance data.
- No operational CRUD, persistent dashboard layouts, notification delivery, exports or complete module workflows are claimed complete.
- No deployment has been performed.

## Next implementation sequence

1. Finish database authorization review, especially explicit financial visibility grants for executive users.
2. Implement a RLS-safe portfolio data contract and connect the Executive Overview to live data, replacing all demo values.
3. Build Project Workspace and project register.
4. Implement schedule, finance, risk and timeline modules.
5. Implement Change Requests, Deliverables, Milestones and Notifications.
6. Implement configuration center, versioned layout governance, reporting snapshots and presentation mode.
7. Run real JWT role-specific RLS, integration, accessibility and regression tests before any production readiness claim.

## Explicit exclusions

- Do not modify the separate Staff Time & Performance application or its Supabase project.
- Do not merge or deploy without explicit user approval.


## Authentication implementation note

The browser app now requires a Supabase-authenticated session and an active database profile before showing the workspace. Configure the two variables in `.env.example` for local execution. This gate is a frontend convenience; every data request remains protected by database RLS.


## Security update — 21 November 2026

- Supabase migration 054 adds administrator-controlled global/project-scoped executive financial access grants with reason, expiry, one-time revocation and retained audit fields.
- RLS now requires an active grant for Executive Viewer access to project contracts, project financial terms, invoices, cash transactions, invoice allocations and contract variations. Finance and project-management role access is retained.
- Invoice balance view now uses `security_invoker = true`.
- Security Advisor returned no findings after this migration.
- Not production-ready: executive access to historical `project_snapshots.snapshot_payload` and `snapshot_metric_values` still needs KPI sensitivity classification and a safe snapshot contract. Real JWT role-specific tests are pending; there are currently no provisioned app users.
- Frontend stylesheet build failure fixed in commit `13887dccc9bbdda957a77faf9bd87ca15565ff84`; GitHub Actions run 29 passed.


## Historical snapshot access hardening — 21 November 2026

- Live Supabase migrations 055 and 056 now restrict authenticated access to safe snapshot metadata columns; opaque project and portfolio JSON payloads are withheld.
- Executive Viewer access to unclassified snapshot KPI values has been removed. Platform Admin and project-membership access paths remain.
- Added security-invoker views `project_snapshot_index` and `portfolio_snapshot_index` for safe snapshot metadata retrieval.
- Security Advisor returned zero lints after the changes.
- Database currently has no KPI definitions and no snapshot rows. Real JWT/RLS tests remain pending until application users are provisioned.
- Base snapshot table wildcard selects are intentionally unavailable to authenticated clients; consume the index views with explicit fields.


## Live portfolio data connection — 21 November 2026

- Added `src/LivePortfolioOverview.tsx` and connected the Executive Overview to the live `public.projects` table using the authenticated Supabase client.
- Query is read-only and relies on existing Supabase RLS. It retrieves project code, name, lifecycle status, start/target-end dates, manager assignment indicator and related client name. It does not use a service-role credential.
- The UI includes loading, query-error, empty-register and filtered-search states. Project totals are derived from the returned RLS-filtered rows; no synthetic projects are inserted.
- Replaced the fixed demo reporting-period/snapshot banner with a live operational-view / no-finalized-snapshot indicator.
- Dashboard layout editing is now shown only to users with the database-derived `platform_admin` role. The current layout editor remains a local preview and is not persistent.
- The database currently has no project rows and no provisioned Auth users, so the real project query cannot yet be exercised through an authenticated browser session. This is a truthful empty state, not a successful end-to-end user test.
- Project lifecycle status is not treated as configurable project phase or calculated health. Phase, health, verified progress, milestone achievement, risk rollups and decisions remain explicitly Not Reported until their governed data contracts are connected.
- GitHub Actions run 42 passed for the previous frontend foundation commit. The GitHub connector does not expose push-triggered runs for the latest frontend commits, so the new slice's CI result remains unverified at this checkpoint.
- No schema changes, user provisioning, merge or deployment were performed in this slice.


## Snapshot-backed project health — 21 November 2026

- Executive Overview now reads `project_snapshot_index`, the security-invoker metadata-only view added in migration 056. It requests only `project_id`, `calculated_health` and `created_at`; it does not request raw snapshot payloads or KPI metric values.
- Snapshot rows are fetched in pages of 1,000, newest first. The latest visible calculated-health status per project is used; projects without a visible snapshot, or with an unrecognized/missing status, are counted as Not Reported.
- The project register now displays calculated health separately from lifecycle status and PM-reported health. The phase column explicitly reads Not configured because no lifecycle-template/phase-assignment schema exists yet.
- Supabase Security Advisor still returns zero security lints after the frontend-only change. No database schema or permissions were modified.
- KPI metric values are intentionally not exposed to Executive Viewer because the current snapshot metric table has no sensitivity classification. The KPI engine exists, but no KPI definitions/configuration rows are published. KPI cards remain unreported until a safe classified KPI read contract is designed.
- There are currently zero project records, zero snapshot records, zero KPI definitions/configurations and zero Auth users. Live browser behavior and role-specific access still require real-user tests.


## CI verification — 21 November 2026

- GitHub Actions workflow run `44831475659` completed successfully for the latest frontend health-integration commit (`ace40388a4e54ada500e96e6c10d3d5f2733f74d`).
- Dependency installation and the TypeScript type-check/production build steps both passed.
- This verifies compilation/build only. It does not replace authenticated-browser, role-specific RLS, or end-to-end workflow testing.


## Configurable project lifecycle backend — 21 November 2026

- Applied Supabase migrations 057 and 058 to create the configurable project lifecycle model. No default phase names or templates were seeded.
- Added global/project-scoped lifecycle templates; numbered draft/published/retired versions; ordered active/inactive phase definitions; explicit transition rules; one active lifecycle assignment per project; and appendable phase history with planned, forecast and actual dates plus progress percentage.
- Added administrator-only lifecycle assignment RPC and Project Manager / Platform Administrator phase-transition and current-phase update RPC. Transition reasons are controlled by each configured transition rule.
- Published/retired versions are immutable; phase and transition definitions are editable only in draft versions. Lifecycle assignment/history records are audited.
- RLS is enabled on all six new tables. Added `project_current_phase` as a security-invoker view. Global template scope is stored separately from the consuming project ID to preserve correct foreign-key integrity for global templates.
- Verification: RLS and policies confirmed on all six tables; a transaction-scoped fixture created a global draft template, two phases and allowed transition rules, then rolled back; unauthenticated RPC calls were rejected.
- Positive JWT tests remain outstanding: the database currently has zero projects and zero Auth users. No production project can yet be assigned a lifecycle.
- Supabase Security Advisor reports two WARN findings because the two authenticated RPC endpoints are SECURITY DEFINER. This is intentional for atomic assignment/history writes without granting direct table writes; both functions use an empty search_path, explicitly validate the active user/profile and role, and revoke execution from anon/PUBLIC. Real role-specific JWT testing is still required.
- The dashboard and existing timeline read models have not yet been connected to the new phase data. Until a lifecycle is configured and assigned, phase remains Not configured / Not Reported.
- Design reference: `docs/database/PROJECT_LIFECYCLE_PHASE_MODEL.md`. Migration 058 SQL is archived in `supabase/migrations/20261120225145_migration_058_global_lifecycle_assignment_scope_fix.sql`; the matching migration 057 SQL source still needs to be archived before clean-environment replay can be claimed.
- PR #1 remains draft and unmerged. No deployment or user provisioning was performed.


## Executive phase read integration — 21 November 2026

- Added migrations 059 and 060: active Executive Viewer users can read non-financial lifecycle phase information; added the security-invoker `project_phase_change_log` view for recent phase changes.
- Connected `src/LivePortfolioOverview.tsx` to `project_current_phase` and `project_phase_change_log`.
- Executive Overview now derives Project Phase Distribution using the configured phase display order, shows unassigned projects separately, and displays the latest 10 phase transitions.
- Project Register now shows current phase, reported phase progress and forecast completion date when data exists. Missing phase assignment remains Not configured.
- Both phase views are confirmed as `security_invoker=true`; direct SQL read checks succeeded (currently empty because there are no projects or phase assignments).
- Security Advisor still reports the two intentional authenticated SECURITY DEFINER RPC warnings. No anon/PUBLIC execute access is granted. Real JWT role tests remain outstanding.
- The latest frontend changes have not yet been verified by an accessible CI run; the GitHub workflow-run connector only returned PR-triggered runs and returned no run for the latest commits. Do not claim build success for this slice.


## Project register operational editors and project-scoped authorization — 21 November 2026

- Integrated the existing governed `ProjectOperationsEditor` into the Project Profile Schedule and Risk tabs. The schedule workspace now supports PM/Platform Admin activity creation and management, while Team Leads can view and update only activities assigned to their own user ID. Baseline dates are captured on creation and are not editable on update; approved revised dates remain under governed change control.
- The Risk tab now provides full risk and license registers with PM/Platform Admin create/edit actions. Risk fields include category, cause, consequence, response, mitigation, contingency, probability/impact, owner, review/resolution dates, trend and escalation. Risk score is protected from manual edits, but the current schema has no writer that populates project_risks.risk_score. The Top 5 panel therefore remains Not Reported until a configurable per-risk scoring process is implemented. License fields include provider, type, quantity/unit, start/expiry/renewal dates, cost/currency, owner and status.
- Operational status values are editable text rather than fixed frontend enums. Risk trend remains constrained to the supported database values. The UI does not hardcode a 1–5 probability/impact scale; levels must be positive and the governed reporting configuration determines scoring.
- Integrated role-aware contractual and financial terms editors in the Project Profile. Contract changes are PM/Platform Admin controlled; financial terms are restricted to project Finance, Finance Admin and Platform Admin according to the existing database policies. Original contract value/currency and approved variation totals are protected by the existing database integrity rules.
- Corrected Change Request permissions to evaluate the active user's role on the selected project. Impact assessments are editable by project PM/Finance or the corresponding global administrator roles; schedule proposals and linked variations are PM/Platform Admin controlled; assigned implementation owners can update progress, while PM/Admin controls assignment, verification and closure. Schedule proposal inserts now include the authenticated creator ID required by the table.
- Corrected Deliverables and Milestones create permissions to filter projects and actions by the user's actual project PM membership or Platform Admin role. Document upload access no longer treats a PM role in an unrelated project as sufficient.
- CR financial impact fields, currency, linked contract variation and structured activity/milestone schedule proposals were already present in the CR workspace; this pass corrected role visibility and save behavior, including clearing optional impact values.
- Frontend build workflow run 536 passed on commit `e50682cbafab288ca083d9d344a9dcfc860d73ec` (TypeScript type-check and Vite production build).
- Historical checkpoint note: the ledger was at 109 migrations and replay run 246 was in progress at that time. This is superseded by the current 112-migration ledger and successful clean replay run 305.
- No Auth users, projects or operational test fixtures currently exist in the live project. Therefore authenticated end-to-end role journeys and real record create/update flows remain unverified. Existing RLS is retained as the enforcement layer; UI gating is not treated as a substitute.
- PR #1 remains draft and unmerged. No deployment. Staff Time & Performance remains untouched.


## Reporting configuration and weekly snapshot archive — 21 November 2026

- Added a Configuration Center with separate Lifecycle and Reporting Rules/KPIs workspaces. Platform Administrators can access both; Configuration Stewards can create/edit/submit drafts; Configuration Approvers can approve, publish and supersede.
- Reporting Configuration UI uses the existing `reporting-config-governance` Edge Function and the governed database RPC. It supports global and project-scoped configuration sets, draft versions, dimensions, KPI definitions, allowlisted formula templates, source mappings, parameters, weights, thresholds, date basis and missing-data status.
- Draft rule arrays are editable through structured JSON editors because the backend validates the full versioned rule schema. Published versions are read-only. Creating a successor version from the latest published/superseded version copies the prior dimensions, KPI definitions and rule parameters into the new draft.
- Added version metadata in the UI: change summary, creator, submitter, approver, publisher and their timestamps. Every create/save/submit/approve/publish/supersede action goes through the existing audited governance function.
- Added Reports & Snapshots workspace. Platform Administrators can create reporting cycles, close cycles after cutoff, build snapshots only when an effective published global reporting configuration exists, and finalize building snapshots. Executive Viewers receive read-only access to available snapshot history.
- Snapshot UI reads only the existing restricted `portfolio_snapshot_index` and `project_snapshot_index` security-invoker views. It does not query protected raw portfolio/project snapshot payloads or expose restricted metric-value tables. Summary counts are derived from the authorized index rows.
- Added migration `20261121205801_reporting_cycles_platform_admin_read_access.sql` so Platform Administrators can read open reporting cycles before a snapshot exists. No direct cycle write permissions were granted; create/close/build/finalize remain guarded Edge Function/RPC actions.
- Live Supabase migration ledger now contains 112 applied migrations. Clean-environment replay run 305 passed; all 112 archived migrations replayed successfully.
- Frontend build workflow run 642 passed on commit `e7391ab2ef9e2583f6a229de78e914d9b73015a1` (TypeScript check and Vite production build).
- Authenticated reporting configuration and snapshot workflows remain unverified because the live project has no Auth users, projects or published reporting configuration. Do not create a real weekly cycle or publish default KPI assumptions without explicit business decisions.
- Added migration `20261121210429_reporting_cycles_merge_read_policy.sql` to combine the reporting-cycle read conditions into one policy. Platform Administrators can read open cycles; Executive Viewers can read cycles only when a portfolio snapshot exists. This removes the multiple-permissive-policy warning introduced by the initial Admin read policy.
- Live security advisor after the policy merge shows no new security warnings. Remaining findings are the intentional private formula-template table with no client policies (INFO) and two pre-existing lifecycle SECURITY DEFINER RPC warnings. Performance advisor retains 19 unindexed foreign-key notices and 83 unused-index notices; no new reporting-cycle policy warning remains.

- Per-risk score population is now implemented through versioned `risk_scoring` parameters and the allowlisted `weighted_sum_v1` formula. The Top 5 Risk Watchlist ranks calculated scores only; no frontend fallback formula is used.
