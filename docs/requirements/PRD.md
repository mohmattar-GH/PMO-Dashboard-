# Product Requirements — PMO Dashboard

**Product:** Executive Project Portfolio Management (PPM) Platform  
**Repository:** `mohmattar-GH/PMO-Dashboard-`  
**Status:** Baseline requirements; subject to controlled refinement.

## 1. Vision and outcomes

Provide one operational system for project teams and one trusted portfolio view for executive management. The platform must support both detailed project execution and CEO-level management-by-exception without requiring executives to navigate every project individually.

## 2. User roles

- **Administrator:** system administration, users, permissions, global configuration, approvals, and audit access.
- **Project Manager:** manage assigned project records, weekly updates, risks, issues, milestones, and forecasts.
- **Finance:** manage financial records, invoices, receipts, allocations, and financial status.
- **Team Lead:** manage assigned activities, progress, and delivery evidence.
- **CEO / Executive Viewer:** read-only portfolio and authorized project details; export permitted reports.

Role assignment and authorization must be enforced server-side and through database policies, not by hiding UI controls alone.

## 3. Project record

Each project profile should support:

### 3.1 General information
Project name and reference, client, project owner, PM, team lead, project status, start/end dates, and team membership.

### 3.2 Contract and obligations
Contract reference, signing date, commencement date, duration, scope, deliverables, obligations, acceptance criteria, penalties, change requests, and approved variations.

### 3.3 Financials
Contract value and currency, payment terms, billing milestones, tax, retention, approved variations, invoices, receipts, outstanding balance, and overdue receivables.

### 3.4 Delivery plan
Activities, dependencies, owners, weights, progress, and milestones. Preserve independently:
- Original baseline start/end dates.
- Approved revised baseline start/end dates.
- Current forecast start/end dates.
- Actual start/end dates.

Forecast updates must never overwrite baselines. Re-baselining must be a controlled approval workflow.

### 3.5 Licenses and renewals
License type, provider, quantity, expiry, renewal status, responsible owner, and notice periods.

### 3.6 Risks, issues, and decisions
Risks with probability, impact, score, mitigation, owner, target resolution date, status, and trend. Track issues, escalations, management decisions, decision owner, due date, and closure evidence.

### 3.7 Weekly updates
Achievements, upcoming work, progress, issues, decisions required, risks, financial notes, PM outlook, and reporting As-of Date.

### 3.8 Documents
Attach documents to the relevant project records with metadata and access controls.

## 4. Portfolio dashboard

The CEO dashboard must provide:
- Portfolio counts: active, on-track, at-risk, delayed, and completed.
- Delivery performance: achieved/overdue milestones, schedule variance, and progress.
- Financial position: contract value, invoiced, collected, outstanding, and overdue.
- Risk exposure: critical/high risks, mitigation status, and portfolio-level ranking.
- Management attention: decisions required, escalations, overdue actions, and upcoming deadlines.
- Weekly highlights and priorities for configurable future windows (initially 7/14/30 days).
- Drill-down from each KPI or alert to its underlying project and source record.
- Fixed weekly snapshots with As-of Date and historical comparison. A new reporting cycle must not overwrite prior snapshots.

## 5. Standalone timeline modules

### 5.1 Master Project Schedule Timeline
A cross-project timeline with selectable layers for activities/tasks, milestones, invoice/payment dates, contract dates, license dates, custom events, and future administrator-defined categories.

Capabilities: category and project filters, owner/status filters, monthly/quarterly/annual zoom, baseline/revised/forecast/actual views, event-to-source-record navigation, and independent export to PDF/image.

Timeline entries must be derived from the underlying source records. Store only custom manually created events as independent events.

### 5.2 Payments & Risk Exposure Timeline
Show invoice/payment events as points (expected invoice, submitted, due, expected payment, receipt, overdue, partial payment) and risk exposure as intervals (identified, reviewed, mitigation period, resolution target, resolved). Support project, severity, status, and date filters.

## 6. Reporting Rules & Configuration Center

This is foundational functionality, not a later enhancement. All business rules must be configurable through permission-controlled application screens.

### 6.1 Configuration scopes
- Global portfolio defaults.
- Project-specific overrides.
- Activity/milestone-level parameters where applicable.

### 6.2 Configurable definitions
- Performance dimensions: add, rename, activate/deactivate, and order.
- KPI definitions, formula/calculation method, source data, and aggregation.
- KPI and dimension weights.
- Status labels, thresholds, colors, and Not Reported/Insufficient Data behavior.
- Schedule variance formula, calendar/working-day basis, tolerance, thresholds, and escalation rules.
- Progress calculation: weighted, manual, or hybrid; activity weights and progress rules.
- Risk probability/impact scales, matrix, score formula, bands, trend, and top-risk selection logic.
- Financial status mapping, due-date rules, partial-payment allocation, credits, and overdue treatment.
- License expiry alerts and contract renewal notice periods.
- Overall project health formula, weights, critical overrides, and PM override policy.
- Weekly reporting cadence, cutoff, required fields, and comparison periods.
- Per-activity and per-milestone original baseline, approved revised baseline, forecast, and actual dates.

### 6.3 Governance
Every configuration change must retain old/new values, actor, timestamp, reason, effective date, approval status, and version. Validate configuration integrity (for example, weights that must total 100%). Formula execution must use approved calculation templates and validated parameters; do not execute arbitrary user-provided SQL or code.

Each weekly snapshot must pin the exact configuration version used. Historical reports must not be silently recalculated when rules change.

### 6.4 Initial defaults (examples only)
Initial suggested dimensions: Schedule, Delivery, Financial, Risk, Contractual Compliance, and Resource/Operational Readiness. Suggested thresholds and formulas are starting defaults only and must remain editable. No example value in this document is a permanent hardcoded rule.

## 7. Security and audit

- Use Supabase Auth and trusted role assignments.
- Apply RLS to all exposed tables; test both permitted and denied access.
- Do not authorize users through editable user metadata.
- Keep service-role credentials server-side only.
- Use private Storage buckets and record-level access controls for sensitive files.
- Audit material changes to contracts, baselines, finance, risks, permissions, and reporting configuration.
- Separate calculated status from human-approved/reported status.

## 8. Reporting and exports

Provide authorized Excel and PDF exports for executive portfolio reports, project details, and standalone timelines. Export must respect the requesting user's access scope and selected filters. Include reporting As-of Date, applied configuration version, and generation metadata.

## 9. Non-functional requirements

- Desktop-first responsive interface with accessible layouts.
- Clear navigation, global search, filtering, and drill-down.
- Reliable auditability, historical reproducibility, and traceability to source records.
- Secure-by-default data access.
- Maintainable, testable architecture with version-controlled migrations.
- Avoid duplicate sources of truth and inconsistent derived values.

## 10. Acceptance criteria — foundational release

1. A project can be created and maintained with its core records.
2. User access is enforced by role and project assignment at the backend.
3. Baseline, revised baseline, forecast, and actual dates are independently retained.
4. Reporting rules can be configured without code changes for supported calculation templates.
5. Configuration changes are versioned, effective-dated, permission-controlled, and audited.
6. A weekly snapshot stores its As-of Date and exact configuration version.
7. Missing required data produces Not Reported/Insufficient Data, never an assumed Green.
8. Dashboard KPIs can be traced to source records.
9. Timeline events reflect source records without duplicating them.
10. Excel/PDF exports respect role permissions and report filters.

## 11. Open design decisions

Resolve during architecture and implementation planning: authentication onboarding/invitation flow; exact project-level permission granularity; approval workflow actors; working-day calendars and holidays; supported currencies and FX policy; invoice-to-payment allocation rules; export templates; and selected frontend/chart/timeline libraries.
