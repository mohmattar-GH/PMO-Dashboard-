create or replace function private.guard_portfolio_snapshot_mutation()
returns trigger language plpgsql set search_path=''
as $function$
declare
 v_mutable_summary_keys text[]:=array[
  'project_count','projects_changed_after_cutoff','source_consistency_status',
  'global_configuration_version_count','project_configuration_link_count','snapshot_generated_at',
  'kpi_calculation_status','projects_with_kpi_results','projects_with_kpi_gaps'
 ];
begin
 if tg_op='DELETE' then raise exception 'Portfolio snapshots are append-only'; end if;
 if old.snapshot_status='building'
    and new.snapshot_status='building'
    and coalesce(current_setting('request.jwt.claims',true)::jsonb->>'role','')='service_role'
    and (to_jsonb(new)-'portfolio_summary')=(to_jsonb(old)-'portfolio_summary')
    and (new.portfolio_summary-v_mutable_summary_keys)=(old.portfolio_summary-v_mutable_summary_keys) then
  return new;
 end if;
 if old.snapshot_status='building'
    and new.snapshot_status='finalized'
    and (to_jsonb(new)-'snapshot_status')=(to_jsonb(old)-'snapshot_status') then
  return new;
 end if;
 raise exception 'Only approved build-time summary fields and the building-to-finalized transition are permitted';
end;
$function$;