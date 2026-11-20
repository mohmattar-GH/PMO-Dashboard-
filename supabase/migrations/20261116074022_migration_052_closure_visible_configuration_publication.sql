
-- Migration 052: transaction-visible publication and closure-accurate snapshot metadata.

alter table public.reporting_configuration_versions
  add column published_transaction_id xid8;

create or replace function private.guard_reporting_version_header()
returns trigger
language plpgsql
set search_path = 'pg_catalog', 'public'
as $function$
begin
 if old.status='published' then
   if tg_op='UPDATE' and old.status='published' and new.status='superseded'
      and (to_jsonb(new)-'status')=(to_jsonb(old)-'status') then
     return new;
   end if;
   raise exception 'Published reporting configuration versions are immutable except for superseding';
 end if;
 if tg_op='DELETE' then return old; end if;
 if tg_op='UPDATE' and new.status='published' and old.status<>'published' then
   new.published_transaction_id:=pg_current_xact_id();
 end if;
 return new;
end;
$function$;

alter table public.reporting_configuration_versions
  add constraint reporting_configuration_versions_published_xid_required
  check (status<>'published' or published_transaction_id is not null);

do $migration$
declare
  v_def text;
begin
  v_def:=pg_get_functiondef('public.build_weekly_portfolio_snapshot(uuid,uuid)'::regprocedure);

  v_def:=replace(v_def,
    'where s.scope_type=''global'' and v.status=''published''',
    'where s.scope_type=''global'' and v.status=''published''' ||
      ' and v.published_transaction_id is not null' ||
      ' and pg_visible_in_snapshot(v.published_transaction_id,v_cycle.closure_snapshot::pg_snapshot)');
  v_def:=replace(v_def,
    'where s.scope_type=''project'' and v.status=''published''',
    'where s.scope_type=''project'' and v.status=''published''' ||
      ' and v.published_transaction_id is not null' ||
      ' and pg_visible_in_snapshot(v.published_transaction_id,v_cycle.closure_snapshot::pg_snapshot)');

  v_def:=replace(v_def,
    '''timezone'',v_cycle.timezone,',
    '''timezone'',v_cycle.timezone,' ||
    E'\n      ''scheduled_cutoff_at'',v_cycle.cutoff_at,' ||
    E'\n      ''actual_closed_at'',v_cycle.closed_at,' ||
    E'\n      ''visibility_boundary_type'',''transaction_snapshot_at_closure'',');
  v_def:=replace(v_def,
    '''source_state_as_of_cutoff'',true,',
    '''source_state_as_of_cutoff'',(v_cycle.closed_at=v_cycle.cutoff_at),');

  v_def:=replace(v_def,
    'select count(*) into v_post_cutoff_count from public.projects p' ||
      E'\n  where p.created_at<=v_cycle.closed_at and p.updated_at>v_cycle.cutoff_at;',
    'select count(*) into v_post_cutoff_count from (' ||
      E'\n    select distinct on (h.record_id) h.record_id,h.operation,h.row_data' ||
      E'\n    from private.operational_record_history h' ||
      E'\n    where h.source_table=''projects''' ||
      E'\n      and pg_visible_in_snapshot(h.transaction_id::xid8,v_cycle.closure_snapshot::pg_snapshot)' ||
      E'\n    order by h.record_id,h.recorded_at desc,h.history_id desc' ||
      E'\n  ) historical_projects' ||
      E'\n  where operation<>''delete'' and (row_data->>''updated_at'')::timestamptz>v_cycle.cutoff_at;');

  v_def:=replace(v_def,
    '''projects_changed_after_cutoff'',v_post_cutoff_count,',
    '''projects_changed_after_scheduled_cutoff'',v_post_cutoff_count,');
  v_def:=replace(v_def,
    '''source_consistency_status'',case when v_post_cutoff_count=0 then ''as_of_cutoff'' else ''contains_post_cutoff_source_changes'' end,',
    '''source_consistency_status'',''as_of_closure_visibility'',');
  v_def:=replace(v_def,
    '''projects_changed_after_cutoff'',v_post_cutoff_count',
    '''projects_changed_after_scheduled_cutoff'',v_post_cutoff_count');

  if position('published_transaction_id' in v_def)=0
     or position('transaction_snapshot_at_closure' in v_def)=0
     or position('projects_changed_after_scheduled_cutoff' in v_def)=0
     or position('historical_projects' in v_def)=0 then
    raise exception 'Could not safely patch closure-visible configuration and snapshot metadata';
  end if;
  execute v_def;
end;
$migration$;

comment on column public.reporting_configuration_versions.published_transaction_id is
  'PostgreSQL transaction ID of the publication transition; snapshots include a configuration version only when this transaction was visible at the cycle closure snapshot.';

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
