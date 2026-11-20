begin;
do $patch$
declare
  d text;
  old_decl text;
  new_decl text;
  old_logic text;
  new_logic text;
begin
  d:=pg_get_functiondef('private.calculate_project_health_v1(uuid,jsonb,timestamp with time zone,date)'::regprocedure);

  old_decl:=E' v_i integer; v_len integer;';
  new_decl:=E' v_i integer; v_len integer;\n v_dimension_item jsonb; v_threshold_item jsonb;\n v_dimension_status text; v_dimension_matched boolean; v_dimension_i integer;';
  if position(old_decl in d)=0 then
    raise exception 'Health function declaration patch point not found';
  end if;
  d:=replace(d,old_decl,new_decl);

  old_logic:=E'  select d->>''dimension_code'' into v_bad_dimension\n  from jsonb_array_elements(v_dimension_scores) d\n  where d->>''dimension_code'' in (select jsonb_array_elements_text(v_critical_dimensions))\n   and d->>''status''=''calculated''\n   and (d->>''score'')::numeric<=coalesce((\n    select min((x->>''upper_bound'')::numeric) from jsonb_array_elements(v_thresholds) x\n    where lower(x->>''status'')=''red'' and x->''upper_bound''<>''null''::jsonb\n   ),v_score_min-1)\n  limit 1;\n  if v_bad_dimension is not null then v_status:=''red''; v_reason:=''Critical dimension override: ''||v_bad_dimension;';
  new_logic:=E'  for v_dimension_item in\n   select d from jsonb_array_elements(v_dimension_scores) d\n   where d->>''dimension_code'' in (select jsonb_array_elements_text(v_critical_dimensions))\n     and d->>''status''=''calculated''\n  loop\n   v_dimension_status:=null; v_dimension_matched:=false;\n   for v_dimension_i in 0..v_len-1 loop\n    v_threshold_item:=v_thresholds->v_dimension_i;\n    if v_dimension_i=v_len-1 then\n     if not v_dimension_matched then v_dimension_status:=lower(v_threshold_item->>''status''); end if;\n    else\n     v_upper:=(v_threshold_item->>''upper_bound'')::numeric;\n     if not v_dimension_matched and (v_dimension_item->>''score'')::numeric<=v_upper then\n      v_dimension_status:=lower(v_threshold_item->>''status''); v_dimension_matched:=true;\n     end if;\n    end if;\n   end loop;\n   if v_dimension_status=''red'' then v_bad_dimension:=v_dimension_item->>''dimension_code''; exit; end if;\n  end loop;\n  if v_bad_dimension is not null then v_status:=''red''; v_reason:=''Critical dimension override: ''||v_bad_dimension;';
  if position(old_logic in d)=0 then
    raise exception 'Critical-dimension logic patch point not found';
  end if;
  d:=replace(d,old_logic,new_logic);
  execute d;
end;
$patch$;
commit;
