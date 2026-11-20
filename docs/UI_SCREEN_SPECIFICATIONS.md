# Executive PPM Platform — Detailed Screen Specifications (Draft 1)

**Status:** Draft for product-owner review — not approved for frontend implementation  
**Date:** 16 November 2026  
**Design baseline:** Approved UI/UX direction and navigation proposal  
**Scope:** Executive Dashboard and Project Workspace first; other screens are specified as navigation context and remain for subsequent design rounds.

## 1. Design rules applying to all screens

- Desktop-first responsive layout; support laptop, large display and tablet widths.
- Persistent left navigation, compact top bar and consistent page title/breadcrumb pattern.
- Use one shared filter pattern: selected portfolio/project, reporting period/as-of date, status and owner where relevant.
- Display data freshness and reporting context. Historical reports must show scheduled cutoff, actual closure timestamp, snapshot status and configuration version.
- Distinguish calculated values from user-reported values. Missing or invalid source data displays Not Reported/Insufficient Data, never Green.
- Every KPI/status exposes a definition, calculation method, source and last-updated/as-of context.
- Every summary value drills down to its source records. Drill-down must preserve active filters and selected snapshot.
- Use explicit empty, loading, validation, permission-denied and error states. Do not show fabricated sample figures in the live product.
- All actions and fields are permission-aware; backend RLS remains the enforcement boundary.
- No CR Management module, CR-specific actions or CR-specific screens in this release.

## 2. Global application shell

### 2.1 Left navigation
1. Executive Overview
2. Portfolio
3. Projects
4. Master Schedule
5. Payments & Risk Timeline
6. Reports & Snapshots
7. Configuration
8. Administration

The current section is visibly selected. Project-specific pages are opened from Projects and dashboard drill-downs; projects are not individually pinned into the global navigation.

### 2.2 Top bar
- Breadcrumb / current page.
- Global search across accessible projects and records.
- Context selector when the page supports portfolio or project scope.
- Notifications / approvals requiring the signed-in user's action.
- User profile and sign-out.

### 2.3 Shared page controls
- Page title and concise explanatory subtitle.
- Primary action aligned consistently (for example, Add Project or Export).
- Filter row with applied-filter chips and Clear All.
- Saved views are a later enhancement; do not imply they exist in the first implementation.
- Tables support sorting, pagination and column visibility where practical.

## 3. Screen E01 — Executive Overview

### Purpose
A CEO-ready weekly portfolio briefing: show where management attention is needed, what changed, and what decisions or interventions are required. It is not a substitute for project-level operational screens.

### Layout hierarchy
**A. Reporting header**
- Title: Executive Overview.
- Portfolio selector (only if user has access to multiple portfolios).
- Reporting week / snapshot selector.
- Snapshot status and actual closure timestamp.
- Scheduled cutoff shown separately from actual closure.
- Export PDF / Excel actions, subject to permission.
- If no finalized snapshot exists, show an explicit “No finalized snapshot for this period” state and do not silently substitute live data.

**B. Portfolio KPI strip**
- Total projects; active projects.
- On Track, At Risk, Delayed and Not Reported counts.
- Contract value, invoiced, collected and outstanding.
- Overdue receivables.
- Each tile: value, comparison with previous finalized snapshot (where available), definition tooltip and drill-down target.
- Currency values must be grouped by currency; do not add unlike currencies into a single total unless a governed conversion configuration exists.

**C. Delivery and health section**
- Portfolio health distribution.
- Health by configured dimension (dimensions must come from the selected snapshot's configuration, not a fixed UI list).
- Milestones achieved in period, overdue milestones and upcoming critical milestones.
- Schedule variance summary, with the rule/tolerance visible through “How calculated”.
- Click on a status segment or dimension to open the filtered project list.

**D. Commercial / cash section**
- Invoiced, collected, outstanding and overdue amounts by currency.
- Payment trend over selected periods.
- Invoice aging bands based on configurable rules.
- Click-through to invoices and payment allocations.

**E. Management attention section**
- Highest-exposure risks (default top five, configurable).
- Projects with worsening health or critical milestone slippage.
- Decisions / escalations awaiting management, including owner and required-by date.
- Each item opens its source project and record.

**F. Weekly narrative**
- Achievements this week.
- Next 7 / 14 / 30 day priorities.
- Blockers and support required.
- Narrative is sourced from weekly project updates and should identify project attribution; no AI-generated statement is treated as verified fact without source links and human review.

### Interactions
- Selecting a snapshot refreshes every panel using that immutable snapshot.
- Selecting a project from any panel opens its Project Workspace with the same snapshot context where historical drill-down is supported.
- Selecting a KPI opens a detail drawer/page with formula, configuration version, source record list and calculation status.
- Export uses the selected snapshot, not unlabelled current live data.
- Presentation mode hides secondary navigation chrome but preserves snapshot/as-of context.

### Role behavior
- CEO / Executive Viewer: read-only, including exports if explicitly granted.
- Administrator: view and manage according to assigned permissions.
- Project Manager: dashboard visibility limited to accessible portfolio/project scope.
- Finance: financial details according to finance permissions; non-financial portfolio information according to project access.

### Required states
- No projects; no finalized snapshot; partial / insufficient source data; mixed currencies; KPI calculation failed; no prior snapshot for comparison; user lacks access to financial panel.


## 3.1 Screen E02 — Executive Dashboard Layout Editor

### Purpose
Give authorized administrators direct control over the dashboard's composition and arrangement without code changes or deletion of operational data.

### Entry and editing mode
- An **Edit Layout** action is available to users with the dashboard-layout administration permission.
- Entering edit mode displays the component catalogue, editable dashboard canvas and layout controls.
- Components can be added from the catalogue, dragged/reordered, resized within supported grid sizes, moved between sections, hidden, restored or removed from the active layout.
- Support configurable grid columns and component widths; the layout reflows responsively on smaller screens.
- Show an unsaved-changes indicator. Users can preview, save draft, discard changes, and publish an approved layout.
- Provide reset-to-approved-default.

### Component catalogue
Initial supported component types:
- KPI card / KPI group.
- Chart (supported chart types only).
- Data table / project list.
- Project health/status distribution.
- Milestone and schedule summary.
- Financial summary and receivables.
- Risk summary / top risks.
- Management decisions and escalations.
- Weekly narrative / priorities.
- Configurable information/status list based on registered data fields.

Each component has controlled settings for title, explanatory text, size, supported data binding, filters, grouping, display format, sort order and visibility. The catalogue is extensible through future registered component types; it does not accept arbitrary code, SQL or untrusted widgets.

### Layout governance
- **Only administrators** may create, edit, reorder, resize, hide, restore, remove, preview, save, publish or reset shared dashboard layouts.
- Ordinary users, including CEO / Executive Viewer, Project Managers and Finance users, have read-only access to the dashboard layout. They cannot rearrange components or save personal layouts.
- Maintain a system-approved default layout and optionally administrator-managed role-specific layouts (CEO, Project Manager, Finance, etc.).
- Layout access never grants access to underlying records. Components must respect the viewer's existing project, finance and role permissions.
- Layout changes are versioned and audited with author, timestamp, change summary and publication state.
- Draft changes are not visible to other users until published.
- Historical finalized reports retain the layout/configuration context used for that report; new layout versions do not rewrite old snapshots.
- Dashboard placement/removal never deletes source records, KPI definitions or operational data.
- KPI formula, threshold and scoring changes remain under the separate Configuration Center approval/version lifecycle.

### Acceptance criteria
- An authorized administrator can add, remove, hide, restore, reorder, resize and reposition components.
- The administrator can control grid columns and component widths, preview the result and publish a new layout version.
- A component removed from the canvas can be added again from the catalogue.
- Publishing a role layout does not bypass row-level or field-level data authorization.
- Users without layout permission cannot change the shared layout.
- Responsive layout reflows without overlap or inaccessible controls.
- Reset restores the currently approved default layout.
- All layout changes are auditable and historical reports remain unchanged.


## 4. Screen P01 — Projects Register

### Purpose
Find, filter and open projects; provide a controlled portfolio-wide operational index.

### Main content
- Searchable project table: project name/code, client, portfolio, project manager, team lead, lifecycle status, calculated health, PM-reported health, phase, target end date, last weekly update.
- Filters: portfolio, client, project manager, health, lifecycle status, phase and date range.
- Quick summary: total / active / at-risk / delayed / not-reported counts.
- Add Project action for authorized roles.
- Export list action subject to permission and data classification.

### Interactions
- Row click opens P02 Project Workspace.
- Health badge opens calculation details; PM-reported status is displayed separately.
- Add Project opens a validated create flow; required fields and duplicate checks are defined by business rules.
- No bulk deletion. Archive/close behavior must follow a separately approved lifecycle policy.

## 5. Screen P02 — Project Workspace (shared header)

### Header content
- Project name and project code.
- Client and portfolio.
- Project Manager and Team Lead.
- Lifecycle status / phase.
- Calculated health and PM-reported health, visually distinct.
- Reporting snapshot/as-of context when entered from a historical report.
- Last update and primary actions allowed to the current role.

### Tab navigation
1. Overview
2. Contract
3. Schedule & Milestones
4. Finance
5. Risks
6. Licenses
7. Team
8. Weekly Updates
9. Documents
10. Decisions

Tabs with no permission are hidden or shown as restricted according to the agreed access design; hiding does not replace server authorization.

## 6. Project Workspace tabs

### P02.1 — Overview
- Project summary and objectives.
- Health score/status with dimension breakdown and calculation trace.
- Verified progress and PM-reported progress shown separately where both exist.
- Next milestones, overdue activities, high risks, overdue invoices and expiring licenses.
- Recent achievements, upcoming work and decisions required.
- Each widget drills into its source tab/record.

### P02.2 — Contract
- Contract reference, client, contract start/end dates, original value and currency.
- Scope, deliverables, obligations, acceptance criteria and penalties.
- Approved variations shown as a separate governed commercial record; revised value is derived from original value plus approved variations.
- Contract documents and version history.
- Authorized create/edit actions with audit trail.
- CR Management remains out of scope. Do not add a CR register, CR approval workflow or CR-specific schedule controls.

### P02.3 — Schedule & Milestones
- Milestone and activity hierarchy with owner, dependency, progress and status.
- Dates remain distinct: original baseline, approved revised baseline, forecast and actual.
- Show variance against the configured comparison baseline and the active schedule calculation rule.
- Support authorized activity/milestone create and update flows.
- Re-baselining must use an explicit governed approval flow; ordinary edits must not overwrite original baseline.
- Dependency visualization and critical-path display are subject to validated calculation support; do not imply critical-path calculation before it is implemented.

### P02.4 — Finance
- Financial terms and contract value by currency.
- Invoices: reference, issue/submission/due dates, gross/net/tax, currency, status, paid/applied, outstanding and aging.
- Cash transactions and allocations; distinguish receipt/payment from invoice allocation.
- Partial payments and reversals show allocation history and reasons.
- Finance actions are restricted to Finance / authorized administrators.
- Currency totals remain separated unless an approved exchange-rate source and conversion rule are configured.
- No direct editing of calculated balances.

### P02.5 — Risks
- Risk register: title, description, category, probability, impact, calculated exposure, owner, identified date, target resolution, resolved date, mitigation, status and trend.
- Risk scales, score formula, matrix, severity bands and top-five selection are configurable.
- Show calculation details and last review.
- Escalation and mitigation actions are auditable.
- No hardcoded 1–5 scale in UI; render configured scale labels/ranges.

### P02.6 — Licenses
- License/provider/type, quantity, entitlement, owner, start/expiry dates, renewal notice and status.
- Configurable warning windows and status mapping.
- Expiry timeline and source-document links.
- No automatic renewal or external procurement action in this release.

### P02.7 — Team
- Project membership, role, team lead, assignment dates and activity ownership.
- Show only information appropriate to the viewer's role.
- Membership changes restricted to authorized project/admin roles.
- Team capacity/resource forecasting is not implied unless separately specified.

### P02.8 — Weekly Updates
- Reporting period and submission state.
- Achievements, next-period plan, blockers, decisions/support required, PM outlook and reported health.
- PM-reported health requires a reason and remains distinct from calculated health.
- Draft / submit / return-for-update behavior according to the approved workflow.
- Submitted updates retain audit history.

### P02.9 — Documents
- Private project document list with name, category/classification, version, uploader, upload date and access status.
- Upload, download and version actions subject to storage policy and classification.
- New version creates a new immutable version; it does not overwrite historical file content.
- No public file links.

### P02.10 — Decisions
- Decision/request title, description, priority, accountable decision-maker, owner, required-by date, status, outcome and supporting documents.
- Filters for pending, overdue and completed.
- Record decision and rationale with audit history.
- Dashboard surfaces items requiring executive action.


### CEO / Executive Viewer financial-data visibility
- Default policy: **restricted**. CEO / Executive Viewer does not receive financial information merely by holding the CEO / Executive Viewer role.
- An administrator must explicitly grant financial-data visibility before the user can see financial dashboard components, financial KPIs, invoice/payment details, contract values, receivables, or financial drill-downs.
- The permission must be enforced by backend authorization/RLS and applicable field-level controls, not only by hiding dashboard components or tabs.
- Without the explicit grant, financial components and navigation entries are omitted or display a clear access-restricted state without leaking values or metadata.
- This restriction does not prevent the administrator from assigning a separate financial permission to a CEO / Executive Viewer account where approved.


### CEO weekly-meeting presentation mode
- Provide a dedicated **Presentation Mode** for weekly CEO / executive portfolio reviews.
- Presentation Mode is a read-only, meeting-oriented view with simplified navigation and controls, clear reporting-period and snapshot status, and an executive-first sequence of portfolio health, delivery, management attention, risks, decisions and weekly narrative.
- Financial components appear only when the signed-in executive has the separately granted financial-data permission; presentation mode never bypasses data authorization.
- Support full-screen viewing and clear previous/next section navigation. Exports, if enabled, use the same access checks and selected reporting snapshot.
- Clearly display the reporting week, snapshot status/as-of time and whether the displayed information is a finalized snapshot or a live view.
- Presentation Mode does not permit layout editing or operational data changes. Only administrators can manage the underlying shared dashboard layouts.


### Executive Dashboard information density
- The standard Executive Dashboard uses the **Detailed** presentation density.
- Show richer charts, KPI breakdowns, project-level operational information, trends, upcoming milestones, risks, decisions and weekly narrative, organized into clear sections with scrolling.
- Preserve configurable component visibility, ordering, sizing and layout under administrator-only control.
- The CEO Presentation Mode remains a separate, simplified meeting-oriented experience; its layout is governed by administrators independently of the standard dashboard.

## 7. Screen-level acceptance criteria

- Dashboard values are sourced from a selected finalized snapshot or clearly labelled live operational view; never mix the two silently.
- Every KPI has a definition, configuration version and traceable source records.
- Historical drill-down retains the selected snapshot context.
- Project workspace never conflates baseline, revised baseline, forecast and actual dates.
- Financial totals are currency-safe and balances are derived, not manually overwritten.
- PM-reported and calculated health remain separate.
- All writes enforce role and project scope in the backend.
- Empty, loading, error, insufficient-data and permission states are designed.
- No CR Management UI or behavior is introduced.
- No frontend code, framework choice or deployment is authorized by this specification.

## 8. Product-owner decisions confirmed and remaining review

### Confirmed decisions
1. Standard Executive Dashboard information density: **Detailed**, with scrollable sections.
2. Dashboard layout editing: **Administrator only**. Other roles have read-only layouts; no personal layout editing.
3. CEO / Executive Viewer financial visibility: **Restricted by default**; explicit administrator grant required and enforced by backend authorization.
4. CEO weekly meeting: dedicated, read-only **Presentation Mode**.
5. Dashboard content: administrators can add, remove, hide, restore, reorder, resize and reposition components; layout changes do not delete source data.
6. Project phase: current phase visible on project cards and register; portfolio phase breakdown and filters; phase progress/dates/history; administrator-configurable lifecycle templates and phase transitions.

### Remaining review before frontend implementation
- Review the complete dashboard information hierarchy and the Project Workspace tab structure.
- Confirm whether any essential fields, actions or project-phase information are missing.
- Review the interaction approach for the administrator Layout Editor and CEO Presentation Mode.
- Select the frontend framework and component library only after the screen structure is approved.

**Approval gate:** The decisions above are captured as the current design baseline, but the detailed screen specification remains a draft. Do not begin frontend implementation until the user explicitly approves the complete screen structure and interaction approach. No framework choice, component-library choice or deployment is implied by this document.


### Project phase visibility on the Executive Dashboard
- Add a prominent **Current Project Phase** field to every project card and the Projects Register row.
- Add a portfolio-level **Phase Breakdown** component showing project counts by configured phase, with drill-down to the matching project list.
- Provide dashboard filters for phase.
- Show phase progress and planned start, forecast completion and actual completion dates when those values are available.
- Preserve phase transition history so management can see when a project entered or exited a phase and identify time spent in each phase.
- Phase definitions, names, ordering, active/inactive state and permitted transitions must be administrator-configurable; do not hardcode a universal lifecycle.
- Support project-specific lifecycle templates where projects follow different delivery methods. Each project must have one clearly identified current phase under its assigned lifecycle.
- Missing phase data must be displayed as Not Reported / Unassigned, never inferred.
- Phase status and progress must remain distinct from overall project health and milestone completion.
- Phase components and fields are subject to the same administrator-only dashboard layout control and viewer data permissions.


## Dashboard composition refinements approved — 20 November 2026

### Information density
- User agreed that the first visual concept was somewhat crowded.
- Retain the standard dashboard's Detailed information density, but improve hierarchy and progressive disclosure:
  1. First section: portfolio KPIs, project health and phase distribution.
  2. Second section: projects requiring attention and upcoming priorities.
  3. Third section: portfolio risks and management decisions.
  4. Further down the scrollable dashboard: financial position (only when authorized), milestone/schedule detail, weekly summary and phase history.
- CEO Presentation Mode remains a separate, simplified executive sequence.

### Financial component configuration
- Financial dashboard visibility must be configurable by an administrator.
- Configuration must support whether the component is included in a layout and whether an unauthorized viewer sees a restricted-access panel or no component at all.
- Layout visibility is not an authorization grant. Backend authorization/RLS and applicable field-level controls must still prevent access to financial values and metadata unless explicitly granted.

### Separate phase components
- User approved keeping the following as two independent dashboard components:
  - **Project Phase Distribution:** project counts and percentages by phase, with phase selection/filter drill-down.
  - **Recent Phase Changes:** project, previous phase, new phase, transition date, and access to full transition history/time-in-phase.
- Each component can be independently added, hidden, removed from the active layout, reordered, and restored by an administrator.
- Hiding/removing a component from the dashboard must not delete phase definitions, project phase assignments, or transition history.

### Approval boundary
- These are approved product/UI design decisions only.
- No frontend implementation, framework selection, component-library selection, or deployment is authorized by this decision.
