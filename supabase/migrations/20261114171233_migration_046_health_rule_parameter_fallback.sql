begin;
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('private.calculate_project_health_v1(uuid,jsonb,timestamptz,date)'::regprocedure);
 d:=replace(d,
 $old$select (parameter_value#>>'{}')::numeric into v_score_min from public.reporting_rule_parameters
 where configuration_version_id=v_version and rule_code='overall_health' and parameter_code='score_min';$old$,
 $new$select coalesce(
  (select (parameter_value#>>'{}')::numeric from public.reporting_rule_parameters where configuration_version_id=v_project_version and rule_code='overall_health' and parameter_code='score_min'),
  (select (parameter_value#>>'{}')::numeric from public.reporting_rule_parameters where configuration_version_id=v_overall_version and rule_code='overall_health' and parameter_code='score_min')
 ) into v_score_min;$new$);
 d:=replace(d,
 $old$select (parameter_value#>>'{}')::numeric into v_score_max from public.reporting_rule_parameters
 where configuration_version_id=v_version and rule_code='overall_health' and parameter_code='score_max';$old$,
 $new$select coalesce(
  (select (parameter_value#>>'{}')::numeric from public.reporting_rule_parameters where configuration_version_id=v_project_version and rule_code='overall_health' and parameter_code='score_max'),
  (select (parameter_value#>>'{}')::numeric from public.reporting_rule_parameters where configuration_version_id=v_overall_version and rule_code='overall_health' and parameter_code='score_max')
 ) into v_score_max;$new$);
 d:=replace(d,
 $old$select parameter_value into v_thresholds from public.reporting_rule_parameters
 where configuration_version_id=v_version and rule_code='overall_health' and parameter_code='thresholds';$old$,
 $new$select coalesce(
  (select parameter_value from public.reporting_rule_parameters where configuration_version_id=v_project_version and rule_code='overall_health' and parameter_code='thresholds'),
  (select parameter_value from public.reporting_rule_parameters where configuration_version_id=v_overall_version and rule_code='overall_health' and parameter_code='thresholds')
 ) into v_thresholds;$new$);
 d:=replace(d,
 $old$select parameter_value into v_critical_dimensions from public.reporting_rule_parameters
 where configuration_version_id=v_version and rule_code='overall_health' and parameter_code='critical_dimension_codes';$old$,
 $new$select coalesce(
  (select parameter_value from public.reporting_rule_parameters where configuration_version_id=v_project_version and rule_code='overall_health' and parameter_code='critical_dimension_codes'),
  (select parameter_value from public.reporting_rule_parameters where configuration_version_id=v_overall_version and rule_code='overall_health' and parameter_code='critical_dimension_codes')
 ) into v_critical_dimensions;$new$);
 d:=replace(d,'select u->>''reported_health_status''','select lower(u->>''reported_health_status'')');
 if position('where configuration_version_id=v_project_version and rule_code=''overall_health''' in d)=0
  or position('lower(u->>''reported_health_status'')' in d)=0 then
  raise exception 'Global/project health configuration fallback patch validation failed';
 end if;
 execute d;
end;
$patch$;
commit;