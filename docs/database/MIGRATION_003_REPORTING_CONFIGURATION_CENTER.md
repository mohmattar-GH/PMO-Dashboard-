# Migration 003 — Reporting Rules & Configuration Center

Status: applied to Supabase project `oihawkpbtgqxxliaamxs` on 14 November 2026.

## Objects created
- `public.reporting_configuration_sets`: global or project-scoped configuration containers.
- `public.reporting_configuration_versions`: numbered versions, effective periods and lifecycle metadata.
- `public.reporting_dimensions`: configurable performance dimensions and weights.
- `public.kpi_definitions`: configurable KPI metadata, calculation method, formula template, source mapping, parameters and weight.
- `public.reporting_rule_parameters`: typed JSONB parameters and validation metadata.
- `private.reporting_configuration_audit`: private audit-event storage.

## Security
- RLS enabled on every table.
- Authenticated users receive SELECT only.
- Global published configurations are readable to signed-in users; project-scoped configuration is restricted to active project members. Configuration governance roles can inspect draft/version states.
- Writes are intended for trusted backend/service-role workflows only. Never put service-role credentials in browser code.
- Published versions and their child definitions are immutable through database triggers, except that a published version can be marked superseded without changing other header fields.
- Private audit tables have explicit deny policies for client roles.

## Important incomplete work
- Automatic audit capture is not wired yet.
- Backend authorization and submit/approve/publish workflows are not implemented.
- Formula templates are stored as metadata; no formula evaluator exists. Formula evaluation must use validated allowlisted templates, never arbitrary SQL/user code.
- Cross-user JWT/RLS tests are outstanding.
- No starter configuration data has been seeded.

## Advisor results after Migration 004
- Security: no findings.
- Health: no findings.
- Performance: INFO-level unused-index notices only; there is no representative workload yet.

Migration 004 added seven FK indexes and explicit client-role deny policies to private audit tables.
