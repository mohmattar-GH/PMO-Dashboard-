# UI Review Round 1 — Full Navigation and Screen Blueprint

**Status:** Draft for product-owner review. The primary navigation was approved by the product owner on 22 November 2026. This approval authorizes continued design detailing only; it does not yet authorize frontend implementation.

## 1. Approved primary navigation

The following primary navigation is approved as the application starting structure:

1. Executive Overview
2. Portfolio
3. Projects Register
4. Master Schedule
5. Payments & Risk Timeline
6. Change Requests
7. Deliverables
8. Milestones
9. Notification Centre
10. Reports & Snapshots
11. Configuration
12. Administration

The navigation is persistent on desktop, collapsible on smaller screens, and permission-aware. The notification bell in the top bar is a shortcut to unread/action-required items; Notification Centre remains a full navigation destination. Project-level screens open from the Projects Register and relevant drill-downs.

## 2. Global application shell

### Desktop
- Left navigation rail: fixed-width, collapsible to icons; active section clearly indicated.
- Top bar: breadcrumb, global search, current portfolio/project context when applicable, notification bell with unread count, user profile.
- Main content: page title, concise description, primary action, filters, then content.
- A consistent right-side detail drawer is used for quick inspection of records without losing the current list/filter context. Full edit and approval workflows open a dedicated record page or focused modal where appropriate.

### Responsive behavior
- Tablet: navigation collapses; filters move into a filter panel; data tables retain essential columns and horizontal scrolling where needed.
- Mobile: navigation becomes a drawer; cards replace dense tables where appropriate; no critical action depends on hover.

### Shared interaction rules
- Preserve filters and search when opening a record and returning to a list.
- Every status/KPI exposes its definition, source, calculation/configuration version and as-of date where relevant.
- Historical snapshot context remains visible during drill-down.
- Clearly distinguish Live data from a Finalized Snapshot.
- Show explicit loading, empty, validation, permission-denied, insufficient-data and error states.
- Missing data is Not Reported/Insufficient Data, never inferred as Green.
- Hide or restrict unauthorized navigation/actions, but enforce every permission at the backend as well.
- Destructive actions require confirmation and a reason where audit policy requires it.

## 3. Executive Overview

### First viewport hierarchy
1. Reporting header: reporting week, portfolio selector, snapshot state/as-of time, export, Presentation Mode.
2. Portfolio KPI strip: project count, active, on-track, at-risk, delayed, not-reported; finance KPIs only when explicitly authorized.
3. Two separate phase components: Project Phase Distribution and Recent Phase Changes.
4. Portfolio health/delivery and projects requiring attention.
5. Management attention: top risks and decisions/escalations.
6. Lower scroll sections: financial position (permission-controlled), milestones/schedule, weekly executive summary.

### Interactions
- Snapshot selector refreshes every dashboard component consistently.
- KPI/chart selection opens a filtered Portfolio or Projects Register view.
- Project/record selection opens the source record with snapshot context retained where supported.
- Presentation Mode is read-only, meeting-oriented, full-screen capable, and supports previous/next section navigation.
- Admins alone can edit shared dashboard layouts; layout visibility never grants data access.

## 4. Portfolio

### Portfolio list
- Portfolio name/code, owner, project count, lifecycle/health summary, last reporting cycle.
- Search, status and owner filters.
- Portfolio detail opens project distribution, health trends, reporting completeness and portfolio-level risks/decisions.
- Portfolio totals aggregate only compatible units/currencies and use configured rules.

## 5. Projects Register

### List view
- Project name/code, client, portfolio, PM, team lead, current phase, lifecycle status, calculated health, PM-reported health, target end date, next milestone, last weekly update.
- Filters: portfolio, client, PM, team lead, phase, health, lifecycle status, date range and reporting completeness.
- Column chooser and sorting; export follows user permissions.
- Add Project opens a guided create flow with required-field validation and duplicate checks.
- Selecting a row opens the Project Workspace.

### Project creation flow
- Step 1: identity and ownership (project name/code, client, portfolio, PM, team lead).
- Step 2: lifecycle template and current phase assignment.
- Step 3: contract and commercial setup (only fields the creating role may maintain).
- Step 4: initial reporting baseline and key dates.
- Step 5: review and create.
- The form saves a draft where supported; incomplete drafts are not counted as fully registered/active projects unless the configured rule says otherwise.

## 6. Project Workspace

### Persistent project header
- Project name/code, client, portfolio, PM, team lead.
- Current lifecycle phase and lifecycle status.
- Calculated health and PM-reported health separately.
- Target completion, next milestone, last update.
- Context banner when opened from a historical snapshot.

### Proposed grouped workspace navigation
**Overview**
- Summary, objectives, health dimensions, progress, upcoming priorities, overdue actions and key alerts.

**Delivery**
- Schedule & Activities: activity hierarchy, dependencies, owners, progress, original baseline, approved revised baseline, forecast and actual dates.
- Milestones: milestone register, achievement evidence, status and governed re-baselining.
- Deliverables: contractual/internal deliverables, submissions, evidence, review comments, resubmission and PM acceptance state.
- Change Requests: intake, impact assessment, approval route, decisions, implementation, verification and closure history.

**Commercial**
- Contract: scope, obligations, contract dates, original value/currency, deliverable obligations, acceptance criteria and approved variations.
- Finance: financial terms, invoices, receipts, payment allocations, outstanding and aging; permission-restricted.
- Payments: payment history and links to invoice/cash transaction sources. Do not create a second payment ledger.

**Governance & Resources**
- Risks: risk register, configurable score/exposure, mitigation, owner, trend and history.
- Licenses: provider/type, quantity, entitlement, owner, expiry and configurable renewal alerts.
- Team: project membership, roles, team lead and activity ownership.
- Weekly Updates: achievements, next-period plan, blockers, support/decisions required, PM outlook and reported health/reason.
- Documents: private files, classification, versions and record links.
- Decisions: management requests, accountable decision-maker, due date, outcome and rationale.

The workspace groups are navigation groupings only. They do not merge separate permissions or data domains.

## 7. Master Schedule

- Full-width cross-project Gantt/timeline.
- Layers can be switched on/off: activities, milestones, deliverables, invoice/payment due dates, contract dates, license dates, decisions and configured custom event types.
- Filters: portfolio, project, PM, owner, phase, status, event type and date range.
- Time zoom: week/month/quarter/year.
- Display modes: original baseline, approved revised baseline, forecast, actual; no mode may overwrite another date set.
- Expand/collapse by portfolio and project.
- Selecting an event opens its authoritative source record.
- Only custom events are independently stored; source-linked records are not duplicated as separate schedule data.

## 8. Payments & Risk Timeline

Two synchronized but independently filterable lanes:

**Payments lane**
- Invoice issue/submission/due dates, expected payment dates where configured, actual receipts, partial allocations, overdue intervals and reversals.
- Currency and payment status always visible; no unlike-currency aggregation without a governed FX configuration.

**Risk lane**
- Identified date, review dates, mitigation target, escalation, target resolution and actual resolution.
- Severity and score use the active configurable risk model.

Selecting a point/interval opens the source invoice, transaction or risk record. Users without finance access cannot see financial event details.

## 9. Change Requests

### Register
- CR reference, title, project, requester, submission date, category, impact summary, current workflow stage, pending approver, target decision date and status.
- Filters by project, stage, status, impact, requester, approver and date.
- New CR opens a guided intake flow.

### CR record workspace
- Request details and rationale.
- Impact assessment for scope, schedule, cost, resources, risk, quality and contractual terms; each dimension must be assessed or marked Not Applicable with a reason.
- Configurable sequential/parallel approval stages and assigned approvers.
- Decision, rationale, comments and immutable history.
- Approved change application is an explicit controlled action, showing exactly which contract, schedule, milestone, deliverable or financial records will be changed.
- Implementation evidence, verification and closure.
- Rejected/withdrawn/returned requests retain history; they are not silently deleted.

## 10. Deliverables

### Register
- Deliverable reference/title, project, contract, owner, due date, submission version, review status, PM acceptance state and overdue indicator.
- Filters by project, owner, status, due date, contract and acceptance state.

### Deliverable detail
- Description, contractual reference, acceptance criteria, due date, owner and linked milestone/activity.
- Versioned submission history and evidence attachments.
- Reviewer comments and request-changes/reject decisions.
- Resubmission creates a new version and preserves earlier versions.
- **Acceptance rule:** status remains Unaccepted until the Project Manager explicitly records acceptance. Review completion or submission alone does not mean acceptance.
- Acceptance actor, date, rationale and evidence are auditable.

## 11. Milestones

### Register
- Milestone, project, owner, category, criticality, original baseline date, approved revised baseline, forecast, actual, status and variance.
- Filters by project, owner, category, criticality, status and date range.
- Summary counts for achieved, upcoming, overdue and at-risk milestones.

### Milestone detail
- Linked activities, dependencies, deliverables, evidence and related CRs.
- Date values remain distinct and history is retained.
- Re-baseline can be requested through an approved CR or a separate approved re-baseline request.
- Reason, impact, approver and old/new dates are retained.
- Variance and status derive from configurable rules and show calculation context.

## 12. Notification Centre

### User inbox
- Tabs/filters: All, Unread, Assigned to Me, Action Required, Escalated.
- Notification item shows severity, short safe summary, source project/record, due date/SLA and timestamp.
- Actions: open source, mark read, acknowledge when required.
- Acknowledgement is mandatory only for event types/severities configured by an administrator.
- Deep links re-check source-record access when opened.

### Admin notification rules
- Configure event, conditions/thresholds, severity, recipients (selected users and/or configured roles), channel, lead time, repeat cadence, business calendar, timezone, quiet hours, escalation, acknowledgement, deduplication and expiry.
- Global defaults with project-level overrides.
- Versioned draft/publish lifecycle and immutable history.
- In-app notifications are the initial supported channel. Email/external channels remain unavailable until provider integration, permission setup and delivery tests are completed.
- Rule test/preview resolves recipients and sample content without sending a real notification unless a separately confirmed test-send action is used.

## 13. Reports & Snapshots

- Snapshot register: reporting period, cutoff, actual closure timestamp, status, configuration version and portfolio summary.
- Snapshot comparison: selected weeks, KPI movement and project-level changes.
- Report builder: portfolio, project, date/snapshot, sections and authorized fields.
- Exports: PDF and Excel.
- Historical snapshot values remain immutable and traceable to their source cutoff and configuration.
- Export permission and financial-data authorization are enforced at generation time.

## 14. Configuration

A dedicated configuration workspace with sections:

1. Reporting cycles, cutoff and closure.
2. Dimensions, KPI catalogue, formulas/templates and source mappings.
3. Weights, thresholds, status mappings and overall health rules.
4. Schedule variance, progress calculation and working calendars.
5. Risk scales, matrix, scoring and escalation rules.
6. Finance/invoice/payment status rules and allocation parameters.
7. License warning periods and renewal rules.
8. Lifecycle templates, phase definitions and transition rules.
9. CR workflow templates, impact dimensions and approval routing.
10. Deliverable statuses, review and acceptance parameters.
11. Milestone categories, statuses and re-baseline rules.
12. Notification event rules, recipients and reminder/escalation schedules.
13. Configuration version history, approvals, effective dates and audit.

Every setting indicates global default versus project override. Formula execution uses approved templates/validated parameters, not arbitrary SQL or code.

## 15. Administration

- User directory and invitation/activation state.
- Role and permission matrix.
- Project/portfolio memberships and assignments.
- Explicit financial-data access grants.
- Configuration/layout administration permissions.
- Audit log and security events.
- Private document/storage access administration.
- System reference data and controlled lookup lists.

All access changes are auditable. Role assignment alone must not imply financial access.

## 16. Cross-screen interaction model

- Lists use consistent filters, sorting, pagination, column visibility and export.
- Record detail pages use a consistent header, status/history strip, content sections and activity/audit history.
- Create/edit uses focused forms with validation, save draft where appropriate, and explicit submit/approve actions.
- Approval actions show current stage, assigned actor, due date, permitted decision choices and mandatory rationale rules.
- Detail drawers are for read-only quick inspection; complex workflows use full record pages.
- Every notification and dashboard item links to its source record and re-checks permissions.
- Audit history is visible to authorized roles and cannot be edited through the UI.

## 17. Approval gates and implementation sequence

The approved navigation is recorded. The remaining product-owner review covers:
1. Executive Overview hierarchy and component behavior.
2. Project Workspace grouping and exact tab content.
3. Register/detail/create flows for CRs, Deliverables and Milestones.
4. Notification inbox and rule editor interactions.
5. Master Schedule and Payments/Risk timeline controls.
6. Reports, Configuration and Administration navigation/detail.
7. Role-specific navigation and permission-restricted states.

**Frontend gate:** Do not select the framework/component library or implement frontend until the product owner approves the complete screen structure and interaction approach. The next review should validate the screen blueprint above, then we can turn the approved design into implementation tickets and build the frontend.

## 18. Explicit scope and safety boundaries

- Change Requests, Deliverables, Milestones and Notification Centre are included in this release; this supersedes earlier out-of-scope CR statements in older design drafts.
- Financial information is restricted by default for CEO/Executive Viewer unless separately granted.
- No arbitrary formula code/SQL entry in configuration.
- No duplicate sources of truth for contract variations, deliverables, milestones, payments or timeline events.
- Do not change the existing Staff Time & Performance application.
- Do not publish/deploy production without explicit approval.
