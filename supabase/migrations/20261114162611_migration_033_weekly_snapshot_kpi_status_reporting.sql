begin;
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('public.build_weekly_portfolio_snapshot(uuid,uuid)'::regprocedure);
 d:=replace(d,$a$'kpi_calculation_status','not_implemented'$a$,$b$'kpi_calculation_status','pending_calculation'$b$);
 d:=replace(d,$a$'kpi_calculation_status','pending_calculation');$a$,
 $b$'kpi_calculation_status',coalesce((select ps.portfolio_summary->>'kpi_calculation_status' from public.portfolio_snapshots ps where ps.id=v_snapshot_id),'not_reported'));$b$);
 if strpos(d,'not_implemented')>0 then raise exception 'Build snapshot KPI status replacement incomplete'; end if;
 execute d;
 d:=pg_get_functiondef('public.finalize_weekly_portfolio_snapshot(uuid,uuid)'::regprocedure);
 d:=replace(d,$a$'kpi_calculation_status','not_implemented'$a$,
 $b$'kpi_calculation_status',coalesce(v_snapshot.portfolio_summary->>'kpi_calculation_status','not_reported')$b$);
 if strpos(d,'not_implemented')>0 then raise exception 'Finalize snapshot KPI status replacement incomplete'; end if;
 execute d;
end;
$patch$;
commit;