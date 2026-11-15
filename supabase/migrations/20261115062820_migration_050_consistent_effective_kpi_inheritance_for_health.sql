begin;
do $patch$
declare
 d text;
 start_marker text := ' dimension_metrics as (';
 end_marker text := E'\n )\n select count(*),';
 s integer; e integer; replacement text;
begin
 d:=pg_get_functiondef('private.calculate_project_health_v1(uuid,jsonb,timestamp with time zone,date)'::regprocedure);
 s:=position(start_marker in d);
 if s=0 then raise exception 'dimension_metrics start marker not found'; end if;
 e:=s+position(end_marker in substring(d from s))-1;
 if e<s then raise exception 'dimension_metrics end marker not found'; end if;
 replacement:= $sql$
 effective_kpis as (
  select distinct on (k.kpi_code)
   k.id,k.configuration_version_id,k.kpi_code,k.weight,k.is_active,kd.dimension_code
  from public.snapshot_config_links l
  join public.kpi_definitions k on k.configuration_version_id=l.configuration_version_id and k.is_active
  join public.reporting_dimensions kd on kd.id=k.dimension_id and kd.is_active
  where l.portfolio_snapshot_id=v_portfolio_snapshot_id
   and (l.scope_type='global' or (l.scope_type='project' and l.scope_entity_id=v_project_id))
  order by k.kpi_code,(l.scope_type='project') desc,k.configuration_version_id desc
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
  left join effective_kpis k on k.dimension_code=d.dimension_code
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
 into v_dim_count,v_dimension_scores,v_score
 from dimension_metrics;
$sql$;
 d:=substring(d from 1 for s-1)||replacement||substring(d from e+length(end_marker));
 execute d;
end;
$patch$;
commit;
