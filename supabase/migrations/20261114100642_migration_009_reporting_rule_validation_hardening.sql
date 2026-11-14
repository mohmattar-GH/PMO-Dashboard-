begin;
CREATE OR REPLACE FUNCTION public.manage_reporting_configuration(p_actor_user_id uuid, p_action text, p_payload jsonb, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_role_codes text[];
  v_set_id uuid;
  v_version_id uuid;
  v_version public.reporting_configuration_versions%rowtype;
  v_set public.reporting_configuration_sets%rowtype;
  v_scope text;
  v_project_id uuid;
  v_next_version integer;
  v_dimensions jsonb;
  v_kpis jsonb;
  v_parameters jsonb;
  v_dimension jsonb;
  v_dimension_code text;
  v_kpi jsonb;
  v_parameter jsonb;
  v_dimension_id uuid;
  v_template_schema jsonb;
  v_required_key text;
  v_parameter_type text;
  v_numeric_value numeric;
  v_dimension_count integer := 0;
  v_kpi_count integer := 0;
  v_parameter_count integer := 0;
  v_active_count integer := 0;
  v_active_weight_count integer := 0;
  v_weight_sum numeric;
  v_action_from text;
  v_action_to text;
  v_before jsonb;
  v_after jsonb;
  v_now timestamptz := now();
begin
  if p_actor_user_id is null then raise exception 'Actor is required'; end if;
  if p_action is null or p_action not in ('create_draft','save_draft_rules','submit','approve','publish','supersede') then
    raise exception 'Unsupported configuration action';
  end if;
  if p_reason is null or length(btrim(p_reason)) < 8 or length(btrim(p_reason)) > 1000 then
    raise exception 'A reason of 8–1000 characters is required';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Payload must be a JSON object';
  end if;
  if coalesce(current_setting('request.jwt.claims', true)::jsonb->>'role','') <> 'service_role' then
    raise exception 'Service role required';
  end if;

  select coalesce(array_agg(ura.role_code), array[]::text[]) into v_role_codes
  from public.user_global_role_assignments ura
  where ura.user_id = p_actor_user_id and ura.status = 'active'
    and ura.effective_from <= v_now and (ura.effective_to is null or ura.effective_to > v_now);

  if p_action in ('create_draft','save_draft_rules','submit') then
    if not (v_role_codes && array['platform_admin','configuration_steward']::text[]) then
      raise exception 'Forbidden: configuration steward permission required';
    end if;
  else
    if not (v_role_codes && array['platform_admin','configuration_approver']::text[]) then
      raise exception 'Forbidden: configuration approver permission required';
    end if;
  end if;

  if p_action = 'create_draft' then
    v_scope := p_payload->>'scope_type';
    if v_scope not in ('global','project') then raise exception 'Invalid scope_type'; end if;
    if length(btrim(coalesce(p_payload->>'configuration_code',''))) = 0
       or length(btrim(coalesce(p_payload->>'name',''))) = 0 then
      raise exception 'configuration_code and name are required';
    end if;
    if v_scope = 'project' then
      begin v_project_id := (p_payload->>'project_id')::uuid;
      exception when others then raise exception 'A valid project_id is required for project scope'; end;
      if not ('platform_admin' = any(v_role_codes)) and not exists (
        select 1 from public.project_memberships pm
        where pm.project_id = v_project_id and pm.user_id = p_actor_user_id
          and pm.status = 'active' and pm.effective_from <= v_now
          and (pm.effective_to is null or pm.effective_to > v_now)
      ) then raise exception 'Forbidden: no active membership for this project'; end if;
    else v_project_id := null;
    end if;

    if nullif(p_payload->>'configuration_set_id','') is not null then
      begin v_set_id := (p_payload->>'configuration_set_id')::uuid;
      exception when others then raise exception 'Invalid configuration_set_id'; end;
      select * into v_set from public.reporting_configuration_sets where id = v_set_id for update;
      if not found or v_set.scope_type <> v_scope or v_set.project_id is distinct from v_project_id then
        raise exception 'Configuration set not found or scope mismatch';
      end if;
    else
      insert into public.reporting_configuration_sets(scope_type,project_id,configuration_code,name,description,created_by)
      values(v_scope,v_project_id,btrim(p_payload->>'configuration_code'),btrim(p_payload->>'name'),
        nullif(p_payload->>'description',''),p_actor_user_id) returning id into v_set_id;
      select * into v_set from public.reporting_configuration_sets where id = v_set_id for update;
    end if;

    select coalesce(max(version_number),0)+1 into v_next_version
    from public.reporting_configuration_versions where configuration_set_id = v_set_id;

    insert into public.reporting_configuration_versions(configuration_set_id,version_number,status,effective_from,effective_to,change_summary,created_by)
    values(v_set_id,v_next_version,'draft',nullif(p_payload->>'effective_from','')::timestamptz,
      nullif(p_payload->>'effective_to','')::timestamptz,btrim(p_reason),p_actor_user_id)
    returning id into v_version_id;

    v_after := jsonb_build_object('id',v_version_id,'configuration_set_id',v_set_id,'version_number',v_next_version,'status','draft');
    insert into private.reporting_configuration_audit(configuration_set_id,configuration_version_id,actor_user_id,action,reason,before_data,after_data)
    values(v_set_id,v_version_id,p_actor_user_id,'draft_created',btrim(p_reason),null,v_after);
    return jsonb_build_object('configuration_set_id',v_set_id,'version',v_after);
  end if;

  begin v_version_id := (p_payload->>'configuration_version_id')::uuid;
  exception when others then raise exception 'A valid configuration_version_id is required'; end;
  select * into v_version from public.reporting_configuration_versions where id=v_version_id for update;
  if not found then raise exception 'Configuration version not found'; end if;
  v_set_id := v_version.configuration_set_id;

  if p_action = 'save_draft_rules' then
    if v_version.status <> 'draft' then raise exception 'Only draft versions can be edited'; end if;
    v_dimensions := coalesce(p_payload->'dimensions','[]'::jsonb);
    v_kpis := coalesce(p_payload->'kpis','[]'::jsonb);
    v_parameters := coalesce(p_payload->'parameters','[]'::jsonb);
    if jsonb_typeof(v_dimensions) <> 'array' or jsonb_typeof(v_kpis) <> 'array' or jsonb_typeof(v_parameters) <> 'array' then
      raise exception 'dimensions, kpis and parameters must be JSON arrays';
    end if;
    if jsonb_array_length(v_dimensions)>100 or jsonb_array_length(v_kpis)>500 or jsonb_array_length(v_parameters)>1000 then
      raise exception 'Configuration payload exceeds allowed limits';
    end if;
    if jsonb_array_length(v_dimensions)=0 then raise exception 'At least one dimension is required'; end if;

    select count(*) filter(where coalesce((x->>'is_active')::boolean,true)),
      count(*) filter(where coalesce((x->>'is_active')::boolean,true) and x ? 'weight' and x->>'weight'<>'null'),
      coalesce(sum((x->>'weight')::numeric) filter(where coalesce((x->>'is_active')::boolean,true)),0)
    into v_active_count,v_active_weight_count,v_weight_sum
    from jsonb_array_elements(v_dimensions) as t(x);
    if v_active_count=0 then raise exception 'At least one active reporting dimension is required'; end if;
    if v_active_weight_count not in (0,v_active_count) then raise exception 'Either all active dimension weights must be supplied or none'; end if;
    if v_active_weight_count>0 and abs(v_weight_sum-1.0)>0.000001 then raise exception 'Active dimension weights must sum to 1.0'; end if;

    delete from public.reporting_rule_parameters where configuration_version_id=v_version_id;
    delete from public.kpi_definitions where configuration_version_id=v_version_id;
    delete from public.reporting_dimensions where configuration_version_id=v_version_id;

    for v_dimension in select x from jsonb_array_elements(v_dimensions) as t(x) loop
      if length(btrim(coalesce(v_dimension->>'dimension_code','')))=0 or length(btrim(coalesce(v_dimension->>'name','')))=0 then
        raise exception 'Each dimension requires dimension_code and name';
      end if;
      if v_dimension ? 'weight' and v_dimension->>'weight'<>'null'
         and ((v_dimension->>'weight')::numeric<0 or (v_dimension->>'weight')::numeric>1) then
        raise exception 'Dimension weights must be between 0 and 1';
      end if;
      if coalesce(v_dimension->>'missing_data_status','not_reported') not in ('not_reported','insufficient_data') then
        raise exception 'Invalid missing_data_status';
      end if;
      insert into public.reporting_dimensions(configuration_version_id,dimension_code,name,description,display_order,weight,is_active,missing_data_status)
      values(v_version_id,btrim(v_dimension->>'dimension_code'),btrim(v_dimension->>'name'),nullif(v_dimension->>'description',''),
        coalesce((v_dimension->>'display_order')::integer,0),
        case when v_dimension->>'weight' is null or v_dimension->>'weight'='null' then null else (v_dimension->>'weight')::numeric end,
        coalesce((v_dimension->>'is_active')::boolean,true),coalesce(v_dimension->>'missing_data_status','not_reported'));
      v_dimension_count:=v_dimension_count+1;
    end loop;

    for v_dimension_code in
      select x->>'dimension_code' from jsonb_array_elements(v_dimensions) as t(x)
      where coalesce((x->>'is_active')::boolean,true)
    loop
      select count(*) filter(where coalesce((k->>'is_active')::boolean,true)),
        count(*) filter(where coalesce((k->>'is_active')::boolean,true) and k ? 'weight' and k->>'weight'<>'null'),
        coalesce(sum((k->>'weight')::numeric) filter(where coalesce((k->>'is_active')::boolean,true)),0)
      into v_active_count,v_active_weight_count,v_weight_sum
      from jsonb_array_elements(v_kpis) as t(k)
      where k->>'dimension_code'=v_dimension_code;
      if v_active_count>0 then
        if v_active_weight_count not in (0,v_active_count) then raise exception 'KPI weights must be supplied for all active KPIs in dimension % or none',v_dimension_code; end if;
        if v_active_weight_count>0 and abs(v_weight_sum-1.0)>0.000001 then raise exception 'Active KPI weights must sum to 1.0 within dimension %',v_dimension_code; end if;
      end if;
    end loop;

    for v_kpi in select x from jsonb_array_elements(v_kpis) as t(x) loop
      if length(btrim(coalesce(v_kpi->>'kpi_code','')))=0 or length(btrim(coalesce(v_kpi->>'name','')))=0 then
        raise exception 'Each KPI requires kpi_code and name';
      end if;
      if v_kpi->>'calculation_method' is null then raise exception 'KPI calculation_method is required'; end if;
      if v_kpi->>'weight' is not null and v_kpi->>'weight'<>'null'
         and ((v_kpi->>'weight')::numeric<0 or (v_kpi->>'weight')::numeric>1) then raise exception 'KPI weights must be between 0 and 1'; end if;
      select ft.parameter_schema into v_template_schema
      from private.reporting_formula_templates ft
      where ft.template_code=v_kpi->>'formula_template'
        and ft.calculation_method=v_kpi->>'calculation_method' and ft.is_active;
      if not found then
        raise exception 'KPI formula_template is not an active allowlisted template for its calculation_method';
      end if;
      for v_required_key in
        select jsonb_array_elements_text(coalesce(v_template_schema->'required','[]'::jsonb))
      loop
        if not (coalesce(v_kpi->'parameters','{}'::jsonb) ? v_required_key) then
          raise exception 'KPI % is missing required template parameter %',v_kpi->>'kpi_code',v_required_key;
        end if;
      end loop;
      v_dimension_id:=null;
      if nullif(v_kpi->>'dimension_code','') is not null then
        select id into v_dimension_id from public.reporting_dimensions
        where configuration_version_id=v_version_id and dimension_code=v_kpi->>'dimension_code' and is_active;
        if v_dimension_id is null then raise exception 'KPI references an unknown or inactive dimension_code'; end if;
      end if;
      if v_kpi->>'weight' is not null and v_kpi->>'weight'<>'null' and v_dimension_id is null then
        raise exception 'A weighted KPI must belong to an active reporting dimension';
      end if;
      if jsonb_typeof(coalesce(v_kpi->'source_mapping','{}'::jsonb))<>'object'
        or jsonb_typeof(coalesce(v_kpi->'parameters','{}'::jsonb))<>'object' then raise exception 'KPI source_mapping and parameters must be JSON objects'; end if;
      insert into public.kpi_definitions(configuration_version_id,dimension_id,kpi_code,name,description,calculation_method,formula_template,source_mapping,parameters,unit,weight,is_active,display_order)
      values(v_version_id,v_dimension_id,btrim(v_kpi->>'kpi_code'),btrim(v_kpi->>'name'),nullif(v_kpi->>'description',''),
        v_kpi->>'calculation_method',v_kpi->>'formula_template',coalesce(v_kpi->'source_mapping','{}'::jsonb),
        coalesce(v_kpi->'parameters','{}'::jsonb),nullif(v_kpi->>'unit',''),
        case when v_kpi->>'weight' is null or v_kpi->>'weight'='null' then null else (v_kpi->>'weight')::numeric end,
        coalesce((v_kpi->>'is_active')::boolean,true),coalesce((v_kpi->>'display_order')::integer,0));
      v_kpi_count:=v_kpi_count+1;
    end loop;

    for v_parameter in select x from jsonb_array_elements(v_parameters) as t(x) loop
      if length(btrim(coalesce(v_parameter->>'rule_code','')))=0 or length(btrim(coalesce(v_parameter->>'parameter_code','')))=0
        or not (v_parameter ? 'parameter_value') then raise exception 'Each parameter requires rule_code, parameter_code and parameter_value'; end if;
      v_parameter_type := coalesce(v_parameter->>'value_type','');
      if v_parameter_type not in ('number','integer','text','boolean','date','duration','json') then
        raise exception 'Invalid parameter value_type';
      end if;
      if jsonb_typeof(coalesce(v_parameter->'validation_definition','{}'::jsonb))<>'object' then
        raise exception 'validation_definition must be a JSON object';
      end if;
      if v_parameter_type in ('number','integer') then
        if jsonb_typeof(v_parameter->'parameter_value')<>'number' then
          raise exception 'Parameter % must be numeric',v_parameter->>'parameter_code';
        end if;
        v_numeric_value := (v_parameter->>'parameter_value')::numeric;
        if v_parameter_type='integer' and v_numeric_value<>trunc(v_numeric_value) then
          raise exception 'Parameter % must be an integer',v_parameter->>'parameter_code';
        end if;
        if v_parameter->'validation_definition' ? 'min'
          and v_numeric_value < (v_parameter->'validation_definition'->>'min')::numeric then
          raise exception 'Parameter % is below its configured minimum',v_parameter->>'parameter_code';
        end if;
        if v_parameter->'validation_definition' ? 'max'
          and v_numeric_value > (v_parameter->'validation_definition'->>'max')::numeric then
          raise exception 'Parameter % exceeds its configured maximum',v_parameter->>'parameter_code';
        end if;
      elsif v_parameter_type='text' then
        if jsonb_typeof(v_parameter->'parameter_value')<>'string' then
          raise exception 'Parameter % must be text',v_parameter->>'parameter_code';
        end if;
      elsif v_parameter_type='boolean' then
        if jsonb_typeof(v_parameter->'parameter_value')<>'boolean' then
          raise exception 'Parameter % must be boolean',v_parameter->>'parameter_code';
        end if;
      elsif v_parameter_type='date' then
        if jsonb_typeof(v_parameter->'parameter_value')<>'string' then
          raise exception 'Parameter % must be an ISO date string',v_parameter->>'parameter_code';
        end if;
        begin
          perform (v_parameter->>'parameter_value')::date;
        exception when others then
          raise exception 'Parameter % contains an invalid date',v_parameter->>'parameter_code';
        end;
      elsif v_parameter_type='duration' then
        if jsonb_typeof(v_parameter->'parameter_value') not in ('number','string') then
          raise exception 'Duration parameter % must be numeric or text',v_parameter->>'parameter_code';
        end if;
      end if;
      if v_parameter->'validation_definition' ? 'enum' then
        if jsonb_typeof(v_parameter->'validation_definition'->'enum')<>'array'
          or not ((v_parameter->'validation_definition'->'enum') @> jsonb_build_array(v_parameter->'parameter_value')) then
          raise exception 'Parameter % is not in its configured allowed values',v_parameter->>'parameter_code';
        end if;
      end if;
      insert into public.reporting_rule_parameters(configuration_version_id,rule_code,parameter_code,parameter_value,value_type,description,validation_definition)
      values(v_version_id,btrim(v_parameter->>'rule_code'),btrim(v_parameter->>'parameter_code'),v_parameter->'parameter_value',
        v_parameter->>'value_type',nullif(v_parameter->>'description',''),coalesce(v_parameter->'validation_definition','{}'::jsonb));
      v_parameter_count:=v_parameter_count+1;
    end loop;

    v_after:=jsonb_build_object('dimensions_count',v_dimension_count,'kpis_count',v_kpi_count,'parameters_count',v_parameter_count);
    insert into private.reporting_configuration_audit(configuration_set_id,configuration_version_id,actor_user_id,action,reason,before_data,after_data)
    values(v_set_id,v_version_id,p_actor_user_id,'draft_rules_saved',btrim(p_reason),null,v_after);
    return jsonb_build_object('saved',true,'dimensions',v_dimension_count,'kpis',v_kpi_count,'parameters',v_parameter_count);
  end if;

  if p_action='submit' then v_action_from:='draft'; v_action_to:='submitted';
  elsif p_action='approve' then v_action_from:='submitted'; v_action_to:='approved';
  elsif p_action='publish' then v_action_from:='approved'; v_action_to:='published';
  else v_action_from:='published'; v_action_to:='superseded'; end if;
  if v_version.status<>v_action_from then raise exception 'Invalid transition: current status %, requested target %',v_version.status,v_action_to; end if;

  if p_action='publish' then
    if v_version.effective_from is null then raise exception 'effective_from is required before publication'; end if;
    if v_version.effective_to is not null and v_version.effective_to<=v_version.effective_from then raise exception 'effective_to must be later than effective_from'; end if;
    if not exists(select 1 from public.reporting_dimensions d where d.configuration_version_id=v_version_id and d.is_active) then raise exception 'At least one active reporting dimension is required'; end if;
    if exists(select 1 from public.reporting_configuration_versions v where v.configuration_set_id=v_set_id and v.status='published' and v.id<>v_version_id) then
      raise exception 'Supersede the currently published version before publishing its replacement'; end if;
    if exists(select 1 from public.kpi_definitions k left join private.reporting_formula_templates ft
      on ft.template_code=k.formula_template and ft.calculation_method=k.calculation_method and ft.is_active
      where k.configuration_version_id=v_version_id and k.is_active and ft.template_code is null) then
      raise exception 'An active KPI uses an inactive or unsupported formula template'; end if;
  end if;

  v_before:=jsonb_build_object('id',v_version.id,'configuration_set_id',v_set_id,'version_number',v_version.version_number,'status',v_version.status);
  update public.reporting_configuration_versions
  set status=v_action_to,
    submitted_by=case when p_action='submit' then p_actor_user_id else submitted_by end,
    submitted_at=case when p_action='submit' then v_now else submitted_at end,
    approved_by=case when p_action='approve' then p_actor_user_id else approved_by end,
    approved_at=case when p_action='approve' then v_now else approved_at end,
    published_by=case when p_action='publish' then p_actor_user_id else published_by end,
    published_at=case when p_action='publish' then v_now else published_at end
  where id=v_version_id and status=v_action_from;
  if not found then raise exception 'Configuration version changed concurrently; reload and retry'; end if;
  v_after:=v_before||jsonb_build_object('status',v_action_to);
  insert into private.reporting_configuration_audit(configuration_set_id,configuration_version_id,actor_user_id,action,reason,before_data,after_data)
  values(v_set_id,v_version_id,p_actor_user_id,p_action,btrim(p_reason),v_before,v_after);
  return jsonb_build_object('version',v_after);
end;
$function$
;
revoke all on function public.manage_reporting_configuration(uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.manage_reporting_configuration(uuid,text,jsonb,text) to service_role;
commit;
