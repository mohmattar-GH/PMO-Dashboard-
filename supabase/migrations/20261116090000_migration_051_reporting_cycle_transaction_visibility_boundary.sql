
-- Migration 051: capture immutable transaction-visibility boundary when a cycle closes.
-- Scheduled cutoff_at is retained as reporting metadata; closure_snapshot is authoritative
-- for the exact committed database state used by the weekly snapshot.

alter table public.reporting_cycles
  add column if not exists closed_at timestamptz,
  add column if not exists closure_snapshot text;

alter table public.reporting_cycles
  add constraint reporting_cycles_closure_boundary_pair_chk
  check ((closed_at is null) = (closure_snapshot is null));

alter table public.reporting_cycles
  add constraint reporting_cycles_closed_requires_boundary_chk
  check (status not in ('closed','snapshotted') or (closed_at is not null and closure_snapshot is not null));

create or replace function private.guard_reporting_cycle_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'DELETE' then
    if exists (select 1 from public.portfolio_snapshots ps where ps.reporting_cycle_id = old.id) then
      raise exception 'A reporting cycle linked to a snapshot cannot be deleted';
    end if;
    return old;
  end if;

  if old.closed_at is not null and
     (new.closed_at is distinct from old.closed_at or new.closure_snapshot is distinct from old.closure_snapshot) then
    raise exception 'A reporting cycle closure boundary is immutable';
  end if;

  if new.status = 'closed' and old.status <> 'closed' then
    if old.status in ('snapshotted','cancelled') then
      raise exception 'A snapshotted or cancelled reporting cycle cannot be closed';
    end if;
    new.closed_at := clock_timestamp();
    new.closure_snapshot := pg_current_snapshot()::text;
  elsif new.status = 'snapshotted' then
    if old.status <> 'closed' or old.closed_at is null or old.closure_snapshot is null then
      raise exception 'Only a closed cycle with a captured visibility boundary can be snapshotted';
    end if;
  elsif old.status = 'closed' and new.status <> 'closed' then
    raise exception 'A closed reporting cycle can only transition to snapshotted';
  end if;

  if exists (select 1 from public.portfolio_snapshots ps where ps.reporting_cycle_id = old.id) then
    if old.status <> 'closed' or new.status <> 'snapshotted'
       or (to_jsonb(new) - 'status' - 'updated_at') <> (to_jsonb(old) - 'status' - 'updated_at') then
      raise exception 'A snapshotted reporting cycle is immutable; only closed-to-snapshotted is permitted';
    end if;
  end if;

  new.updated_at := clock_timestamp();
  return new;
end;
$function$;

create or replace function private.guard_reporting_cycle_insert()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.status in ('closed','snapshotted') or new.closed_at is not null or new.closure_snapshot is not null then
    raise exception 'A reporting cycle must be created before it can be closed';
  end if;
  return new;
end;
$function$;

drop trigger if exists reporting_cycles_guard_insert on public.reporting_cycles;
create trigger reporting_cycles_guard_insert
before insert on public.reporting_cycles
for each row execute function private.guard_reporting_cycle_insert();

-- The history reader uses the captured PostgreSQL snapshot when the KPI calculation
-- sets the transaction-local app.reporting_visibility_snapshot setting.
do $migration$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('private.kpi_source_has_post_cutoff_changes_v1(uuid,text,timestamp with time zone)'::regprocedure);
  v_def := replace(v_def,
    'declare v_table text; v_coverage timestamptz;',
    'declare v_table text; v_coverage timestamptz; v_visibility_snapshot text; v_visibility_boundary timestamptz;');
  v_def := replace(v_def,
    'begin' || E'\n v_table:=case p_source',
    'begin' || E'\n v_visibility_snapshot:=nullif(current_setting(''app.reporting_visibility_snapshot'',true),'''');' ||
    E'\n v_visibility_boundary:=nullif(current_setting(''app.reporting_visibility_closed_at'',true),'''')::timestamptz;' ||
    E'\n v_table:=case p_source');
  v_def := replace(v_def,
    'return v_coverage is null or p_cutoff<v_coverage;',
    'if v_visibility_snapshot is not null then' || E'\n  return v_coverage is null or v_visibility_boundary is null or v_visibility_boundary<v_coverage;' ||
    E'\n end if;' || E'\n return v_coverage is null or p_cutoff<v_coverage;');
  if position('v_visibility_snapshot' in v_def)=0 or position('v_visibility_boundary' in v_def)=0 then
    raise exception 'Could not safely patch KPI history coverage resolver';
  end if;
  execute v_def;

  v_def := pg_get_functiondef('private.read_kpi_source_rows_v1(uuid,text,timestamp with time zone)'::regprocedure);
  v_def := replace(v_def,
    'declare v_table text; v_rows jsonb;',
    'declare v_table text; v_rows jsonb; v_visibility_snapshot text; v_visibility_boundary timestamptz;');
  v_def := replace(v_def,
    'begin' || E'\n if p_project_id is null',
    'begin' || E'\n v_visibility_snapshot:=nullif(current_setting(''app.reporting_visibility_snapshot'',true),'''');' ||
    E'\n v_visibility_boundary:=nullif(current_setting(''app.reporting_visibility_closed_at'',true),'''')::timestamptz;' ||
    E'\n if p_project_id is null');
  v_def := replace(v_def,
    'and h.recorded_at<=p_cutoff',
    'and ((v_visibility_snapshot is not null and v_visibility_boundary is not null' ||
      ' and pg_visible_in_snapshot(h.transaction_id::xid8,v_visibility_snapshot::pg_snapshot)' ||
      ' and h.recorded_at<=v_visibility_boundary)' ||
      ' or (v_visibility_snapshot is null and h.recorded_at<=p_cutoff))');
  if position('pg_visible_in_snapshot' in v_def)=0 then
    raise exception 'Could not safely patch KPI source history reader';
  end if;
  execute v_def;

  -- Bind each KPI calculation to the reporting cycle's immutable closure boundary.
  v_def := pg_get_functiondef('private.calculate_project_snapshot_kpis_v1(uuid)'::regprocedure);
  v_def := replace(v_def,
    'select * into v_cycle from public.reporting_cycles where id=v_portfolio.reporting_cycle_id;',
    'select * into v_cycle from public.reporting_cycles where id=v_portfolio.reporting_cycle_id;' ||
    E'\n if v_cycle.closed_at is null or v_cycle.closure_snapshot is null then' ||
    E'\n  raise exception ''Reporting cycle has no captured transaction-visibility boundary'';' ||
    E'\n end if;' ||
    E'\n perform set_config(''app.reporting_visibility_snapshot'',v_cycle.closure_snapshot,true);' ||
    E'\n perform set_config(''app.reporting_visibility_closed_at'',v_cycle.closed_at::text,true);');
  v_def := replace(v_def,
    'return jsonb_build_object(''project_snapshot_id'',v_ps.id',
    'perform set_config(''app.reporting_visibility_snapshot'','''',true);' ||
    E'\n perform set_config(''app.reporting_visibility_closed_at'','''',true);' ||
    E'\n return jsonb_build_object(''project_snapshot_id'',v_ps.id');
  if position('app.reporting_visibility_snapshot' in v_def)=0 then
    raise exception 'Could not safely bind KPI calculation to closure snapshot';
  end if;
  execute v_def;
end;
$migration$;

-- Snapshot generation must only run against cycles closed with the new boundary.
do $migration$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.build_weekly_portfolio_snapshot(uuid,uuid)'::regprocedure);
  v_def := replace(v_def,
    'if v_cycle.status<>''closed'' then raise exception ''Only closed reporting cycles can be snapshotted''; end if;',
    'if v_cycle.status<>''closed'' then raise exception ''Only closed reporting cycles can be snapshotted''; end if;' ||
    E'\n  if v_cycle.closed_at is null or v_cycle.closure_snapshot is null then' ||
    E'\n    raise exception ''Reporting cycle has no captured transaction-visibility boundary; close it again through the guarded workflow'';' ||
    E'\n  end if;');
  v_def := replace(v_def,
    'v.created_at<=v_cycle.cutoff_at',
    'v.created_at<=v_cycle.closed_at');
  v_def := replace(v_def,
    'v.published_at<=v_cycle.cutoff_at',
    'v.published_at<=v_cycle.closed_at');
  v_def := replace(v_def,
    'v.effective_from<=v_cycle.cutoff_at',
    'v.effective_from<=v_cycle.closed_at');
  v_def := replace(v_def,
    'v.effective_to>v_cycle.cutoff_at',
    'v.effective_to>v_cycle.closed_at');
  v_def := replace(v_def,
    'p.created_at<=v_cycle.cutoff_at',
    'p.created_at<=v_cycle.closed_at');
  v_def := replace(v_def,
    'and exists(select 1 from public.projects p where p.id=s.project_id and p.created_at<=v_cycle.closed_at)',
    'and exists(select 1 from (' ||
      'select distinct on (h.record_id) h.record_id,h.operation ' ||
      'from private.operational_record_history h ' ||
      'where h.source_table=''projects'' ' ||
      'and pg_visible_in_snapshot(h.transaction_id::xid8,v_cycle.closure_snapshot::pg_snapshot) ' ||
      'order by h.record_id,h.recorded_at desc,h.history_id desc' ||
      ') historical_project where historical_project.record_id=s.project_id and historical_project.operation<>''delete'' )');
  v_def := replace(v_def,
    'v_watermark timestamptz := clock_timestamp();',
    'v_watermark timestamptz;');
  v_def := replace(v_def,
    'if v_cycle.cutoff_at>now() then raise exception ''Reporting cutoff has not been reached''; end if;',
    'if v_cycle.cutoff_at>v_cycle.closed_at then raise exception ''Scheduled reporting cutoff is later than the actual closure boundary''; end if;' ||
    E'\n  v_watermark:=v_cycle.closed_at;');
  v_def := replace(v_def,
    'select v_snapshot_id,p.id,p.updated_at,null,null,',
    'select v_snapshot_id,p.id,(ph.row_data->>''updated_at'')::timestamptz,null,null,');
  v_def := replace(v_def,
    '''project_record'',to_jsonb(p),',
    '''project_record'',ph.row_data,');
  v_def := replace(v_def,
    '''source_state_as_of_cutoff'',(p.updated_at is null or p.updated_at<=v_cycle.cutoff_at),',
    '''source_state_as_of_cutoff'',true,' ||
    E'\n      ''source_state_as_of_closure'',true,');
  v_def := replace(v_def,
    'from public.projects p' || E'\n  where p.created_at<=v_cycle.closed_at;',
    'from (' ||
    E'\n    select distinct on (h.record_id) h.record_id,h.operation,h.row_data' ||
    E'\n    from private.operational_record_history h' ||
    E'\n    where h.source_table=''projects''' ||
    E'\n      and pg_visible_in_snapshot(h.transaction_id::xid8,v_cycle.closure_snapshot::pg_snapshot)' ||
    E'\n    order by h.record_id,h.recorded_at desc,h.history_id desc' ||
    E'\n  ) ph' ||
    E'\n  join public.projects p on p.id=ph.record_id' ||
    E'\n  where ph.operation<>''delete'';');
  if position('closure_snapshot' in v_def)=0 or position('ph.row_data' in v_def)=0 then
    raise exception 'Could not safely patch weekly snapshot builder for closure visibility';
  end if;
  execute v_def;

  v_def := pg_get_functiondef('public.finalize_weekly_portfolio_snapshot(uuid,uuid)'::regprocedure);
  v_def := replace(v_def,
    'if not found or v_cycle.status<>''closed'' then raise exception ''Reporting cycle must remain closed during snapshot finalization''; end if;',
    'if not found or v_cycle.status<>''closed'' then raise exception ''Reporting cycle must remain closed during snapshot finalization''; end if;' ||
    E'\n  if v_cycle.closed_at is null or v_cycle.closure_snapshot is null then raise exception ''Reporting cycle closure boundary is missing''; end if;');
  v_def := replace(v_def,
    'select count(*) into v_expected_projects from public.projects p' || E'\n  where p.created_at<=v_cycle.cutoff_at;',
    'select count(*) into v_expected_projects from (' ||
    E'\n    select distinct on (h.record_id) h.record_id,h.operation' ||
    E'\n    from private.operational_record_history h' ||
    E'\n    where h.source_table=''projects''' ||
    E'\n      and pg_visible_in_snapshot(h.transaction_id::xid8,v_cycle.closure_snapshot::pg_snapshot)' ||
    E'\n    order by h.record_id,h.recorded_at desc,h.history_id desc' ||
    E'\n  ) historical_projects where operation<>''delete'';');
  if position('historical_projects' in v_def)=0 then
    raise exception 'Could not safely patch snapshot finalizer project count';
  end if;
  execute v_def;
end;
$migration$;

comment on column public.reporting_cycles.cutoff_at is
  'Configured/scheduled reporting cutoff timestamp. Preserved as reporting metadata; the immutable closure transaction snapshot is authoritative for reconstructing committed source state.';
comment on column public.reporting_cycles.closed_at is
  'Database timestamp captured when the reporting cycle transitions to closed.';
comment on column public.reporting_cycles.closure_snapshot is
  'Serialized PostgreSQL transaction visibility snapshot captured atomically when the cycle closes. Used to include only transactions committed and visible at closure.';
