do $$
declare d text;
begin
  d := pg_get_functiondef('private.evaluate_kpi_template_v1(text,jsonb,jsonb)'::regprocedure);
  d := replace(d, 'jsonb_typeof(p_inputs->''record_count'') <> ''number''', 'jsonb_typeof(p_inputs->''record_count'') is distinct from ''number''');
  d := replace(d, 'jsonb_typeof(p_inputs->''baseline_date'') <> ''string''', 'jsonb_typeof(p_inputs->''baseline_date'') is distinct from ''string''');
  d := replace(d, 'jsonb_typeof(p_inputs->''comparison_date'') <> ''string''', 'jsonb_typeof(p_inputs->''comparison_date'') is distinct from ''string''');
  d := replace(d, 'jsonb_typeof(p_inputs->''value'') <> ''number''', 'jsonb_typeof(p_inputs->''value'') is distinct from ''number''');
  d := replace(d, 'jsonb_typeof(p_inputs->''numerator'') <> ''number''', 'jsonb_typeof(p_inputs->''numerator'') is distinct from ''number''');
  d := replace(d, 'jsonb_typeof(p_inputs->''denominator'') <> ''number''', 'jsonb_typeof(p_inputs->''denominator'') is distinct from ''number''');
  d := replace(d, 'jsonb_typeof(p_inputs->''thresholds'') <> ''array''', 'jsonb_typeof(p_inputs->''thresholds'') is distinct from ''array''');
  d := replace(d, 'jsonb_typeof(p_inputs->''values'') <> ''array''', 'jsonb_typeof(p_inputs->''values'') is distinct from ''array''');
  d := replace(d, 'jsonb_typeof(p_inputs->''weights'') <> ''array''', 'jsonb_typeof(p_inputs->''weights'') is distinct from ''array''');
  d := replace(d, 'jsonb_typeof(v_item) <> ''number''', 'jsonb_typeof(v_item) is distinct from ''number''');
  execute d;
end $$;
revoke all on function private.evaluate_kpi_template_v1(text,jsonb,jsonb) from public;
revoke all on function private.evaluate_kpi_template_v1(text,jsonb,jsonb) from anon, authenticated;
grant execute on function private.evaluate_kpi_template_v1(text,jsonb,jsonb) to service_role;