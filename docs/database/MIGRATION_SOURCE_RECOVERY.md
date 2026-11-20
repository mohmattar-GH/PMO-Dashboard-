# Migration Source Recovery and Replay Validation — 21 November 2026

## Current result

<badge> </badge>
The Executive PPM migration archive is now aligned with the applied Supabase migration ledger and has passed a clean, isolated replay using GitHub Actions.

- Supabase migration ledger: 61 applied migrations.
- Repository: 61 SQL migration files.
- Each file was restored from the exact SQL text retained in `supabase_migrations.schema_migrations.statements[1]`.
- Every migration version prefix now matches the applied ledger version.
- Filenames are ordered chronologically, with no duplicate version prefixes.
- All migration names and SQL statements are sourced from the applied ledger, not reconstructed from current database objects.

## Source recovery and ordering corrections

The initial archive had timestamp-prefix mismatches and source drift. These were corrected by using the live migration ledger as the authoritative source.

- Corrected all migration filename prefixes that differed from the recorded version.
- Aligned the filenames for migrations 054–056 to the ledger's actual migration names.
- Replaced all 61 SQL files with the exact stored applied SQL statements.
- This also corrected source drift detected during replay in migrations 010 and 024.
- The database ledger reports one stored SQL statement per migration for all 61 migrations.

The SQL restoration and filename changes affect GitHub repository files only. They did not alter the hosted database.

## Clean replay test

A free, isolated local Supabase stack was used on a GitHub Actions runner. No paid Supabase branch or additional hosted project was created.

Repository files added:
- `supabase/config.toml` — local-only project configuration using PostgreSQL 17.
- `.github/workflows/database-migration-replay.yml` — repeatable migration replay workflow.

Successful GitHub Actions run:
- Run ID: `44835790149`
- Result: **success**
- Workflow: Database migration replay
- Run URL: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/44835790149

The run completed all steps:
1. Started the isolated local Supabase stack.
2. Applied the migration chain.
3. Ran `supabase db reset` to rebuild the local database and replay all migrations from scratch.
4. Ran `supabase migration list`.
5. Confirmed 61 local migration versions, from `20261114093442` through `20261120225701`.
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

