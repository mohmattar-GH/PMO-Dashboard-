# Executive PPM Platform — Dashboard Wireframes

**Status:** Wireframe draft for product-owner review  
**Date:** 20 November 2026  
**Scope:** Executive Dashboard, phase components, administrator layout editor, and CEO Presentation Mode.  
**Implementation status:** Design only. No frontend code, framework selection, database schema change, or deployment is included.

## 1. Wireframe principles

- The standard dashboard remains Detailed, but uses a clearer visual hierarchy and progressive disclosure.
- The page is scrollable. High-priority portfolio information appears first; supporting detail appears further down.
- Dashboard components are independent modules. Administrators control their inclusion, visibility, order, size, and configuration.
- A component's layout visibility never grants access to its underlying data.
- Financial content is shown only when the signed-in user has explicit financial-data authorization. Administrators configure whether an unauthorized viewer sees a restricted placeholder or no component.
- Phase distribution and phase-change history are separate components.
- All values shown in any design sample are illustrative only; production UI must use authorized, traceable source data.
- The selected reporting period, snapshot status, and as-of context remain visible.

## 2. Screen E01 — Standard Executive Dashboard

### Desktop layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ Executive Overview     Reporting Week [16–22 Nov 2026 ▼] [Portfolio ▼]      │
│ Snapshot: Finalized • As of [date/time]              [Presentation Mode]     │
├──────────────────────────────────────────────────────────────────────────────┤
│ PORTFOLIO AT A GLANCE                                                        │
│ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────────────┐  │
│ │ Projects  │ │ On Track  │ │ At Risk   │ │ Delayed   │ │ Overall Progress│  │
│ │    ##     │ │    ##     │ │    ##     │ │    ##     │ │       ##%       │  │
│ └───────────┘ └───────────┘ └───────────┘ └───────────┘ └─────────────────┘  │
├────────────────────────────────────┬─────────────────────────────────────────┤
│ PROJECT PHASE DISTRIBUTION         │ RECENT PHASE CHANGES                    │
│                                    │                                         │
│ [Donut / bar chart]                │ Project | From → To | Date | Changed by │
│ Phase A       ## projects          │ ...                                     │
│ Phase B       ## projects          │ ...                                     │
│ Phase C       ## projects          │ ...                                     │
│ [Select phase to filter]           │ [View full history]                     │
├────────────────────────────────────┬─────────────────────────────────────────┤
│ PORTFOLIO HEALTH & DELIVERY        │ PROJECTS REQUIRING ATTENTION             │
│                                    │                                         │
│ Health distribution / dimensions   │ Project | Current phase | Health       │
│ Milestones achieved / overdue      │ Reason / next action | Owner             │
│ Schedule variance trend            │ [Open project] [View all]                │
├────────────────────────────────────┴─────────────────────────────────────────┤
│ MANAGEMENT ATTENTION                                                        │
│ ┌────────────────────────────────────┐ ┌───────────────────────────────────┐ │
│ │ TOP PORTFOLIO RISKS                │ │ DECISIONS & ESCALATIONS            │ │
│ │ Exposure | Owner | Trend | Due     │ │ Decision | Owner | Required by     │ │
│ └────────────────────────────────────┘ └───────────────────────────────────┘ │
├──────────────────────┬──────────────────────────┬────────────────────────────┤
│ FINANCIAL POSITION   │ MILESTONES & SCHEDULE     │ WEEKLY EXECUTIVE SUMMARY   │
│ [Authorized data OR  │ Upcoming / overdue        │ Achievements               │
│ restricted placeholder│ milestones and dates    │ Next 7/14/30-day priorities │
│ OR hidden component] │ Variance / trend          │ Blockers / support required│
└──────────────────────┴──────────────────────────┴────────────────────────────┘
                         [Further content may continue below]
```

### Layout and behavior notes

1. **Header:** reporting period and snapshot context are always visible. Switching snapshots refreshes every component against that snapshot. A live view must be explicitly labelled as live.
2. **KPI strip:** tiles are configurable. Currency values remain separated by currency unless a governed conversion rule exists.
3. **Phase distribution:** shows counts and percentages by the project's configured lifecycle phase. Selecting a phase applies a phase filter to the project register or opens a filtered project list.
4. **Recent phase changes:** independent table/list showing project, previous phase, new phase, transition date, and actor where recorded. “View full history” opens the phase history view. Time-in-phase is available where dates support it.
5. **Health and delivery:** uses configured dimensions and KPI rules from the selected snapshot; it does not hardcode a fixed set of dimensions.
6. **Projects requiring attention:** prioritizes configured conditions such as critical milestone slippage, worsening health, overdue actions, or missing weekly updates. Each item links to its source record.
7. **Risks and decisions:** remain separate components, each with drill-down.
8. **Financial position:** administrator controls layout inclusion and unauthorized-view behavior. A user without the financial permission receives no financial values or metadata, regardless of layout configuration.
9. **Weekly summary:** separates achievements, upcoming priorities, blockers, and support/decisions required. Statements link back to their source weekly updates.
10. **Progressive disclosure:** lower-priority detail stays further down the page; component expansion or “View all” opens detailed records without overcrowding the first viewport.

## 3. Phase component detail

### A. Project Phase Distribution

- Display mode configurable from supported chart types (for example, donut or horizontal bar).
- Group projects by their current phase within their assigned lifecycle template.
- Show phase label, project count, percentage, and optionally aggregate phase progress if the definition is configured.
- Clicking a phase applies the same phase filter to the Projects Register.
- Unassigned or missing phase values appear as **Unassigned / Not Reported**; they are never inferred.
- Phase remains distinct from project health and milestone completion.

### B. Recent Phase Changes

- Default list shows the most recent transitions within the selected reporting period; period and row count are configurable.
- Columns: Project, Previous Phase, New Phase, Transition Date, Changed By.
- Selecting a row opens the project's phase history.
- Full history includes effective date/time, previous and new phase, actor, reason/comment where captured, and time spent in the previous phase.
- Authorized users may see only transition records within their project/data permissions.
- Dashboard component visibility does not affect retention of transition history.

## 4. Screen E02 — Administrator Dashboard Layout Editor

### Editor wireframe

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ Dashboard Layout Editor     Layout: [Executive Default ▼]  Version: Draft    │
│ [Preview] [Save Draft] [Publish] [Discard] [Reset to Approved Default]       │
├──────────────────────┬───────────────────────────────────────────────────────┤
│ COMPONENT CATALOGUE  │ DASHBOARD CANVAS                                      │
│                      │                                                       │
│ [ + KPI group ]      │ ┌─────────────────────┐ ┌───────────────────────────┐ │
│ [ + Phase breakdown] │ │ Portfolio KPI strip │ │ Project Phase Distribution│ │
│ [ + Phase changes ]  │ │ [Configure] [⋮]     │ │ [Configure] [⋮]           │ │
│ [ + Health]          │ └─────────────────────┘ └───────────────────────────┘ │
│ [ + Attention list] │ ┌───────────────────────────────────────────────────┐ │
│ [ + Risks ]          │ │ Recent Phase Changes [Configure] [⋮]             │ │
│ [ + Decisions ]      │ └───────────────────────────────────────────────────┘ │
│ [ + Finance ]        │ ┌─────────────────────┐ ┌───────────────────────────┐ │
│ [ + Weekly summary ] │ │ Risks               │ │ Weekly Summary            │ │
│ [ + Schedule ]       │ └─────────────────────┘ └───────────────────────────┘ │
│ [ + Custom status ]  │                                                       │
├──────────────────────┴───────────────────────────────────────────────────────┤
│ LAYOUT SETTINGS: Grid columns [12 ▼]  Density [Detailed ▼]  Responsive [On]  │
│ FINANCE WHEN UNAUTHORIZED: (•) Show restricted panel  ( ) Hide component    │
│ ROLE LAYOUT: [Executive ▼]   Access to data is still governed by permissions │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Editor interaction

- Only administrators with the dashboard-layout permission can enter edit mode.
- Add a component from the catalogue; drag to reorder; resize within supported grid widths; move between rows/sections; hide, restore, or remove from the active layout.
- “Configure” opens component-specific settings such as title, description, supported visualization, data binding, filters, grouping, sort order, row count, and display options.
- For financial components, layout inclusion and unauthorized-view behavior are configurable independently of financial-data grants.
- Preview displays the draft without publishing it to other users.
- Save Draft preserves unpublished changes. Publish creates a new version with audit details. Discard removes only the current draft changes.
- Reset returns to the currently approved default layout.
- Layout changes do not delete source records, KPI definitions, phase assignments, or history.
- Layouts cannot execute arbitrary SQL, scripts, or untrusted embedded widgets.
- Role-specific shared layouts may be configured by administrators. Personal layout editing is not available to ordinary users.

## 5. Screen E03 — CEO Presentation Mode

### Presentation wireframe

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EXECUTIVE PORTFOLIO REVIEW     Reporting Week [date range]   Snapshot status │
│                                                     [Exit Presentation]      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                    PORTFOLIO HEALTH & DELIVERY                              │
│                                                                              │
│        Total Projects       On Track       At Risk       Delayed             │
│             ##                ##             ##             ##              │
│                                                                              │
│                 Phase distribution / key portfolio movement                │
│                                                                              │
│                  Key changes since previous reporting week                  │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ [← Previous section]                         [Next section →]                │
│ Section indicator: 1 of N                                                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Presentation sequence

1. Portfolio health and project phase distribution.
2. Delivery performance and milestone outlook.
3. Projects requiring executive attention.
4. Highest-exposure risks and management decisions.
5. Financial position only when the executive has explicit financial authorization.
6. Weekly achievements, next priorities, blockers, and support required.

Presentation Mode is read-only. It simplifies navigation but never bypasses authorization. The reporting period, snapshot state, and as-of context remain visible throughout navigation.

## 6. Required states and safeguards

- **No finalized snapshot:** show an explicit no-snapshot state; do not silently substitute live data.
- **Live view:** clearly label as live and show last-updated context.
- **Insufficient data:** show Not Reported / Insufficient Data, never Green.
- **No phase assignment:** show Unassigned / Not Reported.
- **No phase changes in period:** show a clear empty state, not a blank table.
- **Unauthorized finance:** show the administrator-selected restricted panel or omit the component; do not leak values, counts, invoice identifiers, or other financial metadata.
- **Permission loss:** remove access to the underlying data immediately according to backend authorization, regardless of cached layout settings.
- **Historical snapshot:** retain its original data cutoff, configuration version, and reporting context.
- **Responsive layout:** components reflow at narrower widths without overlap; drag-and-drop editing is available only where supported and must have an accessible alternative.

## 7. Decisions still required before frontend implementation

This wireframe is a design proposal, not authorization to code. Confirm or revise:

1. Whether the proposed Executive Dashboard section order is approved.
2. Whether the Administrator Layout Editor controls are sufficient.
3. Whether the Presentation Mode sequence is approved.
4. Whether the phase history detail should include a mandatory transition reason, or make it optional/configurable.

No frontend code, framework selection, component-library selection, schema change, or deployment has been performed.
