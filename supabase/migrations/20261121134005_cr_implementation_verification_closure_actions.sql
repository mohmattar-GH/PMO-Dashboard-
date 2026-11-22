-- PM-only Change Request implementation, verification and closure lifecycle.
-- Lifecycle columns are changed only through authenticated, audited RPC actions.

create or replace function private.update_project_change_request_implementation(
  p_change_request_id uuid,
  p_implementation_owner_id uuid,
  p_implementation_due_date date,
  p_implementation_status text,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_cr public.project_change_requests%rowtype;
  v_is_pm_admin boolean := false;
  v_is_owner boolean := false;
  v_next_status text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists (select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;
  if p_implementation_status not in ('not_started','in_progress','blocked','completed') then
    raise exception 'Implementation status must be not_started, in_progress, blocked or completed';
  end if;
  if length(btrim(coalesce(p_reason,''))) < 8 then
    raise exception 'An implementation update reason of at least 8 characters is required';
  end if;
  if length(p_reason)>2000 then raise exception 'Reason cannot exceed 2000 characters'; end if;

  select cr.* into v_cr
  from public.project_change_requests cr
  where cr.id=p_change_request_id
  for update;
  if not found then raise exception 'Change Request not found'; end if;
  if v_cr.status not in ('accepted','in_implementation') then
    raise exception 'Implementation can only be updated for accepted or in-implementation Change Requests';
  end if;

  select exists (
    select 1 from public.project_memberships pm
    where pm.project_id=v_cr.project_id and pm.user_id=v_uid
      and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
  ) or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=v_uid and ura.role_code='platform_admin' and ura.status='active'
      and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now())
  ) into v_is_pm_admin;

  v_is_owner := v_cr.implementation_owner_id=v_uid;
  if not v_is_pm_admin and not v_is_owner then
    raise exception 'Only the Project Manager, Platform Administrator or assigned implementation owner may update implementation';
  end if;
  if not v_is_pm_admin and (
    p_implementation_owner_id is distinct from v_cr.implementation_owner_id
    or p_implementation_due_date is distinct from v_cr.implementation_due_date
  ) then
    raise exception 'Only the Project Manager or Platform Administrator may change implementation ownership or due date';
  end if;

  if p_implementation_owner_id is not null and not exists (
    select 1 from public.project_memberships pm
    where pm.project_id=v_cr.project_id and pm.user_id=p_implementation_owner_id
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
  ) then
    raise exception 'Implementation owner must be an active member of this project';
  end if;
  if p_implementation_status in ('in_progress','blocked','completed') and p_implementation_owner_id is null then
    raise exception 'Assign an implementation owner before progressing the Change Request';
  end if;

  v_next_status := case
    when p_implementation_status='completed' then 'implemented'
    when p_implementation_status in ('in_progress','blocked') then 'in_implementation'
    else v_cr.status
  end;

  perform set_config('app.ppm_cr_transition','on',true);
  update public.project_change_requests
  set implementation_owner_id=p_implementation_owner_id,
      implementation_due_date=p_implementation_due_date,
      implementation_status=p_implementation_status,
      status=v_next_status,
      updated_at=now()
  where id=v_cr.id;

  insert into public.project_change_request_history(
    change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
  ) values (
    v_cr.id,v_cr.project_id,'implementation_updated',v_cr.status,v_next_status,v_uid,btrim(p_reason),
    jsonb_build_object(
      'implementation_owner_id',p_implementation_owner_id,
      'implementation_due_date',p_implementation_due_date,
      'implementation_status',p_implementation_status
    )
  );

  perform private.emit_ppm_notification(
    'change_request',
    case when p_implementation_status='completed' then 'cr_implementation_completed' else 'cr_implementation_updated' end,
    v_cr.project_id,'project_change_requests',v_cr.id,
    coalesce(p_implementation_status,'')||':'||extract(epoch from now())::bigint::text,
    case when p_implementation_status='completed' then 'Change Request implementation completed' else 'Change Request implementation updated' end,
    v_cr.cr_reference||' — '||v_cr.title||' · '||replace(p_implementation_status,'_',' '),
    '/projects/'||v_cr.project_id::text||'/change-requests/'||v_cr.id::text,
    array[v_cr.requested_by,p_implementation_owner_id],v_uid
  );

  return jsonb_build_object(
    'change_request_id',v_cr.id,'status',v_next_status,
    'implementation_status',p_implementation_status,
    'implementation_owner_id',p_implementation_owner_id,
    'implementation_due_date',p_implementation_due_date
  );
end;
$function$;

create or replace function private.verify_project_change_request(
  p_change_request_id uuid,
  p_verification_evidence text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_cr public.project_change_requests%rowtype;
  v_authorized boolean;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists (select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;
  if length(btrim(coalesce(p_verification_evidence,''))) < 8 then
    raise exception 'Verification evidence of at least 8 characters is required';
  end if;
  if length(p_verification_evidence)>4000 then raise exception 'Verification evidence cannot exceed 4000 characters'; end if;

  select cr.* into v_cr from public.project_change_requests cr
  where cr.id=p_change_request_id for update;
  if not found then raise exception 'Change Request not found'; end if;
  if v_cr.status<>'implemented' or v_cr.implementation_status<>'completed' then
    raise exception 'Only completed implementations can be verified';
  end if;

  select exists (
    select 1 from public.project_memberships pm
    where pm.project_id=v_cr.project_id and pm.user_id=v_uid
      and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
  ) or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=v_uid and ura.role_code='platform_admin' and ura.status='active'
      and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now())
  ) into v_authorized;
  if not v_authorized then raise exception 'Only the Project Manager or Platform Administrator may verify implementation'; end if;

  perform set_config('app.ppm_cr_transition','on',true);
  update public.project_change_requests
  set status='verified',verified_by=v_uid,verified_at=now(),updated_at=now()
  where id=v_cr.id;

  insert into public.project_change_request_history(
    change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
  ) values (
    v_cr.id,v_cr.project_id,'implementation_verified',v_cr.status,'verified',v_uid,
    btrim(p_verification_evidence),jsonb_build_object('verification_evidence',btrim(p_verification_evidence))
  );

  perform private.emit_ppm_notification(
    'change_request','cr_implementation_verified',v_cr.project_id,
    'project_change_requests',v_cr.id,'verified:'||extract(epoch from now())::bigint::text,
    'Change Request implementation verified',v_cr.cr_reference||' — '||v_cr.title,
    '/projects/'||v_cr.project_id::text||'/change-requests/'||v_cr.id::text,
    array[v_cr.requested_by,v_cr.implementation_owner_id],v_uid
  );

  return jsonb_build_object('change_request_id',v_cr.id,'status','verified','verified_by',v_uid,'verified_at',now());
end;
$function$;

create or replace function private.close_project_change_request(
  p_change_request_id uuid,
  p_closure_evidence text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_cr public.project_change_requests%rowtype;
  v_authorized boolean;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists (select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;
  if length(btrim(coalesce(p_closure_evidence,''))) < 8 then
    raise exception 'Closure evidence of at least 8 characters is required';
  end if;
  if length(p_closure_evidence)>4000 then raise exception 'Closure evidence cannot exceed 4000 characters'; end if;

  select cr.* into v_cr from public.project_change_requests cr
  where cr.id=p_change_request_id for update;
  if not found then raise exception 'Change Request not found'; end if;
  if v_cr.status<>'verified' then raise exception 'Only verified Change Requests can be closed'; end if;

  select exists (
    select 1 from public.project_memberships pm
    where pm.project_id=v_cr.project_id and pm.user_id=v_uid
      and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
  ) or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=v_uid and ura.role_code='platform_admin' and ura.status='active'
      and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now())
  ) into v_authorized;
  if not v_authorized then raise exception 'Only the Project Manager or Platform Administrator may close a Change Request'; end if;

  perform set_config('app.ppm_cr_transition','on',true);
  update public.project_change_requests
  set status='closed',closed_at=now(),closure_evidence=btrim(p_closure_evidence),updated_at=now()
  where id=v_cr.id;

  insert into public.project_change_request_history(
    change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
  ) values (
    v_cr.id,v_cr.project_id,'closed',v_cr.status,'closed',v_uid,
    btrim(p_closure_evidence),jsonb_build_object('closure_evidence',btrim(p_closure_evidence))
  );

  perform private.emit_ppm_notification(
    'change_request','cr_closed',v_cr.project_id,'project_change_requests',v_cr.id,
    'closed:'||extract(epoch from now())::bigint::text,
    'Change Request closed',v_cr.cr_reference||' — '||v_cr.title,
    '/projects/'||v_cr.project_id::text||'/change-requests/'||v_cr.id::text,
    array[v_cr.requested_by,v_cr.implementation_owner_id],v_uid
  );

  return jsonb_build_object('change_request_id',v_cr.id,'status','closed','closed_at',now());
end;
$function$;

revoke all on function private.update_project_change_request_implementation(uuid,uuid,date,text,text) from public, anon, authenticated, service_role;
revoke all on function private.verify_project_change_request(uuid,text) from public, anon, authenticated, service_role;
revoke all on function private.close_project_change_request(uuid,text) from public, anon, authenticated, service_role;

create or replace function public.update_project_change_request_implementation(
  p_change_request_id uuid,
  p_implementation_owner_id uuid,
  p_implementation_due_date date,
  p_implementation_status text,
  p_reason text
) returns jsonb
language sql
set search_path = ''
as $function$
  select private.update_project_change_request_implementation(
    p_change_request_id,p_implementation_owner_id,p_implementation_due_date,p_implementation_status,p_reason
  );
$function$;

create or replace function public.verify_project_change_request(
  p_change_request_id uuid,
  p_verification_evidence text
) returns jsonb
language sql
set search_path = ''
as $function$
  select private.verify_project_change_request(p_change_request_id,p_verification_evidence);
$function$;

create or replace function public.close_project_change_request(
  p_change_request_id uuid,
  p_closure_evidence text
) returns jsonb
language sql
set search_path = ''
as $function$
  select private.close_project_change_request(p_change_request_id,p_closure_evidence);
$function$;

revoke all on function public.update_project_change_request_implementation(uuid,uuid,date,text,text) from public, anon;
revoke all on function public.verify_project_change_request(uuid,text) from public, anon;
revoke all on function public.close_project_change_request(uuid,text) from public, anon;
grant execute on function public.update_project_change_request_implementation(uuid,uuid,date,text,text) to authenticated;
grant execute on function public.verify_project_change_request(uuid,text) to authenticated;
grant execute on function public.close_project_change_request(uuid,text) to authenticated;
