# Migration Source Recovery Record — 21 November 2026

## Result

The original SQL for lifecycle migrations 057, 059 and 060 has now been recovered directly from the authoritative `supabase_migrations.schema_migrations.statements` records in the live Executive PPM Platform database and restored to GitHub.

This is stronger provenance than reconstruction from current catalog definitions: the database retained the exact migration statements that were originally applied.

## Restored migration files

| Migration | GitHub source | Recovery source |
|---|---|---|
| 057 — Configurable project lifecycle phases | `supabase/migrations/20261120225103_migration_057_configurable_project_lifecycle_phases.sql` | Exact stored statement array for version `20261120225103` |
| 058 — Global lifecycle assignment scope fix | `supabase/migrations/20261120225145_migration_058_global_lifecycle_assignment_scope_fix.sql` | Existing repository source; not changed in this pass |
| 059 — Executive lifecycle phase read access | `supabase/migrations/20261120225319_migration_059_executive_lifecycle_phase_read_access.sql` | Exact stored statement array for version `20261120225319` |
| 060 — Executive phase change read model | `supabase/migrations/20261120225325_migration_060_executive_phase_change_read_model.sql` | Exact stored statement array for version `20261120225325` |

For 057, 059 and 060, the SQL text was copied from the migration history `statements` array without reconstructing it from the current schema. Migration 059 and 060 files previously archived as reconstructed versions were replaced with the exact recorded SQL.

## Verification

- Confirmed all four versions 057–060 are recorded as applied in Supabase migration history.
- Queried `supabase_migrations.schema_migrations` and confirmed it retains `statements` and `rollback` arrays in addition to version/name metadata.
- Retrieved the exact stored statements for 057, 059 and 060.
- Committed migration 057, replaced migration 059 and migration 060 with the exact stored SQL.
- Fetched all three restored GitHub files after commit to confirm that each exists in the feature branch.
- Migration 058 source was fetched and inspected; it remains unchanged.

## Remaining validation

- The restored files now have authoritative source provenance, but a clean-environment replay of the complete migration chain has not yet been run.
- No isolated clean Supabase database/branch was created for replay. Do not claim clean-replay compatibility or production readiness until that test passes.
- The live project was not modified during this recovery pass.

## Scope safeguards

- No Supabase schema or application data changes were made during this recovery pass.
- No Auth users or project fixtures were created.
- PR #1 remains draft and unmerged.
- No deployment was performed.
- The existing Staff Time & Performance application remains untouched.
