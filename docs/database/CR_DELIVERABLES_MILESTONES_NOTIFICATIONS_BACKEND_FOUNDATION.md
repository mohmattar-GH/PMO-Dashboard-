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

Migrations 068–079 implement the first executable CR approval workflow:
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
