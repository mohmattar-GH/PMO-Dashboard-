-- Synthetic evaluator assertions aligned with the published formula-template parameter schema.
do $$
declare x jsonb;
begin
 x:=private.evaluate_kpi_template_v1('count_v1','{"source":"activities"}','{"record_count":4}');
 if (x->>'numeric_value')::numeric<>4 then raise exception 'count failed %',x; end if;
 x:=private.evaluate_kpi_template_v1('date_variance_v1','{"baseline_date":"base","comparison_date":"forecast","day_basis":"calendar_days"}','{"base":"2026-11-01","forecast":"2026-11-06"}');
 if (x->>'numeric_value')::numeric<>5 then raise exception 'date failed %',x; end if;
 x:=private.evaluate_kpi_template_v1('manual_input_v1','{"input_field":"progress"}','{"progress":72.5}');
 if (x->>'numeric_value')::numeric<>72.5 then raise exception 'manual failed %',x; end if;
 x:=private.evaluate_kpi_template_v1('ratio_v1','{"numerator":"paid","denominator":"billed"}','{"paid":25,"billed":100}');
 if (x->>'numeric_value')::numeric<>0.25 then raise exception 'ratio failed %',x; end if;
 x:=private.evaluate_kpi_template_v1('threshold_status_v1','{"value":"variance","thresholds":[{"upper_bound":5,"status":"Red"},{"upper_bound":10,"status":"Amber"},{"upper_bound":null,"status":"Green"}]}','{"variance":8}');
 if x->>'status'<>'Amber' then raise exception 'threshold failed %',x; end if;
 x:=private.evaluate_kpi_template_v1('weighted_sum_v1','{"values":["req","dev","test","deploy"],"weights":[0.15,0.4,0.25,0.2]}','{"req":100,"dev":75,"test":40,"deploy":0}');
 if abs((x->>'numeric_value')::numeric-55)>0.000001 then raise exception 'weighted failed %',x; end if;
 x:=private.evaluate_kpi_template_v1('ratio_v1','{"numerator":"paid","denominator":"billed"}','{"paid":1,"billed":0}');
 if x->>'status'<>'insufficient_data' then raise exception 'zero denominator failed %',x; end if;
 x:=private.evaluate_kpi_template_v1('count_v1','{"source":"activities"}','{}');
 if x->>'status'<>'not_reported' then raise exception 'missing count failed %',x; end if;
end $$;
select has_function_privilege('service_role','private.evaluate_kpi_template_v1(text,jsonb,jsonb)','EXECUTE') as service_role_can_execute,
       has_function_privilege('authenticated','private.evaluate_kpi_template_v1(text,jsonb,jsonb)','EXECUTE') as authenticated_can_execute,
       has_function_privilege('anon','private.evaluate_kpi_template_v1(text,jsonb,jsonb)','EXECUTE') as anon_can_execute;
