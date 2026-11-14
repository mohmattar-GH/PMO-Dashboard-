# Solution Architecture — PMO Dashboard

## 1. Architecture overview

Use a modular web application with a clear separation between:
1. Presentation layer (role-aware user interface).
2. Application/service layer (business workflows, validation, reporting orchestration).
3. Supabase backend (Postgres, Auth, Storage, RLS).
4. Reporting calculation layer (versioned, governed calculation templates).
5. Audit and snapshot layer (immutable history for controlled records and weekly reports).

The browser must never receive Supabase service-role credentials. Client access uses the publishable/anon key with authenticated sessions and RLS. Privileged operations, if required, run in trusted server-side functions with explicit authorization.

## 2. Suggested logical modules

- Identity & Access: profiles, trusted role assignments, project memberships, permission checks.
- Portfolio & Projects: project registry, owners, teams, status, client.
- Contracts & Change Control: contract terms, obligations, amendments, approvals.
- Schedule & Delivery: activities, dependencies, milestones, date versions, progress.
- Financial Management: project financials, invoices, payments, allocations, credits.
- Risk & Issues: risks, assessments, mitigations, issues, escalations, decisions.
- Licenses & Renewals: license inventory and expiry workflow.
- Documents: metadata, private object storage, record links.
- Reporting Configuration: dimensions, KPIs, calculation templates, scoped rule versions, approvals, audit.
- Reporting Engine: validated calculations, status evaluation, drill-down lineage.
- Weekly Reporting: reporting cycles, snapshots, immutable snapshot details.
- Timeline Engine: source-derived timeline projections and custom events.
- Export: access-controlled PDF/XLSX generation with as-of date and configuration provenance.

## 3. Data ownership and source of truth

Operational tables own their records. Dashboards and timelines query or project those records; they must not create competing copies of activities, milestones, invoices, or risks. Weekly snapshots are intentional historical records and must preserve the exact reported values and rule version for that reporting cycle.

Use normalized relational tables with explicit foreign keys, constraints, indexes, and lifecycle fields. Prefer database views or controlled server-side queries for read models. Materialized views may be introduced only where measured performance requires them and must have a documented refresh strategy.

## 4. Reporting rules engine

Represent supported formulas as named, versioned calculation templates with validated parameter schemas. Store parameter values as structured data after validation. Do not accept arbitrary SQL, JavaScript, or expressions from ordinary administrators.

A configuration version should include scope, version number, effective-from/effective-to, lifecycle/approval state, creator, approver, reason, and immutable rule content. Resolve effective rules deterministically using global defaults, project overrides, and permitted activity/milestone overrides.

At snapshot generation:
1. Select the reporting As-of Date and reporting cycle.
2. Resolve the applicable approved configuration version(s).
3. Validate required source data and configuration integrity.
4. Calculate metrics and status using approved templates.
5. Store reported values, source lineage, calculation timestamp, and exact rule version identifiers.
6. Preserve any PM-reported/approved override separately with actor, reason, and evidence.
7. Do not recompute old snapshots when configuration changes.

Missing or invalid inputs must yield an explicit Not Reported/Insufficient Data result unless a configured method defines a safe alternative.

## 5. Schedule integrity

Maintain separate fields or versioned records for original baseline, approved revised baseline, forecast, and actual dates. A forecast edit cannot update baseline fields. A re-baseline requires a dedicated approval event, reason, approver, and effective date. Preserve historical baseline versions.

Avoid counting the same delivery outcome twice when combining activity progress and milestone indicators. Progress aggregation method and weights are configuration, not constants.

## 6. Timeline read model

Master schedule timeline layers derive from activity, milestone, contract, invoice/payment, license, and other source tables. Payment events are point-in-time events. Risk exposure is a time interval with start/review/target/resolution markers. User-defined categories and custom events are separately governed, while source-derived timeline records remain linked to their authoritative source row.

## 7. Security architecture

- Enable RLS for every table exposed through Supabase APIs.
- Use trusted role and project-membership tables or protected app metadata; never rely on user-editable user_metadata for authorization.
- Write policies with least privilege and test SELECT/INSERT/UPDATE/DELETE paths independently.
- UPDATE policies require both USING and WITH CHECK; UPDATE also requires an applicable SELECT policy.
- Keep sensitive finance, contracts, documents, and configuration approvals restricted by role and project scope.
- Use private Storage buckets and policies that validate record/project access.
- Audit administrative actions and material changes.
- Avoid SECURITY DEFINER unless there is a compelling documented requirement and a hardened search_path/authorization design.

## 8. Reliability, testing, and operations

- Store schema changes as reviewed, version-controlled migrations.
- Test constraints, calculation templates, rule resolution, snapshot immutability, RLS allowed/denied cases, and export authorization.
- Add regression tests whenever an existing workflow or calculation changes.
- Log operational failures without leaking secrets or sensitive personal/financial data.
- Backups, retention, recovery objectives, and monitoring must be defined before production use.

## 9. Suggested implementation sequence

1. Confirm framework/runtime and repository baseline; establish lint, type-check, test, and build commands.
2. Design and review relational schema and RLS matrix.
3. Implement identity, roles, project membership, and project registry.
4. Implement configuration/version/audit foundation before KPI dashboards.
5. Implement core project records and schedule integrity.
6. Implement reporting calculation and immutable weekly snapshots.
7. Implement timeline read models and CEO dashboard.
8. Implement exports, comprehensive QA, and handover.

## 10. Decisions requiring validation

The final framework, charting/timeline components, server-side export approach, authentication invitation process, and deployment topology must be selected after inspecting the actual repository contents and confirming the intended frontend stack. Do not scaffold a competing stack before that inspection.
