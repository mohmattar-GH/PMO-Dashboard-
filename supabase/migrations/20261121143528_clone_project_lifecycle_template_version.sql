
create or replace function private.clone_project_lifecycle_template_version(
  p_source_version_id uuid,
  p_change_reason text
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_template_id uuid;
  v_project_id uuid;
  v_source_status text;
  v_version_number integer;
  v_new_version_id uuid;
begin
  if v_actor is null then raise exception 'Authentication is required'; end if;
  if length(btrim(coalesce(p_change_reason,''))) not between 8 and 1000 then
    raise exception 'Version change reason must be 8 to 1000 characters';
  end if;
  if not exists (
    select 1
    from public.user_profiles up
    join public.user_global_role_assignments ura on ura.user_id=up.user_id
    where up.user_id=v_actor and up.is_active
      and ura.role_code='platform_admin' and ura.status='active'
      and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now())
  ) then
    raise exception 'Active Platform Administrator role required';
  end if;

  select template_id,project_id,status
  into v_template_id,v_project_id,v_source_status
  from public.project_lifecycle_template_versions
  where id=p_source_version_id
  for share;

  if not found then raise exception 'Source lifecycle version was not found'; end if;
  if v_source_status not in ('published','retired') then
    raise exception 'Only published or retired lifecycle versions can be cloned';
  end if;

  select coalesce(max(version_number),0)+1
  into v_version_number
  from public.project_lifecycle_template_versions
  where template_id=v_template_id;

  insert into public.project_lifecycle_template_versions(
    template_id,project_id,version_number,status,change_reason,created_by
  ) values (
    v_template_id,v_project_id,v_version_number,'draft',btrim(p_change_reason),v_actor
  ) returning id into v_new_version_id;

  with source_phases as (
    select id,phase_code,phase_name,description,display_order,is_active
    from public.project_lifecycle_phases
    where version_id=p_source_version_id
  ),
  inserted_phases as (
    insert into public.project_lifecycle_phases(
      version_id,template_id,project_id,phase_code,phase_name,description,display_order,is_active
    )
    select v_new_version_id,v_template_id,v_project_id,
      phase_code,phase_name,description,display_order,is_active
    from source_phases
    returning id,phase_code
  ),
  phase_map as (
    select source_phases.id as old_id,inserted_phases.id as new_id
    from source_phases
    join inserted_phases using(phase_code)
  )
  insert into public.project_lifecycle_transition_rules(
    version_id,template_id,project_id,from_phase_id,to_phase_id,reason_required
  )
  select v_new_version_id,v_template_id,v_project_id,
    from_map.new_id,to_map.new_id,r.reason_required
  from public.project_lifecycle_transition_rules r
  join phase_map to_map on to_map.old_id=r.to_phase_id
  left join phase_map from_map on from_map.old_id=r.from_phase_id
  where r.version_id=p_source_version_id;

  return v_new_version_id;
end;
$function$;

revoke all on function private.clone_project_lifecycle_template_version(uuid,text) from public, anon, authenticated;
grant execute on function private.clone_project_lifecycle_template_version(uuid,text) to authenticated;

create or replace function public.clone_project_lifecycle_template_version(
  p_source_version_id uuid,
  p_change_reason text
)
returns uuid
language sql
security invoker
set search_path to ''
as $function$
  select private.clone_project_lifecycle_template_version(p_source_version_id,p_change_reason);
$function$;

revoke all on function public.clone_project_lifecycle_template_version(uuid,text) from public, anon;
grant execute on function public.clone_project_lifecycle_template_version(uuid,text) to authenticated;

comment on function public.clone_project_lifecycle_template_version(uuid,text) is
  'Creates a new editable draft lifecycle version by cloning phases and transition rules from a published or retired version.';
