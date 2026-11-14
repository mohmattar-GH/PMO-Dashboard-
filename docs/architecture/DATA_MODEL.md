# Initial Data Model Blueprint

This document describes logical entities, not an applied database migration. Names and relationships must be reviewed against detailed workflows before implementation.

## Identity and access

- `user_profiles`: user identity/display profile linked to Supabase Auth.
- `role_definitions`: controlled application roles.
- `user_role_assignments`: trusted role assignments, scope, effective dates, actor/audit metadata.
- `project_memberships`: project-specific user access and project role.
- `permission_audit`: permission and membership changes.

Authorization must not depend on user-editable Auth user_metadata.

## Portfolio and project records

- `clients`
- `projects`: project reference, client, owner, PM, team lead, lifecycle status, dates.
- `project_contracts`: contract metadata and terms.
- `contract_obligations`: obligation, due date, owner, evidence, status.
- `change_requests`: request, impact, approval status, approved variation details.
- `project_financials`: currency, original contract value, approved variation totals and derived/current value policy.
- `project_activities`: activity, owner, dependencies, weight, progress, status.
- `project_activity_date_versions`: original baseline, approved revised baseline, forecast, actual dates with version provenance.
- `project_milestones`: milestone definition and status.
- `project_milestone_date_versions`: date categories and approval provenance.
- `project_licenses`: license/provider/quantity/expiry/renewal/owner.
- `project_invoices`: invoice reference, amount, submission/due dates, status.
- `payments`: receipt reference, date, amount, currency.
- `payment_allocations`: allocations of payments to invoices; supports partial payments.
- `invoice_credits`: approved credits/adjustments with audit.
- `project_risks`: description, owner, probability, impact, status, trend, identified/resolution dates.
- `risk_assessments`: versioned assessments and configured score provenance.
- `risk_mitigations`: actions, owners, dates, progress, evidence.
- `project_issues`: issue and escalation lifecycle.
- `management_decisions`: decision required, owner, due date, outcome.
- `project_weekly_updates`: weekly narrative and PM outlook.
- `project_documents`: private Storage object metadata and source-record linkage.

## Reporting configuration and governance

- `reporting_scopes`: global, project, or permitted record scope.
- `reporting_dimensions`: configurable performance dimensions.
- `kpi_definitions`: KPI metadata, template identifier, source mapping, aggregation behavior.
- `calculation_templates`: allow-listed calculation method and parameter schema/version.
- `reporting_config_versions`: immutable configuration version, scope, effective period, approval state.
- `reporting_config_items`: dimension/KPI/rule parameter values within a version.
- `reporting_config_approvals`: submit/review/approve/reject workflow.
- `reporting_config_audit`: old/new values, actor, timestamp, reason, effective date.
- `project_health_overrides`: human-reported status, reason, evidence, actor, time; separate from calculated health.

## Reporting snapshots

- `reporting_cycles`: reporting period, cutoff, As-of Date, lifecycle.
- `weekly_portfolio_snapshots`: immutable portfolio-level snapshot and generation metadata.
- `weekly_project_snapshots`: immutable per-project KPI/status values.
- `weekly_snapshot_metric_details`: metric values, units, status, source lineage, formula/template version.
- `weekly_snapshot_config_links`: exact global/project configuration version identifiers used.

Snapshots are historical outputs; updates to live project data or configuration must not rewrite them.

## Timeline

- `timeline_categories`: governed configurable categories and display metadata.
- `timeline_custom_events`: only user-created events that do not originate from an operational record.
- Source-derived timeline items should be exposed through views/queries with a source type and source record ID, not copied into duplicate event rows.

## Cross-cutting database requirements

- Use UUID primary keys, foreign keys, appropriate unique constraints, and created_at/updated_at fields where appropriate.
- Use numeric/decimal types for money and explicit currency codes; do not use floating-point for financial values.
- Define timezone policy for timestamps and local-date semantics for contractual due dates.
- Add indexes for project_id, owner_id, status, due/forecast dates, reporting cycle, and common filter combinations after query design.
- Use soft deletion only where lifecycle/audit requirements justify it; do not obscure financial or audit history.
- Restrict direct mutation of immutable version and snapshot records.
- Enable and test RLS on all API-exposed tables.
- Keep private documents in controlled Storage buckets and authorize metadata/object access consistently.
