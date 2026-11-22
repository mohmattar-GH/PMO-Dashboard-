# Migration Source Recovery and Replay Validation — 21 November 2026

## Current result

The Executive PPM migration archive is now aligned with the applied Supabase migration ledger and has passed a clean, isolated replay using GitHub Actions.

- Supabase migration ledger: 62 applied migrations.
- Repository: 62 SQL migration files.
- Migrations 001–061 were restored from the exact SQL text retained in `supabase_migrations.schema_migrations.statements[1]` during the source-recovery pass.
- Migration 062 (`security_policy_hardening`) was generated with `supabase migration new`, reviewed, applied to the live PPM database, and aligned to the resulting ledger version.
- All 62 repository filenames now match the live ledger's version and name, are chronologically ordered, and have no duplicate version prefixes.

## Source recovery and ordering corrections

The initial archive had timestamp-prefix mismatches and source drift. These were corrected by using the live migration ledger as the authoritative source.

- Corrected all migration filename prefixes that differed from the recorded version.
- Aligned the filenames for migrations 054–056 to the ledger's actual migration names.
- Replaced the 61 original SQL files with the exact stored applied SQL statements.
- This also corrected source drift detected during replay in migrations 010 and 024.
- Added migration 062, `security_policy_hardening`, using the Supabase CLI migration generator. It restricts full contract-record reads to Project Manager / Finance project roles, Platform Administrator / Finance Administrator global roles, and Executive Viewers with an active explicit grant.
- The database ledger reports one stored SQL statement per migration for all 62 migrations.

The SQL restoration and filename changes affect GitHub repository files only. They did not alter the hosted database.

## Clean replay test

A free, isolated local Supabase stack was used on a GitHub Actions runner. No paid Supabase branch or additional hosted project was created.

Repository files added:
- `supabase/config.toml` — local-only project configuration using PostgreSQL 17.
- `.github/workflows/database-migration-replay.yml` — repeatable migration replay workflow.

Successful GitHub Actions run:
- Run ID: `44837247508`
- Result: **success**
- Workflow: Database migration replay
- Run URL: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/44837247508

The run completed all steps:
1. Started the isolated local Supabase stack.
2. Applied the migration chain.
3. Ran `supabase db reset` to rebuild the local database and replay all migrations from scratch.
4. Ran `supabase migration list`.
5. Confirmed 62 local migration versions, from `20261114093442` through `20261120232936`.
6. Stopped the local Supabase containers.

The stack start applies migrations once, and the explicit reset applies them again from a clean local database. The final migration history list contained all 61 versions.

## Safety boundary

- No hosted Supabase branch or project was created.
- No Supabase access token, remote database URL, or project link was used in the CI workflow.
- No hosted database reset, migration push, schema change, or data change was performed.
- No production data was copied into the local test environment.
- No deployment was performed.
- PR #1 remains draft and unmerged.
- The Staff Time & Performance application was not accessed or changed.

## Remaining work — separate from migration replay

A clean migration replay proves that the checked-in SQL can rebuild a fresh local Supabase database. It does not prove the full application is production-ready.

Still outstanding:
- Provision test Auth users and project memberships, then run real JWT/RLS permission tests.
- Review the SECURITY DEFINER lifecycle RPCs and their Security Advisor warnings.
- Review the Team Lead contract SELECT policy scope.
- Test invoice cash-allocation reversal under the current RLS policies.
- Complete the KPI safe-read contract and sensitivity classification.
- Verify the full frontend-to-database integration and role-specific user journeys.
- Perform a clean replay again whenever migration files change; the GitHub workflow now runs automatically for migration/config/workflow changes.



## Security and authorization hardening — 21 November 2026

Migration 062 (`20261120232936_security_policy_hardening.sql`) was applied to the live PPM database and is committed in the feature branch. It replaces the broad project-contract read policy: Team Leads and Project Viewers no longer receive full contract records; active Project Managers and Finance users retain project-scoped access; Platform Administrator / Finance Administrator retain global access; Executive Viewer access still requires an active explicit financial grant.

Rollback-only role tests verified the new contract policy and grant scope. Finance allocation reversal succeeded; Team Lead reversal was denied. All 47 tables across public/private schemas have RLS enabled, the private formula-template table remains inaccessible to client roles, and six key read-model views use `security_invoker=true`. No temporary fixtures remained after tests.

Security Advisor remains at two WARN findings for the intentionally authenticated SECURITY DEFINER lifecycle RPCs and one INFO finding for the intentionally private formula-template table with no client policies. The lifecycle functions use an empty search path and explicit identity/profile/role/effective-date checks. SQL-level tests used simulated request claims, not real signed JWTs. Real Auth/Data API and Storage end-to-end tests remain outstanding. See `docs/database/SECURITY_AUTHORIZATION_TEST_RESULTS.md` and `docs/checkpoints/2026-11-21-security-authorization-tests.md`.
