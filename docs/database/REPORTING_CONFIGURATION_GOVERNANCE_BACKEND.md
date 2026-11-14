# Reporting Configuration Governance Backend

## Deployed service
- Supabase Edge Function: `reporting-config-governance`
- Project: `oihawkpbtgqxxliaamxs`
- Deployment status: ACTIVE
- Function version: 3
- JWT verification: enabled
- Source: `supabase/functions/reporting-config-governance/index.ts`
- Edge Function delegates each operation to one transactional PostgreSQL RPC; it no longer performs multi-request writes.

## Database migration 008
- Applied version: `20261114100526`
- Name: `migration_008_atomic_reporting_configuration_governance`
- Source: `supabase/migrations/20261114100526_migration_008_atomic_reporting_configuration_governance.sql`
- Adds private `reporting_formula_templates` registry with six initial allowlisted calculation templates: weighted_sum, ratio, date_variance, threshold_status, count and manual_input.
- Adds `public.manage_reporting_configuration(actor, action, payload, reason)`, a SECURITY INVOKER function with an empty search_path. EXECUTE is revoked from PUBLIC/anon/authenticated and granted only to service_role.
- The RPC validates the authenticated actor's effective-dated global role assignments and, for project-scoped creation, active effective-dated project membership.
- Database operations and private audit insertion execute in one PostgreSQL transaction. A failed validation, write or audit insert rolls back the complete operation.
- Draft creation locks the configuration-set row before allocating the next version number. Draft rule saves lock the version row and replace dimensions/KPIs/parameters atomically.
- Enforces payload array limits, required fields, normalized active dimension weights (when supplied), normalized active KPI weights within each dimension (when supplied), KPI calculation-method/template pairing, active template allowlisting, known dimension references, and JSON object shape for source mappings/parameters.
- Submit/approve/publish/supersede transitions lock the version row, verify expected current status and write the audit record in the same transaction.
- No arbitrary SQL or user-supplied executable formula is evaluated.

## Migration 009 — rule validation hardening
- Applied version: `20261114100642`; name: `migration_009_reporting_rule_validation_hardening`.
- Source: `supabase/migrations/20261114100642_migration_009_reporting_rule_validation_hardening.sql`.
- Formula-template metadata now enforces required parameter keys for each KPI template.
- KPI references must point to active dimensions; weighted KPIs must be assigned to an active dimension.
- Rule parameters now receive type validation for number, integer, text, boolean, date and duration values. Numeric parameters support configured min/max bounds; all parameter types can use configured enumerated allowed values.
- Catalog/source checks confirmed the new validations are present in the deployed function. Security Advisor returned no findings.
- Full action-level tests remain blocked until test Auth users and effective-dated role assignments are provisioned.

## Supported actions
All requests require a valid Supabase user JWT and a non-empty reason (8–1000 characters).
- `create_draft`: create a global/project configuration set and initial draft version, or create a new draft version in an existing set.
- `save_draft_rules`: atomically replace dimensions, KPI definitions and rule parameters on a draft.
- `submit`: steward/admin submits a draft.
- `approve`: approver/admin approves a submitted version.
- `publish`: approver/admin publishes an approved version, subject to effective date, active dimension and active template checks.
- `supersede`: approver/admin supersedes a published version before a replacement is published.

## Authorization and secrets
- The Edge Function validates the bearer token using Supabase Auth.
- The RPC independently checks the supplied actor's active, effective-dated role assignments. It requires a service-role request context and cannot be executed by authenticated/anon clients.
- Platform Admin and Configuration Steward can create/edit/submit; Platform Admin and Configuration Approver can approve/publish/supersede.
- Project-scoped creation checks active project membership unless the actor is Platform Admin.
- The function uses a server-side secret key only in the Edge Function runtime. No secret is returned to the browser. JWT verification is enabled.
- The RPC is SECURITY INVOKER, not SECURITY DEFINER; its empty search_path and restricted EXECUTE grants are intentional.

## Audit
- Migration 005 provides the private audit table and service-only audit RPC.
- Migration 008 writes directly to `private.reporting_configuration_audit` inside the same transaction as the configuration changes. The older audit RPC remains in place but is no longer called by the Edge Function.

## Verification status
- Migration 008 is present in Supabase migration history.
- Catalog inspection confirms RPC is SECURITY INVOKER, has an empty search_path, and EXECUTE is granted to service_role but not authenticated.
- A negative authorization-path database test was run with a service-role request context and a UUID with no role assignment; the RPC rejected the actor.
- Supabase Security and Health advisors returned no findings.
- Edge Function is ACTIVE at version 3 with JWT verification enabled.
- Current project has zero Auth users, zero active global role assignments and zero configuration sets. Therefore positive end-to-end user tests, approval workflow tests and seeded configuration tests cannot yet be run.

## Remaining hardening
- Add positive and negative JWT tests with actual Auth users and role assignments, including project membership boundaries and separation of duties.
- Add explicit parameter-value type/range validation against each template's parameter schema; current validation checks parameter metadata shape and allowed value_type, but does not yet enforce every declared value's domain.
- Require/validate KPI dimension assignment where KPI weights are used, and add formula-specific required parameter checks.
- Consider replacing wildcard CORS with approved application origins when frontend origins are established.
- Add operational database records, KPI calculation engine, weekly snapshot generation, scheduling and immutable correction workflow.
