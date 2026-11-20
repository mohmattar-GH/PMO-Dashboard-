# Executive PPM Platform — CR, Deliverables, Milestones & Notification Wireframes

**Status:** Draft for product-owner review  
**Date:** 20 November 2026  
**Scope:** Portfolio registers and project-level workflows for Change Requests, Deliverables, Milestones, and Notifications.  
**Implementation status:** Design only. No frontend code, schema change, or deployment is included.

## 1. Design principles

- This document extends the approved dashboard wireframes and current project workspace design.
- Full Change Request Management is included in the current release. This supersedes older screen-specification statements that CR Management was deferred.
- Portfolio registers provide cross-project oversight; project workspace trackers provide operational detail. Both use the same underlying records.
- Existing contract variations, contract deliverables, project milestones, activities, documents, audit and financial records must be assessed and reused or extended. Do not create duplicate financial variation records or duplicate milestone/deliverable sources.
- All workflow stages, statuses, approval routes, thresholds, SLAs, reminders, recipients and escalation rules are configurable and versioned.
- Every write is permission-checked by trusted backend/RLS, audited and traceable. UI visibility is not authorization.
- Historical snapshots remain immutable and retain the source/configuration context used at generation.
- The wireframes are conceptual. Example labels and values are illustrative, not live records.

## 2. Navigation and information architecture

Add the following portfolio-level navigation destinations:
- Change Requests
- Deliverables
- Milestones
- Notifications

Project Workspace adds:
- Change Requests
- Deliverables
- Schedule & Milestones (retain existing schedule/activity view and add milestone tracker context)

The Notification Centre is available from the global top bar and as a full-page inbox. Record-specific notifications deep-link to the exact authorized record.

## 3. Screen CR01 — Portfolio Change Requests Register

### Desktop wireframe

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Change Requests                              [Create CR] [Export ▼]         │
│ Search [________________]  Project [All ▼] Status [All ▼] Priority [All ▼] │
│ Owner [All ▼] Approver [All ▼] Submitted [Date range]   [More filters]     │
├─────────────────────────────────────────────────────────────────────────────┤
│ OPEN ##   AWAITING APPROVAL ##   OVERDUE SLA ##   APPROVED THIS PERIOD ##   │
│ PENDING COST IMPACT [permission-gated]   SCHEDULE IMPACT ##                 │
├──────┬───────────┬─────────┬──────────┬──────────┬──────────┬───────────────┤
│ CR # │ Title     │ Project │ Status   │ Priority │ Owner    │ Age / Due     │
├──────┼───────────┼─────────┼──────────┼──────────┼──────────┼───────────────┤
│ ...  │ ...       │ ...     │ ...      │ ...      │ ...      │ ...           │
└──────┴───────────┴─────────┴──────────┴──────────┴──────────┴───────────────┘
```

### Register behavior
- Search by CR reference/title; filter by project, status, priority, requester, owner, approver, date, SLA state and impact category.
- Configurable columns and saved administrative views; exports follow role and field permissions.
- Summary tiles drill into matching records.
- Each row opens CR02. Status and age use configured workflow/SLA rules; do not hardcode labels or thresholds.
- Financial impact figures are omitted unless the user has explicit financial permission. Do not leak hidden values through totals, tooltips, exports or metadata.

## 4. Screen CR02 — Change Request Workspace

### Record header and summary

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ CR-2026-###  [Status badge]  [Priority]  Project: [Project name]             │
│ [Edit] [Submit] [Withdraw] [More actions ▼]  (actions permission/state based)│
├─────────────────────────────────────────────────────────────────────────────┤
│ Summary | Impact Assessment | Approvals | Implementation | History | Files  │
├─────────────────────────────────────────────────────────────────────────────┤
│ Title / description / justification                                         │
│ Requester / submitted date / origin / category / affected contract          │
│ Business reason / urgency / desired effective date                          │
│ Linked deliverables / milestones / activities / risks / documents            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Tabs and fields

**A. Summary**
- CR reference, title, description, justification, origin/type/category, priority.
- Requester, organization, project, submitted date, desired effective date.
- Affected contract/clauses and linked records.
- Current workflow stage, assigned owner, next action, SLA due date.
- Record-level comments and attachments.

**B. Impact Assessment**
- Scope change: current vs proposed scope, inclusions/exclusions, acceptance implications.
- Schedule: affected activities/milestones, current baseline/revised/forecast dates, proposed impact in days and rationale.
- Cost/budget: amount, currency, one-off/recurring impact, tax/retention treatment as configured; visible only to authorized financial users.
- Resources: roles/capacity/duration and availability impact.
- Risks: new/changed risks, mitigations and residual exposure.
- Contractual/compliance/license/operational impacts.
- Assessment owner, evidence, assessment status, assumptions and confidence.
- Structured before/after comparison; preserve source baseline values.

**C. Approvals**
- Configurable approval stages and sequence/parallel rules.
- Approver, role, decision, timestamp, mandatory reason/comment, delegation and due date.
- Approve / reject / return for clarification / request reassessment actions only when authorized and valid for current state.
- Separation-of-duties validation; apply configured self-approval restrictions.
- Complete immutable decision trail.

**D. Implementation**
- Approved change package and linked operational records to update.
- Implementation owner, tasks, target dates, progress, verification criteria and evidence.
- Actual schedule/financial/scope effects recorded after implementation.
- Verification outcome, verifier, date and closure decision.
- An approved CR does not silently alter original baselines. Any revised baseline update is an explicit controlled action with reason, approver and audit.

**E. History & Files**
- Version history, field change log, workflow transition history, comments, documents and evidence.
- Preserve rejected, withdrawn, superseded and closed CRs for traceability.

### Configurable workflow proposal

Initial suggested stages (administrator-configurable):
Draft → Submitted → Impact Assessment → Pending Approval → Approved / Rejected / Withdrawn → In Implementation → Implemented → Verified → Closed.

The configuration must support return-for-clarification, reassessment, multiple approval stages, conditional routing, thresholds, delegated approvers, due dates, SLA pause/resume rules and escalation. These are proposals, not fixed rules.

## 5. Screen DL01 — Portfolio Deliverables Register

### Desktop wireframe

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Deliverables                                  [Add Deliverable] [Export ▼]  │
│ Search [____________] Project [All ▼] Status [All ▼] Owner [All ▼]         │
│ Due [Date range] Type [All ▼] Acceptance [All ▼]   [More filters]          │
├─────────────────────────────────────────────────────────────────────────────┤
│ TOTAL ##   IN PROGRESS ##   SUBMITTED ##   AWAITING REVIEW ##   OVERDUE ## │
│ ACCEPTED ##   REJECTED / CHANGES REQUIRED ##                                │
├────────┬────────────┬─────────┬───────────┬──────────┬──────────┬───────────┤
│ Ref    │ Deliverable│ Project │ Owner     │ Due      │ Status   │ Reviewer  │
├────────┼────────────┼─────────┼───────────┼──────────┼──────────┼───────────┤
│ ...    │ ...        │ ...     │ ...       │ ...      │ ...      │ ...       │
└────────┴────────────┴─────────┴───────────┴──────────┴──────────┴───────────┘
```

### Deliverable detail drawer/page

- Reference, title, description, project and contract linkage.
- Contractual/internal classification, contract clause, deliverable type/category.
- Owner, producing team, reviewer and accepting authority.
- Acceptance criteria and required evidence.
- Baseline/revised/forecast/actual submission and acceptance dates where applicable.
- Linked activities, milestones, dependencies and related CRs.
- Submission version list with uploaded file, submitter, timestamp and notes.
- Review decision: accepted / changes required / rejected / waived, reviewer, date and reason.
- Resubmission creates a new version; never overwrite earlier submitted evidence.
- Full comments, activity and audit history.

### Proposed configurable lifecycle

Not Started → In Progress → Ready for Submission → Submitted → Under Review → Accepted / Changes Required / Rejected / Waived / Cancelled.

Allow resubmission and configurable review stages, acceptance authority, SLA and transitions. Statuses and transitions are administrator-managed.

## 6. Screen MS01 — Portfolio Milestones Register

### Desktop wireframe

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Milestones                                    [Add Milestone] [Export ▼]   │
│ Search [____________] Project [All ▼] Status [All ▼] Criticality [All ▼]   │
│ Owner [All ▼] Date [Range] Type [All ▼]   [More filters]                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ TOTAL ##   ACHIEVED ##   UPCOMING ##   OVERDUE ##   AT RISK ##              │
│ ON-TIME ACHIEVEMENT ##%   BASELINE VARIANCE [configured unit]               │
├───────────┬─────────┬─────────┬────────────┬────────────┬──────────┬────────┤
│ Milestone │ Project │ Owner   │ Baseline   │ Forecast   │ Status   │ Variance│
├───────────┼─────────┼─────────┼────────────┼────────────┼──────────┼────────┤
│ ...       │ ...     │ ...     │ ...        │ ...        │ ...      │ ...    │
└───────────┴─────────┴─────────┴────────────┴────────────┴──────────┴────────┘
```

### Milestone detail
- Reference, title, description, project, category (contractual/internal/payment/governance/custom), owner and criticality.
- Original baseline date, approved revised baseline, forecast date and actual completion date shown separately.
- Progress/achievement evidence, acceptance authority and completion approval where required.
- Linked activities, dependencies, deliverables and CRs.
- Delay/variance calculation explanation, source rule and reporting configuration version.
- Re-baseline request: proposed date, reason, impact, supporting CR (where applicable), approver and audit history.
- Preserve prior baseline values and change history; ordinary edits cannot overwrite original baseline.
- Timeline/Gantt link opens the same authoritative milestone record, not a duplicate event.

## 7. Screen NT01 — Notification Centre

### Inbox wireframe

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Notifications                 [Mark visible as read] [Notification settings]│
│ Inbox ##  Unread ##  Assigned to me ##  Escalated ##                        │
│ Filter: All / Unread / CRs / Deliverables / Milestones / Escalations        │
├───────────────┬─────────────────────────────────────────────────────────────┤
│ TODAY         │ [High] CR-### approval required                             │
│               │ Project / short safe summary / due time                     │
│               │ [Open record] [Acknowledge]                                 │
│               ├─────────────────────────────────────────────────────────────┤
│ EARLIER       │ [Medium] Deliverable review overdue                         │
│               │ Project / short safe summary / due time                     │
│               │ [Open record] [Mark read]                                   │
└───────────────┴─────────────────────────────────────────────────────────────┘
```

### User interactions
- Unread/read, acknowledge where required, filters, search and pagination.
- Deep link opens the exact source record only if the user still has access.
- Notification preview must not reveal confidential CR, contract or financial details to unauthorized recipients.
- Distinguish informational notifications from action-required tasks and escalations.
- Delivery status is visible where appropriate; failed email delivery is never shown as successful.

## 8. Screen NT02 — Administrator Notification Rules

### Rules editor wireframe

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Notification Rules                         [Create Rule] [Publish Version] │
│ Rule set [Global ▼] Version [Draft]   Effective from [date]                 │
├─────────────────────────────────────────────────────────────────────────────┤
│ EVENT              CONDITION       RECIPIENT       CHANNEL    REMINDER      │
│ CR approval needed  Submitted       Approver role   In-app     SLA-based     │
│ Deliverable overdue Due date passed Owner + PM      In-app     Daily*        │
│ Milestone at risk   Threshold hit   PM + Sponsor    In-app     Configurable  │
├─────────────────────────────────────────────────────────────────────────────┤
│ Selected rule: [event] [conditions] [severity] [recipients]                 │
│ [lead time] [repeat interval] [business calendar] [quiet hours]             │
│ [escalation chain] [deduplication] [expiry] [acknowledgement required]      │
│ Channels: In-app (initial) | Email / other channels when integrated/tested  │
│ [Test rule] [Save draft] [Discard] [Publish]                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Rule configuration
- Event type and source entity; condition/threshold; severity; lead time and repeat cadence.
- Recipients by user, project role, owner, requester, approver and configured escalation chain.
- In-app channel initially; email and other external channels only after provider integration, permissions, delivery testing and operational approval.
- Working calendar, timezone, quiet hours, SLA pause/resume, deduplication, digest/grouping, retry, expiry and acknowledgement.
- Per-rule and per-project enable/disable, effective dates, draft/publish lifecycle and immutable version/audit history.
- Test/preview must show resolved recipients and sample payload without sending real messages unless a separately confirmed test-send action is used.

### Initial event catalogue
- CR created/submitted/returned/approval requested/approved/rejected/implementation due/implemented/verified/closed.
- Deliverable due soon/overdue/submitted/review assigned/review overdue/changes requested/resubmitted/accepted/rejected.
- Milestone approaching/forecast slipping/overdue/achieved/re-baselined/blocked.
- Dependency blocked/unblocked, ownership reassigned, decision required and escalation threshold reached.

## 9. Permissions and governance

- Project Manager: create/manage CRs and trackers for assigned projects within configured authority; submit CRs and assess impacts; cannot bypass approvals.
- Approver: decide only assigned approval stages; decisions require configured rationale and are audited.
- Finance: assess/approve financial impacts and contract variations within assigned permissions.
- Team Lead / contributor: update assigned activities and deliverable evidence as permitted.
- Executive Viewer: read-only portfolio/project visibility subject to project scope and explicit financial permission.
- Administrator: configure workflows, statuses, approval routing, notification rules and permissions; administrative configuration changes are versioned and audited.
- Exact permissions and separation-of-duty constraints must be finalized in the permission matrix. No role inherits authority merely from UI visibility.

## 10. Cross-module behavior

- Approved CRs can create or update linked work only through a controlled application step. The system records exactly which deliverables, milestones, activities, contract variation and financial terms were affected.
- A CR with commercial impact must integrate with the existing contract-variation model rather than creating a second competing financial adjustment.
- Deliverable and milestone trackers use the existing authoritative tables where possible.
- All trackers appear at both project and portfolio level using the same record IDs and filters.
- Notifications reference source records and honor their permissions at delivery and at click time.
- Dashboard KPIs and timelines derive from authoritative operational records.
- Weekly snapshots preserve source and configuration state; later approvals or updates do not rewrite prior finalized snapshots.

## 11. Product-owner review decisions

Please review and approve or revise:
1. CR lifecycle and approval design: should approval be sequential, parallel, or configurable per CR type/impact threshold? Recommended: configurable, with sequential and parallel stages supported.
2. Whether every CR must include a documented schedule/cost/scope impact assessment, or whether impact sections can be marked not applicable with a reason. Recommended: mandatory assessment outcome for each impact dimension.
3. Deliverable acceptance: which roles may accept deliverables, and is client/authority acceptance captured internally or through a future external portal? Recommended: configurable accepting authority; internal capture in this release.
4. Milestone re-baselining: should it require an approved CR, or can an authorized standalone re-baseline request be approved? Recommended: support both paths, with mandatory reason and audit.
5. Notifications: approve in-app as the initial channel, with email enabled only after integration and delivery tests? Recommended: yes.
6. Reminder/escalation schedules and business calendars: configure globally with project overrides? Recommended: yes.
7. Should notification acknowledgement be mandatory for all action-required items, or only selected severity/event types? Recommended: configurable by rule.

**Approval boundary:** This is a design proposal only. No frontend implementation, database migration, external notification integration or production deployment has been performed.

## Product-owner decisions — 20 November 2026

The user has confirmed the following design decisions for this release:

1. **CR approval routing:** Configurable. The workflow must support sequential and parallel approval stages, with routes governed by administrator-managed configuration.
2. **CR impact assessment:** Required for every CR. Each impact dimension must contain an assessment or be explicitly marked Not Applicable with a documented reason.
3. **Deliverable acceptance:** A deliverable remains **Unaccepted** until the Project Manager formally records acceptance in the system. Submission or review activity alone must not change it to Accepted.
4. **Milestone re-baselining:** Support both an approved Change Request and a separate approved re-baseline request. Require a reason, preserve prior baseline values and retain approval/audit history.
5. **Notification channels:** Implement in-app notifications first. Email is enabled only after provider integration and delivery testing.
6. **Reminder and escalation schedules:** Provide global defaults with project-level overrides.

**Still awaiting product-owner decision:**

7. **Notification acknowledgement:** Whether acknowledgement is required for every action-required notification or is configurable by event type and severity. Do not assume a default until confirmed.

These are approved product decisions for design. They do not authorize frontend implementation, schema changes or deployment. The user must still review and approve the complete wireframes and interaction approach before implementation begins.
