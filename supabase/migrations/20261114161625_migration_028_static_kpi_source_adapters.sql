-- Reconstructed from the live definitions applied as migration 028 (version 20261114161625).
-- This is the original source-adapter layer before migration 030 extended the source registry.
begin;
CREATE OR REPLACE FUNCTION private.kpi_source_field_allowed_v1(p_source text, p_field text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 select case p_source
  when 'projects' then p_field=any(array['lifecycle_status','start_date','target_end_date','currency_code'])
  when 'activities' then p_field=any(array['progress_percent','weight','baseline_start_date','baseline_due_date','approved_revised_start_date','approved_revised_due_date','forecast_start_date','forecast_due_date','actual_start_date','actual_due_date','status','verification_status'])
  when 'milestones' then p_field=any(array['progress_percent','weight','baseline_start_date','baseline_due_date','approved_revised_start_date','approved_revised_due_date','forecast_start_date','forecast_due_date','actual_start_date','actual_due_date','status','is_critical'])
  when 'invoices' then p_field=any(array['total_amount','subtotal_amount','tax_amount','retention_amount','issue_date','submission_date','due_date','status','currency_code'])
  when 'cash_transactions' then p_field=any(array['amount','transaction_date','transaction_type','status','currency_code'])
  when 'risks' then p_field=any(array['probability_level','impact_level','risk_score','target_resolution_date','resolved_date','status','trend','is_escalated'])
  when 'licenses' then p_field=any(array['quantity','renewal_cost','expiry_date','renewal_notice_date','status'])
  when 'weekly_updates' then p_field=any(array['overall_progress_percent','reported_health_status','status','week_start','week_end'])
  when 'management_decisions' then p_field=any(array['required_by_date','status','priority','decision_type'])
  when 'contract_deliverables' then p_field=any(array['due_date','status'])
  when 'contracts' then p_field=any(array['original_contract_value','signed_date','commencement_date','contractual_end_date','status','currency_code'])
  when 'financial_terms' then p_field=any(array['original_contract_value','approved_variations','revised_contract_value','tax_rate','retention_rate','currency_code'])
  else false end;
$function$

CREATE OR REPLACE FUNCTION private.read_kpi_source_rows_v1(p_project_id uuid, p_source text, p_cutoff timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare v_rows jsonb;
begin
 if p_project_id is null or p_cutoff is null then
  raise exception 'Project and source cutoff are required' using errcode='22023';
 end if;
 case p_source
  when 'projects' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.projects t
   where t.id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  when 'activities' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_activities t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  when 'milestones' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_milestones t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  when 'invoices' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_invoices t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  when 'cash_transactions' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_cash_transactions t
   where t.project_id=p_project_id and t.created_at<=p_cutoff;
  when 'risks' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_risks t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  when 'licenses' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_licenses t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  when 'weekly_updates' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_weekly_updates t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff
     and (t.submitted_at is null or t.submitted_at<=p_cutoff);
  when 'management_decisions' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_management_decisions t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  when 'contract_deliverables' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.contract_deliverables t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  when 'contracts' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_contracts t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  when 'financial_terms' then
   select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_rows from public.project_financial_terms t
   where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at<=p_cutoff;
  else
   raise exception 'Unsupported KPI source: %',p_source using errcode='22023';
 end case;
 return v_rows;
end;
$function$

CREATE OR REPLACE FUNCTION private.kpi_source_has_post_cutoff_changes_v1(p_project_id uuid, p_source text, p_cutoff timestamp with time zone)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare v_changed boolean:=false;
begin
 case p_source
  when 'projects' then select exists(select 1 from public.projects t where t.id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'activities' then select exists(select 1 from public.project_activities t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'milestones' then select exists(select 1 from public.project_milestones t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'invoices' then select exists(select 1 from public.project_invoices t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'cash_transactions' then v_changed:=false;
  when 'risks' then select exists(select 1 from public.project_risks t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'licenses' then select exists(select 1 from public.project_licenses t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'weekly_updates' then select exists(select 1 from public.project_weekly_updates t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'management_decisions' then select exists(select 1 from public.project_management_decisions t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'contract_deliverables' then select exists(select 1 from public.contract_deliverables t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'contracts' then select exists(select 1 from public.project_contracts t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  when 'financial_terms' then select exists(select 1 from public.project_financial_terms t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.updated_at>p_cutoff) into v_changed;
  else raise exception 'Unsupported KPI source: %',p_source using errcode='22023';
 end case;
 return v_changed;
end;
$function$

revoke all on function private.kpi_source_field_allowed_v1(text,text) from public,anon,authenticated;
revoke all on function private.read_kpi_source_rows_v1(uuid,text,timestamptz) from public,anon,authenticated;
revoke all on function private.kpi_source_has_post_cutoff_changes_v1(uuid,text,timestamptz) from public,anon,authenticated;
grant execute on function private.kpi_source_field_allowed_v1(text,text) to service_role;
grant execute on function private.read_kpi_source_rows_v1(uuid,text,timestamptz) to service_role;
grant execute on function private.kpi_source_has_post_cutoff_changes_v1(uuid,text,timestamptz) to service_role;
commit;
