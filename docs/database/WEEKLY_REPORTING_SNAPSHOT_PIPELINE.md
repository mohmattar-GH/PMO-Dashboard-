# Weekly Reporting Cycle and Snapshot Pipeline

## Supabase deployment
- Project: `oihawkpbtgqxxliaamxs` (Executive PPM Platform).
- Migrations 006–013 establish the reporting-cycle/snapshot schema, access policies, generation and correction RPCs, source-cutoff controls, scheduler, and supporting indexes.
- Edge Function: `weekly-reporting-snapshots`, ACTIVE, version 1, JWT verification enabled.
- Source: `supabase/functions/weekly-reporting-snapshots/index.ts`.

## Lifecycle and API
The Edge Function validates a user JWT with Supabase Auth and invokes service-role-only SECURITY INVOKER PostgreSQL RPCs. No service-role key is returned to the client. Every user-requested operation requires a reason of 8–1000 characters.

| API action | Database RPC | Authorization |
|---|---|---|
| `create_cycle` | `create_reporting_cycle` | Active effective-dated platform_admin |
| `close_cycle` | `close_reporting_cycle` | Active effective-dated platform_admin; cutoff must have elapsed |
| `build_snapshot` | `build_weekly_portfolio_snapshot` | Active platform_admin when invoked through the user API; service scheduler may run as system |
| `finalize_snapshot` | `finalize_weekly_portfolio_snapshot` | Active platform_admin when invoked through the user API; service scheduler may run as system |
| `record_correction` | `record_snapshot_correction` | Active effective-dated platform_admin or configuration_approver |

Reporting cycles include a code, period start/end, cutoff timestamp, as-of date and IANA timezone. Cycle code is unique. A cycle can be closed only after its configured cutoff. A cycle linked to a snapshot cannot be edited except for the controlled closed-to-snapshotted transition.

## Snapshot contents and lineage
- One portfolio snapshot per reporting cycle.
- One project snapshot per project created on or before the cutoff.
- Portfolio summary includes cycle dates/timezone, project count, global configuration count, project configuration-link count, source watermark, and source consistency status.
- Snapshot links capture global and project configuration versions that were created and published by the cutoff and whose effective period covers the cutoff.
- Project snapshot payload captures the project record and the exact linked configuration version IDs.
- A project changed after the cutoff is not silently excluded. Its current captured state is flagged with `source_state_as_of_cutoff=false`; the portfolio summary reports `contains_post_cutoff_source_changes` when any such project exists.
- The source watermark records when extraction occurred.

## Immutability and correction
- Portfolio snapshots can transition once from `building` to `finalized`.
- Project snapshots, metric values and configuration links cannot be updated or deleted; they can only be inserted while the parent snapshot is building.
- A finalized reporting cycle is immutable.
- A correction is a separate append-only record linking the original finalized snapshot to a finalized replacement snapshot for the same period, as-of date and timezone. The original snapshot remains unchanged.
- Snapshot generation, finalization and correction audit entries are written in the same database transaction as their respective operations.

## Automated processor
- `pg_cron` is enabled.
- Job name: `weekly-portfolio-snapshot-processor`.
- Schedule: `*/15 * * * *` (every 15 minutes).
- The job calls `private.process_due_reporting_cycles()`.
- It finds open cycles whose cutoff has elapsed, closes each cycle, builds its snapshot, and finalizes it.
- Each attempt is recorded in private `reporting_snapshot_job_runs` as succeeded or failed. A failed attempt rolls back that cycle's close/build/finalize operations and records the error for retry on a later run.
- The processor is a SECURITY INVOKER function, with empty search_path and EXECUTE granted only to the PostgreSQL `postgres` role. It runs through the database scheduler, not a public API.
- The processor was smoke-tested directly and returned zero processed cycles because no reporting cycles exist. The cron job is configured and active; an actual scheduled job-run record had not yet appeared at verification time.

## Current functional limits
- The operational source modules (contracts, activities, milestones, invoices/payments, risks, licenses, weekly updates and documents) are not implemented yet.
- The KPI calculation engine is not implemented. No KPI formulas are evaluated and no official health score is produced. Snapshots explicitly report `kpi_calculation_status=not_implemented` and health as `not_reported`; metric rows are not fabricated.
- Project source history is not versioned yet. If a project record changes after cutoff, the pipeline captures the current record and flags it; it does not reconstruct the earlier value as of cutoff.
- A published global reporting configuration effective at the cutoff is mandatory. Project overrides are linked when applicable.
- The dedicated project currently has zero Auth users, zero active global role assignments, zero projects and zero reporting configuration sets. Positive user-flow tests and a real snapshot generation test cannot yet be run.

## Verification
- Migrations 006–013 are present in Supabase migration history.
- All six public snapshot tables have RLS enabled.
- All five public cycle/snapshot RPCs are SECURITY INVOKER; EXECUTE is false for anon/authenticated and true for service_role.
- A negative cycle-creation test rejected an actor with no active role assignment.
- The scheduler job exists and is active; direct processor smoke test completed with zero processed/failed cycles.
- Security Advisor returned no findings after scheduler setup. Performance Advisor previously identified five unindexed snapshot foreign keys; Migration 013 adds the corresponding indexes. Re-run the advisor after migration 013 to confirm.
- No real project or reporting-cycle data was inserted for testing.

## Next work
1. Provision controlled test Auth identities and effective-dated platform_admin/configuration_approver assignments.
2. Create and publish a test global reporting configuration effective for a test reporting cycle.
3. Add project operational tables and test data, then run a full cycle → close → build → finalize → correction scenario.
4. Implement validated KPI evaluation from allowlisted templates and store metric values with source lineage.
5. Add historical source versioning if exact as-of-cutoff reconstruction is required.
6. Validate the cron job's first scheduled execution and failure/retry behavior.
