# Project Register Operational Editors Checkpoint — 21 November 2026

## Repository and environment
- Repository: `mohmattar-GH/PMO-Dashboard-`
- Branch: `feature/ppm-frontend-foundation`
- Pull request: #1 — draft, unmerged
- Supabase: `Executive PPM Platform` (`oihawkpbtgqxxliaamxs`), eu-central-1
- Live migration ledger: 109 applied migrations
- Separate Staff Time & Performance repository/project: untouched

## Completed in this slice
- Integrated `ProjectOperationsEditor` into Project Profile Schedule and Risk tabs.
- PM/Platform Admin can create and manage project schedule activities, risks and licenses.
- Team Leads can update only activities assigned to their own user ID; they cannot change activity baselines.
- Activity baseline dates are write-once from the frontend; approved revised dates remain governed.
- Risk score is reporting-engine calculated; risk probability/impact levels are positive numeric values without a hardcoded scale.
- Risk and license status values are editable rather than fixed UI enums.
- Contract and financial editors remain connected to the Project Profile and rely on existing RLS and database integrity guards.
- CR impact assessment, financial amount/currency, linked variation and schedule-change UI are present. This pass corrected project-scoped authorization and schedule proposal creator attribution.
- Deliverables and Milestones creation now filter to projects where the user is PM, unless the user is Platform Admin.
- Project-specific PM/Finance checks now govern CR impact assessment, schedule proposal, linked variation, implementation, verification and closure controls.

## Verification
- Frontend workflow run 536 passed: TypeScript type-check and Vite production build.
- Clean migration replay run 253 was in progress at checkpoint time. Await completion before stating full migration replay passed.
- Live Supabase currently has no Auth users, projects, milestones, deliverables or notifications. Real authenticated role-journey tests and CRUD browser tests are therefore not yet possible.
- No deployment or PR merge performed.

## Remaining release gates
1. Complete clean migration replay for all 109 migrations.
2. Provision controlled test identities and project fixtures in an isolated test environment.
3. Run positive and negative signed-JWT role tests for PM, Finance, Team Lead, Platform Admin and Executive Viewer.
4. Run browser tests for project creation, contract/finance edits, activity assignment, risk/license CRUD, CR lifecycle, deliverable submissions/reviews/acceptance, milestone rebaseline and notification inbox.
5. Continue outstanding general project-profile editing, broader configurable dashboard widgets/KPI authoring and scheduled notification processing as separate implementation slices.


## Reporting configuration and weekly snapshot archive — 21 November 2026

- Added a Configuration Center with separate Lifecycle and Reporting Rules/KPIs workspaces. Platform Administrators can access both; Configuration Stewards can create/edit/submit drafts; Configuration Approvers can approve, publish and supersede.
- Reporting Configuration UI uses the existing `reporting-config-governance` Edge Function and the governed database RPC. It supports global and project-scoped configuration sets, draft versions, dimensions, KPI definitions, allowlisted formula templates, source mappings, parameters, weights, thresholds, date basis and missing-data status.
- Draft rule arrays are editable through structured JSON editors because the backend validates the full versioned rule schema. Published versions are read-only. Creating a successor version from the latest published/superseded version copies the prior dimensions, KPI definitions and rule parameters into the new draft.
- Added version metadata in the UI: change summary, creator, submitter, approver, publisher and their timestamps. Every create/save/submit/approve/publish/supersede action goes through the existing audited governance function.
- Added Reports & Snapshots workspace. Platform Administrators can create reporting cycles, close cycles after cutoff, build snapshots only when an effective published global reporting configuration exists, and finalize building snapshots. Executive Viewers receive read-only access to available snapshot history.
- Snapshot UI reads only the existing restricted `portfolio_snapshot_index` and `project_snapshot_index` security-invoker views. It does not query protected raw portfolio/project snapshot payloads or expose restricted metric-value tables. Summary counts are derived from the authorized index rows.
- Added migration `20261121205801_reporting_cycles_platform_admin_read_access.sql` so Platform Administrators can read open reporting cycles before a snapshot exists. No direct cycle write permissions were granted; create/close/build/finalize remain guarded Edge Function/RPC actions.
- Live Supabase migration ledger now contains 110 applied migrations. Clean-environment replay run 281 is in progress.
- Frontend build workflow run 589 passed on commit `15479162ed932bef35331a4fe696b1795a6d754e` (TypeScript check and Vite production build).
- Authenticated reporting configuration and snapshot workflows remain unverified because the live project has no Auth users, projects or published reporting configuration. Do not create a real weekly cycle or publish default KPI assumptions without explicit business decisions.
