# Configurable KPI Calculation Engine — Implementation Contract

## Purpose

Implement deterministic, configuration-driven KPI evaluation for the Executive PPM Platform. KPI results must be reproducible, explainable, linked to source records, and frozen into the weekly portfolio snapshot under the exact configuration version used.

This document is the implementation contract for the next backend milestone. It does not claim that the engine is implemented.

## Existing foundations verified

- Configuration entities: `reporting_configuration_sets`, `reporting_configuration_versions`, `reporting_dimensions`, `kpi_definitions`, and `reporting_rule_parameters`.
- Formula allowlist: `private.reporting_formula_templates`.
- Existing active template codes: `count_v1`, `date_variance_v1`, `manual_input_v1`, `ratio_v1`, `threshold_status_v1`, and `weighted_sum_v1`.
- Snapshot entities: `portfolio_snapshots`, `project_snapshots`, `snapshot_config_links`, and `snapshot_metric_values`.
- `build_weekly_portfolio_snapshot(uuid, uuid)` currently creates project/configuration snapshots but explicitly sets KPI calculation to `not_implemented`. It does not yet populate KPI metric rows.
- Operational source tables are in place for projects, contracts, financial terms, milestones, activities, invoices, cash transactions/payment allocations, risks, licenses, weekly updates, and management decisions.

## Non-negotiable execution and security rules

1. Formula evaluation must use a finite, versioned allowlist. Configuration must never contain executable SQL, PL/pgSQL, JavaScript, or arbitrary expressions.
2. Source mappings must resolve only to explicitly supported source identifiers and fields. Never concatenate configuration values into SQL identifiers or SQL fragments.
3. Only a trusted backend/scheduler path may calculate and write official KPI values. A user-facing request must authenticate the user and check effective-dated role assignments before invoking that path.
4. Do not trust `user_metadata` for authorization. Never expose service-role or secret keys to a browser.
5. Snapshot metric rows may be inserted only while the parent snapshot is in `building` state. Finalized snapshots and their children remain immutable.
6. Every metric must retain the exact KPI definition/configuration version, calculation template/version, source cutoff, and source-record lineage needed to explain the result.
7. A missing source value must produce `not_reported` or `insufficient_data`, never a Green/healthy status or a fabricated zero.
8. A calculation error or invalid configuration must fail the calculation transaction; it must not silently produce a healthy status.
9. Historical snapshots must never be recalculated using a later configuration version.

## Formula template contract

The six existing template families are the initial allowlist:

| Template | Intended operation | Required configuration |
|---|---|---|
| `count_v1` | Count qualifying records from a supported source | source identifier, optional supported filters |
| `date_variance_v1` | Difference between two configured date fields | source identifier, baseline field, comparison field, day basis |
| `manual_input_v1` | Read a human-entered, attributable field | supported source identifier, input field |
| `ratio_v1` | Divide two validated numeric operands | numerator and denominator source definitions |
| `threshold_status_v1` | Map a numeric result to configured status bands | numeric input and ordered threshold/status mapping |
| `weighted_sum_v1` | Weighted aggregate of validated numeric inputs | operand definitions and weights |

The evaluator must reject unknown template codes, unsupported source identifiers, unsupported fields, invalid operand shapes, missing required parameters, unexpected parameter keys where a strict schema is declared, invalid weights, and malformed threshold ranges.

Template definitions are versioned metadata. Changing a template's behavior requires a new template version/code and tests; it must not silently change the meaning of an already published configuration.

## Supported source registry

The initial registry should explicitly enumerate the operational sources and fields that the evaluator can read. Candidate source families:

- Project profile: lifecycle status, start date, target end date, currency, project manager and team lead.
- Activities: baseline/revised/forecast/actual dates, progress, verification status, status, weight, assignment.
- Milestones: baseline/revised/forecast/actual dates, progress, status, weight, critical flag.
- Contracts and financial terms: contract value, approved variations, revised value, currency, contract dates.
- Invoices: invoice dates, status, amounts, currency and contract reference.
- Cash and allocations: confirmed receipt/credit amounts, dates, allocation state and currency.
- Risks: probability, impact, configured risk score, status, trend, escalation and target/resolved dates.
- Licenses: quantity, expiry, renewal notice, renewal cost, status.
- Weekly updates: submitted/reviewed state, PM-reported progress/health and narrative fields.
- Management decisions: priority, status, required-by date and decision metadata.

The actual registry must be implemented as static SQL/typed branches or equivalent allowlisted code. Configuration cannot introduce arbitrary table or column names.

## Evaluation and output contract

For every active KPI in the effective configuration version:

1. Resolve the effective project configuration, falling back to the linked global configuration where no project override applies.
2. Validate the template and source mapping against the allowlist.
3. Resolve source records at the reporting cutoff. Until immutable source history is implemented, a source modified after the cutoff must be explicitly flagged as not reconstructable; do not present its current value as a historically accurate value.
4. Calculate the numeric/text result deterministically.
5. Apply configured status mapping and missing-data policy.
6. Insert one `snapshot_metric_values` row per KPI/project snapshot, including value, unit, status and JSON source lineage.
7. Record the configuration version ID and formula template/version in lineage or snapshot payload.
8. Preserve PM-reported health separately from calculated health. PM overrides require a reason and must never overwrite the calculated result.

Suggested status vocabulary for metric rows: `calculated`, `green`, `amber`, `red`, `not_reported`, `insufficient_data`, `invalid_configuration`. Final status vocabulary and presentation labels remain configurable where applicable.

## Aggregation rules

- KPI weights within a dimension must either all be supplied or all be omitted; supplied active weights must total 1.0.
- Dimension weights must either all be supplied or all be omitted; supplied active dimension weights must total 1.0.
- Weighted aggregation must not treat missing KPI values as zero.
- A dimension with incomplete required inputs is `not_reported` or `insufficient_data` according to its configured policy.
- Overall project health must not be Green when any mandatory dimension is missing, invalid, or subject to a configured critical override.
- Global portfolio rollups must preserve the count of reported, not-reported, and insufficient-data projects; they must not hide missing coverage in an average.

## Snapshot integrity

- The snapshot builder and KPI evaluator must run within a transaction boundary for the snapshot build. A failure must roll back the incomplete snapshot rather than leave partial KPI rows.
- Configuration links must refer to the exact effective published global and project configuration versions selected for the cycle cutoff.
- Snapshot metrics and project payloads must preserve the exact configuration version and source cutoff.
- Finalization must reject snapshots with an incomplete or failed calculation state.
- Corrections create a replacement snapshot with a reason; they do not mutate the original finalized snapshot.

## Required verification

### Pure calculation tests
- All six template families: valid, missing, malformed, boundary and invalid-input cases.
- Threshold boundaries and overlapping/gapped threshold rejection.
- Ratio denominator zero and null behavior.
- Weighted sums with missing values, zero weights and invalid totals.
- Date variance with calendar-day and configured working-day basis.
- Numeric precision, negative values, currency separation and percentage bounds.

### Authorization and integrity tests
- Unauthenticated and unauthorized callers cannot calculate or mutate snapshots.
- A project manager cannot evaluate projects outside effective membership.
- Executive viewer can read only the authorized snapshot scope and cannot write.
- Published configuration and finalized snapshot children cannot be mutated.
- Formula inputs cannot invoke arbitrary SQL or access unsupported tables/fields.

### Snapshot integration tests
- Synthetic test project with representative activities, milestones, invoices, allocations, risks, licenses, weekly updates and decisions.
- Publish a global configuration and a project override; verify precedence and configuration links.
- Build a snapshot, verify every KPI value/status/lineage, finalize it, then verify immutability.
- Modify a source after cutoff and verify the result is marked as historically unreconstructable until source-history support is completed.
- Verify missing records remain Not Reported/Insufficient Data and never default to Green.

## Explicitly out of scope for this milestone

- Change Request Management (deferred to a future release).
- Frontend screens or dashboard UI (requires prior UI/UX proposal review and user agreement).
- Production publishing/deployment.
- Arbitrary user-authored formulas or SQL.
