begin;
CREATE OR REPLACE FUNCTION public.build_weekly_portfolio_snapshot(p_reporting_cycle_id uuid, p_actor_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_cycle public.reporting_cycles%rowtype;
  v_snapshot_id uuid;
  v_global_count integer;
  v_project_count integer;
  v_post_cutoff_count integer;
  v_watermark timestamptz := clock_timestamp();
begin
  if coalesce(current_setting('request.jwt.claims',true)::jsonb->>'role','') <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_actor_user_id is not null and not exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=p_actor_user_id and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) then raise exception 'Forbidden: platform administrator permission required'; end if;

  select * into v_cycle from public.reporting_cycles where id=p_reporting_cycle_id for update;
  if not found then raise exception 'Reporting cycle not found'; end if;
  if v_cycle.status<>'closed' then raise exception 'Only closed reporting cycles can be snapshotted'; end if;
  if v_cycle.cutoff_at>now() then raise exception 'Reporting cutoff has not been reached'; end if;
  if exists(select 1 from public.portfolio_snapshots where reporting_cycle_id=v_cycle.id) then
    raise exception 'A snapshot already exists for this reporting cycle';
  end if;

  select count(*) into v_global_count
  from (
    select distinct on (s.id) v.id
    from public.reporting_configuration_sets s
    join public.reporting_configuration_versions v on v.configuration_set_id=s.id
    where s.scope_type='global' and v.status='published'
      and v.effective_from<=v_cycle.cutoff_at
      and (v.effective_to is null or v.effective_to>v_cycle.cutoff_at)
    order by s.id,v.effective_from desc,v.version_number desc
  ) effective_global;
  if v_global_count=0 then
    raise exception 'No published global reporting configuration is effective at the reporting cutoff; snapshot was not created';
  end if;

  insert into public.portfolio_snapshots(reporting_cycle_id,generated_by,snapshot_status,source_watermark,portfolio_summary)
  values(v_cycle.id,p_actor_user_id,'building',v_watermark,
    jsonb_build_object('reporting_cycle_code',v_cycle.cycle_code,'as_of_date',v_cycle.as_of_date,
      'period_start',v_cycle.period_start,'period_end',v_cycle.period_end,'timezone',v_cycle.timezone,
      'kpi_calculation_status','not_implemented','portfolio_health_status','not_reported',
      'data_completeness_status','operational_modules_pending'))
  returning id into v_snapshot_id;

  insert into public.snapshot_config_links(portfolio_snapshot_id,configuration_version_id,scope_type,scope_entity_id)
  select v_snapshot_id,effective_global.id,'global',null
  from (
    select distinct on (s.id) v.id
    from public.reporting_configuration_sets s
    join public.reporting_configuration_versions v on v.configuration_set_id=s.id
    where s.scope_type='global' and v.status='published'
      and v.effective_from<=v_cycle.cutoff_at
      and (v.effective_to is null or v.effective_to>v_cycle.cutoff_at)
    order by s.id,v.effective_from desc,v.version_number desc
  ) effective_global;

  insert into public.snapshot_config_links(portfolio_snapshot_id,configuration_version_id,scope_type,scope_entity_id)
  select v_snapshot_id,effective_project.id,'project',effective_project.project_id
  from (
    select distinct on (s.id) s.project_id,v.id
    from public.reporting_configuration_sets s
    join public.reporting_configuration_versions v on v.configuration_set_id=s.id
    where s.scope_type='project' and v.status='published'
      and v.effective_from<=v_cycle.cutoff_at
      and (v.effective_to is null or v.effective_to>v_cycle.cutoff_at)
    order by s.id,v.effective_from desc,v.version_number desc
  ) effective_project;

  insert into public.project_snapshots(portfolio_snapshot_id,project_id,source_updated_at,calculated_health,reported_health,snapshot_payload)
  select v_snapshot_id,p.id,p.updated_at,null,null,
    jsonb_build_object(
      'project_record',to_jsonb(p),
      'reporting_configuration_version_ids',
        coalesce((
          select jsonb_agg(distinct scl.configuration_version_id order by scl.configuration_version_id)
          from public.snapshot_config_links scl
          where scl.portfolio_snapshot_id=v_snapshot_id
            and (scl.scope_type='global' or (scl.scope_type='project' and scl.scope_entity_id=p.id))
        ),'[]'::jsonb),
      'kpi_calculation_status','not_implemented',
      'data_completeness_status','operational_modules_pending',
      'health_status','not_reported',
      'source_state_as_of_cutoff',(p.updated_at is null or p.updated_at<=v_cycle.cutoff_at),
      'source_state_captured_at',v_watermark
    )
  from public.projects p
  where p.created_at<=v_cycle.cutoff_at;

  get diagnostics v_project_count = row_count;
  select count(*) into v_post_cutoff_count from public.projects p
  where p.created_at<=v_cycle.cutoff_at and p.updated_at>v_cycle.cutoff_at;

  update public.portfolio_snapshots
  set portfolio_summary=portfolio_summary||jsonb_build_object(
    'project_count',v_project_count,
    'projects_changed_after_cutoff',v_post_cutoff_count,
    'source_consistency_status',case when v_post_cutoff_count=0 then 'as_of_cutoff' else 'contains_post_cutoff_source_changes' end,
    'global_configuration_version_count',v_global_count,
    'project_configuration_link_count',(select count(*) from public.snapshot_config_links where portfolio_snapshot_id=v_snapshot_id and scope_type='project'),
    'snapshot_generated_at',v_watermark
  )
  where id=v_snapshot_id;

  insert into private.security_audit_events(actor_user_id,action,entity_schema,entity_table,entity_id,reason,after_data)
  values(p_actor_user_id,'portfolio_snapshot_built','public','portfolio_snapshots',v_snapshot_id,
    'System-generated weekly reporting snapshot',
    jsonb_build_object('reporting_cycle_id',v_cycle.id,'project_count',v_project_count,'projects_changed_after_cutoff',v_post_cutoff_count,'global_configuration_version_count',v_global_count));

  return jsonb_build_object('portfolio_snapshot_id',v_snapshot_id,'reporting_cycle_id',v_cycle.id,
    'snapshot_status','building','project_count',v_project_count,'global_configuration_version_count',v_global_count,
    'kpi_calculation_status','not_implemented');
end;
$function$
;
CREATE OR REPLACE FUNCTION public.finalize_weekly_portfolio_snapshot(p_portfolio_snapshot_id uuid, p_actor_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_snapshot public.portfolio_snapshots%rowtype;
  v_cycle public.reporting_cycles%rowtype;
  v_expected_projects integer;
  v_actual_projects integer;
begin
  if coalesce(current_setting('request.jwt.claims',true)::jsonb->>'role','') <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_actor_user_id is not null and not exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=p_actor_user_id and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) then raise exception 'Forbidden: platform administrator permission required'; end if;

  select * into v_snapshot from public.portfolio_snapshots where id=p_portfolio_snapshot_id for update;
  if not found then raise exception 'Portfolio snapshot not found'; end if;
  if v_snapshot.snapshot_status<>'building' then raise exception 'Only building snapshots can be finalized'; end if;
  select * into v_cycle from public.reporting_cycles where id=v_snapshot.reporting_cycle_id for update;
  if not found or v_cycle.status<>'closed' then raise exception 'Reporting cycle must remain closed during snapshot finalization'; end if;

  if not exists(select 1 from public.snapshot_config_links where portfolio_snapshot_id=v_snapshot.id and scope_type='global') then
    raise exception 'Snapshot is missing its global configuration version link';
  end if;
  select count(*) into v_expected_projects from public.projects p
  where p.created_at<=v_cycle.cutoff_at;
  select count(*) into v_actual_projects from public.project_snapshots where portfolio_snapshot_id=v_snapshot.id;
  if v_expected_projects<>v_actual_projects then
    raise exception 'Snapshot project count mismatch: expected %, captured %',v_expected_projects,v_actual_projects;
  end if;

  update public.portfolio_snapshots set snapshot_status='finalized' where id=v_snapshot.id;
  update public.reporting_cycles set status='snapshotted' where id=v_cycle.id;

  insert into private.security_audit_events(actor_user_id,action,entity_schema,entity_table,entity_id,reason,after_data)
  values(p_actor_user_id,'portfolio_snapshot_finalized','public','portfolio_snapshots',v_snapshot.id,
    'System finalized immutable weekly reporting snapshot',
    jsonb_build_object('reporting_cycle_id',v_cycle.id,'project_count',v_actual_projects,'kpi_calculation_status','not_implemented'));

  return jsonb_build_object('portfolio_snapshot_id',v_snapshot.id,'reporting_cycle_id',v_cycle.id,
    'snapshot_status','finalized','project_count',v_actual_projects,'kpi_calculation_status','not_implemented');
end;
$function$
;
commit;