# Reporting Cycle Closure Visibility and Historical Reconstruction

**Status:** Implemented in Supabase migrations 051–053  
**Applied migration versions:** 20261116073920, 20261116074022, 20261116074129  
**Last verified:** 16 November 2026

## Decision

The PPM platform retains two separate reporting timestamps:

- **Scheduled cutoff (`reporting_cycles.cutoff_at`)** — the configured reporting-period boundary and presentation metadata.
- **Actual closure boundary (`closed_at` + `closure_snapshot`)** — the authoritative committed database state used to reconstruct the weekly report.

The actual closure visibility boundary is authoritative for the report. The platform must not claim that a report is an exact reconstruction of the scheduled cutoff when the cycle was closed later. Both timestamps are stored and surfaced in the portfolio snapshot.

## Database implementation

### 1. Reporting-cycle closure boundary

Migration 051 adds:

- `closed_at timestamptz`
- `closure_snapshot text` containing the serialized PostgreSQL `pg_snapshot`.

The guarded transition from an open/draft cycle to `closed` captures `clock_timestamp()` and `pg_current_snapshot()` in the same database statement. The boundary pair must be present together; a cycle cannot be inserted already closed; and the boundary cannot be changed after closure. A closed cycle can only move to `snapshotted` through the existing finalization path.

### 2. Transaction-visible operational history

The operational history trigger already records the source transaction ID as `pg_current_xact_id()::text`. Migration 051 updates the historical reader to use:

- `pg_visible_in_snapshot(history.transaction_id::xid8, closure_snapshot::pg_snapshot)`
- The recorded event timestamp not later than `closed_at`
- Latest visible row per record, excluding records whose latest visible event is a delete.

This excludes transactions that were not committed and visible at cycle closure, even if their row-history event timestamp was earlier than the closure boundary.

Project registry rows are reconstructed from the same visibility snapshot. Snapshot finalization compares the captured project count with the closure-visible project registry, not the current live project table.

### 3. Configuration publication visibility

Migration 052 adds `reporting_configuration_versions.published_transaction_id xid8`.

When a draft/approved version transitions to published, a database trigger records `pg_current_xact_id()`. Snapshot generation includes a published configuration version only if its publication transaction was visible in the cycle's closure snapshot. The transaction ID is immutable after publication. Existing published configuration versions were zero when this migration was applied.

Migration 053 extends the portfolio snapshot mutation allowlist for closure metadata.

### 4. Snapshot metadata

Portfolio snapshot summary includes:

- `scheduled_cutoff_at`
- `actual_closed_at`
- `visibility_boundary_type = transaction_snapshot_at_closure`
- `source_consistency_status = as_of_closure_visibility`
- `projects_changed_after_scheduled_cutoff`

Project snapshot payload distinguishes:

- `source_state_as_of_scheduled_cutoff` (true only when scheduled cutoff and closure boundary coincide)
- `source_state_as_of_closure` (true for this reconstruction path)

The source watermark is the actual closure timestamp.

## Live integration verification — 16 November 2026

All test fixtures were cleaned up after the run. Final checks returned zero test users, projects, portfolios, reporting cycles, configuration sets, configuration versions, snapshots and test history rows.

Verified:

1. Closing a reporting cycle captures a non-null timestamp and PostgreSQL visibility snapshot.
2. The closure snapshot excludes its own still-running transaction.
3. A configuration published in a transaction after closure is not visible to that closure snapshot.
4. The closure timestamp/snapshot cannot be modified after closure.
5. A published configuration's publication transaction ID cannot be changed.
6. An end-to-end weekly snapshot was built and finalized using a configuration and project committed before closure.
7. A second project created after closure was excluded from the snapshot.
8. An update to the pre-closure project committed after closure was excluded; the snapshot retained the pre-closure project name.
9. The project KPI `PROJECT_COUNT` returned 1 / calculated; project health returned Green; portfolio snapshot finalization succeeded.
10. The snapshot explicitly reported that it represented closure state, not the earlier scheduled cutoff.

## Remaining verification and limitations

- A deliberately long-running concurrent transaction that starts before closure and commits after closure has not yet been tested with two independent database sessions. The PostgreSQL snapshot visibility predicate is designed to exclude it; this race-specific test remains a validation item.
- Real signed Auth JWT invocation of the Edge Functions remains outstanding. SQL tests with simulated claims are not equivalent to signed JWT verification.
- Clean migration replay from GitHub in an isolated Supabase branch/database remains outstanding.
- All operational history source tables must continue to have active history coverage before a cycle can be treated as historically reconstructable. The existing coverage checks remain in force.
- No frontend has been implemented. The next step is to present the proposed UI structure, navigation, screens and workflows for user approval.

## Release interpretation

The closure-boundary correction is implemented and passed the described live database integration tests. Do not describe the entire platform as production-ready until the remaining Auth/JWT, concurrent-transaction race and clean migration-replay gates are complete.
