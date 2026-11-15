begin;
create or replace function private.refresh_portfolio_health_rollup_v1(p_portfolio_snapshot_id uuid)
returns jsonb language plpgsql set search_path=''
as $function$
declare v_summary jsonb;
begin
 if coalesce(current_setting('request.jwt.claims',true)::jsonb->>'role','')<>'service_role' then raise exception 'Service role required'; end if;
 select jsonb_build_object(
  'portfolio_health_status',case when count(*)=0 or count(*) filter(where calculated_health is null or calculated_health='not_reported')>0 then 'not_reported'
   when count(*) filter(where calculated_health='red')>0 then 'red'
   when count(*) filter(where calculated_health='amber')>0 then 'amber' else 'green' end,
  'calculated_health_status_counts',jsonb_build_object(
   'green',count(*) filter(where calculated_health='green'),
   'amber',count(*) filter(where calculated_health='amber'),
   'red',count(*) filter(where calculated_health='red'),
   'not_reported',count(*) filter(where calculated_health is null or calculated_health='not_reported')),
  'projects_with_calculated_health',count(*) filter(where calculated_health is not null and calculated_health<>'not_reported'),
  'projects_with_reported_health',count(*) filter(where reported_health is not null)
 ) into v_summary from public.project_snapshots where portfolio_snapshot_id=p_portfolio_snapshot_id;
 update public.portfolio_snapshots set portfolio_summary=portfolio_summary||v_summary
 where id=p_portfolio_snapshot_id and snapshot_status='building';
 if not found then raise exception 'Portfolio snapshot must exist and remain in building state'; end if;
 return v_summary;
end;
$function$;
revoke all on function private.refresh_portfolio_health_rollup_v1(uuid) from public,anon,authenticated;
grant execute on function private.refresh_portfolio_health_rollup_v1(uuid) to service_role;
create or replace function private.guard_portfolio_snapshot_mutation()
returns trigger language plpgsql set search_path=''
as $function$
declare v_mutable_summary_keys text[]:=array[
 'project_count','projects_changed_after_cutoff','source_consistency_status',
 'global_configuration_version_count','project_configuration_link_count','snapshot_generated_at',
 'kpi_calculation_status','projects_with_kpi_results','projects_with_kpi_gaps',
 'portfolio_health_status','calculated_health_status_counts','projects_with_calculated_health','projects_with_reported_health'
];
begin
 if tg_op='DELETE' then raise exception 'Portfolio snapshots are append-only'; end if;
 if old.snapshot_status='building' and new.snapshot_status='building'
  and coalesce(current_setting('request.jwt.claims',true)::jsonb->>'role','')='service_role'
  and (to_jsonb(new)-'portfolio_summary')=(to_jsonb(old)-'portfolio_summary')
  and (new.portfolio_summary-v_mutable_summary_keys)=(old.portfolio_summary-v_mutable_summary_keys) then return new; end if;
 if old.snapshot_status='building' and new.snapshot_status='finalized'
  and (to_jsonb(new)-'snapshot_status')=(to_jsonb(old)-'snapshot_status') then return new; end if;
 raise exception 'Only approved build-time summary fields and the building-to-finalized transition are permitted';
end;
$function$;
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('private.calculate_project_snapshot_kpis_v1(uuid)'::regprocedure);
 if position('private.refresh_portfolio_health_rollup_v1(v_portfolio.id)' in d)=0 then
  d:=replace(d,'   return jsonb_build_object(''project_snapshot_id'',v_ps.id,',
   '   perform private.refresh_portfolio_health_rollup_v1(v_portfolio.id);'||E'\n   return jsonb_build_object(''project_snapshot_id'',v_ps.id,');
 end if;
 if position('private.refresh_portfolio_health_rollup_v1(v_portfolio.id)' in d)=0 then raise exception 'Portfolio health rollup call insertion failed'; end if;
 execute d;
end;
$patch$;
commit;