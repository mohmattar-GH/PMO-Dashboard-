begin;

create or replace function private.kpi_source_field_allowed_v1(p_source text,p_field text)
returns boolean
language sql
immutable
set search_path=''
as $$
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
$$;

create or replace function private.read_kpi_source_rows_v1(
 p_project_id uuid,p_source text,p_cutoff timestamptz
)
returns jsonb
language plpgsql
stable
security invoker
set search_path=''
as $$
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
$$;

create or replace function private.resolve_kpi_inputs_v1(
 p_project_id uuid,p_cutoff timestamptz,p_template_code text,p_parameters jsonb,p_source_mapping jsonb
)
returns jsonb
language plpgsql
stable
security invoker
set search_path=''
as $$
declare
 v_inputs jsonb:='{}'::jsonb;
 v_lineage jsonb:='[]'::jsonb;
 v_mapping jsonb;
 v_spec jsonb;
 v_source text;
 v_field text;
 v_aggregate text;
 v_rows jsonb;
 v_row jsonb;
 v_count integer;
 v_values numeric[];
 v_dates text[];
 v_result jsonb;
 v_key text;
 v_id text;
 v_numeric numeric;
 v_text text;
 v_source_count integer;
begin
 if jsonb_typeof(coalesce(p_source_mapping,'{}'::jsonb))<>'object'
   or jsonb_typeof(coalesce(p_parameters,'{}'::jsonb))<>'object' then
  raise exception 'KPI mapping and parameters must be JSON objects' using errcode='22023';
 end if;
 v_mapping:=coalesce(p_source_mapping->'inputs','{}'::jsonb);
 if jsonb_typeof(v_mapping)<>'object' then
  raise exception 'source_mapping.inputs must be an object' using errcode='22023';
 end if;

 if p_template_code='count_v1' then
  v_source:=p_parameters->>'source';
  v_rows:=private.read_kpi_source_rows_v1(p_project_id,v_source,p_cutoff);
  v_count:=jsonb_array_length(v_rows);
  if v_count>5000 then
   return jsonb_build_object('inputs',v_inputs,'source_lineage',jsonb_build_array(jsonb_build_object('source',v_source,'status','insufficient_data','row_count',v_count)));
  end if;
  v_inputs:=jsonb_build_object('record_count',v_count);
  select coalesce(jsonb_agg(jsonb_build_object('id',x->>'id','source',v_source)),'[]'::jsonb)
    into v_lineage from (select value x from jsonb_array_elements(v_rows) limit 100) q;
  return jsonb_build_object('inputs',v_inputs,'source_lineage',jsonb_build_array(jsonb_build_object('source',v_source,'aggregate','count','row_count',v_count,'records',v_lineage)));
 end if;

 if p_template_code='date_variance_v1' then
  v_key:=p_parameters->>'baseline_date';
  if v_mapping ? v_key then
   v_spec:=v_mapping->v_key; v_source:=v_spec->>'source'; v_field:=v_spec->>'field'; v_aggregate:=coalesce(v_spec->>'aggregate','value');
   if not private.kpi_source_field_allowed_v1(v_source,v_field) then raise exception 'Unsupported source field mapping: %.%',v_source,v_field using errcode='22023'; end if;
   v_rows:=private.read_kpi_source_rows_v1(p_project_id,v_source,p_cutoff);
   v_source_count:=jsonb_array_length(v_rows);
   if v_source_count>5000 then return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage,'resolution_status','insufficient_data'); end if;
   if v_aggregate='value' and v_source_count=1 then v_inputs:=v_inputs||jsonb_build_object(v_key,v_rows->0->>v_field);
   elsif v_aggregate in ('min','max') then
    select case when v_aggregate='min' then min(value->>v_field) else max(value->>v_field) end into v_text from jsonb_array_elements(v_rows);
    if v_text is not null then v_inputs:=v_inputs||jsonb_build_object(v_key,v_text); end if;
   else raise exception 'Date inputs support value (single row), min or max aggregate'; end if;
   v_lineage:=v_lineage||jsonb_build_array(jsonb_build_object('input_key',v_key,'source',v_source,'field',v_field,'aggregate',v_aggregate,'row_count',v_source_count));
  end if;
  v_key:=p_parameters->>'comparison_date';
  if v_mapping ? v_key then
   v_spec:=v_mapping->v_key; v_source:=v_spec->>'source'; v_field:=v_spec->>'field'; v_aggregate:=coalesce(v_spec->>'aggregate','value');
   if not private.kpi_source_field_allowed_v1(v_source,v_field) then raise exception 'Unsupported source field mapping: %.%',v_source,v_field using errcode='22023'; end if;
   v_rows:=private.read_kpi_source_rows_v1(p_project_id,v_source,p_cutoff); v_source_count:=jsonb_array_length(v_rows);
   if v_source_count>5000 then return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage,'resolution_status','insufficient_data'); end if;
   if v_aggregate='value' and v_source_count=1 then v_inputs:=v_inputs||jsonb_build_object(v_key,v_rows->0->>v_field);
   elsif v_aggregate in ('min','max') then
    select case when v_aggregate='min' then min(value->>v_field) else max(value->>v_field) end into v_text from jsonb_array_elements(v_rows);
    if v_text is not null then v_inputs:=v_inputs||jsonb_build_object(v_key,v_text); end if;
   else raise exception 'Date inputs support value (single row), min or max aggregate'; end if;
   v_lineage:=v_lineage||jsonb_build_array(jsonb_build_object('input_key',v_key,'source',v_source,'field',v_field,'aggregate',v_aggregate,'row_count',v_source_count));
  end if;
 else
  if p_template_code='manual_input_v1' then
   v_mapping:=v_mapping;
  elsif p_template_code='ratio_v1' then
   if not (v_mapping ? (p_parameters->>'numerator')) or not (v_mapping ? (p_parameters->>'denominator')) then
    return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage);
   end if;
  elsif p_template_code='threshold_status_v1' then
   if not (v_mapping ? (p_parameters->>'value')) then return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage); end if;
  elsif p_template_code='weighted_sum_v1' then
   for v_key in select jsonb_array_elements_text(p_parameters->'values') loop
    if not (v_mapping ? v_key) then return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage); end if;
   end loop;
  end if;
  for v_key,v_spec in select key,value from jsonb_each(v_mapping) loop
   if jsonb_typeof(v_spec)<>'object' then raise exception 'Each source_mapping.inputs entry must be an object'; end if;
   v_source:=v_spec->>'source'; v_field:=v_spec->>'field'; v_aggregate:=coalesce(v_spec->>'aggregate','value');
   if not private.kpi_source_field_allowed_v1(v_source,v_field) then raise exception 'Unsupported source field mapping: %.%',v_source,v_field using errcode='22023'; end if;
   if v_aggregate not in ('value','count','sum','avg','min','max') then raise exception 'Unsupported aggregate: %',v_aggregate using errcode='22023'; end if;
   v_rows:=private.read_kpi_source_rows_v1(p_project_id,v_source,p_cutoff);
   v_source_count:=jsonb_array_length(v_rows);
   if v_source_count>5000 then return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage,'resolution_status','insufficient_data'); end if;
   if v_aggregate='count' then
    v_inputs:=v_inputs||jsonb_build_object(v_key,v_source_count);
   elsif v_aggregate in ('sum','avg') then
    select array_agg((x->>v_field)::numeric) filter(where x->>v_field is not null) into v_values from jsonb_array_elements(v_rows) x;
    if coalesce(array_length(v_values,1),0)>0 then
     if v_aggregate='sum' then select sum(z) into v_numeric from unnest(v_values) z;
     else select avg(z) into v_numeric from unnest(v_values) z; end if;
     v_inputs:=v_inputs||jsonb_build_object(v_key,v_numeric);
    end if;
   elsif v_aggregate in ('min','max') then
    select case when v_aggregate='min' then min(x->>v_field) else max(x->>v_field) end into v_text from jsonb_array_elements(v_rows) x;
    if v_text is not null then
     if v_text ~ '^-?[0-9]+([.][0-9]+)?$' then v_inputs:=v_inputs||jsonb_build_object(v_key,v_text::numeric);
     else v_inputs:=v_inputs||jsonb_build_object(v_key,v_text); end if;
    end if;
   elsif v_aggregate='value' then
    if v_source_count=1 and v_rows->0->>v_field is not null then
     v_text:=v_rows->0->>v_field;
     if v_text ~ '^-?[0-9]+([.][0-9]+)?$' then v_inputs:=v_inputs||jsonb_build_object(v_key,v_text::numeric);
     else v_inputs:=v_inputs||jsonb_build_object(v_key,v_text); end if;
    end if;
   end if;
   select coalesce(jsonb_agg(jsonb_build_object('id',x->>'id')),'[]'::jsonb) into v_result
    from (select value x from jsonb_array_elements(v_rows) limit 100) q;
   v_lineage:=v_lineage||jsonb_build_array(jsonb_build_object('input_key',v_key,'source',v_source,'field',v_field,'aggregate',v_aggregate,'row_count',v_source_count,'records',v_result));
  end loop;
 end if;
 return jsonb_build_object('inputs',v_inputs,'source_lineage',v_lineage);
end;
$$;

revoke all on function private.kpi_source_field_allowed_v1(text,text) from public,anon,authenticated;
revoke all on function private.read_kpi_source_rows_v1(uuid,text,timestamptz) from public,anon,authenticated;
revoke all on function private.resolve_kpi_inputs_v1(uuid,timestamptz,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function private.kpi_source_field_allowed_v1(text,text) to service_role;
grant execute on function private.read_kpi_source_rows_v1(uuid,text,timestamptz) to service_role;
grant execute on function private.resolve_kpi_inputs_v1(uuid,timestamptz,text,jsonb,jsonb) to service_role;

commit;