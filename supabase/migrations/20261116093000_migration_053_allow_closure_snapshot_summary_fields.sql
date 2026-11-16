
-- Permit the closure-boundary metadata keys written by the snapshot builder.
do $migration$
declare
  v_def text;
begin
  v_def:=pg_get_functiondef('private.guard_portfolio_snapshot_mutation()'::regprocedure);
  v_def:=replace(v_def,
    '''project_count'',''projects_changed_after_cutoff'',''source_consistency_status'',',
    '''project_count'',''projects_changed_after_cutoff'',''projects_changed_after_scheduled_cutoff'',''source_consistency_status'',''scheduled_cutoff_at'',''actual_closed_at'',''visibility_boundary_type'',');
  if position('visibility_boundary_type' in v_def)=0
     or position('projects_changed_after_scheduled_cutoff' in v_def)=0 then
    raise exception 'Could not safely extend portfolio snapshot mutation allowlist';
  end if;
  execute v_def;
end;
$migration$;
