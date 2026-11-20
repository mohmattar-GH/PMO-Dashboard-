create or replace function private.evaluate_kpi_template_v1(
  p_template_code text,
  p_parameters jsonb,
  p_inputs jsonb
)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $function$
declare
  v_result numeric := null;
  v_value numeric;
  v_numerator numeric;
  v_denominator numeric;
  v_weight numeric;
  v_weight_sum numeric := 0;
  v_status text := 'calculated';
  v_lineage jsonb := '[]'::jsonb;
  v_item jsonb;
  v_previous numeric := null;
  v_upper numeric;
  v_status_value text;
  v_date_a date;
  v_date_b date;
  v_i integer;
  v_len integer;
  v_threshold_matched boolean := false;
  v_key text;
  v_raw jsonb;
  v_source text;
begin
  if p_template_code is null or p_parameters is null or p_inputs is null
     or jsonb_typeof(p_parameters) is distinct from 'object'
     or jsonb_typeof(p_inputs) is distinct from 'object' then
    raise exception 'KPI evaluator requires a template code and JSON object parameters/inputs' using errcode='22023';
  end if;

  if p_inputs ? 'source_lineage' then
    if jsonb_typeof(p_inputs->'source_lineage') is distinct from 'array' then
      raise exception 'source_lineage must be a JSON array' using errcode='22023';
    end if;
    v_lineage := p_inputs->'source_lineage';
  end if;

  case p_template_code
    when 'count_v1' then
      if p_parameters - array['source']::text[] <> '{}'::jsonb or not (p_parameters ? 'source') then
        raise exception 'count_v1 requires only source parameter' using errcode='22023';
      end if;
      v_source := p_parameters->>'source';
      if v_source not in ('projects','activities','milestones','invoices','cash_transactions','risks','licenses','weekly_updates','management_decisions','contract_deliverables') then
        raise exception 'count_v1 source is not in the supported source registry' using errcode='22023';
      end if;
      if jsonb_typeof(p_inputs->'record_count') is distinct from 'number' then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','count','source_lineage',v_lineage);
      end if;
      v_result := (p_inputs->>'record_count')::numeric;
      if v_result < 0 or trunc(v_result) <> v_result then
        raise exception 'count_v1 record_count must be a non-negative integer' using errcode='22023';
      end if;

    when 'date_variance_v1' then
      if p_parameters - array['baseline_date','comparison_date','day_basis']::text[] <> '{}'::jsonb
         or not (p_parameters ?& array['baseline_date','comparison_date','day_basis']) then
        raise exception 'date_variance_v1 requires baseline_date, comparison_date and day_basis' using errcode='22023';
      end if;
      if p_parameters->>'day_basis' <> 'calendar_days' then
        raise exception 'Unsupported day_basis; only calendar_days is currently supported' using errcode='22023';
      end if;
      v_key := p_parameters->>'baseline_date';
      if v_key is null or length(v_key)>64 then raise exception 'Invalid baseline_date input key' using errcode='22023'; end if;
      if jsonb_typeof(p_inputs->v_key) is distinct from 'string' then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','date_variance','source_lineage',v_lineage);
      end if;
      v_raw := p_inputs->v_key;
      if (v_raw#>>'{}') !~ '^\d{4}-\d{2}-\d{2}$' then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','date_variance','source_lineage',v_lineage);
      end if;
      v_date_a := (v_raw#>>'{}')::date;
      v_key := p_parameters->>'comparison_date';
      if v_key is null or length(v_key)>64 then raise exception 'Invalid comparison_date input key' using errcode='22023'; end if;
      if jsonb_typeof(p_inputs->v_key) is distinct from 'string' then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','date_variance','source_lineage',v_lineage);
      end if;
      v_raw := p_inputs->v_key;
      if (v_raw#>>'{}') !~ '^\d{4}-\d{2}-\d{2}$' then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','date_variance','source_lineage',v_lineage);
      end if;
      v_date_b := (v_raw#>>'{}')::date;
      v_result := v_date_b - v_date_a;

    when 'manual_input_v1' then
      if p_parameters - array['input_field']::text[] <> '{}'::jsonb or not (p_parameters ? 'input_field') then
        raise exception 'manual_input_v1 requires only input_field parameter' using errcode='22023';
      end if;
      v_key := p_parameters->>'input_field';
      if v_key is null or length(v_key)>64 then raise exception 'Invalid manual input field key' using errcode='22023'; end if;
      if jsonb_typeof(p_inputs->v_key) is distinct from 'number' then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','manual_input','source_lineage',v_lineage);
      end if;
      v_result := (p_inputs->>v_key)::numeric;

    when 'ratio_v1' then
      if p_parameters - array['numerator','denominator']::text[] <> '{}'::jsonb
         or not (p_parameters ?& array['numerator','denominator']) then
        raise exception 'ratio_v1 requires numerator and denominator input keys' using errcode='22023';
      end if;
      v_key := p_parameters->>'numerator';
      if v_key is null or length(v_key)>64 then raise exception 'Invalid numerator input key' using errcode='22023'; end if;
      if jsonb_typeof(p_inputs->v_key) is distinct from 'number' then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','ratio','source_lineage',v_lineage);
      end if;
      v_numerator := (p_inputs->>v_key)::numeric;
      v_key := p_parameters->>'denominator';
      if v_key is null or length(v_key)>64 then raise exception 'Invalid denominator input key' using errcode='22023'; end if;
      if jsonb_typeof(p_inputs->v_key) is distinct from 'number' then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','ratio','source_lineage',v_lineage);
      end if;
      v_denominator := (p_inputs->>v_key)::numeric;
      if v_denominator = 0 then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','insufficient_data','calculation_method','ratio','source_lineage',v_lineage);
      end if;
      v_result := v_numerator / v_denominator;

    when 'threshold_status_v1' then
      if p_parameters - array['value','thresholds']::text[] <> '{}'::jsonb
         or not (p_parameters ?& array['value','thresholds']) then
        raise exception 'threshold_status_v1 requires value input key and thresholds' using errcode='22023';
      end if;
      v_key := p_parameters->>'value';
      if v_key is null or length(v_key)>64 then raise exception 'Invalid threshold value input key' using errcode='22023'; end if;
      if jsonb_typeof(p_inputs->v_key) is distinct from 'number'
         or jsonb_typeof(p_parameters->'thresholds') is distinct from 'array'
         or jsonb_array_length(p_parameters->'thresholds')=0 then
        return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','threshold_status','source_lineage',v_lineage);
      end if;
      v_value := (p_inputs->>v_key)::numeric;
      v_len := jsonb_array_length(p_parameters->'thresholds');
      for v_i in 0..v_len-1 loop
        v_item := p_parameters->'thresholds'->v_i;
        if jsonb_typeof(v_item) is distinct from 'object' or not (v_item ? 'status')
           or (v_item - array['upper_bound','status']::text[]) <> '{}'::jsonb then
          raise exception 'Each threshold must contain only upper_bound and status' using errcode='22023';
        end if;
        v_status_value := v_item->>'status';
        if v_status_value is null or length(v_status_value) not between 1 and 32 then
          raise exception 'Threshold status must contain 1 to 32 characters' using errcode='22023';
        end if;
        if v_i=v_len-1 then
          if v_item->'upper_bound' is distinct from 'null'::jsonb then
            raise exception 'Final threshold must have a null upper_bound' using errcode='22023';
          end if;
          if not v_threshold_matched then v_status := v_status_value; end if;
        else
          if jsonb_typeof(v_item->'upper_bound') is distinct from 'number' then
            raise exception 'Non-final thresholds require numeric upper_bound' using errcode='22023';
          end if;
          v_upper := (v_item->>'upper_bound')::numeric;
          if v_previous is not null and v_upper<=v_previous then
            raise exception 'Threshold upper_bound values must be strictly increasing' using errcode='22023';
          end if;
          if not v_threshold_matched and v_value<=v_upper then
            v_status := v_status_value;
            v_threshold_matched := true;
          end if;
          v_previous := v_upper;
        end if;
      end loop;
      v_result := v_value;

    when 'weighted_sum_v1' then
      if p_parameters - array['values','weights']::text[] <> '{}'::jsonb
         or not (p_parameters ?& array['values','weights']) then
        raise exception 'weighted_sum_v1 requires values input keys and weights' using errcode='22023';
      end if;
      if jsonb_typeof(p_parameters->'values') is distinct from 'array'
         or jsonb_typeof(p_parameters->'weights') is distinct from 'array'
         or jsonb_array_length(p_parameters->'values')=0
         or jsonb_array_length(p_parameters->'values')<>jsonb_array_length(p_parameters->'weights') then
        raise exception 'Weighted values and weights must be non-empty arrays of equal length' using errcode='22023';
      end if;
      v_len := jsonb_array_length(p_parameters->'values');
      for v_i in 0..v_len-1 loop
        if jsonb_typeof(p_parameters->'values'->v_i) is distinct from 'string' then
          raise exception 'Weighted value entries must be input keys' using errcode='22023';
        end if;
        v_key := p_parameters->'values'->>v_i;
        if v_key is null or length(v_key)>64 then raise exception 'Invalid weighted input key' using errcode='22023'; end if;
        if jsonb_typeof(p_inputs->v_key) is distinct from 'number' then
          return jsonb_build_object('numeric_value',null,'text_value',null,'status','not_reported','calculation_method','weighted_sum','source_lineage',v_lineage);
        end if;
        v_item := p_parameters->'weights'->v_i;
        if jsonb_typeof(v_item) is distinct from 'number' then raise exception 'Weights must all be numeric' using errcode='22023'; end if;
        v_weight := (v_item#>>'{}')::numeric;
        if v_weight<0 or v_weight>1 then raise exception 'Each weight must be between 0 and 1' using errcode='22023'; end if;
        v_weight_sum := v_weight_sum+v_weight;
        v_result := coalesce(v_result,0)+((p_inputs->>v_key)::numeric*v_weight);
      end loop;
      if abs(v_weight_sum-1)>0.000001 then raise exception 'Weights must sum to 1' using errcode='22023'; end if;

    else
      raise exception 'Unsupported KPI formula template: %',p_template_code using errcode='22023';
  end case;

  return jsonb_build_object('numeric_value',v_result,'text_value',null,'status',v_status,
    'calculation_method',case p_template_code when 'count_v1' then 'count' when 'date_variance_v1' then 'date_variance'
      when 'manual_input_v1' then 'manual_input' when 'ratio_v1' then 'ratio'
      when 'threshold_status_v1' then 'threshold_status' when 'weighted_sum_v1' then 'weighted_sum' end,
    'source_lineage',v_lineage);
end;
$function$;
revoke all on function private.evaluate_kpi_template_v1(text,jsonb,jsonb) from public;
revoke all on function private.evaluate_kpi_template_v1(text,jsonb,jsonb) from anon, authenticated;
grant execute on function private.evaluate_kpi_template_v1(text,jsonb,jsonb) to service_role;