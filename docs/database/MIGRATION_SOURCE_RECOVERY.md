# Migration Source Recovery Record — 21 November 2026

## Purpose

Record the source-recovery work for lifecycle migrations applied to the dedicated Executive PPM Platform database. This record distinguishes original historical source from SQL reconstructed from the live catalog.

## Findings

- Migration 057, `20261120225103_migration_057_configurable_project_lifecycle_phases`, is applied to the live database but its original SQL file was not found in the GitHub branch or repository commit search.
- Migration 058 source is present in GitHub at `supabase/migrations/20261120225145_migration_058_global_lifecycle_assignment_scope_fix.sql`.
- Migration 059 original SQL file was not found. Its live RLS policy definitions were inspected in `pg_policies`.
- Migration 060 original SQL file was not found. Its live view definition and `security_invoker=true` option were inspected in PostgreSQL catalogs.

## Recovered source files committed

1. `supabase/migrations/20261120225319_migration_059_executive_lifecycle_phase_read_access.sql`
   - Reconstructed using the live post-migration SELECT policies for the six lifecycle tables.
   - Adds active `platform_admin` and `executive_viewer` global-role read paths while retaining active project-membership paths.
   - The file header explicitly labels it recovered source, not the original historical SQL.

2. `supabase/migrations/20261120225325_migration_060_executive_phase_change_read_model.sql`
   - Reconstructed from `pg_get_viewdef` and `pg_class.reloptions`.
   - Recreates `public.project_phase_change_log` as a `security_invoker=true` view and grants SELECT to authenticated users.
   - The file header explicitly labels it recovered source, not the original historical SQL.

## Still unresolved

- Migration 057 remains absent. Its schema was subsequently modified by migration 058, so the current catalog cannot be used to recreate the exact pre-058 migration without guessing.
- Migration 059 is reconstructed from the current policies. Although the current policy behavior is captured, the exact historical SQL text and any intermediate state are not recoverable from the catalog.
- Migrations 059 and 060 have not been replayed on a clean database.
- No isolated clean-environment migration replay has been performed. Do not claim that the GitHub migration directory is replay-complete.
- Do not apply these recovered files to the live project: the live database already contains their effects.

## Verification performed

- Queried the live PostgreSQL catalog for the two lifecycle views, their definitions, and view options.
- Queried `pg_policies` for all six lifecycle tables and captured the current SELECT policy expressions.
- Confirmed migration 058 source exists in the target branch.
- Confirmed the missing original 057/059/060 source files were not found at the expected paths; earlier repository commit search did not locate the original 057 source.

## Safe next step

Recover migration 057 from an authoritative original source or create a separately reviewed schema-baseline/recovery migration from a full schema dump. Then test the complete migration chain from a clean database before removing any recovery labels or claiming replay compatibility.

## Scope safeguards

- No Supabase schema or data changes were made during this recovery pass.
- No user accounts or project fixtures were created.
- PR #1 remains draft and unmerged.
- No deployment was performed.
- The existing Staff Time & Performance application remains untouched.
