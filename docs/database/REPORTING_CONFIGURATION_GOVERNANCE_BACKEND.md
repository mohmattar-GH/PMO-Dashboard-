# Reporting Configuration Governance Backend

## Deployed service
- Supabase Edge Function: `reporting-config-governance`
- Project: `oihawkpbtgqxxliaamxs`
- Deployment status: ACTIVE
- Function version: 2
- JWT verification: enabled
- Source: `supabase/functions/reporting-config-governance/index.ts`

## Supported actions
All requests require a valid Supabase user JWT and a non-empty reason (8–1000 characters).
- `create_draft`: create a global/project configuration set and initial draft version, or create a new draft version in an existing set.
- `save_draft_rules`: add dimensions, KPI definitions and rule parameters to a draft. Calculation methods are allowlisted; arbitrary SQL is not executed.
- `submit`: steward/admin submits a draft.
- `approve`: approver/admin approves a submitted version.
- `publish`: approver/admin publishes an approved version, subject to effective date and active dimension checks.
- `supersede`: approver/admin supersedes a published version before a replacement is published.

## Authorization
The function validates the bearer token using Supabase Auth, then reads active, effective-dated global role assignments from the database. It does not trust user-editable metadata. Platform Admin and Configuration Steward can create/edit/submit; Platform Admin and Configuration Approver can approve/publish/supersede. Project-scoped creation also checks active project membership unless the actor is Platform Admin.

The function uses a server-side secret key only in the Edge Function runtime. No secret is returned to the browser. JWT verification is enabled.

## Audit
Migration 005 adds `public.write_reporting_configuration_audit`, a SECURITY DEFINER RPC with an empty search_path and execution granted only to service_role. It writes to the private audit schema. The Edge Function calls this RPC after each successful operation.

## Important limitations / test gates
- The Edge Function is deployed, but no authenticated test users/role assignments exist yet; successful and denied action paths have not been end-to-end tested.
- `save_draft_rules` is currently insert-only for a new draft version. It is not a general patch/delete API.
- Weight-sum validation, full formula-template validation, full parameter validation, transactionally atomic bulk rule saves, and concurrency-safe version-number allocation remain to be implemented before production use.
- A publish requires an active dimension and effective_from. The service enforces a single published version per configuration set.
- No configuration sets or rules have been seeded.
