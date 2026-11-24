# PMO Dashboard — Executive Project Portfolio Management

A standalone Project Portfolio Management platform for project execution, portfolio oversight, and CEO-level weekly reporting.

## System boundaries

- GitHub repository: `mohmattar-GH/PMO-Dashboard-`.
- Dedicated Supabase project: `Executive PPM Platform` (`oihawkpbtgqxxliaamxs`).
- The existing Staff Time & Performance application and its Supabase project are strictly out of scope.
- Production publishing/deployment requires explicit user approval.

## Product outcomes

1. Maintain governed project records across contracts, schedules, activities, milestones, deliverables, change requests, finance, licenses, risks, decisions, and weekly updates.
2. Provide a CEO-ready portfolio dashboard with drill-down to source records.
3. Provide independent master schedule and payments/risk timelines.
4. Provide configurable Change Request, Deliverables, Milestones, and in-app Notification Centre workflows.
5. Preserve weekly reporting snapshots and historical context.
6. Make KPI definitions, formulas, weights, thresholds, status mappings, date rules, workflow rules, and calculation methods configurable through governed configuration.

## Non-negotiable design principles

- Configurable rules are data, not hardcoded business logic.
- Every configuration version is auditable and effective-dated.
- Each weekly snapshot records the exact configuration version used; historical snapshots are not silently recalculated.
- Original baseline, approved revised baseline, forecast, and actual dates remain distinct.
- Missing or insufficient data is never interpreted as Green.
- Calculated health and PM-reported/approved status are stored separately; overrides require a reason and audit trail.
- Timeline views derive from source records; only genuinely custom events are stored as independent timeline events.
- Supabase Row Level Security (RLS) protects exposed tables and private storage resources.
- No service-role secret is exposed to browser code.

## Current implementation status — 24 November 2026

### Supabase backend

The dedicated Supabase project has migrations and database foundations for identity and access, project registry and memberships, reporting configuration and snapshots, project operations, lifecycle and phase history, Change Requests, deliverable submissions and PM acceptance, notifications, dashboard layouts, and master-schedule events.

The latest verified inspection (23 November) confirmed RLS enabled on the listed public tables. No platform administrator, project memberships, or operational records had been provisioned at that inspection. The database foundation is not evidence of completed end-to-end workflows.

### Frontend

The repository contains an initial Next.js App Router / React / TypeScript application increment, including:

- Supabase server/browser clients and session refresh.
- Email/password login and sign-out.
- Responsive application shell with the approved 12-section navigation.
- Executive Overview server-side reads for project counts, milestones, open Change Requests, unaccepted deliverables, unread notifications, and latest portfolio snapshot.
- An access-setup warning when a signed-in user has no active global role or project membership.

Other navigation destinations are not yet complete operational modules. The application is not a first-release candidate until modules, secure provisioning, authorization, and end-to-end testing are completed.

### CI status

The latest inspected Frontend CI run on `main` was run 6, commit `f998019adb09947e2444d61a49f08440fb0ba54d`, and failed at the Node.js setup step because npm caching was configured without a dependency lockfile. Type-check and production-build steps were skipped, not passed. The workflow has been corrected to remove the unsupported cache dependency; a new run must verify both checks before CI can be considered green.

### UI and delivery gate

The first-round UI blueprint in `docs/UI_REVIEW_ROUND_1_2026-11-22.md` was accepted on 23 November 2026 as the baseline for the first software release. Post-release UI changes may be requested after review of the first release.

## Delivery sequence

1. Establish secure platform-admin provisioning without weakening RLS.
2. Validate authentication, global roles, project memberships, and positive/negative authorization cases.
3. Implement Projects Register and Project Workspace.
4. Implement schedule, milestone, deliverable, and Change Request workflows.
5. Implement notifications, reporting/snapshots, configuration, and administration.
6. Implement finance-aware views only with explicit backend authorization; complete exports.
7. Complete CI, browser, RLS, workflow, regression, and acceptance testing before first-release sign-off.

See `docs/requirements/PRD.md`, `docs/architecture/ARCHITECTURE.md`, `docs/UI_SCREEN_SPECIFICATIONS.md`, `docs/UI_REVIEW_ROUND_1_2026-11-22.md`, and the latest project checkpoint.

