begin;
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('private.calculate_project_snapshot_kpis_v1(uuid)'::regprocedure);
 d:=replace(d,
 $a$ update public.project_snapshots
 set snapshot_payload=$a$,
 $b$ perform set_config('app.snapshot_kpi_calculation','on',true);
 update public.project_snapshots
 set snapshot_payload=$b$);
 d:=replace(d,
 $a$ where id=v_ps.id;
 update public.portfolio_snapshots ps$a$,
 $b$ where id=v_ps.id;
 perform set_config('app.snapshot_kpi_calculation','off',true);
 update public.portfolio_snapshots ps$b$);
 if strpos(d,'app.snapshot_kpi_calculation')=0 then raise exception 'KPI calculation guard flag was not added'; end if;
 execute d;
end;
$patch$;
create or replace function private.reject_snapshot_child_mutation()
returns trigger language plpgsql set search_path=''
as $function$
declare v_parent_status text;
begin
 if tg_table_name='project_snapshots'
    and tg_op='UPDATE'
    and coalesce(current_setting('request.jwt.claims',true)::jsonb->>'role','')='service_role'
    and coalesce(current_setting('app.snapshot_kpi_calculation',true),'off')='on'
    and new.portfolio_snapshot_id=old.portfolio_snapshot_id
    and new.project_id=old.project_id
    and (to_jsonb(new)-'snapshot_payload')=(to_jsonb(old)-'snapshot_payload')
    and new.snapshot_payload @> old.snapshot_payload then
  select snapshot_status into v_parent_status from public.portfolio_snapshots where id=new.portfolio_snapshot_id;
  if v_parent_status='building' then return new; end if;
 end if;
 raise exception 'Snapshot records are immutable; create a replacement snapshot instead';
end;
$function$;
create or replace function private.guard_portfolio_snapshot_mutation()
returns trigger language plpgsql set search_path=''
as $function$
begin
 if tg_op='DELETE' then raise exception 'Portfolio snapshots are append-only'; end if;
 if old.snapshot_status='building' and new.snapshot_status='building'
    and coalesce(current_setting('request.jwt.claims',true)::jsonb->>'role','')='service_role'
    and (to_jsonb(new)-'portfolio_summary')=(to_jsonb(old)-'portfolio_summary')
    and new.portfolio_summary @> old.portfolio_summary then return new; end if;
 if old.snapshot_status='building' and new.snapshot_status='finalized'
    and (to_jsonb(new)-'snapshot_status')=(to_jsonb(old)-'snapshot_status') then return new; end if;
 raise exception 'Only trusted build-time summary enrichment and the building-to-finalized transition are permitted';
end;
$function$;
commit;