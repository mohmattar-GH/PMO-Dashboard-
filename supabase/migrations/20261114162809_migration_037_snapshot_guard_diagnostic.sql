create or replace function private.reject_snapshot_child_mutation()
returns trigger language plpgsql set search_path=''
as $function$
declare v_parent_status text; v_claim text; v_flag text; v_depth integer; v_same boolean; v_contains boolean;
begin
 v_claim:=coalesce(current_setting('request.jwt.claims',true)::jsonb->>'role','');
 v_flag:=coalesce(current_setting('app.snapshot_kpi_calculation',true),'off');
 v_depth:=pg_catalog.pg_trigger_depth();
 v_same:=(to_jsonb(new)-'snapshot_payload')=(to_jsonb(old)-'snapshot_payload');
 v_contains:=new.snapshot_payload @> old.snapshot_payload;
 if tg_table_name='project_snapshots' and tg_op='UPDATE' and v_claim='service_role' and v_flag='on'
    and new.portfolio_snapshot_id=old.portfolio_snapshot_id and new.project_id=old.project_id and v_same and v_contains then
  select snapshot_status into v_parent_status from public.portfolio_snapshots where id=new.portfolio_snapshot_id;
  if v_parent_status='building' then return new; end if;
 end if;
 raise exception 'Snapshot guard diagnostic: table %, op %, claim %, flag %, current_user %, depth %, same %, contains %, parent %',
 tg_table_name,tg_op,v_claim,v_flag,current_user,v_depth,v_same,v_contains,v_parent_status;
end;
$function$;