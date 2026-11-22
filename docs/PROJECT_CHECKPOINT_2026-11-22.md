# Verified Project Checkpoint — 22 November 2026

## Project and boundaries

- Product: Executive Project Portfolio Management (PPM) Platform / PMO Dashboard.
- GitHub repository: `mohmattar-GH/PMO-Dashboard-`, default branch `main`.
- Dedicated Supabase project: `oihawkpbtgqxxliaamxs` (Executive PPM Platform).
- Existing Staff Time & Performance application and Supabase project are separate and must remain untouched.
- User handles publishing/deployment. Do not deploy production without explicit approval.
- Frontend framework/component-library choice remains open. Do not implement frontend until the user approves the complete UI screen structure and interactions.

## User-approved product scope

- CEO-ready portfolio dashboard for weekly reviews, with detailed standard dashboard and separate read-only Presentation Mode.
- Project Register and detailed project workspace, including project phase, contracts, financial terms, schedules/activities, milestones, deliverables, risks, licenses, invoices/payments, weekly updates, decisions, documents, and team ownership.
- Configurable standalone master schedule timeline and separate payment/risk timeline views. Custom timeline events must not duplicate source records.
- Full Change Request management is included in the current release (this supersedes the earlier defer-CR decision).
- Deliverables tracker with submission/review/resubmission history. A deliverable remains Unaccepted until the Project Manager explicitly accepts it.
- Milestone tracker with original baseline, approved revised baseline, forecast and actual dates retained separately; support approved CR-driven and standalone approved re-baselining.
- In-app Notification Centre first. Email/external channels only after integration and delivery testing.
- Notification recipients and acknowledgement are configurable; acknowledgement is required only for selected event types/severities.
- Global reminder/escalation defaults with project-level overrides.
- Dashboard content/layout is administrator-controlled: add/remove/hide/restore/reorder/resize/reposition components. Layout changes do not delete source data.
- CEO/Executive Viewer financial visibility is restricted by default; an explicit grant is required and enforced by backend authorization.
- All KPI rules, formulas/templates, weights, thresholds, status mappings, workflow stages, approval routing, date rules, risk scoring, notification routing, SLAs and dashboard layout settings must be configurable, versioned, permission-controlled and audited.
- Weekly snapshots retain source cutoff and exact configuration lineage; historical snapshots must not be silently recalculated.
- Missing information must not be interpreted as Green.
- CR approval routing is configurable for sequential/parallel stages. Every impact dimension requires an assessment or Not Applicable with documented reason. PM decision model is recorded in recent migrations.

## Verified Supabase state on 22 November 2026

Live Supabase inspection returned an applied migration history through:
- `20261121211410` — `configurable_project_risk_score_engine`.

The applied migration history includes:
- Identity/access and project register foundation.
- Versioned reporting configuration, KPI evaluator and weekly snapshot pipeline.
- Operational project records, finance integrity, document storage and timeline read models.
- Configurable project lifecycle and phase history.
- CR workflow, transition engine, impact assessment, approvals, controlled contract/schedule application, implementation/verification/closure.
- Deliverable submission/review/PM acceptance actions.
- In-app notification engine, routing and recipient update permissions.
- Administrator-managed dashboard layout versions/history.
- Custom master-schedule timeline events.
- Configurable risk scoring.

Live table inventory confirmed the corresponding public tables exist and RLS is enabled on all listed public tables. Key tables include:
- `projects`, `project_memberships`, `project_contracts`, `project_financial_terms`
- `project_activities`, `project_activity_dependencies`, `project_milestones`
- `contract_deliverables`, `contract_deliverable_submissions`, `contract_deliverable_reviews`
- `project_change_requests`, `project_change_request_impacts`, `project_change_request_approvals`, `project_change_request_history`
- `project_milestone_rebaseline_requests`, `project_milestone_baseline_history`
- `project_invoices`, `project_cash_transactions`, `invoice_payment_allocations`, `project_risks`, `project_licenses`
- `ppm_notification_rules`, `ppm_user_notifications`
- `ppm_dashboard_layouts`, `ppm_dashboard_layout_history`
- `project_custom_timeline_events`, `project_custom_timeline_event_history`
- Reporting configuration, KPI, weekly cycle, portfolio/project snapshot and snapshot correction tables.

Important data-state qualification:
- The database has no provisioned user profiles, global role assignments, project memberships or operational project records yet; most business tables are empty.
- Lifecycle template seed data, dashboard layout seed data, role definitions and related template records are present.
- A database table and migration being present does not prove the end-to-end user workflow has passed acceptance testing.

## GitHub repository state

- Documentation, SQL migration source and Supabase Edge Function source are committed.
- Repository root currently contains `README.md`, `docs/` and `supabase/`.
- No frontend application source was present in the inspected root.
- README was reconciled with the verified live backend state in commit `b2fb2099a8148f314871765048942e6aa0239d6e`.

## UI review gate — still open

The repository contains:
- `docs/UI_UX_PROPOSAL.md`
- `docs/UI_SCREEN_SPECIFICATIONS.md`
- `docs/UI_DASHBOARD_WIREFRAMES.md`
- `docs/UI_CR_DELIVERABLES_MILESTONES_NOTIFICATION_WIREFRAMES.md`

The design documents explicitly require user review before frontend implementation. User has approved several principles (detailed dashboard, administrator-only layout control, separate phase components, presentation mode, financial access restrictions, CR/Deliverable/Milestone scope), but the complete screen structure and interaction approach still require review/explicit approval.

## Outstanding work — priority order

1. **UI/product-owner review:** Walk through the dashboard, Project Register, project workspace, CR, Deliverables, Milestones, Notification Centre, configuration screens and Presentation Mode. Confirm complete navigation, screen hierarchy and interaction behavior.
2. **Backend security verification:** Provision controlled test users/roles/projects and run positive/negative JWT/RLS tests across all modules, especially financial data, approvals, notification recipients, document access and administrative configuration.
3. **Backend workflow acceptance:** Exercise CR creation/impact/approval/application/verification/closure; PM acceptance of deliverables; milestone re-baseline approval; notification rule delivery and inbox behavior; dashboard layout versioning.
4. **Snapshot/KPI validation:** Test configured KPI calculations, missing-input behavior, source cutoffs, historical lineage and reproducibility with realistic seeded data.
5. **Frontend implementation:** Only after explicit UI approval; select framework and component library with the user.
6. **End-to-end and regression testing:** Validate all roles, exports, responsive behavior, timelines, audit history and error/empty states.
7. **Operational handover:** Update checkpoint and technical documentation. Production publishing remains with the user and requires explicit approval.

## Do not do

- Do not modify the Staff Time & Performance application or its Supabase project.
- Do not deploy/publish production.
- Do not hardcode business rules or expose service-role secrets to browser code.
- Do not create duplicate sources of truth for milestones, deliverables, contract variations or timeline events.
- Do not start frontend implementation before the user approves the full UI structure and interactions.
