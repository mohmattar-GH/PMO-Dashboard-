begin;
create table private.operational_history_coverage (
 source_table text primary key,
 coverage_started_at timestamptz not null,
 backfilled_rows bigint not null default 0,
 status text not null default 'active' check (status in ('active','paused'))
);
create table private.operational_record_history (
 history_id bigint generated always as identity primary key,
 source_table text not null check (source_table = any(array[
  'projects','project_activities','project_milestones','project_invoices','project_cash_transactions',
  'invoice_payment_allocations','project_risks','project_licenses','project_weekly_updates',
  'project_management_decisions','contract_deliverables','project_contracts',
  'project_financial_terms','project_contract_variations'
 ])),
 project_id uuid not null,
 record_id uuid not null,
 recorded_at timestamptz not null,
 operation text not null check (operation in ('baseline','insert','update','delete')),
 transaction_id text not null,
 actor_user_id uuid,
 row_data jsonb not null check (jsonb_typeof(row_data)='object')
);
create index operational_record_history_asof_idx
 on private.operational_record_history(source_table,project_id,record_id,recorded_at desc,history_id desc);
create index operational_record_history_project_time_idx
 on private.operational_record_history(project_id,recorded_at desc);

alter table private.operational_history_coverage enable row level security;
alter table private.operational_record_history enable row level security;
revoke all on private.operational_history_coverage,private.operational_record_history from public,anon,authenticated;
grant select on private.operational_history_coverage,private.operational_record_history to service_role;

create or replace function private.capture_operational_record_history()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
declare
 v_row jsonb;
 v_record_id uuid;
 v_project_id uuid;
 v_operation text;
begin
 if tg_table_schema<>'public' or tg_table_name<>all(array[
  'projects','project_activities','project_milestones','project_invoices','project_cash_transactions',
  'invoice_payment_allocations','project_risks','project_licenses','project_weekly_updates',
  'project_management_decisions','contract_deliverables','project_contracts',
  'project_financial_terms','project_contract_variations'
 ]) then
  raise exception 'Operational history trigger invoked for an unsupported source table';
 end if;
 if tg_op='DELETE' then
  v_row:=to_jsonb(old);
  v_operation:='delete';
 else
  v_row:=to_jsonb(new);
  v_operation:=lower(tg_op);
 end if;
 v_record_id:=(v_row->>'id')::uuid;
 if tg_table_name='projects' then v_project_id:=v_record_id;
 else v_project_id:=(v_row->>'project_id')::uuid; end if;
 if v_record_id is null or v_project_id is null then
  raise exception 'Operational history requires record and project identifiers';
 end if;
 insert into private.operational_record_history(
  source_table,project_id,record_id,recorded_at,operation,transaction_id,actor_user_id,row_data
 ) values (
  tg_table_name,v_project_id,v_record_id,clock_timestamp(),v_operation,
  pg_current_xact_id()::text,auth.uid(),v_row
 );
 if tg_op='DELETE' then return old; end if;
 return new;
end;
$function$;

revoke all on function private.capture_operational_record_history() from public,anon,authenticated,service_role;

do $history$
declare
 v_table text;
 v_started_at timestamptz:=clock_timestamp();
 v_rows bigint;
 v_tables text[]:=array[
  'projects','project_activities','project_milestones','project_invoices','project_cash_transactions',
  'invoice_payment_allocations','project_risks','project_licenses','project_weekly_updates',
  'project_management_decisions','contract_deliverables','project_contracts',
  'project_financial_terms','project_contract_variations'
 ];
begin
 foreach v_table in array v_tables loop
  insert into private.operational_history_coverage(source_table,coverage_started_at,status)
  values(v_table,v_started_at,'active');
  if v_table='projects' then
   execute format(
    'insert into private.operational_record_history(source_table,project_id,record_id,recorded_at,operation,transaction_id,actor_user_id,row_data)
     select %L,t.id,t.id,$1,''baseline'',pg_current_xact_id()::text,null,to_jsonb(t) from public.%I t',
    v_table,v_table
   ) using v_started_at;
  else
   execute format(
    'insert into private.operational_record_history(source_table,project_id,record_id,recorded_at,operation,transaction_id,actor_user_id,row_data)
     select %L,t.project_id,t.id,$1,''baseline'',pg_current_xact_id()::text,null,to_jsonb(t) from public.%I t',
    v_table,v_table
   ) using v_started_at;
  end if;
  get diagnostics v_rows=row_count;
  update private.operational_history_coverage set backfilled_rows=v_rows where source_table=v_table;
  execute format(
   'create trigger %I after insert or update or delete on public.%I for each row execute function private.capture_operational_record_history()',
   'capture_history_'||v_table,v_table
  );
 end loop;
end;
$history$;

create or replace function private.kpi_source_has_post_cutoff_changes_v1(
 p_project_id uuid,p_source text,p_cutoff timestamptz
)
returns boolean
language plpgsql
stable
set search_path=''
as $function$
declare v_table text; v_coverage timestamptz;
begin
 v_table:=case p_source
  when 'projects' then 'projects'
  when 'activities' then 'project_activities'
  when 'milestones' then 'project_milestones'
  when 'invoices' then 'project_invoices'
  when 'cash_transactions' then 'project_cash_transactions'
  when 'payment_allocations' then 'invoice_payment_allocations'
  when 'risks' then 'project_risks'
  when 'licenses' then 'project_licenses'
  when 'weekly_updates' then 'project_weekly_updates'
  when 'management_decisions' then 'project_management_decisions'
  when 'contract_deliverables' then 'contract_deliverables'
  when 'contracts' then 'project_contracts'
  when 'financial_terms' then 'project_financial_terms'
  else null end;
 if v_table is null then raise exception 'Unsupported KPI source: %',p_source using errcode='22023'; end if;
 select coverage_started_at into v_coverage from private.operational_history_coverage
 where source_table=v_table and status='active';
 return v_coverage is null or p_cutoff<v_coverage;
end;
$function$;

create or replace function private.read_kpi_source_rows_v1(
 p_project_id uuid,p_source text,p_cutoff timestamptz
)
returns jsonb
language plpgsql
stable
set search_path=''
as $function$
declare v_table text; v_rows jsonb;
begin
 if p_project_id is null or p_cutoff is null then
  raise exception 'Project and source cutoff are required' using errcode='22023';
 end if;
 v_table:=case p_source
  when 'projects' then 'projects'
  when 'activities' then 'project_activities'
  when 'milestones' then 'project_milestones'
  when 'invoices' then 'project_invoices'
  when 'cash_transactions' then 'project_cash_transactions'
  when 'payment_allocations' then 'invoice_payment_allocations'
  when 'risks' then 'project_risks'
  when 'licenses' then 'project_licenses'
  when 'weekly_updates' then 'project_weekly_updates'
  when 'management_decisions' then 'project_management_decisions'
  when 'contract_deliverables' then 'contract_deliverables'
  when 'contracts' then 'project_contracts'
  when 'financial_terms' then 'project_financial_terms'
  else null end;
 if v_table is null then raise exception 'Unsupported KPI source: %',p_source using errcode='22023'; end if;
 if private.kpi_source_has_post_cutoff_changes_v1(p_project_id,p_source,p_cutoff) then
  raise exception 'Historical source coverage does not include cutoff % for %',p_cutoff,p_source using errcode='22023';
 end if;
 select coalesce(jsonb_agg(latest.row_data order by latest.record_id),'[]'::jsonb)
 into v_rows
 from (
  select distinct on (h.record_id) h.record_id,h.operation,h.row_data
  from private.operational_record_history h
  where h.source_table=v_table and h.project_id=p_project_id and h.recorded_at<=p_cutoff
  order by h.record_id,h.recorded_at desc,h.history_id desc
 ) latest
 where latest.operation<>'delete';
 return v_rows;
end;
$function$;

revoke all on function private.kpi_source_has_post_cutoff_changes_v1(uuid,text,timestamptz) from public,anon,authenticated;
revoke all on function private.read_kpi_source_rows_v1(uuid,text,timestamptz) from public,anon,authenticated;
grant execute on function private.kpi_source_has_post_cutoff_changes_v1(uuid,text,timestamptz) to service_role;
grant execute on function private.read_kpi_source_rows_v1(uuid,text,timestamptz) to service_role;

comment on table private.operational_record_history is
 'Append-only row-state history for operational KPI sources. Each record captures a full row image at insert, update, delete, or baseline time.';
comment on table private.operational_history_coverage is
 'Earliest reliable historical cutoff for each operational source; cutoffs before coverage are explicitly not reconstructable.';
commit;