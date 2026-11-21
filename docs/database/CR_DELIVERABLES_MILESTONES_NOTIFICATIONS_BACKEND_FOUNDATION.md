# CR, Deliverables, Milestones and Notifications — Backend Foundation

**Date:** 21 November 2026  
**Status:** CR approval engine implemented in the backend; CR-to-contract/schedule execution and other module workflows remain incomplete  
**Supabase project:** Executive PPM Platform (oihawkpbtgqxxliaamxs)  
**Repository branch:** feature/ppm-frontend-foundation

## Applied migration

20261121094748_project_change_request_workflow_and_notifications

The migration adds:
- Configurable workflow templates, version records, stages, transitions, role-code allowlists, stage requirements, and SLA hours.
- Project Change Request register with workflow-version/stage references, requester/owner, target decision date, implementation, verification and closure fields.
- Separate CR impact assessments. Financial impact data is more restricted than the base CR register and is limited to Project Manager / Finance project memberships and Platform Administrator / Finance Administrator global roles.
- Approval assignment and decision records, plus an append-oriented CR event-history table.
- Deliverable submission version records and review records.
- Additional deliverable ownership, classification, baseline/revised/forecast/actual submission and acceptance date fields. Deliverables default to acceptance_status = 'unaccepted'; accepted status requires the existing PM-controlled acceptance fields (accepted_by, accepted_at) and status accepted.
- Milestone re-baseline request and baseline-history tables.
- Admin-managed notification rules and per-user in-app notification inbox records with read/acknowledgement state and deduplication.

## Authorization and integrity controls

- RLS is enabled on all 14 new tables.
- Project-scoped access uses active project memberships and effective dates.
- CR financial impact rows are separately restricted.
- Workflow configuration and notification rules are Platform Administrator controlled.
- Approval decisions are editable only by the assigned user or Platform Administrator, and only decision fields are granted for client updates.
- Notification inbox rows are readable by the recipient; client updates are limited to read/acknowledgement fields. Inserts are reserved for trusted server-side processing.
- Delete privileges are revoked from authenticated users for the new records to preserve history.
- External email delivery is not configured or enabled.

## Verification performed

- Supabase migrations 064–066 were applied successfully: 20261121094748 (module schema), 20261121094854 (RLS policy overlap hardening and FK indexes), and 20261121094908 (composite deliverable-review FK index), and 20261121095042 (PM-only immutable deliverable acceptance guard).
- Catalog verification confirms RLS enabled on all 14 new tables and policies present.
- Deliverable acceptance default and required acceptance metadata constraint are present.
- Security Advisor: no new security findings; the two existing lifecycle SECURITY DEFINER WARNs and one intentional INFO for the server-only private formula-template table remain. The multiple-permissive-policy warnings introduced by the first policy layout were removed by migration 065. Performance Advisor now reports no unindexed foreign keys on the new module tables; 19 remaining unindexed-FK notices relate to pre-existing financial/lifecycle tables.
- Database currently has zero Auth users, projects, CRs, notifications and deliverables. No real-user or signed-JWT authorization tests were possible.

## Explicitly incomplete — do not treat as production-ready

This is a schema foundation, not the complete module implementation:
- CR transition engine, approval routing/parallel-vs-sequential execution, self-approval enforcement, mandatory impact completeness, SLA processing and atomic application to contract variations / schedules are not yet implemented.
- CR event-history population is not yet wired to all mutations.
- Deliverable submission/review write workflows and the PM acceptance action are not yet implemented as controlled atomic operations.
- Milestone re-baseline approval/application RPC and immutable baseline-change capture are not yet implemented. Existing milestone dates remain in their original authoritative table.
- Notification rule evaluation, recipient resolution, event generation, retry/delivery processing and acknowledgement enforcement are not yet implemented.
- Role-based recipient assignment and approver resolution require the workflow execution layer.
- No frontend screens were changed in this slice. Continue to present UI changes for review before implementation.

## Next backend gates

1. Implement workflow publication immutability and CR transition/approval engine with separation-of-duties checks.
2. Implement atomic, auditable CR application to contract variation and schedule records.
3. Implement deliverable submission, review and PM acceptance actions.
4. Implement milestone re-baseline approval and application without overwriting original baseline history.
5. Implement in-app notification event processing and recipient-safe deep links.
6. Add rollback-only authorization tests, then real signed-JWT HTTP tests once test accounts are provisioned.
7. Run clean migration replay, frontend build, and security/performance advisors.

No merge or deployment was performed. The Staff Time & Performance application was not accessed or modified.


## Migration source reconciliation

The four migration source files are named to match the versions recorded in the live Supabase migration ledger:
- 20261121094748_project_change_request_workflow_and_notifications.sql
- 20261121094854_cr_workflow_policy_and_index_hardening.sql
- 20261121094908_contract_deliverable_review_fk_index.sql
- 20261121095042_contract_deliverable_pm_acceptance_guard.sql

The 14 new tables all have RLS enabled. The seven new multiple-permissive SELECT policy warnings were eliminated by splitting write policies from read policies. Remaining Performance Advisor unindexed-FK findings are on pre-existing tables, not the new module tables. All four migration files were compared byte-for-byte against the SQL statements recorded in the live Supabase migration ledger; all matched. The clean-environment replay of the complete 67-migration chain has not yet been run.

The PM acceptance trigger is SECURITY INVOKER with an empty search_path; direct EXECUTE is revoked from client roles. Catalog verification confirms the trigger is installed and the strengthened status/acceptance constraint is active. A positive signed-JWT acceptance test remains pending because no Auth users or project fixtures exist.


## Change Request workflow engine — 21 November 2026

Migrations 068–084 implement the executable CR approval and approved-change application workflow. Migrations 085–087 add controlled deliverable submission, review and PM acceptance. Migrations 088–090 add event-driven in-app notifications:
- Administrator publication of a draft workflow version validates the configured stages, transition roles and required impact dimensions. Published workflow versions and their stage/transition/impact-dimension definitions are immutable; changes require a new version.
- Stage approval mode is configurable as sequential or parallel. Required approver roles are resolved against active, effective project memberships and global role assignments.
- CR submission is permitted only to an active Project Manager or Platform Administrator. A published/effective CR workflow must be selected.
- Every required impact dimension in the selected workflow version must have a recorded assessment or a not-applicable reason before submission. Assessment actors and timestamps are stamped by the database; impact rows are locked after submission.
- Approval decisions are processed atomically. Sequential stages block later approvers until earlier approval steps complete; parallel stages accept decisions in any order. The requester cannot approve their own CR.
- CR lifecycle fields cannot be changed directly by client updates. New CRs must start as drafts, requester identity is stamped from Auth, and submitted CR identity/content cannot be rewritten.
- Approval decision and history tables are not writable by authenticated clients. Approver-role members can read their role's pending approval rows. Public RPC endpoints are SECURITY INVOKER wrappers; narrowly scoped SECURITY DEFINER implementations are located in the non-exposed private schema. Anonymous execution is denied.
- Workflow transitions and decisions are written to append-only CR history in the same transaction.

### Rollback-only verification

A transaction-scoped fixture test used simulated Auth claim subjects and temporary test identities/project/workflow/CR records, then rolled the entire transaction back. The verified result:
- PM submission entered the configured review stage.
- A later sequential approver was denied while the earlier Finance approval remained pending.
- Finance approval was recorded and the workflow remained in review awaiting the next approval.
- Team Lead approval completed the sequence and moved the CR to the configured terminal Approved stage.
- Two approvals and three history events were present in the transaction result.
- A post-test query confirmed zero temporary Auth users, projects or CR records remain.
- Separate rollback-only guard tests confirmed direct client updates cannot set a CR status to an approved state and cannot directly publish a draft workflow version. Both attempts were rejected by the intended database guards.

This is SQL-level simulation, not a real signed-JWT HTTP/API test. Real Supabase Auth/JWT and Storage authorization testing remains outstanding.

### Still incomplete

- Approved CRs are not yet atomically applied to contract variations, contract values, schedule activities or milestone dates. This integration must avoid duplicate commercial adjustments and preserve approved variation history.
- No CR frontend screens/actions have been implemented; the approved wireframes remain the UI gate.
- SLA processing, due-date escalation and CR notification event generation are not yet connected to the notification rules/inbox.
- Admin UI for workflow template/version/stage/transition/impact-dimension authoring is not yet implemented.
- Parallel approval logic is implemented but the rollback-only integration fixture exercised the sequential path; parallel and self-approval denial still require dedicated test cases.
- Clean-environment replay of the complete 79-migration chain remains outstanding.


## Approved CR application to contract and schedule — 21 November 2026

Migrations 080–084 add atomic application of approved CR changes:
- Workflow stages now support a configurable decision outcome (approved/rejected) independently of whether the stage is terminal. This permits the CR to enter an Approved decision stage, apply changes, and continue through implementation/verification/closure stages.
- CR decision actor and timestamp are captured by the database. Every approval row records the actual deciding user, including role-based approvals where the approver was not preassigned to a named user.
- A financially impactful CR must have one net financial amount/currency, a linked contract, a matching draft contract variation and a Finance/Finance Admin approval stage. Currency must match the contract and project financial terms.
- The PM-facing RPC create_change_request_contract_variation creates a single CR-linked draft variation using the assessed net cost impact. The variation is protected from independent submission/approval; it can be approved only by the CR application path after all configured approval rounds complete and an actual Finance approval is recorded.
- Typed schedule-change records target an existing project activity or milestone and store proposed start/due dates plus reason. They can be created only while the CR is draft. Once approved, the application records the previous approved-revised dates and updates only approved_revised_start_date / approved_revised_due_date on the target activity or milestone. Baseline dates remain unchanged.
- Direct client edits to approved revised schedule dates are blocked. The approved CR application or the separate approved milestone re-baseline path is required.
- A single application record per CR captures applied actor/time, linked variation, financial amount/currency, schedule change count and audit metadata. The trigger applies variation, financial rollup and all schedule changes in the same transaction; any failure rolls back the entire CR approval transition. Duplicate application is blocked.
- Finance can read CR decision history and application records. Team Leads can read schedule impact records but do not receive financial application records.

### Rollback-only end-to-end verification

A transaction-scoped test used temporary Auth identities, a project, contract, financial terms, workflow, CR, activity and milestone. It then rolled back all fixtures. Verified results before rollback:
- PM created the CR, assessed required dimensions and created a linked draft variation for USD 100.
- PM submitted the CR; Finance then Team Lead approvals completed in configured sequential order. An out-of-order approval attempt was denied.
- The CR reached its configured Approved decision stage.
- The linked contract variation became Approved; the actual Finance approver was recorded as the variation decision actor.
- Project financial terms reflected USD 100 in approved variations.
- The activity approved-revised due date changed to 5 December 2026 and the milestone approved-revised due date changed to 15 December 2026. Original baseline dates were not changed.
- One application record and two applied schedule-change records were created.
- The entire test transaction rolled back. Follow-up counts confirmed zero temporary Auth users, projects and CRs.

This remains SQL-level simulation using temporary claim subjects, not real signed-JWT HTTP/API testing. Parallel approval, rejection/return paths, self-approval denial in a live user journey, and full Storage authorization still require dedicated tests.

### Still incomplete

- CR screens, schedule-change entry UI, variation creation action and approval inbox UI are not implemented. The approved wireframes remain the UI gate.
- SLA timers, due-date escalation, notification rule evaluation and event delivery are not connected to this workflow.
- Deliverable submission/review actions and PM-facing acceptance UI remain outstanding.
- Milestone re-baseline request approval/application is separate from CR schedule changes and remains outstanding; baseline date protection is already in place.
- Clean-environment replay of the complete 84-migration chain remains outstanding.


## Deliverable submission, review and PM acceptance — 21 November 2026

Migrations 085–087 implement the deliverable action layer:
- The assigned deliverable owner or an active Project Manager can submit a deliverable. A submission receives a sequential version number, submitted-by actor, timestamp, notes and optional project document/version reference.
- Document references are checked against the project and the user's document-classification read permission. Only uploaded document versions can be attached.
- The assigned reviewer or an active Project Manager can record one review decision per submission: accepted, changes_required or rejected. Rejection requires a reason.
- A reviewer decision of accepted does not accept the deliverable. The deliverable remains acceptance_status='unaccepted' and status='reviewed' until a separate PM acceptance action is performed.
- Only an active Project Manager assigned to the project can call the acceptance action. It requires the latest submission to have an accepted review outcome, then records accepted_by and accepted_at. Direct client acceptance/status updates are blocked.
- Submission and review tables are read-only to authenticated clients; writes occur through controlled RPC actions. Submission/review records are immutable except for the submission status update performed by the review action.
- Operational audit events are recorded for submissions and reviews. The deliverable operational history captures lifecycle state changes.

### Rollback-only verification

A transaction-scoped fixture test verified:
- Assigned Team Lead submitted a deliverable; submission number 1 and actual submission date were stamped.
- Assigned reviewer recorded an accepted review.
- Deliverable remained unaccepted after the review; the review outcome alone did not set acceptance fields.
- Direct PM table update attempting to mark it accepted was rejected.
- PM acceptance action succeeded and stamped the PM actor/time, changing status and acceptance_status to accepted.
- The transaction rolled back; no test users or deliverables were retained.

The test used simulated claim subjects, not signed-JWT HTTP/API or actual Storage file upload. Document classification validation is implemented, but end-to-end Storage upload/download and document-linked submission tests remain outstanding.


## Event-driven in-app notifications — 21 November 2026

Migrations 088–090 implement immediate in-app event notifications:
- Platform Administrators configure event rules with severity, recipient project roles/global roles, optional target users, actor exclusion, effective dates and acknowledgement requirement.
- Notification rule updates increment version_no and archive the previous rule configuration in ppm_notification_rule_history. Rule JSON is validated against the supported immediate-event recipient schema.
- CR events emit notifications for submission, approval needed, approval and rejection. Sequential workflows notify only the next actionable approver; the next approver is notified after the preceding approver completes their decision. Parallel workflows notify all assigned approvers.
- Deliverable events emit notifications for submission, review accepted, changes required, rejection and formal PM acceptance.
- Recipient resolution uses active profiles and effective project memberships/global role assignments. Notification rows are recipient-scoped and deduplicated by rule version, event instance, source record and recipient.
- Users can mark notifications read; the database stamps read_at. Rules requiring acknowledgement can be acknowledged once; the database stamps acknowledged_at. Notification content and recipient are immutable.
- In-app notifications only. No email integration or delivery. Scheduled reminders, lead-time triggers, repeats, quiet hours and escalation rules are explicitly rejected by the current rule validator and remain future work.

### Rollback-only notification verification

A transaction-scoped test configured CR submitted and CR approval-needed rules:
- PM received the CR submitted notification.
- Finance received the first sequential approval notification.
- Team Lead was not notified until Finance completed its approval; Team Lead was then notified.
- Finance marked its notification read and acknowledged it; read_at and acknowledged_at were stamped.
- Updating a rule incremented its version and archived the prior configuration.
- The CR reached its Approved stage and the transaction rolled back. No test users, projects, CRs, rules or notifications were retained.

This test used simulated Auth claim subjects, not signed-JWT HTTP/API requests. Deliverable event triggers are installed but require a separate event-specific integration test.

## Current module boundary

The backend now includes CR workflow execution and approved financial/schedule application, deliverable submission/review/PM acceptance, and immediate in-app notification generation. User-facing CR/deliverable/configuration/notification screens, scheduled notification processing, external email, milestone re-baseline approval/application, real signed-JWT/API/Storage tests, and full clean replay of the latest migration chain remain outstanding.


## PM-only Change Request decision model — 21 November 2026

Four migrations (20261121123154, 20261121123213, 20261121123320, 20261121123531) replace the previous CR approval route with a single assigned-Project-Manager decision:
- `submit_project_change_request` submits a draft after validating the selected published impact-dimension configuration, completion of every required assessment (assessed or N/A with a reason), and an active assigned Project Manager.
- `decide_project_change_request` permits only the assigned active Project Manager to accept or reject a submitted CR. The requester cannot decide their own CR. A reason is mandatory; actor and timestamp are database-recorded.
- There are no Finance, Team Lead or other approval stages, no sequential/parallel CR approval assignments, and no approval-needed notifications. The legacy transition RPC is disabled; approval rows are retained as historical data but client writes and approval triggers are disabled.
- Finance and technical impact remain assessment inputs. The old Finance-approval prerequisite for submission and for CR-linked contract variation application has been removed. Currency, contract/variation matching and transaction integrity checks remain.
- PM acceptance atomically applies the linked contract variation and approved schedule changes and writes an application/history record. Original baseline dates remain untouched.
- The assigned PM cannot be changed after submission. Direct lifecycle writes remain blocked by the database guard.
- In-app CR notifications now cover submission and the PM's accepted/rejected decision only.

### Verification and limitations

- Supabase applied all three migrations; the live migration ledger count is 95.
- Exact SQL source hash comparison passed for migrations 091 and 093. Migration 092 source was reconciled to the exact live ledger statement and exact comparison passed.
- Catalog checks confirm the new public RPCs are SECURITY INVOKER wrappers, callable by authenticated users; their private SECURITY DEFINER implementations are not executable by client roles. The old transition wrapper is not executable by authenticated users. Approval-assignment triggers and the legacy Finance submission guard are absent.
- Security Advisor shows no new CR-related warning. The two existing public lifecycle SECURITY DEFINER warnings remain; the private formula-template INFO remains. Performance Advisor still reports 19 unindexed-FK notices on existing lifecycle/financial tables; no new CR-module FK notice was reported.
- The database has no Auth users, projects or CR records, so positive/negative role-journey tests with real fixtures and signed JWTs could not be performed. The new RPC paths have been catalog-verified, not claimed as end-to-end tested.
- Full clean-environment replay of all 93 migrations and latest frontend build remain outstanding. No merge or deployment occurred.


### Migration ledger correction — 21 November 2026

- A subsequent live-ledger count confirmed 95 applied migrations (including the already-applied milestone re-baseline migration and the four PM-only CR refactor migrations). This count supersedes earlier 93/94 references in this checkpoint sequence.
- Added migration 20261121123531_revoke_legacy_cr_approval_helpers to revoke authenticated/service-role execution of obsolete approval and Finance trigger helpers. Its SQL source matches the live migration ledger exactly.
- Catalog verification confirms the legacy CR transition RPC and obsolete approval helper functions are not executable by authenticated users. The only active CR submission/decision API wrappers are the new PM-only SECURITY INVOKER RPCs.
