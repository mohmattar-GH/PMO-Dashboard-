begin;
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('public.build_weekly_portfolio_snapshot(uuid,uuid)'::regprocedure);
 d:=replace(d,
 $a$'snapshot_generated_at',v_watermark
  )$a$,
 $b$'snapshot_generated_at',v_watermark,
    'kpi_calculation_status',case when v_project_count=0 then 'not_reported'
      else coalesce(portfolio_summary->>'kpi_calculation_status','not_reported') end
  )$b$);
 if strpos(d,'v_project_count=0 then ''not_reported''')=0 then
  raise exception 'No-project KPI status handling was not added';
 end if;
 execute d;
end;
$patch$;
commit;