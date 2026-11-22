
create or replace function private.get_project_team_directory(p_project_id uuid)
returns table (
  project_id uuid,
  user_id uuid,
  project_role text,
  display_name text,
  job_title text
)
language plpgsql
security definer
set search_path to ''
stable
as $function$
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.projects p
    where p.id = p_project_id
      and (
        exists (
          select 1
          from public.project_memberships viewer
          where viewer.project_id = p.id
            and viewer.user_id = auth.uid()
            and viewer.status = 'active'
            and viewer.effective_from <= now()
            and (viewer.effective_to is null or viewer.effective_to > now())
        )
        or exists (
          select 1
          from public.user_global_role_assignments ura
          where ura.user_id = auth.uid()
            and ura.role_code = any(array['platform_admin','executive_viewer']::text[])
            and ura.status = 'active'
            and ura.effective_from <= now()
            and (ura.effective_to is null or ura.effective_to > now())
        )
      )
  ) then
    raise exception 'You are not authorized to view this project team directory';
  end if;

  return query
  select
    pm.project_id,
    pm.user_id,
    pm.project_role::text,
    up.display_name,
    up.job_title
  from public.project_memberships pm
  join public.user_profiles up on up.user_id = pm.user_id
  where pm.project_id = p_project_id
    and pm.status = 'active'
    and pm.effective_from <= now()
    and (pm.effective_to is null or pm.effective_to > now())
    and up.is_active
  order by pm.project_role, up.display_name;
end;
$function$;

revoke all on function private.get_project_team_directory(uuid) from public, anon, authenticated;
grant execute on function private.get_project_team_directory(uuid) to authenticated;

create or replace function public.get_project_team_directory(p_project_id uuid)
returns table (
  project_id uuid,
  user_id uuid,
  project_role text,
  display_name text,
  job_title text
)
language sql
security invoker
set search_path to ''
stable
as $function$
  select * from private.get_project_team_directory(p_project_id);
$function$;

revoke all on function public.get_project_team_directory(uuid) from public, anon;
grant execute on function public.get_project_team_directory(uuid) to authenticated;

comment on function public.get_project_team_directory(uuid) is
  'Returns only active project member names and roles to an authorized project member, Platform Administrator or Executive Viewer.';
