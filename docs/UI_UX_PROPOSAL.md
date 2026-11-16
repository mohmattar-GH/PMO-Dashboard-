# Executive PPM Platform — UI/UX Proposal for Review

**Status:** Proposal only — no frontend implementation has started  
**Audience:** Product owner / executive sponsor  
**Design objective:** A professional executive portfolio workspace that supports weekly CEO review while remaining usable for project teams' daily operational work.

## 1. Proposed visual direction

- Desktop-first responsive application; optimize the main workspace for laptop and large-screen executive presentations.
- Dark navy/charcoal left navigation with a light neutral content canvas.
- Restrained accent colors; status colors reserved for meaningful health, risk and payment states.
- Strong information hierarchy, compact data density, consistent filters and drill-downs.
- Charts and timelines must be backed by operational records and show their reporting/as-of context.
- Executive presentation mode should reduce navigation chrome and emphasize the selected reporting snapshot.

## 2. Proposed primary navigation

1. **Executive Overview** — CEO portfolio dashboard and weekly reporting.
2. **Portfolio** — portfolio list, health distribution and cross-project comparison.
3. **Projects** — searchable project register and project workspaces.
4. **Master Schedule** — cross-project Gantt/timeline with configurable event layers.
5. **Payments & Risk Timeline** — financial events and risk exposure over time.
6. **Reports & Snapshots** — weekly snapshots, historical comparisons and exports.
7. **Configuration** — reporting rules, KPI definitions, scoring and thresholds.
8. **Administration** — users, roles, access and system audit.

The primary navigation remains fixed. Project-specific work is opened from Projects or drill-down links, rather than creating a separate navigation item for every project.

## 3. Executive Overview — proposed screen layout

**Header**
- Reporting cycle / week selector.
- Snapshot state and explicit “as of closure” timestamp.
- Portfolio selector and export action.
- Quick access to management decisions requiring attention.

**First row — portfolio KPIs**
- Total projects and active projects.
- On Track / At Risk / Delayed / Not Reported counts.
- Contract value, invoiced, collected and outstanding.
- Overdue receivables.

**Second row — portfolio performance**
- Project health distribution with drill-down.
- Milestone achievement and overdue milestone summary.
- Financial position and receivables trend.

**Third row — executive attention**
- Top portfolio risks (with severity, owner and mitigation).
- Decisions and escalations awaiting management.
- Projects with deteriorating health or critical milestone slippage.

**Fourth row — weekly narrative**
- Key achievements this week.
- Priorities for the next 7/14/30 days.
- Blockers and support required.

The CEO view should avoid displaying every operational field. Each metric should link to the underlying project, invoice, milestone, risk or decision record.

## 4. Project workspace

Each project opens in a consistent workspace with a compact project header (name, client, PM, team lead, health, phase and reporting date) and these tabs:

1. **Overview** — project summary, health dimensions, progress and immediate attention items.
2. **Contract** — contractual terms, dates, deliverables, acceptance obligations and approved variations.
3. **Schedule & Milestones** — activities, dependencies, baseline/revised/forecast/actual dates and progress.
4. **Finance** — financial terms, invoices, payments, allocations, receipts and outstanding balance.
5. **Risks** — risk register, probability/impact, mitigation, owner, trend and top-five exposure.
6. **Licenses** — license inventory, quantities, owners, expiry and renewal dates.
7. **Team** — assigned roles, team lead and activity ownership.
8. **Weekly Updates** — achievements, upcoming work, blockers, PM outlook and reported health/reason.
9. **Documents** — controlled project document library, classification and versions.
10. **Decisions** — management decisions, due dates, priority and outcome.

Quick-add actions should be available within the relevant tabs. Data entry should use focused forms with validation and save-draft behavior; approval-required changes should clearly show their approval state.

## 5. Master Schedule screen

- Full-width Gantt/timeline as the primary content.
- Project, owner, status and date-range filters.
- Configurable layers: activities, milestones, invoice dates, contract dates, license dates, decisions and future custom event types.
- Baseline, approved revised, forecast and actual date display modes.
- Expand/collapse by project; click an event to open its source record.
- Month/quarter/year zoom and export.
- Do not store duplicate schedule events when the event already exists as an operational project record.

## 6. Payments & Risk Timeline screen

Two aligned timeline lanes:

- **Payments:** invoice issue/submission/due dates, partial allocations, actual receipts, overdue periods and outstanding balance.
- **Risks:** identified date, target resolution, escalation, mitigation milestones and resolved date.

Filters should support portfolio/project, payment status, risk severity, owner and date range. Clicking an event opens its source invoice, cash transaction or risk record.

## 7. Reports & Snapshots

- Weekly snapshot register with period, actual closure timestamp, snapshot status and portfolio health.
- Compare selected snapshots week-over-week.
- Drill down from portfolio KPI to project and source records.
- Export CEO dashboard and project-level reports to PDF and Excel.
- Historical snapshots remain immutable and retain the configuration version used to calculate them.

## 8. Configuration Center

Configuration should be a dedicated workspace, not a hidden settings page. Proposed sections:

- Dimensions, KPI catalogue and weights.
- KPI formula templates and source mappings.
- Overall health formula, status thresholds and critical overrides.
- Schedule variance, calendars and progress rules.
- Risk scales, matrix, scoring and escalation rules.
- Finance and invoice/payment status mappings.
- License expiry and renewal notice periods.
- Reporting cycle, cutoff and closure rules.
- Version history, effective dates, approvals and audit log.

Every configuration section should show whether a value is a global default or project override. Draft changes must not affect published snapshots. Formula configuration remains restricted to approved templates; no arbitrary SQL or code entry.

## 9. Role-based experience

- **CEO / Executive Viewer:** Executive Overview, Portfolio, project read-only views, Reports & Snapshots.
- **Project Manager:** assigned project workspaces, weekly updates, schedules, risks, decisions and project documents.
- **Finance:** financial terms, invoices, payments, allocations and finance reporting.
- **Team Lead:** assigned activities/milestones, progress and relevant project documents.
- **Administrator / Configuration Steward / Approver:** access administration and controlled configuration lifecycle, according to assigned permissions.

Navigation and actions should be permission-aware. Hiding a menu item is not a substitute for database authorization.

## 10. Proposed interaction principles

- Every KPI and status has a visible definition or “how calculated” detail.
- Every important dashboard value drills down to source records.
- Use consistent filters across portfolio and project screens.
- Distinguish calculated health from PM-reported health.
- Missing or insufficient data must show Not Reported, never Green.
- Preserve a clear audit trail for configuration and financial approvals.
- Show scheduled cutoff and actual closure timestamp distinctly on historical reports.

## 11. Decisions requested before wireframes

Please review the proposed structure and confirm whether to use it as the basis for detailed screen wireframes. No frontend framework, component library or visual implementation will be selected until this direction is approved.

Items to revisit during wireframes:
- Whether Executive Overview should open in a single-page CEO presentation layout or a dashboard with drill-down panels.
- Whether the project workspace tabs should be grouped into “Delivery”, “Commercial” and “Governance” sections.
- Whether the left navigation should remain expanded or collapse to icons on smaller screens.
- Final typography, spacing, chart style and status palette.

## 12. Scope guardrails

- CR Management remains deferred to a future release.
- No changes to the existing Staff Time & Performance application.
- No production deployment/publishing as part of this design review.
- UI implementation begins only after the user approves the screen structure and interaction approach.
