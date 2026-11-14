begin;
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('private.kpi_source_field_allowed_v1(text,text)'::regprocedure);
 d:=replace(d,$a$  when 'risks' then$a$,$b$  when 'payment_allocations' then p_field=any(array['allocated_amount','allocation_date','status'])
  when 'risks' then$b$);
 if position('when ''payment_allocations''' in d)=0 then raise exception 'field allowlist patch failed'; end if; execute d;

 d:=pg_get_functiondef('private.read_kpi_source_rows_v1(uuid,text,timestamptz)'::regprocedure);
 d:=replace(d,$a$  when 'risks' then$a$,$b$  when 'payment_allocations' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.invoice_payment_allocations t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and (t.reversed_at is null or t.reversed_at>p_cutoff);
  when 'risks' then$b$);
 if position('when ''payment_allocations''' in d)=0 then raise exception 'source reader patch failed'; end if; execute d;

 d:=pg_get_functiondef('private.kpi_source_has_post_cutoff_changes_v1(uuid,text,timestamptz)'::regprocedure);
 d:=replace(d,$a$  when 'risks' then$a$,$b$  when 'payment_allocations' then
   select exists(select 1 from public.invoice_payment_allocations t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.reversed_at<=p_cutoff) into v_changed;
  when 'risks' then$b$);
 if position('when ''payment_allocations''' in d)=0 then raise exception 'cutoff patch failed'; end if; execute d;

 d:=pg_get_functiondef('private.evaluate_kpi_template_v1(text,jsonb,jsonb)'::regprocedure);
 d:=replace(d,$a$'cash_transactions','risks'$a$,$b$'cash_transactions','payment_allocations','risks'$b$);
 d:=replace(d,$a$'contract_deliverables')$a$,$b$'contract_deliverables','contracts','financial_terms')$b$);
 execute d;

 d:=pg_get_functiondef('private.calculate_project_snapshot_kpis_v1(uuid)'::regprocedure);
 if position('projects_with_kpi_results' in d)=0 then
  d:=replace(d,$a$ return jsonb_build_object('project_snapshot_id',v_ps.id,$a$,
   $b$ update public.portfolio_snapshots ps
   set portfolio_summary=ps.portfolio_summary||jsonb_build_object(
    'kpi_calculation_status',a.kpi_status,
    'projects_with_kpi_results',a.projects_with_results,
    'projects_with_kpi_gaps',a.projects_with_gaps)
   from (
    select case
     when count(*)=0 then 'not_reported'
     when count(*) filter(where p.snapshot_payload->>'kpi_calculation_status'='contains_not_reconstructable_sources')>0 then 'contains_not_reconstructable_sources'
     when count(*) filter(where p.snapshot_payload->>'kpi_calculation_status' in ('calculated_with_gaps','not_reported'))>0 then 'calculated_with_gaps'
     else 'calculated' end kpi_status,
     count(*) filter(where coalesce((p.snapshot_payload->>'kpi_count')::int,0)>0) projects_with_results,
     count(*) filter(where p.snapshot_payload->>'kpi_calculation_status' in ('calculated_with_gaps','contains_not_reconstructable_sources','not_reported')) projects_with_gaps
    from public.project_snapshots p where p.portfolio_snapshot_id=v_portfolio.id
   ) a where ps.id=v_portfolio.id;
   return jsonb_build_object('project_snapshot_id',v_ps.id,$b$);
  if position('projects_with_kpi_results' in d)=0 then raise exception 'portfolio rollup patch failed'; end if; execute d;
 end if;
end;
$patch$;
commit;