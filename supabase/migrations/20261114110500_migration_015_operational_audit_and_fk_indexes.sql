begin;

-- Index every operational foreign key flagged by the Supabase performance advisor.
create index contract_deliverables_contract_project_fk_idx on public.contract_deliverables(contract_id,project_id);
create index contract_deliverables_accepted_by_fk_idx on public.contract_deliverables(accepted_by);
create index contract_deliverables_created_by_fk_idx on public.contract_deliverables(created_by);
create index invoice_allocations_cash_project_fk_idx on public.invoice_payment_allocations(cash_transaction_id,project_id);
create index invoice_allocations_invoice_project_fk_idx on public.invoice_payment_allocations(invoice_id,project_id);
create index invoice_allocations_created_by_fk_idx on public.invoice_payment_allocations(created_by);
create index project_activities_created_by_fk_idx on public.project_activities(created_by);
create index project_activities_milestone_project_fk_idx on public.project_activities(milestone_id,project_id);
create index project_activities_verified_by_fk_idx on public.project_activities(verified_by);
create index activity_dependencies_created_by_fk_idx on public.project_activity_dependencies(created_by);
create index activity_dependencies_predecessor_project_fk_idx on public.project_activity_dependencies(predecessor_activity_id,project_id);
create index activity_dependencies_successor_project_fk_idx on public.project_activity_dependencies(successor_activity_id,project_id);
create index cash_transactions_created_by_fk_idx on public.project_cash_transactions(created_by);
create index project_contracts_created_by_fk_idx on public.project_contracts(created_by);
create index project_financial_terms_created_by_fk_idx on public.project_financial_terms(created_by);
create index project_invoices_contract_project_fk_idx on public.project_invoices(contract_id,project_id);
create index project_invoices_created_by_fk_idx on public.project_invoices(created_by);
create index project_licenses_created_by_fk_idx on public.project_licenses(created_by);
create index project_licenses_owner_fk_idx on public.project_licenses(owner_user_id);
create index project_decisions_created_by_fk_idx on public.project_management_decisions(created_by);
create index project_decisions_decided_by_fk_idx on public.project_management_decisions(decided_by);
create index project_decisions_owner_fk_idx on public.project_management_decisions(owner_user_id);
create index project_decisions_requested_by_fk_idx on public.project_management_decisions(requested_by);
create index project_milestones_created_by_fk_idx on public.project_milestones(created_by);
create index project_milestones_owner_fk_idx on public.project_milestones(owner_user_id);
create index project_risks_created_by_fk_idx on public.project_risks(created_by);
create index project_risks_owner_fk_idx on public.project_risks(owner_user_id);
create index project_weekly_updates_created_by_fk_idx on public.project_weekly_updates(created_by);
create index project_weekly_updates_reviewed_by_fk_idx on public.project_weekly_updates(reviewed_by);
create index project_weekly_updates_submitted_by_fk_idx on public.project_weekly_updates(submitted_by);

-- Audit operational record changes in the private schema. SECURITY DEFINER is
-- confined to this trigger function, with a fixed search_path and no API grant.
create or replace function private.audit_project_operational_change()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_row jsonb;
  v_before jsonb;
  v_after jsonb;
  v_id uuid;
  v_project_id uuid;
  v_action text;
begin
  if tg_op='INSERT' then
    v_row:=to_jsonb(new);
    v_after:=v_row;
    v_id:=(v_row->>'id')::uuid;
    v_project_id:=(v_row->>'project_id')::uuid;
    v_action:='insert';
  elsif tg_op='UPDATE' then
    v_before:=to_jsonb(old);
    v_after:=to_jsonb(new);
    v_id:=(v_after->>'id')::uuid;
    v_project_id:=(v_after->>'project_id')::uuid;
    v_action:='update';
  else
    v_before:=to_jsonb(old);
    v_id:=(v_before->>'id')::uuid;
    v_project_id:=(v_before->>'project_id')::uuid;
    v_action:='delete';
  end if;

  insert into private.security_audit_events(
    actor_user_id,action,entity_schema,entity_table,entity_id,project_id,
    reason,before_data,after_data
  ) values (
    auth.uid(),'operational_record_'||v_action,'public',tg_table_name,
    v_id,v_project_id,null,v_before,v_after
  );

  if tg_op='DELETE' then return old; end if;
  return new;
end;
$function$;
revoke all on function private.audit_project_operational_change() from public,anon,authenticated,service_role;

do $audit_triggers$
declare t text;
begin
  foreach t in array array[
    'project_contracts','contract_deliverables','project_financial_terms',
    'project_milestones','project_activities','project_activity_dependencies',
    'project_invoices','project_cash_transactions','invoice_payment_allocations',
    'project_risks','project_licenses','project_weekly_updates',
    'project_management_decisions'
  ] loop
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function private.audit_project_operational_change()',t||'_audit_changes',t);
    execute format('revoke delete on public.%I from authenticated',t);
  end loop;
end;
$audit_triggers$;

commit;