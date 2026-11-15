begin;
alter table public.project_weekly_updates add column reported_health_reason text;
alter table public.project_weekly_updates add constraint project_weekly_updates_reported_health_check
check (
 (reported_health_status is null and reported_health_reason is null)
 or (lower(reported_health_status) in ('green','amber','red','not_reported')
  and reported_health_reason is not null and length(btrim(reported_health_reason)) between 8 and 1000)
);
create or replace function private.calculate_project_health_v1(
 p_project_snapshot_id uuid,p_dimension_results jsonb,p_cutoff timestamptz,p_as_of_date date
)
returns jsonb language plpgsql stable set search_path=''
as $function$
declare
 v_project_id uuid; v_portfolio_snapshot_id uuid; v_overall_version uuid; v_project_version uuid; v_version uuid;
 v_score_min numeric; v_score_max numeric; v_thresholds jsonb; v_critical_dimensions jsonb;
 v_score numeric; v_status text; v_reason text; v_dim_count integer;
 v_reported_health text; v_reported_reason text; v_reported_week_end date;
 v_dimension_scores jsonb:='[]'::jsonb; v_bad_dimension text;
 v_item jsonb; v_upper numeric; v_previous numeric:=null; v_matched boolean:=false;
 v_i integer; v_len integer;
begin
 select ps.project_id,ps.portfolio_snapshot_id into v_project_id,v_portfolio_snapshot_id
 from public.project_snapshots ps where ps.id=p_project_snapshot_id;
 if not found then raise exception 'Project snapshot not found'; end if;
 select configuration_version_id into v_overall_version from public.snapshot_config_links
 where portfolio_snapshot_id=v_portfolio_snapshot_id and scope_type='global'
 order by configuration_version_id desc limit 1;
 select configuration_version_id into v_project_version from public.snapshot_config_links
 where portfolio_snapshot_id=v_portfolio_snapshot_id and scope_type='project' and scope_entity_id=v_project_id
 order by configuration_version_id desc limit 1;
 v_version:=coalesce(v_project_version,v_overall_version);
 if v_version is null then
  return jsonb_build_object('calculated_health','not_reported','health_score',null,
   'health_reason','No applicable reporting configuration version is linked to this snapshot','dimension_scores','[]'::jsonb);
 end if;
 select parameter_value into v_score_min from public.reporting_rule_parameters
 where configuration_version_id=v_version and rule_code='overall_health' and parameter_code='score_min';
 select parameter_value into v_score_max from public.reporting_rule_parameters
 where configuration_version_id=v_version and rule_code='overall_health' and parameter_code='score_max';
 select parameter_value into v_thresholds from public.reporting_rule_parameters
 where configuration_version_id=v_version and rule_code='overall_health' and parameter_code='thresholds';
 select parameter_value into v_critical_dimensions from public.reporting_rule_parameters
 where configuration_version_id=v_version and rule_code='overall_health' and parameter_code='critical_dimension_codes';
 if v_score_min is null or v_score_max is null or v_score_max<=v_score_min
    or jsonb_typeof(v_thresholds) is distinct from 'array' or jsonb_array_length(v_thresholds)=0
    or jsonb_typeof(coalesce(v_critical_dimensions,'[]'::jsonb)) is distinct from 'array' then
  return jsonb_build_object('calculated_health','not_reported','health_score',null,
   'health_reason','Overall health rules are not fully configured for the effective reporting version','dimension_scores','[]'::jsonb);
 end if;
 v_len:=jsonb_array_length(v_thresholds);
 for v_i in 0..v_len-1 loop
  v_item:=v_thresholds->v_i;
  if jsonb_typeof(v_item) is distinct from 'object'
    or (v_item-array['upper_bound','status']::text[])<>'{}'::jsonb
    or not (v_item?'status') or lower(v_item->>'status') not in ('green','amber','red') then
   raise exception 'Invalid overall health threshold entry';
  end if;
  if v_i=v_len-1 then
   if v_item->'upper_bound' is distinct from 'null'::jsonb then raise exception 'Final health threshold must have null upper_bound'; end if;
  else
   if jsonb_typeof(v_item->'upper_bound') is distinct from 'number' then raise exception 'Non-final health thresholds require numeric upper_bound'; end if;
   v_upper:=(v_item->>'upper_bound')::numeric;
   if (v_previous is not null and v_upper<=v_previous) or v_upper<v_score_min or v_upper>v_score_max then
    raise exception 'Invalid overall health threshold ordering or range';
   end if;
   v_previous:=v_upper;
  end if;
 end loop;
 with effective_dimensions as (
  select distinct on (d.dimension_code) d.id,d.dimension_code,d.name,d.weight,d.configuration_version_id
  from public.snapshot_config_links l
  join public.reporting_dimensions d on d.configuration_version_id=l.configuration_version_id and d.is_active
  where l.portfolio_snapshot_id=v_portfolio_snapshot_id
   and (l.scope_type='global' or (l.scope_type='project' and l.scope_entity_id=v_project_id))
  order by d.dimension_code,(l.scope_type='project') desc,l.configuration_version_id desc
 ),
 dimension_metrics as (
  select d.dimension_code,d.name,d.weight,
   count(k.id) filter(where k.is_active) kpi_count,
   count(m.id) filter(where k.is_active and m.numeric_value is not null and m.status not in ('not_reported','insufficient_data')) available_count,
   count(k.id) filter(where k.is_active and k.weight is not null) weighted_count,
   sum(k.weight) filter(where k.is_active) kpi_weight_sum,
   case when count(k.id) filter(where k.is_active)>0
     and count(m.id) filter(where k.is_active and m.numeric_value is not null and m.status not in ('not_reported','insufficient_data'))=count(k.id) filter(where k.is_active)
     and count(k.id) filter(where k.is_active and k.weight is not null)=count(k.id) filter(where k.is_active)
     and abs(sum(k.weight) filter(where k.is_active)-1)<0.000001
    then sum(m.numeric_value*k.weight) filter(where k.is_active) else null end dimension_score
  from effective_dimensions d
  left join public.kpi_definitions k on k.configuration_version_id=d.configuration_version_id and k.dimension_id=d.id
  left join public.snapshot_metric_values m on m.project_snapshot_id=p_project_snapshot_id
   and m.configuration_version_id=k.configuration_version_id and m.kpi_code=k.kpi_code
  group by d.dimension_code,d.name,d.weight
 )
 select count(*),
  coalesce(jsonb_agg(jsonb_build_object('dimension_code',dimension_code,'dimension_name',name,'weight',weight,
   'score',dimension_score,'status',case when dimension_score is null then 'insufficient_data'
    when dimension_score<v_score_min or dimension_score>v_score_max then 'insufficient_data' else 'calculated' end)
   order by dimension_code),'[]'::jsonb),
  case when count(*)>0 and count(*) filter(where dimension_score is null)=0
    and count(*) filter(where weight is null)=0 and abs(sum(weight)-1)<0.000001
    and min(dimension_score)>=v_score_min and max(dimension_score)<=v_score_max
   then sum(dimension_score*weight) else null end
 into v_dim_count,v_dimension_scores,v_score from dimension_metrics;
 if v_dim_count=0 or v_score is null then
  v_status:='not_reported'; v_reason:='One or more reporting dimensions lack complete KPI values or valid weights';
 else
  for v_i in 0..v_len-1 loop
   v_item:=v_thresholds->v_i;
   if v_i=v_len-1 then
    if not v_matched then v_status:=lower(v_item->>'status'); end if;
   else
    v_upper:=(v_item->>'upper_bound')::numeric;
    if not v_matched and v_score<=v_upper then v_status:=lower(v_item->>'status'); v_matched:=true; end if;
   end if;
  end loop;
  if v_status is null then v_status:='not_reported'; end if;
  select d->>'dimension_code' into v_bad_dimension from jsonb_array_elements(v_dimension_scores) d
  where d->>'dimension_code' in (select jsonb_array_elements_text(v_critical_dimensions))
   and d->>'status'='calculated'
   and (d->>'score')::numeric<=coalesce((
    select min((x->>'upper_bound')::numeric) from jsonb_array_elements(v_thresholds) x
    where lower(x->>'status')='red' and x->'upper_bound'<>'null'::jsonb
   ),v_score_min-1) limit 1;
  if v_bad_dimension is not null then v_status:='red'; v_reason:='Critical dimension override: '||v_bad_dimension;
  else v_reason:='Calculated from configured dimension weights and overall health thresholds'; end if;
 end if;
 select u->>'reported_health_status',u->>'reported_health_reason',(u->>'week_end')::date
 into v_reported_health,v_reported_reason,v_reported_week_end
 from jsonb_array_elements(private.read_kpi_source_rows_v1(v_project_id,'weekly_updates',p_cutoff)) u
 where u->>'status' in ('submitted','reviewed') and (u->>'week_end')::date<=p_as_of_date
  and nullif(u->>'reported_health_status','') is not null
 order by (u->>'week_end')::date desc,(u->>'updated_at')::timestamptz desc limit 1;
 return jsonb_build_object('calculated_health',coalesce(v_status,'not_reported'),'health_score',v_score,
  'health_reason',v_reason,'dimension_scores',v_dimension_scores,'reported_health',v_reported_health,
  'reported_health_reason',v_reported_reason,'reported_health_week_end',v_reported_week_end,
  'configuration_version_id',v_version);
end;
$function$;
revoke all on function private.calculate_project_health_v1(uuid,jsonb,timestamptz,date) from public,anon,authenticated;
grant execute on function private.calculate_project_health_v1(uuid,jsonb,timestamptz,date) to service_role;

do $patch$
declare d text;
begin
 d:=pg_get_functiondef('private.calculate_project_snapshot_kpis_v1(uuid)'::regprocedure);
 d:=replace(d,'v_dimension_summary jsonb:=''[]''::jsonb;','v_dimension_summary jsonb:=''[]''::jsonb;'||E'\n v_health jsonb;');
 d:=replace(d,'perform set_config(''app.snapshot_kpi_calculation'',''on'',true);',
  'v_health:=private.calculate_project_health_v1(v_ps.id,v_dimension_summary,v_cycle.cutoff_at,v_cycle.as_of_date);'||E'\n perform set_config(''app.snapshot_kpi_calculation'',''on'',true);');
 d:=replace(d,'''calculated_health_status'',''not_reported'',',
  '''calculated_health_status'',coalesce(v_health->>''calculated_health'',''not_reported''),'||E'\n ''calculated_health_score'',v_health->''health_score'','||E'\n ''calculated_health_reason'',v_health->>''health_reason'','||E'\n ''reported_health_reason'',v_health->>''reported_health_reason'','||E'\n ''reported_health_week_end'',v_health->''reported_health_week_end'','||E'\n ''health_configuration_version_id'',v_health->''configuration_version_id'',');
 d:=replace(d,'update public.project_snapshots'||E'\n set snapshot_payload=snapshot_payload||jsonb_build_object(',
  'update public.project_snapshots'||E'\n set calculated_health=coalesce(v_health->>''calculated_health'',''not_reported''),'||E'\n reported_health=v_health->>''reported_health'','||E'\n snapshot_payload=snapshot_payload||jsonb_build_object(');
 d:=replace(d,'''health_configuration_version_id'',v_health->''configuration_version_id'','||E'\n  ''calculated_health_reason'',''Overall health aggregation requires a published configurable health mapping and complete dimension weights''',''health_configuration_version_id'',v_health->''configuration_version_id''');
 execute d;
end;
$patch$;
commit;