
create or replace function private.create_project_register_entry(
  p_project_code text,
  p_name text,
  p_client_id uuid,
  p_portfolio_id uuid,
  p_project_manager_id uuid,
  p_team_lead_id uuid,
  p_start_date date,
  p_target_end_date date,
  p_timezone text,
  p_currency_code text
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_project_id uuid;
  v_timezone text := coalesce(nullif(btrim(p_timezone),''),'UTC');
  v_currency text := nullif(upper(btrim(coalesce(p_currency_code,''))),'');
begin
  if v_actor is null then
    raise exception 'Authentication is required';
  end if;

  if not exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = v_actor
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  ) then
    raise exception 'Only an active Platform Administrator can register a project';
  end if;

  if length(btrim(coalesce(p_project_code,''))) = 0
     or length(btrim(coalesce(p_name,''))) = 0 then
    raise exception 'Project code and project name are required';
  end if;

  if p_project_manager_id is null then
    raise exception 'An assigned Project Manager is required';
  end if;

  if p_start_date is not null and p_target_end_date is not null and p_target_end_date < p_start_date then
    raise exception 'Target end date cannot be earlier than the project start date';
  end if;

  if not exists (select 1 from pg_catalog.pg_timezone_names tz where tz.name = v_timezone) then
    raise exception 'The supplied project timezone is not a recognized IANA timezone';
  end if;

  if v_currency is not null and v_currency !~ '^[A-Z]{3}$' then
    raise exception 'Currency code must be a three-letter ISO-style code';
  end if;

  if not exists (
    select 1 from public.user_profiles up
    where up.user_id = p_project_manager_id and up.is_active
  ) then
    raise exception 'The selected Project Manager must have an active application profile';
  end if;

  if p_team_lead_id is not null and not exists (
    select 1 from public.user_profiles up
    where up.user_id = p_team_lead_id and up.is_active
  ) then
    raise exception 'The selected Team Lead must have an active application profile';
  end if;

  if p_client_id is not null and not exists (
    select 1 from public.clients c where c.id = p_client_id and c.status = 'active'
  ) then
    raise exception 'The selected client is not active or does not exist';
  end if;

  if p_portfolio_id is not null and not exists (
    select 1 from public.portfolios p where p.id = p_portfolio_id and p.status = 'active'
  ) then
    raise exception 'The selected portfolio is not active or does not exist';
  end if;

  insert into public.projects(
    project_code,name,client_id,portfolio_id,project_manager_id,team_lead_id,
    lifecycle_status,start_date,target_end_date,timezone,currency_code,created_by
  ) values (
    upper(btrim(p_project_code)),btrim(p_name),p_client_id,p_portfolio_id,p_project_manager_id,p_team_lead_id,
    'draft',p_start_date,p_target_end_date,v_timezone,v_currency,v_actor
  )
  returning id into v_project_id;

  insert into public.project_memberships(
    project_id,user_id,project_role,status,effective_from,assigned_by,reason
  ) values (
    v_project_id,p_project_manager_id,'project_manager','active',now(),v_actor,'Assigned during project registration'
  );

  if p_team_lead_id is not null then
    insert into public.project_memberships(
      project_id,user_id,project_role,status,effective_from,assigned_by,reason
    ) values (
      v_project_id,p_team_lead_id,'team_lead','active',now(),v_actor,'Assigned during project registration'
    );
  end if;

  return v_project_id;
end;
$function$;

revoke all on function private.create_project_register_entry(text,text,uuid,uuid,uuid,uuid,date,date,text,text) from public, anon, authenticated;
grant execute on function private.create_project_register_entry(text,text,uuid,uuid,uuid,uuid,date,date,text,text) to authenticated;

create or replace function public.create_project_register_entry(
  p_project_code text,
  p_name text,
  p_client_id uuid default null,
  p_portfolio_id uuid default null,
  p_project_manager_id uuid default null,
  p_team_lead_id uuid default null,
  p_start_date date default null,
  p_target_end_date date default null,
  p_timezone text default 'UTC',
  p_currency_code text default null
)
returns uuid
language sql
security invoker
set search_path to ''
as $function$
  select private.create_project_register_entry(
    p_project_code,p_name,p_client_id,p_portfolio_id,p_project_manager_id,p_team_lead_id,
    p_start_date,p_target_end_date,p_timezone,p_currency_code
  );
$function$;

revoke all on function public.create_project_register_entry(text,text,uuid,uuid,uuid,uuid,date,date,text,text) from public, anon;
grant execute on function public.create_project_register_entry(text,text,uuid,uuid,uuid,uuid,date,date,text,text) to authenticated;

comment on function public.create_project_register_entry(text,text,uuid,uuid,uuid,uuid,date,date,text,text) is
  'Creates a draft project and its initial Project Manager/Team Lead memberships; callable only by active Platform Administrators.';
