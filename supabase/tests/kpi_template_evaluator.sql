-- Synthetic evaluator assertions; no persistent business data is written.
do $$
declare r jsonb;
begin
  r := private.evaluate_kpi_template_v1('count_v1','{"source":"project_activities"}','{"record_count":4}');
  if (r->>'numeric_value')::numeric <> 4 or r->>'status' <> 'calculated' then raise exception 'count test failed: %',r; end if;
  r := private.evaluate_kpi_template_v1('date_variance_v1','{"baseline_date":"baseline","comparison_date":"forecast","day_basis":"calendar_days"}','{"baseline_date":"2026-11-01","comparison_date":"2026-11-06"}');
  if (r->>'numeric_value')::numeric <> 5 then raise exception 'date variance test failed: %',r; end if;
  r := private.evaluate_kpi_template_v1('manual_input_v1','{"input_field":"verified_progress"}','{"value":72.5}');
  if (r->>'numeric_value')::numeric <> 72.5 then raise exception 'manual input test failed: %',r; end if;
  r := private.evaluate_kpi_template_v1('ratio_v1','{}','{"numerator":25,"denominator":100}');
  if (r->>'numeric_value')::numeric <> 0.25 then raise exception 'ratio test failed: %',r; end if;
  r := private.evaluate_kpi_template_v1('threshold_status_v1','{}','{"value":8,"thresholds":[{"upper_bound":5,"status":"Red"},{"upper_bound":10,"status":"Amber"},{"upper_bound":null,"status":"Green"}]}');
  if r->>'status' <> 'Amber' then raise exception 'threshold selection failed: %',r; end if;
  r := private.evaluate_kpi_template_v1('threshold_status_v1','{}','{"value":11,"thresholds":[{"upper_bound":5,"status":"Red"},{"upper_bound":10,"status":"Amber"},{"upper_bound":null,"status":"Green"}]}');
  if r->>'status' <> 'Green' then raise exception 'final threshold failed: %',r; end if;
  r := private.evaluate_kpi_template_v1('weighted_sum_v1','{}','{"values":[100,75,40,0],"weights":[0.15,0.4,0.25,0.2]}');
  if abs((r->>'numeric_value')::numeric - 55) > 0.000001 then raise exception 'weighted sum failed: %',r; end if;
  r := private.evaluate_kpi_template_v1('ratio_v1','{}','{"numerator":1,"denominator":0}');
  if r->>'status' <> 'insufficient_data' then raise exception 'zero denominator failed: %',r; end if;
  r := private.evaluate_kpi_template_v1('count_v1','{"source":"project_activities"}','{}');
  if r->>'status' <> 'not_reported' then raise exception 'missing count failed: %',r; end if;
  r := private.evaluate_kpi_template_v1('ratio_v1','{}','{}');
  if r->>'status' <> 'not_reported' then raise exception 'missing ratio failed: %',r; end if;
end $$;
select has_function_privilege('service_role','private.evaluate_kpi_template_v1(text,jsonb,jsonb)') as service_role_can_execute,
       has_function_privilege('authenticated','private.evaluate_kpi_template_v1(text,jsonb,jsonb)') as authenticated_can_execute,
       has_function_privilege('anon','private.evaluate_kpi_template_v1(text,jsonb,jsonb)') as anon_can_execute;
