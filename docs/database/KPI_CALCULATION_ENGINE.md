# KPI calculation engine — backend foundation

## Implemented in Supabase
- Private PostgreSQL function: `private.evaluate_kpi_template_v1(text, jsonb, jsonb)`.
- Allowlisted templates: `count_v1`, `date_variance_v1`, `manual_input_v1`, `ratio_v1`, `threshold_status_v1`, `weighted_sum_v1`.
- Deterministic calculation only; no dynamic SQL, table names, column names, or executable expressions are accepted.
- Inputs are pre-resolved JSON values supplied by a trusted backend caller. The function does not read operational tables.
- Threshold bands are ordered and the final band must have a null upper bound. Weights must be numeric, between 0 and 1, and sum to 1.
- Missing inputs return `not_reported`; zero ratio denominator returns `insufficient_data`.
- Function EXECUTE is granted only to `service_role`; `anon` and `authenticated` cannot execute it.
- Date variance currently supports `calendar_days` only. Working-day calendars are not yet implemented.

## Verification
Synthetic database assertions passed for all six templates, threshold selection and overflow, weighted progress example (55), zero denominator, and missing data. Privilege checks returned service_role=true, authenticated=false, anon=false. Security Advisor and Health Advisor returned no findings. Performance Advisor reports 91 INFO-level unused-index notices; no indexes were removed.

## Not yet implemented
1. Static source registry/adapters to resolve KPI source mappings to operational records.
2. Global/project configuration resolution and mapping of KPI definitions to evaluator inputs.
3. Integration into `build_weekly_portfolio_snapshot`; it still reports KPI calculation as `not_implemented` and inserts no metric rows.
4. Dimension aggregation, overall project health, portfolio rollups and PM override handling.
5. Source-record lineage generation and exact configuration/template version lineage per metric.
6. Immutable operational source history and true historical as-of-cutoff reconstruction.
7. End-to-end tests with real Auth identities, projects, published configurations and weekly cycles.

This is an isolated calculation primitive, not yet a production-ready KPI reporting pipeline.

## Configuration parameter compatibility

Migration 027 aligned evaluator inputs with the required parameter names in the existing formula-template registry:
- `count_v1`: `source` is restricted to the static source allowlist; resolved count is supplied as `record_count`.
- `date_variance_v1`: `baseline_date` and `comparison_date` parameters name pre-resolved input keys; `day_basis` currently supports `calendar_days`.
- `manual_input_v1`: `input_field` names a pre-resolved numeric input key.
- `ratio_v1`: `numerator` and `denominator` name pre-resolved numeric input keys.
- `threshold_status_v1`: `value` names a numeric input key and `thresholds` contains ordered bands.
- `weighted_sum_v1`: `values` contains pre-resolved input keys and `weights` contains matching numeric weights.
Synthetic assertions were rerun against this configuration-compatible contract. This still does not implement source resolution from `source_mapping`.

## Implemented source-resolution and snapshot integration — migrations 028–032

The KPI pipeline now has a trusted backend source resolver and is wired into snapshot creation through an `AFTER INSERT` trigger on `project_snapshots`. Snapshot creation, KPI resolution, metric inserts and project/portfolio rollup updates share the same database transaction. A calculation error aborts the snapshot build transaction.

### Source mapping contract

For templates that consume named inputs, configure `source_mapping.inputs` as an object keyed by the input names used in `parameters`:

```json
{
  "inputs": {
    "baseline_due": {
      "source": "activities",
      "field": "baseline_due_date",
      "aggregate": "max"
    },
    "forecast_due": {
      "source": "activities",
      "field": "forecast_due_date",
      "aggregate": "max"
    }
  }
}
```

The corresponding date-variance parameters refer to `baseline_due` and `forecast_due`, with `day_basis: "calendar_days"`.

Supported aggregates:
- `count`: count source records.
- `sum` and `avg`: numeric fields only.
- `min` and `max`: deterministic text ordering; numeric-looking results are returned as numbers.
- `value`: only returns a value when exactly one source row exists. Multiple rows remain missing rather than silently selecting one.

The `count_v1` template uses its configured `source` parameter directly and does not require an input map.

### Source registry

The static registry currently supports:
- `projects`
- `activities`
- `milestones`
- `invoices`
- `cash_transactions`
- `payment_allocations`
- `risks`
- `licenses`
- `weekly_updates`
- `management_decisions`
- `contract_deliverables`
- `contracts`
- `financial_terms`

Each source has an explicit field allowlist. Configuration values are never used as SQL identifiers. The resolver supports one project at a time, a maximum of 5,000 source rows per input, and includes up to 100 source record IDs in lineage. Custom filters, joins and arbitrary source expressions are not supported.

Payment allocation records are interpreted as of cutoff using their creation and reversal timestamps. Cash transactions are treated as immutable source records.

### Cutoff integrity

For sources with `updated_at`, if a record existed by the cutoff but was modified after it, the resolver marks the affected KPI `not_reported` with a `not_reconstructable` lineage status. It does not use the newer value as if it existed at the cutoff. Records created after the cutoff are excluded. This is a deliberate safe limitation until immutable operational source history is implemented.

### Snapshot outputs

- Each active KPI is resolved using the effective linked configuration. A project-scoped KPI definition overrides a global definition with the same KPI code.
- Metric rows now retain `configuration_version_id`, `formula_template_code`, and `source_cutoff`, alongside source record lineage.
- KPI metrics are inserted during project snapshot creation; a calculation failure rolls back the snapshot transaction.
- Project snapshot payloads include KPI calculation status, missing/insufficient/not-reconstructable counts, and per-dimension weighted values/statuses.
- Portfolio summary includes KPI calculation status and project coverage counts.
- Dimension weighted values are calculated only when all active KPI weights are present, sum to 1, and all numeric inputs are available. Otherwise the dimension is explicitly `weights_not_configured` or `insufficient_data`.
- Overall calculated project health remains `not_reported`. A configurable dimension-to-health aggregation/status mapping and complete health override workflow have not yet been implemented.

### Verification performed after migrations 028–032

- Synthetic SQL assertions passed for source mapping resolution on an empty project, missing values, payment-allocation field allowlisting, count-source allowlisting, weighted progress example (55), and threshold status selection.
- Privilege checks confirmed the calculation entry point is executable by `service_role` and not by `authenticated` or `anon`.
- Snapshot calculation trigger exists; `snapshot_metric_values` has RLS enabled.
- Security Advisor: no findings. Health Advisor: no findings.
- Performance Advisor: no unindexed-FK finding after adding the configuration-version index. Remaining notices are INFO-level unused-index observations due to no representative workload.
- Full snapshot integration with real Auth users, projects and published configurations has not been run: the dedicated project currently has no provisioned users/projects/configurations.

### Remaining work

1. Provision controlled test identities, project records and a published test configuration, then run positive and negative JWT/RLS tests and a full weekly snapshot build/finalize test.
2. Add immutable source-history tables/triggers so changed source rows can be reconstructed for historical cutoffs rather than flagged.
3. Implement configurable dimension-to-project-health aggregation, thresholds, critical overrides and reasoned PM override separation.
4. Add richer source filters and source definitions only through reviewed static adapters.
5. Reconcile and commit the exact historical SQL source for migrations 028 and 029. Migrations 030–032 and this implementation note are committed; do not assume the earlier two migration source files are already present in GitHub.

## Weekly snapshot lifecycle integration and immutability correction — migrations 033–039

A full synthetic snapshot build exposed a conflict between the KPI trigger and the pre-existing append-only snapshot guards. The guards were tightened so the trusted build workflow can enrich only designated calculation fields while the snapshot is still building; ordinary edits remain rejected.

- Project snapshot KPI enrichment is allowed only when the verified service-role request claim is present, the private KPI calculation function has enabled its transaction-local `app.snapshot_kpi_calculation` flag, the parent portfolio snapshot is still `building`, and every project snapshot column other than the eight designated KPI payload keys is unchanged.
- Portfolio snapshot summary enrichment is allowed only for the service-role build path, only while `building`, and only for the explicit source-capture and KPI rollup summary keys.
- Snapshot metrics remain immutable. Finalized portfolio snapshots remain immutable except for the existing building-to-finalized transition.
- The weekly build and finalize RPC responses now return the actual KPI calculation status from the snapshot summary rather than the old `not_implemented` marker.
- Migration 037 was a temporary diagnostic guard revision; migration 038 replaces it with the final allowlisted payload guard. It is retained in migration history for replay fidelity.

### End-to-end synthetic snapshot test

A transaction-scoped synthetic integration test was run using:
- One temporary Auth user and platform-admin assignment.
- One synthetic project and one verified activity.
- One published global reporting configuration, one dimension and one `count_v1` KPI.
- One closed reporting cycle and the actual weekly snapshot build/finalize RPCs.

Assertions passed:
- The snapshot trigger created a KPI metric of `1` with status `calculated`.
- The dimension result was `calculated`.
- Snapshot finalization succeeded and returned KPI status `calculated`.

The entire test transaction was rolled back. A follow-up query confirmed zero persisted test projects, cycles, Auth users or test KPI metrics. This validates the database build/finalize path under a simulated service-role database session; it is not yet a real Edge Function/JWT end-to-end test.

### Migration source reconciliation

- Migration source files 028 and 029 have been reconstructed from the live applied function definitions and current schema, then committed. They were not recovered from the original historical local migration files; clean-database replay still needs independent verification.
- Migration files 030–039 are now committed, with migration 032 filename aligned to the actual Supabase migration version `20261114161839`.
- Security Advisor: no findings. Health Advisor: no findings. Performance Advisor currently reports 87 INFO-level unused-index notices; with no representative production workload, none were removed.

### Remaining work

1. Verify a clean migration replay in an isolated database/branch when a cost-free or approved test environment is available.
2. Run a true Edge Function invocation with real Auth/JWT identities and verify role-specific RLS behavior. The SQL integration test did not exercise user JWTs.
3. Add immutable operational source history for true historical as-of reconstruction.
4. Implement configurable dimension-to-project-health aggregation, thresholds, critical overrides and reasoned PM override handling.
5. Continue KPI portfolio rollups and completeness rules, then operational CRUD and UI only after the user's UI/UX proposal review.

### Empty-portfolio handling — migration 040
- If a weekly snapshot contains no projects, the build and finalize responses now report KPI status `not_reported`, not `pending_calculation`.
- A transaction-scoped synthetic empty-portfolio build/finalize test passed; the test transaction was rolled back.
