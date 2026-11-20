# Frontend Implementation Status

Updated: 20 November 2026

## Delivery slice 1 — React application foundation

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
