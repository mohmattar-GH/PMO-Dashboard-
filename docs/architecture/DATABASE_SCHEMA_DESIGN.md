# Relational Database Schema Design

Status: logical design for review — no SQL has been applied.
Target database: Executive PPM Platform, PostgreSQL 17.

## 1. Design principles

- PostgreSQL relational model with UUID primary keys, explicit foreign keys and check constraints.
- Money uses `numeric(19,4)` (or a reviewed currency-specific precision), never floating point; every monetary value carries an ISO currency code.
- Timestamps are stored as `timestamptz` in UTC. Contractual/reporting dates that are calendar dates are `date` values with an explicit project/reporting timezone.
- Operational records are authoritative. Dashboards and timelines are projections, not duplicate stores.
- Configuration versions, approvals, audit events, approved baselines and reporting snapshots are immutable after publication/approval.
- Soft deletion is not the default for financial/audit/history tables; use explicit lifecycle statuses and archival.
- Every child record has a direct `project_id` where useful for efficient authorization and is constrained to a valid parent/project relationship.
- Database constraints protect invariants even when requests bypass frontend validation.

## 2. Proposed schema namespaces

Initial recommendation:
- `public`: only explicitly granted client-facing tables/views/RPCs required by the selected frontend.
- `private`: internal audit, authorization internals, calculation support and privileged metadata not directly exposed by PostgREST.
- Storage: private buckets only, with object policies aligned to project membership and document metadata.

The exact API exposure and grants will be verified against the project's Data API settings before implementation. No anonymous business-data grants are planned.

## 3. Identity and access

| Entity | Key fields and relationships | Purpose |
|---|---|---|
| user_profiles | id = auth.users.id, display_name, job_title, is_active | Non-authoritative profile details |
| app_role_definitions | code, name, description, is_system_role | Controlled role catalogue |
| user_global_role_assignments | user_id, role_code, effective_from/to, status, assigned_by | Trusted cross-project role assignment |
| project_memberships | project_id, user_id, project_role, effective_from/to, status | Project-scoped access |
| permission_audit | actor_id, subject_user_id, action, before/after, reason, created_at | Audit of role and membership changes |

Authorization must never use user-editable Auth `user_metadata`.

## 4. Portfolio and project master data

| Entity | Key fields and relationships | Purpose |
|---|---|---|
| clients | client_code, name, status, contacts metadata | Client/customer directory |
| portfolios | portfolio_code, name, owner_id, status | Optional grouping above projects |
| projects | project_code, name, client_id, portfolio_id, pm_id, lifecycle_status, start_date, target_end_date, timezone, currency_code | Master project registry |
| project_team_assignments | project_id, user_id, responsibility, start/end, status | Operational assignment distinct from authorization membership |
| project_status_history | project_id, old_status, new_status, reason, actor_id, changed_at | Lifecycle audit |

Project code is unique within the platform. Project status values are reference/configuration data, not hardcoded UI labels.

## 5. Contracts and change control

| Entity | Key fields and relationships | Purpose |
|---|---|---|
| project_contracts | project_id, contract_ref, signed_date, start/end dates, currency, contract_value, status, document_id | Contract header |
| contract_obligations | contract_id, obligation_type, description, due_date, owner_id, status, evidence_document_id | Trackable contractual obligation |
| change_requests | project_id, request_ref, description, requested_by, submitted_at, status, schedule/financial impact | Change request lifecycle |
| change_request_approvals | change_request_id, approver_id, decision, decided_at, comments | Approval chain |
| contract_amendments | contract_id, change_request_id, amendment_ref, approved_value_delta, effective_date, status | Approved commercial changes |

Approved amendments should not overwrite original contract value; derive current approved value from the original plus approved amendments or preserve a controlled financial ledger.

## 6. Schedule, activities and milestones

| Entity | Key fields and relationships | Purpose |
|---|---|---|
| project_activities | project_id, parent_activity_id, activity_code, name, owner_id, WBS path/order, progress_value, progress_method_id, status, weight, start/end actuals | Work breakdown and execution |
| activity_dependencies | predecessor_activity_id, successor_activity_id, dependency_type, lag | Schedule network |
| activity_date_versions | activity_id, date_type, start_date, finish_date, version_no, approval_id, effective_at, recorded_by | Separate baseline/revised baseline/forecast/actual dates |
| project_milestones | project_id, milestone_code, name, owner_id, status, weight | Milestone definition |
| milestone_date_versions | milestone_id, date_type, target_date, version_no, approval_id, effective_at | Milestone date history |
| schedule_approvals | project_id, approval_type, reason, submitted_by, approved_by, status, decided_at | Re-baseline and controlled schedule changes |
| progress_updates | project_id, activity_id or milestone_id, as_of_date, reported_progress, notes, reported_by | Time-stamped progress observations |

Date types are controlled values: original_baseline, revised_baseline, forecast, actual. Enforce one current approved baseline version per applicable scope/date type, but retain all historical versions. Revised baseline requires explicit approval and reason. Forecast updates never alter baseline dates.

Progress aggregation, weights, calendars, working days, schedule variance and milestone criticality are controlled by reporting configuration versions.

## 7. Finance

| Entity | Key fields and relationships | Purpose |
|---|---|---|
| project_financial_accounts | project_id, currency_code, approved_contract_value, financial_owner_id | Project finance settings |
| invoices | project_id, contract_id, invoice_ref, invoice_date, submission_date, due_date, amount, currency_code, status | Invoice lifecycle |
| invoice_status_history | invoice_id, old_status, new_status, changed_by, changed_at, reason | Invoice lifecycle history |
| payments | project_id, payment_ref, received_date, amount, currency_code, payment_method, evidence_document_id | Incoming payment |
| payment_allocations | payment_id, invoice_id, allocated_amount, currency_code, allocated_at | Supports partial/multiple allocations |
| invoice_adjustments | invoice_id, adjustment_type, amount, reason, approval_id | Credit/debit adjustments |
| financial_approvals | target_type, target_id, approval_type, approver_id, decision, decided_at | Controlled financial approval |

Constraints must prevent cross-project allocations and invalid currency mismatches unless an explicit FX conversion record is introduced. Payment received and payment allocated are separate concepts. Outstanding balance is calculated from invoice amount plus/minus approved adjustments less allocations, not manually typed as a competing source of truth.

## 8. Risks, issues, decisions and weekly updates

| Entity | Key fields and relationships | Purpose |
|---|---|---|
| risks | project_id, risk_ref, title, description, owner_id, identified_date, target_resolution_date, resolved_at, status | Risk register |
| risk_assessments | risk_id, probability_value, impact_value, score_value, assessment_date, config_version_id, assessed_by | Versioned risk score |
| risk_mitigations | risk_id, action, owner_id, due_date, status, progress, evidence_document_id | Mitigation actions |
| issues | project_id, issue_ref, title, severity, owner_id, opened_at, due_date, status, resolved_at | Issue register |
| management_decisions | project_id, decision_ref, description, decision_owner_id, required_by, status, outcome, decided_at | Decision tracking |
| weekly_project_updates | project_id, reporting_cycle_id, as_of_date, narrative, achievements, next_steps, blockers, submitted_by, submitted_at | PM weekly narrative |
| status_overrides | project_id, target_type, target_id, reported_status, reason, evidence, created_by, created_at, expires_at | Human override kept separate from calculated health |

Risk scores and status labels are calculated under a configuration version. Missing probability/impact or incomplete required data must not default to low risk/Green.

## 9. Reporting configuration and version governance

| Entity | Key fields and relationships | Purpose |
|---|---|---|
| reporting_scopes | scope_type (global/project/activity/milestone), scope_entity_id nullable, priority | Scope hierarchy |
| reporting_dimensions | code, name, description, active | Delivery, financial, risk, compliance etc. |
| calculation_templates | code, version, method_key, parameter_schema, output_schema, active | Allow-listed methods; no arbitrary code |
| kpi_definitions | code, name, dimension_id, unit, template_id, aggregation_method, active | KPI catalogue |
| reporting_config_versions | scope_id, version_no, status, effective_from/to, reason, created_by, approved_by, approved_at, content_hash | Immutable version header |
| reporting_config_items | config_version_id, item_type, item_key, parameter_json, source_mapping | Versioned rule parameters |
| reporting_config_approvals | config_version_id, stage, approver_id, decision, decided_at, comments | Workflow |
| reporting_config_audit | config_version_id, action, actor_id, old_value, new_value, reason, occurred_at | Change history |
| reporting_config_publications | config_version_id, published_by, published_at | Publication record |

Configuration covers KPI formulas/methods, dimensions, weights, thresholds, status mappings, date rules, calendars, progress methods, risk matrix/scoring, financial rules, license/contract notice periods, health formulas, critical overrides and reporting cutoffs. Global defaults may be overridden by project and, where explicitly allowed, activity/milestone scope.

Formula execution must use an allow-listed method registry and validated parameters. Never execute user-entered SQL, JavaScript, or arbitrary formula text. Published versions are immutable; edits create a new draft/version. Resolve scope precedence deterministically and persist the resolved version set used for each report.

## 10. Weekly reporting and immutable snapshots

| Entity | Key fields and relationships | Purpose |
|---|---|---|
| reporting_cycles | cycle_code, period_start/end, cutoff_at, as_of_date, timezone, status | Reporting calendar |
| portfolio_snapshots | reporting_cycle_id, generated_at, generated_by, snapshot_status, portfolio_summary_json | Immutable CEO/portfolio summary |
| project_snapshots | portfolio_snapshot_id, project_id, source_updated_at, calculated_health, reported_health, snapshot_payload | Per-project historical view |
| snapshot_metric_values | project_snapshot_id, kpi_code, numeric/text value, unit, status, source_lineage_json | KPI values and traceability |
| snapshot_config_links | snapshot_id, config_version_id, scope_type, scope_entity_id | Exact config provenance |
| snapshot_corrections | original_snapshot_id, replacement_snapshot_id, reason, approved_by, created_at | Explicit correction chain |

Snapshot generation should run as a controlled transaction/process:
1. Freeze reporting cutoff and as-of date.
2. Resolve and pin approved configuration versions for all applicable scopes.
3. Validate source completeness and data quality.
4. Calculate KPIs and health using allow-listed methods.
5. Store reported values, status, source lineage and config links.
6. Store manual overrides separately from calculated results.
7. Mark snapshot immutable and record generator/actor/time.
8. Any correction creates a replacement/correction record; never silently mutate the original snapshot.

## 11. Documents and timelines

| Entity | Key fields and relationships | Purpose |
|---|---|---|
| documents | project_id, bucket_id, object_path, file_name, mime_type, size, classification, uploaded_by, created_at | Private file metadata |
| document_links | document_id, source_type, source_id | Link to contracts, invoices, risks, milestones etc. |
| timeline_categories | code, label, layer, color/token, sort_order, enabled, configuration | Configurable display layers |
| timeline_custom_events | project_id, category_id, title, start_at/date, end_at/date, all_day, description, created_by | Only events not represented by operational source records |

Master Schedule Timeline items derive from activities, milestones, contract dates, invoices/payment events, licenses and configured future source types. Payments are point events. Risk exposure is rendered as an interval derived from risk dates and lifecycle. Do not persist duplicate timeline rows for source records; expose a unified read model with source type and source record ID.

## 12. Indexing and integrity

Initial indexing plan (finalize after query plans):
- Foreign keys and project-scoped lookup fields.
- `(project_id, status)`, `(project_id, due_date)`, `(project_id, forecast_finish)`.
- Invoice/payment references and invoice allocation lookup.
- Active memberships by `(user_id, project_id, status)`.
- Reporting cycle and snapshot lookup.
- Effective-dated configuration scope lookup.
- GIN indexes only where JSONB query patterns justify them.

Constraints:
- Unique project_code, client_code, invoice_ref per defined scope.
- Positive amounts where applicable; allocation amount > 0.
- Enforce allocated totals not exceeding permitted invoice/payment totals using transactional logic/trigger or controlled RPC, not a naive row CHECK.
- Ensure parent and child records belong to the same project.
- Validate date ordering and allowed lifecycle transitions.
- Enforce immutable published configuration and snapshots with database-level protection.

## 13. Delivery boundaries and implementation sequence

Phase A — confirm detailed fields, role matrix, timezone/currency policy, and reporting scope precedence.
Phase B — create migration(s) for identity, projects, membership, audit and core references.
Phase C — implement schedule, contract, finance, risk and document domains with RLS tests.
Phase D — implement configuration versioning/approval and calculation templates.
Phase E — implement reporting cycles, immutable snapshots and timeline read models.
Phase F — apply security/performance advisors and execute role-based negative tests.

This design does not authorize applying the entire schema in one unreviewed migration. Build in small, reviewable migrations and verify each against the dedicated project.
