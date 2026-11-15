begin;
do $patch$
declare
  d text;
  old_marker text;
  new_marker text;
begin
  d:=pg_get_functiondef('public.build_weekly_portfolio_snapshot(uuid,uuid)'::regprocedure);
  old_marker:=E'  insert into private.security_audit_events(actor_user_id,action,entity_schema,entity_table,entity_id,reason,after_data)\n  values(p_actor_user_id,''portfolio_snapshot_built''';
  new_marker:=E'  perform private.refresh_portfolio_health_rollup_v1(v_snapshot_id);\n\n'||old_marker;
  if position(old_marker in d)=0 then
    raise exception 'Could not locate snapshot-built audit insertion point';
  end if;
  if position('perform private.refresh_portfolio_health_rollup_v1(v_snapshot_id)' in d)=0 then
    d:=replace(d,old_marker,new_marker);
    execute d;
  end if;

  d:=pg_get_functiondef('public.finalize_weekly_portfolio_snapshot(uuid,uuid)'::regprocedure);
  old_marker:=E'  update public.portfolio_snapshots set snapshot_status=''finalized'' where id=v_snapshot.id;';
  new_marker:=E'  if not (v_snapshot.portfolio_summary ? ''portfolio_health_status'')\n     or not (v_snapshot.portfolio_summary ? ''calculated_health_status_counts'')\n     or not (v_snapshot.portfolio_summary ? ''projects_with_calculated_health'')\n     or not (v_snapshot.portfolio_summary ? ''projects_with_reported_health'') then\n    raise exception ''Portfolio health rollup is incomplete; snapshot cannot be finalized'';\n  end if;\n\n  if exists (select 1 from public.project_snapshots p\n    where p.portfolio_snapshot_id=v_snapshot.id\n      and (p.calculated_health is null\n        or not (p.snapshot_payload ? ''kpi_calculation_status'')\n        or not (p.snapshot_payload ? ''calculated_health_status''))) then\n    raise exception ''One or more project snapshots have incomplete KPI/health calculations'';\n  end if;\n\n'||old_marker;
  if position(old_marker in d)=0 then
    raise exception 'Could not locate snapshot finalization update point';
  end if;
  if position('Portfolio health rollup is incomplete' in d)=0 then
    d:=replace(d,old_marker,new_marker);
    execute d;
  end if;
end;
$patch$;
commit;
