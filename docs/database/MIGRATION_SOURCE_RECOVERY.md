# Migration Source Recovery Record — 21 November 2026

## Result

The original SQL for lifecycle migrations 057–060 has now been recovered directly from the authoritative `supabase_migrations.schema_migrations.statements` records in the live Executive PPM Platform database and restored to GitHub.

This is stronger provenance than reconstruction from current catalog definitions: the database retained the exact migration statements that were originally applied.

## Restored migration files

| Migration | GitHub source | Recovery source |
|---|---|---|
| 057 — Configurable project lifecycle phases | `supabase/migrations/20261120225103_migration_057_configurable_project_lifecycle_phases.sql` | Exact stored statement array for version `20261120225103` |
| 058 — Global lifecycle assignment scope fix | `supabase/migrations/20261120225145_migration_058_global_lifecycle_assignment_scope_fix.sql` | Exact stored statement array for version `20261120225145` |
| 059 — Executive lifecycle phase read access | `supabase/migrations/20261120225319_migration_059_executive_lifecycle_phase_read_access.sql` | Exact stored statement array for version `20261120225319` |
| 060 — Executive phase change read model | `supabase/migrations/20261120225325_migration_060_executive_phase_change_read_model.sql` | Exact stored statement array for version `20261120225325` |

For 057–060, the SQL text was copied from each migration's history `statements` array without reconstructing it from the current schema. The 059 and 060 files previously archived as reconstructed versions were replaced with exact recorded SQL. The 058 file was also aligned to the exact stored SQL after a byte-for-byte comparison identified explanatory header comments that were not part of the applied statement.

## Verification

- Confirmed all four versions 057–060 are recorded as applied in Supabase migration history.
- Queried `supabase_migrations.schema_migrations` and confirmed it retains `statements` and `rollback` arrays in addition to version/name metadata.
- Retrieved the exact stored statements for migrations 057, 058, 059 and 060.
- Committed migration 057, replaced migration 059 and migration 060, and aligned migration 058 to the exact stored SQL.
- Re-fetched all four GitHub files and compared each file's full content to its stored migration-history statement; all four comparisons matched exactly.

## Remaining validation

- All four restored files now have authoritative source provenance and byte-for-byte matches against their stored applied SQL. A clean-environment replay of the complete migration chain has not yet been run.
- No isolated clean Supabase database/branch was created for replay. Do not claim clean-replay compatibility or production readiness until that test passes.
- The live project was not modified during this recovery pass.

## Scope safeguards

- No Supabase schema or application data changes were made during this recovery pass.
- No Auth users or project fixtures were created.
- PR #1 remains draft and unmerged.
- No deployment was performed.
- The existing Staff Time & Performance application remains untouched.


## Broader applied migration archive reconciliation — 21 November 2026

### Repository coverage

- The live Executive PPM migration ledger contains 61 applied migrations.
- The feature branch now contains 61 SQL migration files under `supabase/migrations/`.
- Each applied migration name has a matching repository file. Matching was performed by the migration name suffix because several pre-existing repository filenames use timestamp prefixes that differ from the applied ledger version.
- Migrations 001–004 were missing and have now been restored from the exact SQL statement retained in the live migration ledger.
- Migrations 057–060 were also checked against their exact stored SQL during this pass.

### Exact-source verification

- Migrations 001, 002, 003 and 004: all four newly created files were re-fetched from GitHub and compared byte-for-byte as UTF-8 text with the corresponding `statements[1]` value in `supabase_migrations.schema_migrations`. All four matched.
- Migrations 057, 058, 059 and 060: all four files were re-fetched and compared byte-for-byte with their stored applied SQL. All four matched.
- The other 53 migration files were confirmed present by matching applied migration names to repository filenames. They have not all been byte-for-byte compared in this pass.

### Validation boundary

- Repository source coverage now matches the 61 migrations recorded as applied in the live project.
- A clean-environment replay of all 61 migrations has **not** been performed. Archive completeness is not proof of replayability; dependencies, ordering, extensions, roles, storage resources, Edge Functions, and platform-specific state may still affect a clean replay.
- No new Supabase project or branch was created for testing. No live schema or application data was changed in this reconciliation.
- PR #1 remains draft and unmerged. No deployment or user provisioning was performed. Staff Time & Performance remains untouched.
