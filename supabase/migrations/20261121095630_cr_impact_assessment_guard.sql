-- Lock impact assessments at submission and stamp assessment actors from Auth.
create or replace function private.guard_project_change_request_impact_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_cr_status text;
  v_uid uuid := auth.uid();
  v_authorized boolean;
begin
  if tg_op='DELETE' then
    raise exception 'Change Request impact assessment rows are retained for audit';
  end if;

  select cr.project_id,cr.status into v_project_id,v_cr_status
  from public.project_change_requests cr
  where cr.id=new.change_request_id
  for share;
  if not found or v_project_id is distinct from new.project_id then
    raise exception 'Impact assessment must reference its Change Request project';
  end if;
  if v_cr_status <> 'draft' then
    raise exception 'Impact assessments are locked after Change Request submission';
  end if;

  select (
    exists (
      select 1 from public.project_memberships pm
      where pm.project_id=new.project_id and pm.user_id=v_uid
        and pm.project_role in ('project_manager','finance')
        and pm.status='active' and pm.effective_from<=now()
        and (pm.effective_to is null or pm.effective_to>now())
    )
    or exists (
      select 1 from public.user_global_role_assignments ura
      where ura.user_id=v_uid and ura.role_code in ('platform_admin','finance_admin')
        and ura.status='active' and ura.effective_from<=now()
        and (ura.effective_to is null or ura.effective_to>now())
    )
  ) into v_authorized;
  if not coalesce(v_authorized,false) then
    raise exception 'Active Project Manager, Finance or authorized administrator access required';
  end if;

  if new.assessment_status='assessed' then
    if nullif(btrim(new.impact_summary),'') is null then
      raise exception 'Provide an impact summary before marking this dimension assessed';
    end if;
    new.assessed_by := v_uid;
    new.assessed_at := now();
  else
    new.assessed_by := null;
    new.assessed_at := null;
  end if;
  return new;
end;
$$;

create trigger project_cr_impact_mutation_guard
before insert or update or delete on public.project_change_request_impacts
for each row execute function private.guard_project_change_request_impact_mutation();

revoke delete on public.project_change_request_impacts from authenticated;
