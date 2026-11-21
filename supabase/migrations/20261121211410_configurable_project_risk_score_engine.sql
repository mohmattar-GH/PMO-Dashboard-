begin;

create or replace function private.compute_project_risk_score_v1(
  p_project_id uuid,
  p_probability integer,
  p_impact integer
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_project_set_count integer := 0;
  v_global_set_count integer := 0;
  v_set_id uuid;
  v_version_id uuid;
  v_probability_max numeric;
  v_impact_max numeric;
  v_probability_weight numeric;
  v_impact_weight numeric;
  v_multiplier numeric;
  v_eval jsonb;
begin
  if p_project_id is null or p_probability is null or p_impact is null
     or p_probability <= 0 or p_impact <= 0 then
    return null;
  end if;

  select count(distinct s.id)
    into v_project_set_count
  from public.reporting_configuration_sets s
  join public.reporting_configuration_versions v on v.configuration_set_id = s.id
  join public.reporting_rule_parameters rp on rp.configuration_version_id = v.id
  where s.scope_type = 'project'
    and s.project_id = p_project_id
    and v.status = 'published'
    and v.effective_from <= now()
    and (v.effective_to is null or v.effective_to > now())
    and rp.rule_code = 'risk_scoring';

  if v_project_set_count > 1 then
    return null;
  elsif v_project_set_count = 1 then
    select s.id into v_set_id
    from public.reporting_configuration_sets s
    where s.scope_type = 'project' and s.project_id = p_project_id
      and exists (
        select 1
        from public.reporting_configuration_versions v
        join public.reporting_rule_parameters rp on rp.configuration_version_id = v.id
        where v.configuration_set_id = s.id
          and v.status = 'published'
          and v.effective_from <= now()
          and (v.effective_to is null or v.effective_to > now())
          and rp.rule_code = 'risk_scoring'
      )
    limit 1;
  else
    select count(distinct s.id)
      into v_global_set_count
    from public.reporting_configuration_sets s
    join public.reporting_configuration_versions v on v.configuration_set_id = s.id
    join public.reporting_rule_parameters rp on rp.configuration_version_id = v.id
    where s.scope_type = 'global'
      and v.status = 'published'
      and v.effective_from <= now()
      and (v.effective_to is null or v.effective_to > now())
      and rp.rule_code = 'risk_scoring';

    if v_global_set_count <> 1 then
      return null;
    end if;

    select s.id into v_set_id
    from public.reporting_configuration_sets s
    where s.scope_type = 'global'
      and exists (
        select 1
        from public.reporting_configuration_versions v
        join public.reporting_rule_parameters rp on rp.configuration_version_id = v.id
        where v.configuration_set_id = s.id
          and v.status = 'published'
          and v.effective_from <= now()
          and (v.effective_to is null or v.effective_to > now())
          and rp.rule_code = 'risk_scoring'
      )
    limit 1;
  end if;

  select v.id into v_version_id
  from public.reporting_configuration_versions v
  join public.reporting_rule_parameters rp on rp.configuration_version_id = v.id
  where v.configuration_set_id = v_set_id
    and v.status = 'published'
    and v.effective_from <= now()
    and (v.effective_to is null or v.effective_to > now())
    and rp.rule_code = 'risk_scoring'
  group by v.id, v.version_number, v.published_at
  order by v.version_number desc, v.published_at desc
  limit 1;

  if v_version_id is null then
    return null;
  end if;

  select
    max(nullif(rp.parameter_value #>> '{}', '')::numeric) filter (where rp.parameter_code = 'probability_scale_max' and rp.value_type = 'number'),
    max(nullif(rp.parameter_value #>> '{}', '')::numeric) filter (where rp.parameter_code = 'impact_scale_max' and rp.value_type = 'number'),
    max(nullif(rp.parameter_value #>> '{}', '')::numeric) filter (where rp.parameter_code = 'probability_weight' and rp.value_type = 'number'),
    max(nullif(rp.parameter_value #>> '{}', '')::numeric) filter (where rp.parameter_code = 'impact_weight' and rp.value_type = 'number'),
    coalesce(max(nullif(rp.parameter_value #>> '{}', '')::numeric) filter (where rp.parameter_code = 'score_multiplier' and rp.value_type = 'number'), 100)
  into v_probability_max, v_impact_max, v_probability_weight, v_impact_weight, v_multiplier
  from public.reporting_rule_parameters rp
  where rp.configuration_version_id = v_version_id
    and rp.rule_code = 'risk_scoring';

  if v_probability_max is null or v_impact_max is null
     or v_probability_weight is null or v_impact_weight is null
     or v_probability_max <= 0 or v_impact_max <= 0
     or trunc(v_probability_max) <> v_probability_max
     or trunc(v_impact_max) <> v_impact_max
     or v_probability_weight < 0 or v_probability_weight > 1
     or v_impact_weight < 0 or v_impact_weight > 1
     or abs(v_probability_weight + v_impact_weight - 1) > 0.000001
     or v_multiplier <= 0
     or p_probability > v_probability_max
     or p_impact > v_impact_max then
    return null;
  end if;

  v_eval := private.evaluate_kpi_template_v1(
    'weighted_sum_v1',
    jsonb_build_object(
      'values', jsonb_build_array('probability_normalized', 'impact_normalized'),
      'weights', jsonb_build_array(v_probability_weight, v_impact_weight)
    ),
    jsonb_build_object(
      'probability_normalized', p_probability::numeric / v_probability_max,
      'impact_normalized', p_impact::numeric / v_impact_max
    )
  );

  if v_eval->>'status' <> 'calculated' or nullif(v_eval->>'numeric_value', '') is null then
    return null;
  end if;

  return round((v_eval->>'numeric_value')::numeric * v_multiplier, 2);
exception
  when others then
    return null;
end;
$function$;

create or replace function private.set_project_risk_score_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  new.risk_score := private.compute_project_risk_score_v1(
    new.project_id,
    new.probability_level,
    new.impact_level
  );
  return new;
end;
$function$;

create or replace function private.recalculate_project_risk_scores_v1(
  p_scope_type text,
  p_project_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_count integer := 0;
begin
  if p_scope_type = 'global' then
    update public.project_risks r
      set risk_score = private.compute_project_risk_score_v1(r.project_id, r.probability_level, r.impact_level)
    where r.risk_score is distinct from private.compute_project_risk_score_v1(r.project_id, r.probability_level, r.impact_level);
  elsif p_scope_type = 'project' and p_project_id is not null then
    update public.project_risks r
      set risk_score = private.compute_project_risk_score_v1(r.project_id, r.probability_level, r.impact_level)
    where r.project_id = p_project_id
      and r.risk_score is distinct from private.compute_project_risk_score_v1(r.project_id, r.probability_level, r.impact_level);
  else
    raise exception 'Invalid risk-scoring configuration scope';
  end if;
  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

create or replace function private.recalculate_project_risk_scores_on_config_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_scope_type text;
  v_project_id uuid;
begin
  if old.status is distinct from new.status
     and (old.status = 'published' or new.status = 'published') then
    select s.scope_type, s.project_id
      into v_scope_type, v_project_id
    from public.reporting_configuration_sets s
    where s.id = new.configuration_set_id;

    perform private.recalculate_project_risk_scores_v1(v_scope_type, v_project_id);
  end if;
  return new;
end;
$function$;

revoke all on function private.compute_project_risk_score_v1(uuid, integer, integer) from public, anon, authenticated, service_role;
revoke all on function private.set_project_risk_score_before_write() from public, anon, authenticated, service_role;
revoke all on function private.recalculate_project_risk_scores_v1(text, uuid) from public, anon, authenticated, service_role;
revoke all on function private.recalculate_project_risk_scores_on_config_transition() from public, anon, authenticated, service_role;

drop trigger if exists project_risks_set_calculated_score on public.project_risks;
create trigger project_risks_set_calculated_score
before insert or update of project_id, probability_level, impact_level
on public.project_risks
for each row execute function private.set_project_risk_score_before_write();

drop trigger if exists reporting_configuration_versions_recalculate_risk_scores on public.reporting_configuration_versions;
create trigger reporting_configuration_versions_recalculate_risk_scores
after update of status
on public.reporting_configuration_versions
for each row execute function private.recalculate_project_risk_scores_on_config_transition();

commit;
