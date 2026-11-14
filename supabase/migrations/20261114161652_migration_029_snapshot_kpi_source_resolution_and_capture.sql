-- Reconstructed from live definitions applied as migration 029 (version 20261114161652).
-- Migration 030 subsequently extends the calculator with portfolio-level KPI rollups.
begin;
alter table public.snapshot_metric_values
 add column if not exists configuration_version_id uuid references public.reporting_configuration_versions(id) on delete restrict;
alter table public.snapshot_metric_values add column if not exists formula_template_code text;
alter table public.snapshot_metric_values add column if not exists source_cutoff timestamptz;

CREATE OR REPLACE FUNCTION private.resolve_kpi_inputs_v1(p_project_id uuid, p_cutoff timestamp with time zone, p_template_code text, p_parameters jsonb, p_source_mapping jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
 v_inputs jsonb:='{}'::jsonb;
 v_lineage jsonb:='[]'::jsonb;
 v_mapping jsonb;
 v_spec jsonb;
 v_source text;
 v_field text;
 v_aggregate text;
 v_rows jsonb;
 v_count integer;
 v_values numeric[];
 v_result jsonb;
 v_key text;
 v_text text;
 v_numeric numeric;
 v_source_count integer;
 v_keys text[];
begin
 if jsonb_typeof(coalesce(p_source_mapping,'{}'::jsonb))<>'object' or jsonb_typeof(coalesce(p_parameters,'{}'::jsonb))<>'object' then
  raise exception 'KPI mapping and parameters must be JSON objects' using errcode='22023';
 end if;
 v_mapping:=coalesce(p_source_mapping->'inputs','{}'::jsonb);
 if jsonb_typeof(v_mapping)<>'object' then raise exception 'source_mapping.inputs must be an object' using errcode='22023'; end if;

 if p_template_code='count_v1' then
  v_source:=p_parameters->>'source';
  if private.kpi_source_has_post_cutoff_changes_v1(p_project_id,v_source,p_cutoff) then
   return jsonb_build_object('inputs',v_inputs,'source_lineage',jsonb_build_array(jsonb_build_object('source',v_source,'status','not_reconstructable')),'resolution_status','not_reconstructable');
  end if;
  v_rows:=private.read_kpi_source_rows_v1(p_project_id,v_source,p_cutoff);
  v_count:=jsonb_array_length(v_rows);
  if v_count>5000 then return jsonb_build_object('inputs',v_inputs,'source_lineage','[]'::jsonb,'resolution_status','insufficient_data'); end if;
  v_inputs:=jsonb_build_object('record_count',v_count);
  select coalesce(jsonb_agg(jsonb_build_object('id',x->>'id','source',v_source)),'[]'::jsonb) into v_result
   from (select value x from jsonb_array_elements(v_rows) limit 100) q;
  return jsonb_build_object('inputs',v_inputs,'source_lineage',jsonb_build_array(jsonb_build_object('source',v_source,'aggregate','count','row_count',v_count,'records',v_result)));
 end if;

 if p_template_code='date_variance_v1' then
  v_keys:=array[p_parameters->>'baseline_date',p_parameters->>'comparison_date'];
 elsif p_template_code='ratio_v1' then
  v_keys:=array[p_parameters->>'numerator',p_parameters->>'denominator'];
 elsif p_template_code='threshold_status_v1' then
  v_keys:=array[p_parameters->>'value'];
 elsif p_template_code='manual_input_v1' then
  v_keys:=array[p_parameters->>'input_field'];
 elsif p_template_code='weighted_sum_v1' then
  select array_agg(value) into v_keys from jsonb_array_elements_text(p_parameters->'values');
 else
  raise exception 'Unsupported KPI template: %',p_template_code using errcode='22023';
 end if;

 foreach v_key in array v_keys loop
  if v_key is null or length(v_key)>64 then raise exception 'KPI input key is invalid'; end if;
  if not (v_mapping ? v_key) then
   return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage);
  end if;
  v_spec:=v_mapping->v_key;
  if jsonb_typeof(v_spec)<>'object' then raise exception 'Each source_mapping.inputs entry must be an object'; end if;
  v_source:=v_spec->>'source'; v_field:=v_spec->>'field'; v_aggregate:=coalesce(v_spec->>'aggregate','value');
  if not private.kpi_source_field_allowed_v1(v_source,v_field) then raise exception 'Unsupported source field mapping: %.%',v_source,v_field using errcode='22023'; end if;
  if v_aggregate not in ('value','count','sum','avg','min','max') then raise exception 'Unsupported aggregate: %',v_aggregate using errcode='22023'; end if;
  if private.kpi_source_has_post_cutoff_changes_v1(p_project_id,v_source,p_cutoff) then
   return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage||jsonb_build_array(jsonb_build_object('input_key',v_key,'source',v_source,'status','not_reconstructable')),'resolution_status','not_reconstructable');
  end if;
  v_rows:=private.read_kpi_source_rows_v1(p_project_id,v_source,p_cutoff);
  v_source_count:=jsonb_array_length(v_rows);
  if v_source_count>5000 then return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage,'resolution_status','insufficient_data'); end if;

  if v_aggregate='count' then
   v_inputs:=v_inputs||jsonb_build_object(v_key,v_source_count);
  elsif v_aggregate in ('sum','avg') then
   select array_agg((x->>v_field)::numeric) filter(where x->>v_field is not null) into v_values from jsonb_array_elements(v_rows) x;
   if coalesce(array_length(v_values,1),0)>0 then
    if v_aggregate='sum' then select sum(z) into v_numeric from unnest(v_values) z;
    else select avg(z) into v_numeric from unnest(v_values) z; end if;
    v_inputs:=v_inputs||jsonb_build_object(v_key,v_numeric);
   end if;
  elsif v_aggregate in ('min','max') then
   select case when v_aggregate='min' then min(x->>v_field) else max(x->>v_field) end into v_text from jsonb_array_elements(v_rows) x;
   if v_text is not null then
    if v_text ~ '^-?[0-9]+([.][0-9]+)?$' then v_inputs:=v_inputs||jsonb_build_object(v_key,v_text::numeric);
    else v_inputs:=v_inputs||jsonb_build_object(v_key,v_text); end if;
   end if;
  elsif v_aggregate='value' and v_source_count=1 and v_rows->0->>v_field is not null then
   v_text:=v_rows->0->>v_field;
   if v_text ~ '^-?[0-9]+([.][0-9]+)?$' then v_inputs:=v_inputs||jsonb_build_object(v_key,v_text::numeric);
   else v_inputs:=v_inputs||jsonb_build_object(v_key,v_text); end if;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',x->>'id')),'[]'::jsonb) into v_result
   from (select value x from jsonb_array_elements(v_rows) limit 100) q;
  v_lineage:=v_lineage||jsonb_build_array(jsonb_build_object('input_key',v_key,'source',v_source,'field',v_field,'aggregate',v_aggregate,'row_count',v_source_count,'records',v_result));
 end loop;
 return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage);
end;
$function$

CREATE OR REPLACE FUNCTION private.calculate_project_snapshot_kpis_v1(p_project_snapshot_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 v_ps public.project_snapshots%rowtype;
 v_portfolio public.portfolio_snapshots%rowtype;
 v_cycle public.reporting_cycles%rowtype;
 v_kpi record;
 v_resolved jsonb;
 v_eval jsonb;
 v_lineage jsonb;
 v_count integer:=0;
 v_not_reported integer:=0;
 v_insufficient integer:=0;
 v_not_reconstructable integer:=0;
 v_dimension_summary jsonb:='[]'::jsonb;
 v_dup text;
begin
 select * into v_ps from public.project_snapshots where id=p_project_snapshot_id for update;
 if not found then raise exception 'Project snapshot not found'; end if;
 select * into v_portfolio from public.portfolio_snapshots where id=v_ps.portfolio_snapshot_id;
 select * into v_cycle from public.reporting_cycles where id=v_portfolio.reporting_cycle_id;
 if v_portfolio.snapshot_status<>'building' then raise exception 'KPI metrics can only be calculated for a building snapshot'; end if;

 select k.kpi_code into v_dup
 from public.snapshot_config_links l
 join public.kpi_definitions k on k.configuration_version_id=l.configuration_version_id and k.is_active
 where l.portfolio_snapshot_id=v_portfolio.id
  and (l.scope_type='global' or (l.scope_type='project' and l.scope_entity_id=v_ps.project_id))
 group by k.kpi_code
 having count(*) filter(where l.scope_type='global')>1
    or count(*) filter(where l.scope_type='project')>1
 limit 1;
 if v_dup is not null then raise exception 'Ambiguous active KPI code across linked configuration sets: %',v_dup; end if;

 for v_kpi in
  select distinct on (k.kpi_code)
   k.id,k.configuration_version_id,k.kpi_code,k.name,k.calculation_method,k.formula_template,
   k.source_mapping,k.parameters,k.unit,k.weight,k.dimension_id,d.dimension_code,d.name as dimension_name,
   l.scope_type
  from public.snapshot_config_links l
  join public.kpi_definitions k on k.configuration_version_id=l.configuration_version_id and k.is_active
  left join public.reporting_dimensions d on d.id=k.dimension_id
  where l.portfolio_snapshot_id=v_portfolio.id
    and (l.scope_type='global' or (l.scope_type='project' and l.scope_entity_id=v_ps.project_id))
  order by k.kpi_code,(l.scope_type='project') desc,k.configuration_version_id
 loop
  v_resolved:=private.resolve_kpi_inputs_v1(v_ps.project_id,v_cycle.cutoff_at,v_kpi.formula_template,v_kpi.parameters,v_kpi.source_mapping);
  v_lineage:=coalesce(v_resolved->'source_lineage','[]'::jsonb);
  if v_resolved ? 'resolution_status' then
   v_eval:=jsonb_build_object('numeric_value',null,'text_value',null,
     'status',case v_resolved->>'resolution_status' when 'insufficient_data' then 'insufficient_data' else 'not_reported' end,
     'calculation_method',v_kpi.calculation_method,'source_lineage',v_lineage);
   if v_resolved->>'resolution_status'='not_reconstructable' then v_not_reconstructable:=v_not_reconstructable+1; end if;
   if v_resolved->>'resolution_status'='insufficient_data' then v_insufficient:=v_insufficient+1; end if;
  else
   v_eval:=private.evaluate_kpi_template_v1(v_kpi.formula_template,v_kpi.parameters,
     coalesce(v_resolved->'inputs','{}'::jsonb)||jsonb_build_object('source_lineage',v_lineage));
  end if;
  if v_eval->>'status'='not_reported' then v_not_reported:=v_not_reported+1; end if;
  if v_eval->>'status'='insufficient_data' then v_insufficient:=v_insufficient+1; end if;
  insert into public.snapshot_metric_values(
   project_snapshot_id,kpi_code,numeric_value,text_value,unit,status,source_lineage,
   configuration_version_id,formula_template_code,source_cutoff
  ) values (
   v_ps.id,v_kpi.kpi_code,nullif(v_eval->>'numeric_value','')::numeric,v_eval->>'text_value',
   v_kpi.unit,coalesce(v_eval->>'status','not_reported'),
   v_lineage||jsonb_build_array(jsonb_build_object('configuration_version_id',v_kpi.configuration_version_id,
     'kpi_definition_id',v_kpi.id,'formula_template',v_kpi.formula_template,'calculation_method',v_kpi.calculation_method,
     'source_cutoff',v_cycle.cutoff_at)),
   v_kpi.configuration_version_id,v_kpi.formula_template,v_cycle.cutoff_at
  );
  v_count:=v_count+1;
 end loop;

 select coalesce(jsonb_agg(jsonb_build_object(
   'configuration_version_id',x.configuration_version_id,'dimension_code',x.dimension_code,'dimension_name',x.dimension_name,
   'metric_count',x.metric_count,'reported_metric_count',x.reported_count,'weighted_value',x.weighted_value,
   'status',x.dimension_status
 ) order by x.dimension_code),'[]'::jsonb)
 into v_dimension_summary
 from (
  select d.configuration_version_id,d.dimension_code,d.name as dimension_name,
   count(*) metric_count,
   count(*) filter(where m.numeric_value is not null and m.status not in ('not_reported','insufficient_data')) reported_count,
   case when count(*) filter(where k.weight is not null)=count(*) and abs(sum(k.weight)-1)<0.000001
       and count(*) filter(where m.numeric_value is not null)=count(*)
     then sum(m.numeric_value*k.weight) else null end weighted_value,
   case when count(*) filter(where m.numeric_value is null or m.status in ('not_reported','insufficient_data'))>0 then 'insufficient_data'
        when count(*) filter(where k.weight is not null)=count(*) and abs(sum(k.weight)-1)<0.000001 then 'calculated'
        else 'weights_not_configured' end dimension_status
  from public.snapshot_metric_values m
  join public.kpi_definitions k on k.configuration_version_id=m.configuration_version_id and k.kpi_code=m.kpi_code
  join public.reporting_dimensions d on d.id=k.dimension_id and d.is_active
  where m.project_snapshot_id=v_ps.id
  group by d.configuration_version_id,d.dimension_code,d.name
 ) x;

 update public.project_snapshots
 set snapshot_payload=snapshot_payload||jsonb_build_object(
  'kpi_calculation_status',case when v_count=0 then 'not_reported' when v_not_reconstructable>0 then 'contains_not_reconstructable_sources'
    when v_not_reported>0 or v_insufficient>0 then 'calculated_with_gaps' else 'calculated' end,
  'kpi_count',v_count,'kpi_not_reported_count',v_not_reported,
  'kpi_insufficient_data_count',v_insufficient,'kpi_not_reconstructable_count',v_not_reconstructable,
  'dimension_results',v_dimension_summary,
  'calculated_health_status','not_reported',
  'calculated_health_reason','Overall health aggregation requires a published configurable health mapping and complete dimension weights'
 )
 where id=v_ps.id;
   return jsonb_build_object('project_snapshot_id',v_ps.id,'kpi_count',v_count,'not_reported',v_not_reported,
  'insufficient_data',v_insufficient,'not_reconstructable',v_not_reconstructable,'dimensions',v_dimension_summary);
end;
$function$

CREATE OR REPLACE FUNCTION private.on_project_snapshot_calculate_kpis_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 perform private.calculate_project_snapshot_kpis_v1(new.id);
 return new;
end;
$function$


drop trigger if exists trg_project_snapshot_calculate_kpis_v1 on public.project_snapshots;
create trigger trg_project_snapshot_calculate_kpis_v1
 after insert on public.project_snapshots
 for each row execute function private.on_project_snapshot_calculate_kpis_v1();

revoke all on function private.resolve_kpi_inputs_v1(uuid,timestamptz,text,jsonb,jsonb) from public,anon,authenticated;
revoke all on function private.calculate_project_snapshot_kpis_v1(uuid) from public,anon,authenticated;
revoke all on function private.on_project_snapshot_calculate_kpis_v1() from public,anon,authenticated;
grant execute on function private.resolve_kpi_inputs_v1(uuid,timestamptz,text,jsonb,jsonb) to service_role;
grant execute on function private.calculate_project_snapshot_kpis_v1(uuid) to service_role;
grant execute on function private.on_project_snapshot_calculate_kpis_v1() to service_role;
commit;
