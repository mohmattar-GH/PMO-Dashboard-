# PMO Dashboard — Executive Project Portfolio Management

A standalone, enterprise-oriented Project Portfolio Management (PPM) platform for project execution, portfolio oversight, and CEO-level weekly reporting.

## System boundaries

- GitHub repository: `mohmattar-GH/PMO-Dashboard-` — application source, database migrations, architecture, tests, and project documentation.
- Supabase project: `Executive PPM Platform` (`oihawkpbtgqxxliaamxs`) — dedicated backend for this platform.
- Existing Staff Time & Performance application and its Supabase project are out of scope and must not be modified.
- Production publishing/deployment is reserved for explicit user approval.

## Product outcomes

1. Maintain reliable project records across contracts, schedules, activities, milestones, finance, licenses, risks, issues, decisions, and weekly updates.
2. Provide a portfolio-wide CEO dashboard with drill-down to source records.
3. Provide independent master schedule and payments/risk exposure timelines.
4. Preserve weekly reporting snapshots and historical context.
5. Make KPI definitions, formulas, weights, thresholds, status mappings, date rules, and calculation methods configurable through a governed configuration center.

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

## Initial delivery sequence

1. Architecture, requirements, data model, security model, and acceptance criteria.
2. Configurable reporting rules and project-management foundation.
3. Master schedule and payments/risk timelines.
4. CEO dashboard, weekly snapshots, and exports.
5. Security, functional, regression, and acceptance testing.
6. Operational documentation and handover.

See [Product Requirements](docs/requirements/PRD.md) and [Architecture](docs/architecture/ARCHITECTURE.md).

## Status

Repository initialized with the project charter and baseline requirements. Application implementation and Supabase schema are not yet represented as completed work.
