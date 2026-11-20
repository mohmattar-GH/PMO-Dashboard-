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
- Dashboard content remains illustrative demo data. Live project and snapshot integration is not yet complete.
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
