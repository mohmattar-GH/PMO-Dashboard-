create or replace function private.guard_ppm_dashboard_layout()
returns trigger
language plpgsql
set search_path to ''
as $function$
declare
  v_allowed text[] := array[
    'portfolio_summary',
    'project_health',
    'project_phase',
    'project_register',
    'data_quality'
  ];
  v_visible text[];
  v_order text[];
begin
  if jsonb_typeof(new.layout_config->'visible_widgets') <> 'array'
     or jsonb_typeof(new.layout_config->'widget_order') <> 'array' then
    raise exception 'Dashboard layout requires visible_widgets and widget_order arrays';
  end if;

  v_visible := array(select jsonb_array_elements_text(new.layout_config->'visible_widgets'));
  v_order := array(select jsonb_array_elements_text(new.layout_config->'widget_order'));

  if cardinality(v_visible) < 1
     or cardinality(v_visible) <> (select count(distinct x) from unnest(v_visible) as x)
     or cardinality(v_order) <> cardinality(v_allowed)
     or cardinality(v_order) <> (select count(distinct x) from unnest(v_order) as x)
     or not (v_visible <@ v_allowed)
     or not (v_order @> v_allowed and v_allowed @> v_order)
     or not (v_visible <@ v_order) then
    raise exception 'Dashboard layout contains invalid, duplicate or missing widget identifiers';
  end if;

  if tg_op = 'INSERT' then
    if new.version_no <> 1 then
      raise exception 'New dashboard layouts must start at version 1';
    end if;
    new.created_by := coalesce(new.created_by, auth.uid());
    new.updated_by := coalesce(new.updated_by, auth.uid());
    new.updated_at := now();
  else
    if new.id is distinct from old.id
       or new.layout_code is distinct from old.layout_code
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
      raise exception 'Dashboard layout identity and creator are immutable';
    end if;
    if new.layout_config is distinct from old.layout_config
       or new.layout_name is distinct from old.layout_name then
      new.version_no := old.version_no + 1;
    else
      new.version_no := old.version_no;
    end if;
    new.updated_by := auth.uid();
    new.updated_at := now();
  end if;
  return new;
end;
$function$;

revoke all on function private.guard_ppm_dashboard_layout() from public, anon, authenticated;
