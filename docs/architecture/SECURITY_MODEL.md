# Database Security & Authorization Model

Status: design baseline — not yet applied to Supabase.
Target: Executive PPM Platform (`oihawkpbtgqxxliaamxs`) only.

## 1. Security objectives

- Deny access by default; no anonymous access to business data.
- Enforce authorization in PostgreSQL, not only in frontend navigation.
- Scope operational access by project membership and trusted global roles.
- Separate operational editing from financial, configuration-approval, and user-administration privileges.
- Preserve a complete audit trail for security-sensitive and management-significant changes.
- Never expose a Supabase service-role/secret key to a browser or desktop client.

## 2. Identity and trust boundaries

Supabase Auth is the identity provider. Application profile data is stored separately from authorization data.

- `user_profiles`: display name, contact/display preferences and account lifecycle metadata; linked 1:1 to `auth.users`.
- Global role claims, if used in JWTs, must be written only to trusted `app_metadata` by a privileged administrative workflow. Never authorize from `user_metadata`, because users can edit it.
- Project access is represented by database-managed `project_memberships` rows, with effective dates and active/revoked state.
- Role assignment, invitation, suspension and membership administration are privileged workflows. They must validate the actor's authority on the server and write an audit event.
- JWT claims may remain stale until refresh. Sensitive actions must re-check current database authorization rather than assuming a previously issued claim is instantly current.

## 3. Application roles and permissions

The following are proposed application roles. They are not PostgreSQL login roles.

| Capability | Platform Admin | Project Manager | Finance | Team Lead | Executive Viewer |
|---|---:|---:|---:|---:|---:|
| Manage users and global role assignments | Yes | No | No | No | No |
| Manage project registry and project membership | Yes | Assigned projects (limited) | No | No | No |
| Read assigned project operational records | Yes | Yes | Yes | Yes | All portfolio |
| Create/update project activities and milestones | Yes | Yes | Read | Assigned scope | No |
| Manage risks, issues and weekly updates | Yes | Yes | Read | Assigned scope | Read |
| Create/manage invoices, payments and allocations | Yes | Read | Yes | No | Read summary; detailed access configurable |
| Approve financial records | Yes | No by default | Authorized approver only | No | No |
| Draft reporting configuration | Yes | Authorized configuration steward | No | No | No |
| Approve/publish reporting configuration | Yes, with separation-of-duties controls | No by default | No | No | No |
| Generate/export reports | Yes | Yes | Finance reports | Assigned-scope reports | Yes |
| Read audit trail | Yes | Project-relevant events | Finance-relevant events | Own/project-relevant events | Executive audit summaries only |
| Manage private documents | Yes | Assigned projects | Finance documents | Assigned scope | Read permitted documents |

Notes:
- A person may hold more than one role, but approval workflows should prevent self-approval for high-impact changes where practical.
- Executive Viewer is read-only. Export permission is explicit and may be further restricted by report/data classification.
- Project Manager and Team Lead access is limited to active project memberships and assigned scope.
- Finance access is limited to finance records for authorized projects; it does not imply write access to delivery data.
- The matrix is a proposed default and must be confirmed before production rollout.

## 4. Authorization model

Use two authorization dimensions:

1. Global trusted role: platform administration and cross-project capabilities.
2. Project membership role: access to a particular project's operational and financial records.

Every business row should carry a `project_id` directly or be reachable through a constrained parent relationship. Child-table policies must validate access through the parent project, not trust a client-supplied project identifier.

Recommended policy structure:
- `SELECT`: active project member with an allowed role, or trusted executive/global reader.
- `INSERT`: active project member with create permission; validate project membership and ownership fields in `WITH CHECK`.
- `UPDATE`: both `USING` and `WITH CHECK`; also require an applicable `SELECT` policy.
- `DELETE`: deny by default for financial, audit, snapshot, configuration-version and approved-baseline records. Prefer controlled lifecycle transitions/archival.
- Admin-only workflows: execute through a trusted server-side function or Edge Function that verifies the actor and records the action. Do not give the browser a service-role key.

Avoid RLS recursion. If policies query membership tables, those tables need narrowly scoped self-read policies and explicit grants. Keep internal authorization tables outside exposed API schemas where practical. Do not add broad `SECURITY DEFINER` helpers merely to bypass a policy error.

## 5. Schema and API exposure

Recommended initial posture:
- No `anon` grants on business tables, views, or RPC functions.
- Enable RLS on every table in an exposed schema.
- Grant `authenticated` only the table/view/function privileges required by the UI.
- Keep internal authorization/audit/configuration tables out of exposed schemas unless there is a clear API need.
- Use `security_invoker = true` for views that are accessible to authenticated users, so underlying grants and RLS are evaluated as the caller.
- Verify Supabase Data API exposed-schema settings explicitly. New public tables are no longer automatically exposed by default; exposure and SQL grants are separate controls.
- Do not expose private Storage buckets. Storage object policies must check the same project/record authorization as document metadata.

## 6. Sensitive data boundaries

- Finance: invoice values, payment evidence, bank/payment references and financial notes require Finance or Admin permissions; executive access should use approved summaries unless detailed access is explicitly authorized.
- Contracts: commercial terms and attachments should be restricted by project and role.
- Documents: store files in private buckets; store only metadata and object path in database. Do not use public object URLs for confidential files.
- Configuration: draft, review, approve and publish are distinct permissions. Published versions are immutable.
- Snapshots: generated records are append-only; corrections create a superseding snapshot or explicit correction record rather than editing historical values.
- Audit: append-only to application roles; no ordinary user update/delete permission.

## 7. Audit requirements

Record at minimum:
- actor user ID and actor role/scope at action time;
- action and target entity/table/record;
- timestamp in UTC;
- before/after values for controlled fields (redact secrets and unnecessary personal data);
- reason/comment for overrides, re-baselines, approvals, configuration changes and financial adjustments;
- request/correlation identifier where available.

Audit events must be written server-side or by database triggers for critical fields. A client-provided actor ID is not authoritative; derive the actor from the authenticated context.

## 8. Authentication and session controls

- Require authenticated accounts for all application routes and business APIs.
- Use secure session handling appropriate to the selected frontend framework.
- Enforce MFA for privileged roles where the account plan and rollout permit it; at minimum require strong authentication for platform administrators and configuration approvers.
- Apply sensible JWT/session lifetime and revocation controls for privileged access.
- Deactivate access through membership/role state immediately in database policy checks; do not rely solely on deleting an Auth user to invalidate already-issued tokens.
- Invitation and password-reset flows must not disclose whether arbitrary email addresses have accounts.

## 9. Required RLS test matrix

Before any production release, test with separate real test identities for each role and at least two projects:

1. Anonymous user cannot read or mutate any business data.
2. Project A member cannot read or mutate Project B records by guessing UUIDs.
3. Team Lead cannot alter finance, project registry, configuration or another team's records.
4. Finance cannot alter delivery schedule, risk scores or project health.
5. Executive Viewer can read authorized portfolio views and export permitted reports, but cannot mutate source data.
6. PM cannot approve their own high-impact re-baseline/configuration change when separation of duties applies.
7. UPDATE cannot move a row into a project the user cannot access (`WITH CHECK`).
8. Child records cannot be attached to an unauthorized project through a forged foreign key.
9. Historical snapshots, audit rows, approved config versions and approved baseline versions cannot be edited/deleted by normal roles.
10. Private Storage objects cannot be downloaded or replaced across project boundaries.
11. A revoked membership loses access even if the user still has a valid JWT.
12. Views and RPCs do not bypass underlying RLS or reveal restricted columns.

## 10. Supabase-specific implementation guardrails

- Do not use `auth.role()`; target policies with `TO authenticated` / `TO anon`.
- Do not use user-editable `user_metadata` for authorization.
- UPDATE policies require both `USING` and `WITH CHECK`; UPDATE also needs SELECT visibility.
- Views exposed to clients should use `security_invoker = true` (PostgreSQL 15+).
- Avoid `SECURITY DEFINER`. If a documented exception is unavoidable, put the function in a non-exposed schema, pin a safe `search_path`, validate `auth.uid()` and arguments, restrict EXECUTE grants, and run security advisors.
- Never put service-role or secret API keys in client environment variables.
- Keep SQL migrations in GitHub and verify applied schema, grants, policies and advisors after each migration.

## 11. Implementation gate

This document is a design baseline, not evidence that RLS or grants have been deployed. No database access should be enabled until the schema, role matrix, policies and negative tests are implemented and verified in the dedicated PPM project.
