# Change Requests, Deliverables, Milestones & Notifications — Scope Decision

**Decision date:** 20 November 2026  
**Status:** Approved scope; detailed design and implementation pending  
**Product:** Executive PPM Platform  
**Repository:** `mohmattar-GH/PMO-Dashboard-`

## Scope decision

The product owner has explicitly reversed the earlier decision to defer Change Request (CR) Management. Full CR Management is now included in the current release, together with dedicated Deliverables and Milestones trackers and a configurable Notification Centre.

This supersedes the prior checkpoint statement that CR Management is deferred. It does not authorize frontend implementation before the user reviews and approves the relevant screen designs and interactions.

## 1. Change Request Management

Provide an end-to-end controlled workflow, not merely a list of CRs.

### CR record
- Unique CR reference, title, description, reason/justification, requester, requesting organization, submission date and linked project.
- Origin/type/category, priority and affected contract, deliverables, milestones, activities and documents.
- Impact assessment covering scope, schedule, cost/budget, resources, risks, contractual terms, licenses and operational readiness.
- Before/after values and supporting evidence for each affected baseline or contractual item.
- Recommendation, decision, approver(s), decision date, decision rationale and comments.
- Implementation owner, target date, implementation status, verification and closure evidence.

### Configurable workflow
- Initial lifecycle proposal: Draft → Submitted → Impact Assessment → Pending Approval → Approved / Rejected / Withdrawn → In Implementation → Implemented → Verified → Closed.
- Workflow stages, transitions, required fields, approval levels, approver roles, thresholds, delegation, SLA timers and rejection/return paths must be configurable by authorized administrators.
- Enforce separation of duties and role-based authorization. A requester must not approve their own CR where the configured governance rules prohibit it.
- Capture immutable decision history, actor, timestamps, reasons, comments and record revisions.
- Approved CRs may update project scope, contract variation values, schedules, deliverables, milestones, activities, resource plans and reporting baselines only through controlled, auditable transactions.
- Approval must not silently overwrite original baselines. Preserve original baseline, approved revised baseline, forecast and actual values distinctly.
- Rejected, withdrawn and superseded requests remain traceable.
- Support CR register filters, search, status summaries, aging, approval bottlenecks, impact summaries and project-level drill-down.

### CR KPIs
- Open CR count by status and priority.
- CRs awaiting impact assessment / approval.
- Average approval cycle time and aging.
- Approved / rejected / withdrawn counts and rates.
- Pending and approved cost impact.
- Schedule impact (days) and affected milestones.
- CRs overdue against configured SLA.
- Approved CR implementation progress and overdue implementation actions.

## 2. Deliverables Tracker

Use the existing operational deliverables data model as the source of truth; verify and extend it only where required.

Each deliverable should support:
- Unique reference, name, description, category/type and linked project.
- Contractual / non-contractual classification and contract clause/reference where applicable.
- Deliverable owner, responsible team, reviewer and accepting authority.
- Planned/baseline, approved revised, forecast and actual submission/acceptance dates as applicable.
- Dependencies, linked activities and milestones, acceptance criteria and required evidence/documents.
- Submission version/history, review outcome, comments, rejection reason, resubmission and acceptance record.
- Configurable lifecycle and status mapping (for example: Not Started, In Progress, Ready for Submission, Submitted, Under Review, Changes Required, Accepted, Rejected, Waived, Cancelled).
- Full audit history; no loss of prior submissions or acceptance decisions.

### Deliverables KPIs
- Total deliverables by status.
- Submitted, accepted and rejected counts.
- Acceptance rate and on-time submission/acceptance rate.
- Overdue and upcoming deliverables.
- Deliverables awaiting client/authority review.
- Average review and acceptance cycle time.
- Deliverables at risk due to dependencies or CR decisions.

## 3. Milestones Tracker

Use the existing milestone and schedule records as the source of truth. Avoid duplicate milestone stores.

Each milestone should support:
- Unique reference, name, description, category, owner and linked project.
- Contractual / internal / payment / governance classification.
- Baseline date, approved revised date, forecast date and actual completion date kept separately.
- Completion/achievement evidence, acceptance authority, dependencies and linked deliverables/activities/CRs.
- Configurable criticality, weighting, tolerance, status mapping and escalation rules.
- Approval-controlled re-baselining with reason, approver and audit history.
- Milestone achievement history and change log.

### Milestone KPIs
- Achievement percentage (with configurable calculation basis).
- Achieved on time / achieved late.
- Upcoming milestones by configurable horizon.
- Overdue milestones and days overdue.
- Critical milestones at risk.
- Baseline-to-forecast variance.
- Milestones blocked by pending CRs, deliverables or dependencies.

## 4. Notification Centre

Provide an in-app notification centre and a configurable notification rules engine. External delivery channels should be enabled only when integration and credentials are configured and approved.

### Event coverage
- CR created, submitted, returned, assigned, assessment due, approval requested, approved, rejected, withdrawn, implementation due, implemented and closed.
- Deliverable due soon, overdue, submitted, review assigned, review overdue, changes requested, resubmitted, accepted, rejected or waived.
- Milestone approaching, forecast slipping, overdue, achieved, re-baselined or blocked.
- Dependency blocked/unblocked, ownership reassigned, decision required and escalation threshold reached.

### Administrator-configurable rules
- Events and triggering conditions, severity/priority, lead time and reminder interval.
- Recipient selection by user, role, project assignment, owner, approver, client contact (if authorized) and escalation chain.
- Per-event and per-project enable/disable controls.
- Business calendar, working days, timezone, quiet hours and escalation thresholds.
- Delivery channel: in-app initially; email and other channels only when configured and tested.
- Deduplication, grouping/digest behavior, retry policy, expiry and acknowledgement requirements.
- Rule versioning, effective dates and audit trail.

### User notification experience
- Unread/read state, mark read, acknowledge where required, filters and search.
- Deep link to the exact authorized source record.
- No sensitive details in notification previews when the recipient lacks access to the underlying record.
- Respect project membership, role permissions and financial/contract confidentiality.
- Record delivery attempts, outcomes and errors; do not represent a failed external delivery as successful.

## 5. Cross-module behavior and integrity

- CRs, deliverables, milestones, activities, contracts, invoices, risks and decisions must link to the same project and preserve referential integrity.
- Approved CR changes must flow into relevant operational records through explicit, auditable application steps.
- Dashboard, project register, project workspace, reports and timelines must derive values from authoritative records.
- Add project-level tabs/sections and portfolio-level registers for Change Requests, Deliverables and Milestones; include configurable dashboard components and drill-downs.
- Provide exports and filters consistent with the platform's existing reporting permissions.
- Historical weekly snapshots must preserve the exact source state and reporting configuration used; later changes must not rewrite finalized snapshots.
- All statuses, workflow rules, thresholds, SLA values, reminder periods and notification routing must be configurable and versioned. Do not hardcode business rules.
- Enforce authorization in database/RLS and trusted backend services, not only in the UI. Never rely on user-editable Auth metadata for roles.

## 6. Existing backend assets and gaps

Already present in the database foundation:
- `contract_deliverables`
- `project_milestones`
- `project_activities` and dependencies
- `project_contract_variations` with a draft → submitted → approved/rejected contract-variation workflow
- Private audit infrastructure and project document storage

Important distinction: contract variations are not a complete CR Management module. The existing table/workflow must be assessed and integrated or extended; do not create conflicting duplicate financial variation records. A CR may have financial impact, but approval and application of that impact must remain transactionally consistent with contract variation and financial terms.

Not yet established as implemented:
- Full CR intake, impact assessment, configurable multi-stage approvals, implementation/verification and closure.
- Complete deliverables lifecycle and versioned submission/acceptance workflow.
- Full milestone tracker UI and controlled re-baselining experience.
- Notification rules, recipient resolution, in-app inbox, delivery log and external channel integrations.
- Portfolio-level registers, KPI definitions and dashboard components for these modules.

## 7. Delivery and review gates

1. Update the PRD, project workspace screen specification, permission matrix, data model and acceptance criteria to include this approved scope.
2. Present the CR workflow, deliverables tracker, milestones tracker and notification centre wireframes for product-owner review.
3. Confirm approval roles, separation-of-duty rules, client-facing access and external notification channels before implementation.
4. Review database changes against the existing schema and migration history; reuse current tables where sound and create reviewed migrations only for genuine gaps.
5. Implement backend authorization, auditability, transaction integrity and tests before relying on UI controls.
6. Implement frontend only after the user approves the relevant wireframes and interaction approach.
7. Keep the separate Staff Time & Performance application untouched. Do not publish/deploy production without explicit user approval.

## 8. Explicit scope correction

Previous checkpoint notes stated that CR Management was deferred to a future release. The user's instruction on 20 November 2026 — “I want to include it all now” — supersedes that deferral. Full CR Management is part of the current release scope.
