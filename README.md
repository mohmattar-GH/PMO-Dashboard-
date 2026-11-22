# PMO Dashboard — Executive Project Portfolio Management

A standalone, enterprise-oriented Project Portfolio Management (PPM) platform for project execution, portfolio oversight, and CEO-level weekly reporting.

## System boundaries

- GitHub repository: `mohmattar-GH/PMO-Dashboard-` — application source (when implemented), database migrations, architecture, tests, and project documentation.
- Supabase project: `Executive PPM Platform` (`oihawkpbtgqxxliaamxs`) — dedicated backend for this platform.
- Existing Staff Time & Performance application and its Supabase project are out of scope and must not be modified.
- Production publishing/deployment is reserved for explicit user approval.

## Product outcomes

1. Maintain reliable project records across contracts, schedules, activities, milestones, deliverables, change requests, finance, licenses, risks, decisions, and weekly updates.
2. Provide a portfolio-wide CEO dashboard with drill-down to source records.
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
- Supabase Row Level Security (RLS) protects every exposed table and private storage resource.
- No service-role secret is exposed to browser code.

## Verified implementation status — 22 November 2026

### Supabase backend

The dedicated Supabase project contains an applied migration history covering:

- Identity, role assignments, project registry, and project memberships.
- Versioned reporting configuration, KPI evaluation, and weekly reporting snapshots.
- Operational project records: contracts, financial terms, activities/dependencies, milestones, invoices/payments, risks, licenses, weekly updates, decisions, and documents.
- Project lifecycle and phase configuration/history.
- Change Request workflow, impact assessment, approvals, controlled application, implementation/verification/closure.
- Deliverable submissions, reviews, and Project Manager acceptance actions.
- In-app notification rules and user inbox.
- Administrator-managed Executive Dashboard layouts and custom master-schedule timeline events.

The current database inspection confirmed RLS enabled on all listed public tables. No project records, memberships, or user profiles have been provisioned yet; most operational tables are empty. A database foundation is not the same as a populated or user-accepted application.

### GitHub

Database migration SQL, Edge Function source, architecture, requirements, screen specifications, wireframes, and checkpoint documentation are committed in this repository.

The repository root currently contains documentation and the `supabase/` source tree; no frontend application source is present yet.

### UI and delivery gate

The approved primary navigation and the full first-round screen blueprint are documented in `docs/UI_REVIEW_ROUND_1_2026-11-22.md`. The navigation approval does not yet constitute approval of every screen interaction. Do not begin frontend implementation or select a frontend framework/component library until the user approves the complete screen structure and interaction approach.

Production publishing/deployment remains reserved for explicit user approval.

## Initial delivery sequence

1. Complete backend verification, including positive and negative authorization tests with real test users.
2. Review and approve the complete dashboard, project workspace, tracker, notification, and administrator configuration screen designs.
3. Implement the frontend against the approved screen specifications.
4. Complete end-to-end, security, regression, and acceptance testing.
5. Prepare operational documentation and handover.

See `docs/requirements/PRD.md`, `docs/architecture/ARCHITECTURE.md`, `docs/UI_SCREEN_SPECIFICATIONS.md`, `docs/UI_REVIEW_ROUND_1_2026-11-22.md`, and `docs/PROJECT_CHECKPOINT_2026-11-22.md`.
