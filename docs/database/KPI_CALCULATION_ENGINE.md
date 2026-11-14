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
