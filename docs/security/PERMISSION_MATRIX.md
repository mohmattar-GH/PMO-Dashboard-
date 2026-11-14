# Application Permission Matrix

Status: proposed baseline for implementation review. Permissions are enforced in PostgreSQL RLS and trusted server-side workflows; UI visibility is not a security boundary.

## 1. Role model

Global roles:
- `platform_admin`: administers the platform, trusted roles and global settings.
- `executive_viewer`: portfolio-wide read-only access and authorized report export.
- `configuration_steward`: drafts reporting configurations; cannot approve their own high-impact changes.
- `configuration_approver`: approves and publishes configuration versions.
- `finance_admin`: finance-wide administration where explicitly assigned.

Project-scoped roles:
- `project_manager`: manages assigned project's operational delivery records.
- `finance`: manages assigned project's financial records only.
- `team_lead`: manages assigned activities and permitted delivery updates.
- `project_viewer`: read-only access to assigned project records within data-classification restrictions.

A user may have multiple assignments. Effective access is the union of explicitly granted permissions, subject to separation-of-duties restrictions and sensitive-data rules. Global roles must be assigned only by trusted administrative workflows.

## 2. Entity-level permission matrix

Legend: C=create, R=read, U=update, A=approve, E=export, —=no access. “Assigned” means only projects with an active membership. Sensitive columns may be withheld even where row-level read is allowed.

| Data domain | Platform Admin | Executive Viewer | Project Manager | Finance | Team Lead | Project Viewer |
|---|---|---|---|---|---|---|
| Portfolio/project registry | C/R/U | R | R/U for assigned projects; create only if delegated | R | R assigned | R assigned |
| Project team assignments | C/R/U | R summary | R/U assigned, no global roles | R limited | R assigned | R limited |
| Project contracts/obligations | C/R/U | R summary; details policy-controlled | R/U assigned | R financial terms only | R delivery obligations assigned | R approved fields |
| Change requests | C/R/U/A | R | C/R/U; approval per delegation | R financial impact; approve finance impact if assigned | R assigned | R |
| Activities/dependencies | C/R/U | R | C/R/U assigned | R | C/R/U assigned scope | R |
| Milestones and schedule dates | C/R/U/A | R | C/R/U; submit rebaseline | R | U assigned execution dates/progress, not baseline | R |
| Risks and mitigations | C/R/U | R portfolio | C/R/U assigned | R financial exposure | C/R/U assigned | R |
| Issues/decisions/weekly updates | C/R/U | R portfolio | C/R/U assigned | R finance-relevant | C/R/U assigned | R |
| Invoices/adjustments | C/R/U/A by delegated workflow | R summary; detailed values configurable | R status/summary; no amount edits | C/R/U; A only if designated | — | R limited summary |
| Payments/allocations | C/R/U/A by delegated workflow | R summary; detailed values configurable | R status/summary | C/R/U; A only if designated | — | R limited summary |
| Licenses/renewals | C/R/U | R | C/R/U assigned | R cost fields if allowed | R assigned | R approved fields |
| Reporting configuration drafts | C/R/U | — | Request change only | Request finance-rule change only | Request change only | — |
| Reporting configuration approval/publication | A subject to separation of duties | — | — | — | — | — |
| Weekly snapshots | R; controlled correction workflow | R/E | R assigned project snapshots | R finance-relevant metrics | R assigned project snapshots | R assigned project snapshots |
| Audit trail | R all | R executive summary | R relevant project events | R finance events | R own/project events | — |
| Private documents | R/U all subject to classification | R allowed executive documents | C/R/U assigned permitted docs | C/R/U finance docs | C/R/U assigned delivery docs | R explicitly shared docs |
| User accounts/global roles | C/R/U | — | — | — | — | — |
| Project memberships | C/R/U | — | Request or manage assigned project members only if delegated | — | — | — |
| Report export | E authorized reports | E portfolio and project reports | E assigned projects | E authorized finance reports | E assigned-scope reports | E only if granted |

## 3. Data classification and field-level restrictions

- **Internal operational:** project plans, activities, milestones, risks, weekly updates. Project membership governs access.
- **Commercially confidential:** contract terms, pricing, invoice values, payment evidence, penalties and margins. Finance/Admin and explicitly authorized project leadership; executive detail access must be configurable.
- **Restricted security/admin:** role assignments, security configuration, audit internals, secrets and integration credentials. Platform Admin or dedicated trusted server workflows only.
- **Historical reporting:** snapshot values are read-only to ordinary users. A correction creates a linked replacement/correction record.

Row-level RLS alone does not hide individual columns. Use column grants, narrowly scoped views with `security_invoker = true`, or trusted server-side endpoints for restricted fields. Do not expose full rows and rely on UI masking.

## 4. Critical workflow permissions

### Configuration lifecycle
1. Steward creates a draft version.
2. System validates supported template, parameter schema, weights, thresholds, effective dates and scope.
3. Approver reviews the full diff, reason and impact.
4. Approver publishes; the version becomes immutable.
5. Runtime resolves global defaults plus permitted project/activity/milestone overrides.
6. Snapshots record every resolved configuration version.
7. A user cannot approve their own high-impact configuration change unless an explicit emergency policy is later approved and audited.

### Baseline re-planning
1. PM submits a re-baseline request with rationale and impact.
2. Required approver reviews it.
3. Approval creates a new baseline version; original baseline remains preserved.
4. Forecast changes do not require or mutate a baseline approval.
5. Every change is auditable.

### Finance
- Finance users can create/update invoices, payment receipts, allocations and adjustments within assigned projects.
- Approval authority is separate from data entry where practical.
- Allocations must be validated transactionally; users cannot create cross-project or currency-invalid allocations.
- Project Managers may view status/summary without receiving unrestricted payment evidence or bank details.

### Executive reporting/export
- Executive Viewer is read-only.
- Export permission is a separate explicit capability.
- Exports apply the same project, role and data-classification rules as on-screen views.
- Every export should record requester, report type, filters/as-of date, timestamp and output classification.

## 5. RLS policy patterns to implement

- Enable RLS on every table in an API-exposed schema.
- Use `TO authenticated` explicitly in policies.
- Use `(select auth.uid())` for stable caller identity checks.
- Project child rows must validate active membership through their parent project's `project_id`.
- UPDATE requires both `USING` and `WITH CHECK`, and an applicable SELECT policy.
- INSERT checks must validate both project access and protected ownership/approval fields.
- Deny DELETE by default for finance, audit, snapshots, published config, approvals and baseline history.
- Keep internal role/audit tables in a non-exposed schema where possible.
- If an RLS helper requires `SECURITY DEFINER`, keep it in a non-exposed schema, pin `search_path`, fully qualify referenced objects, revoke default EXECUTE grants, grant only required roles, and test it as an untrusted caller. Prefer direct RLS subqueries when practical.
- Never authorize from user-editable `user_metadata`.

## 6. Required authorization test cases

Use at least two projects (A and B) and separate identities for every role:
1. Anonymous cannot read or mutate any business record.
2. Project A PM cannot access Project B rows by guessing IDs.
3. Team Lead cannot change contract value, invoice amount, payment allocation, configuration or baseline version.
4. Finance cannot change activity progress, milestone dates, risk rating or project health.
5. Executive Viewer can read approved portfolio reporting and export only authorized data; all writes fail.
6. Project Viewer cannot mutate any record.
7. Revoked membership immediately loses access even while an existing JWT remains valid.
8. A forged `project_id` or parent foreign key cannot attach a row to another project.
9. UPDATE cannot transfer an accessible row into an inaccessible project.
10. Published config, approved baseline, audit and weekly snapshot records cannot be edited/deleted by normal roles.
11. A user cannot approve their own protected configuration or baseline change.
12. Restricted finance columns and private documents remain inaccessible to unauthorized roles.

## 7. Decisions to confirm before production

The matrix is a sensible default, not a claim that organizational delegations are already known. Confirm:
- Whether Executive Viewer can see all commercial contract and invoice amounts or only portfolio summaries by default.
- Whether PMs can see detailed invoice/payment values for their assigned projects.
- Which roles can approve financial transactions and schedule re-baselines.
- Whether project membership administration is delegated to PMs.
- Whether exports are enabled for all project viewers or only named roles.
