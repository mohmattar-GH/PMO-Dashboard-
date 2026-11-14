begin;
create or replace function private.reject_snapshot_child_mutation()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
 v_parent_status text;
begin
 if tg_table_name='project_snapshots'
    and tg_op='UPDATE'
    and current_user='service_role'
    and pg_catalog.pg_trigger_depth()>=2
    and new.portfolio_snapshot_id=old.portfolio_snapshot_id
    and new.project_id=old.project_id
    and (to_jsonb(new)-'snapshot_payload')=(to_jsonb(old)-'snapshot_payload')
    and new.snapshot_payload @> old.snapshot_payload then
  select snapshot_status into v_parent_status
  from public.portfolio_snapshots where id=new.portfolio_snapshot_id;
  if v_parent_status='building' then return new; end if;
 end if;
 raise exception 'Snapshot records are immutable; create a replacement snapshot instead';
end;
$function$;

create or replace function private.guard_portfolio_snapshot_mutation()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
 if tg_op='DELETE' then
  raise exception 'Portfolio snapshots are append-only';
 end if;
 if old.snapshot_status='building'
    and new.snapshot_status='building'
    and current_user='service_role'
    and (to_jsonb(new)-'portfolio_summary')=(to_jsonb(old)-'portfolio_summary')
    and new.portfolio_summary @> old.portfolio_summary then
  return new;
 end if;
 if old.snapshot_status='building'
    and new.snapshot_status='finalized'
    and (to_jsonb(new)-'snapshot_status')=(to_jsonb(old)-'snapshot_status') then
  return new;
 end if;
 raise exception 'Only trusted build-time summary enrichment and the building-to-finalized transition are permitted';
end;
$function$;
commit;