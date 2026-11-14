create or replace function private.reject_snapshot_child_mutation()
returns trigger language plpgsql set search_path=''
as $function$
declare v_parent_status text; v_kpi_keys text[]:=array[
 'kpi_calculation_status','kpi_count','kpi_not_reported_count','kpi_insufficient_data_count',
 'kpi_not_reconstructable_count','dimension_results','calculated_health_status','calculated_health_reason'
];
begin
 if tg_table_name='project_snapshots'
    and tg_op='UPDATE'
    and coalesce(current_setting('request.jwt.claims',true)::jsonb->>'role','')='service_role'
    and coalesce(current_setting('app.snapshot_kpi_calculation',true),'off')='on'
    and new.portfolio_snapshot_id=old.portfolio_snapshot_id
    and new.project_id=old.project_id
    and (to_jsonb(new)-'snapshot_payload')=(to_jsonb(old)-'snapshot_payload')
    and (new.snapshot_payload-v_kpi_keys)=(old.snapshot_payload-v_kpi_keys) then
  select snapshot_status into v_parent_status from public.portfolio_snapshots where id=new.portfolio_snapshot_id;
  if v_parent_status='building' then return new; end if;
 end if;
 raise exception 'Snapshot records are immutable; create a replacement snapshot instead';
end;
$function$;