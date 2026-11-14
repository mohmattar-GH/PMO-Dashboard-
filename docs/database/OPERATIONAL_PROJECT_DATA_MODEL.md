# Operational Project Data Model

## Supabase deployment
- Project: `oihawkpbtgqxxliaamxs` (Executive PPM Platform).
- Migrations 014–017 establish the operational record model, audit capture, role-scoped access, and configuration-driven risk/status fields.
- All 13 operational public tables have RLS enabled.
- All 13 operational tables have an audit trigger writing before/after records to private `security_audit_events`.
- Authenticated users have no DELETE privilege on these operational tables. Corrections should use status changes, reversals or controlled future workflows rather than deleting records.

## Operational modules

| Area | Tables | Purpose |
|---|---|---|
| Contracts | `project_contracts`, `contract_deliverables` | Contract references, dates, scope, obligations, acceptance, penalties, payment terms and deliverables |
| Financial terms | `project_financial_terms` | Original contract value, approved variation aggregate, tax/retention and payment terms |
| Schedule | `project_milestones`, `project_activities`, `project_activity_dependencies` | Baseline, approved revised, forecast and actual dates; weighted progress; owners; dependencies |
| Billing and cash | `project_invoices`, `project_cash_transactions`, `invoice_payment_allocations` | Invoice lifecycle, payment/credit/refund/adjustment transactions and partial allocations |
| Risk | `project_risks` | Risk description, probability/impact levels, owner, mitigation, dates, trend and escalation |
| Licenses | `project_licenses` | Provider, type, quantity, expiry, renewal and owner |
| Weekly reporting | `project_weekly_updates` | Achievements, completed/upcoming work, blockers, decisions, outlook and review status |
| Management | `project_management_decisions` | Decisions required, priority, ownership, deadlines and outcome |

## Data integrity and governance
- Composite foreign keys ensure child records reference a contract, milestone, activity, invoice or transaction in the same project.
- Date ranges and percentage/amount bounds are validated at database level.
- Baseline start/due dates are immutable through ordinary update operations. A separately approved and audited re-baseline workflow is still required.
- Project operational records are audited with actor, operation, entity, project and before/after JSON in the private audit schema.
- Finance records have separate read/write policies. Project finance members and global finance administrators can manage finance data; project managers and executive viewers have read access under current policy. Executive viewers therefore currently see finance records in the reporting context.
- Project managers/platform administrators can create/update contract, deliverable, milestone, risk, license, weekly update and management decision records.
- Assigned team leads can update their assigned activities; they cannot reassign the activity through that policy.
- Project managers/platform administrators can manage dependencies.
- Authenticated users cannot delete operational rows.
- Supabase Security Advisor: no findings. Health Advisor: no findings.
- Performance Advisor: no remaining unindexed foreign-key or multiple-permissive-policy findings after Migrations 015–016. INFO-level unused-index findings remain because no representative application workload has run.

## Configuration alignment
- Risk probability/impact levels are positive integers without a hard-coded 1–5 ceiling. Valid scale and matrix rules must come from the published reporting configuration.
- Risk score is a nullable calculated field; only trusted backend/database roles can set it. It remains unpopulated until the governed KPI/risk calculation engine exists.
- Invoice status is not constrained to a hard-coded list. Status mappings are to be governed by the reporting configuration.
- Progress and health are not automatically scored by these tables. Missing calculated results must remain Not Reported / Insufficient Data.
- Weight values are stored as fractions from 0 to 1; cross-record weight-sum validation is pending in the operational API/workflow layer.

## Important gaps before production use
1. No operational records exist yet; the database currently has no Auth users, projects or project memberships. Real data access tests cannot yet run.
2. The current database schema is a foundation, not a complete user-facing workflow. No project CRUD Edge Function or frontend screens have been implemented.
3. Invoice allocations currently have positive-amount and same-project constraints, but there is no transactional service yet enforcing allocation totals against invoice and cash transaction balances, currency consistency, reversals or concurrency.
4. Approved contract variations are not yet represented as a dedicated approval/variation ledger. The financial aggregate field must not be treated as an independently verified approved-variation calculation until that workflow exists.
5. A governed change-request/re-baseline approval workflow remains outstanding.
6. Project documents and private Storage bucket integration remain outstanding.
7. Timeline custom-event/category tables and the timeline UI remain outstanding; timeline views should derive events from these operational records.
8. Full source history is not yet retained for exact historical as-of reconstruction. Weekly snapshot source-cutoff flags identify post-cutoff changes but do not reconstruct prior values.
9. KPI/risk evaluation, validated calculation templates and financial roll-up engine remain outstanding.
10. Positive/negative end-to-end JWT/RLS tests require controlled Auth users and role assignments.

## Next implementation sequence
1. Provision test Auth users and controlled role/project memberships; validate role isolation and financial access.
2. Implement transactional APIs for invoice allocations, payments, credits, reversals and approved variations.
3. Add change requests and governed re-baseline approvals.
4. Add document metadata, private Storage and record-level access checks.
5. Implement validated KPI and risk calculations using published configuration versions.
6. Add source history, timeline event projection and weekly snapshot end-to-end tests.
7. Build frontend workflows only after the user confirms the framework/workflow direction.


## Secure project document management (Migrations 021–022)
- Document metadata and version history are stored separately from file bytes. Files reside in the private `project-documents` Storage bucket.
- Current limits: 50 MiB per file; PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, JPEG, PNG, TXT and CSV.
- Classification is mandatory and access is evaluated at request time against active project memberships and effective global role assignments. The classifications are `project`, `management`, `finance`, and `restricted`.
- Uploads use a pending metadata row and a unique immutable object path. Storage INSERT policy requires a matching pending version and write access. Finalization requires the object to exist and uses a database timestamp. Uploaded versions cannot be edited; new content is a new version.
- Reads require an uploaded version and current read permission. No public bucket, public URL, authenticated object update policy or authenticated object delete policy is configured.
- Current-version view: `public.project_document_current_versions` (security invoker).
- Both document tables have RLS and operational audit triggers.
- Backend is implemented; frontend UI and real-user upload/download/authorization tests remain outstanding. Do not describe document management as end-to-end complete until those tests and UI are delivered.


## Timeline read models (Migration 023)
Two read-only database projections now expose operational events for future timeline interfaces:

| View | Source events | Date semantics |
|---|---|---|
| `project_master_schedule_timeline` | Activities, milestones, contract commencement/end, license renewal/expiry, management decision due dates | Separate rows for baseline, approved revised, forecast and actual activity/milestone dates; contractual/forecast event dates for other records |
| `project_payment_risk_timeline` | Invoice issue/due dates, cash transactions, risk exposure intervals | Actual invoice issue/cash dates; contractual invoice due dates; risk interval from identification to resolution or target resolution |

- Both views use PostgreSQL `security_invoker = true`, are SELECT-granted to authenticated users, and rely on source-table RLS. They do not create duplicate event records.
- Stable event identifiers include source type, source record ID and event/date-basis discriminator. Each row carries the source record ID/reference, status, owner where applicable, severity, amount/currency where applicable and JSON metadata for drill-through.
- The master schedule projection preserves all four date scenarios independently; it does not infer one scenario from another.
- Current datasets are empty because no project or operational data has been provisioned. Validate view results and row visibility with controlled JWT users before production.
- Custom user-defined timeline events/categories, timeline UI, filtering/zoom/export, KPI evaluation and portfolio dashboard aggregates remain future work.
