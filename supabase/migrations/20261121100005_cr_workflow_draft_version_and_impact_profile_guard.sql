create or replace function private.guard_project_change_request_workflow_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_old_stage public.ppm_workflow_stages%rowtype;
  v_pending integer;
  v_round integer;
  v_result text;
begin
  if (new.id,new.project_id,new.cr_reference,new.requested_by)
     is distinct from (old.id,old.project_id,old.cr_reference,old.requested_by) then
    raise exception 'Change Request identity and requester fields are immutable';
  end if;

  if current_setting('app.ppm_cr_transition',true) <> 'on' then
    if (to_jsonb(new)-array[
        'status','current_stage_id','submitted_at','decided_at',
        'closed_at','decision_reason','verified_by','verified_at','closure_evidence',
        'implementation_status'
      ]) is distinct from
       (to_jsonb(old)-array[
        'status','current_stage_id','submitted_at','decided_at',
        'closed_at','decision_reason','verified_by','verified_at','closure_evidence',
        'implementation_status'
      ]) then
      raise exception 'Change Request workflow fields can only be changed through the workflow action';
    end if;
  end if;

  if old.status <> 'draft' and new.workflow_version_id is distinct from old.workflow_version_id then
    raise exception 'The workflow version is fixed when the Change Request is submitted';
  end if;

  if old.status <> 'draft' and
     (new.title,new.description,new.justification,new.request_type,new.category,new.priority,
      new.contract_id,new.contract_variation_id)
       is distinct from
     (old.title,old.description,old.justification,old.request_type,old.category,old.priority,
      old.contract_id,old.contract_variation_id) then
    raise exception 'Submitted Change Request details are immutable; use a new Change Request or configured amendment process';
  end if;

  if old.current_stage_id is not null and new.current_stage_id is distinct from old.current_stage_id then
    select * into v_old_stage from public.ppm_workflow_stages where id=old.current_stage_id;
    if cardinality(v_old_stage.required_role_codes)>0 then
      v_result := current_setting('app.ppm_cr_approval_result',true);
      if v_result not in ('approved','rejected','returned') then
        raise exception 'A stage with required approvers can only be exited through a recorded approval decision';
      end if;
      select coalesce(max(a.round_no),0) into v_round
      from public.project_change_request_approvals a
      where a.change_request_id=old.id and a.stage_id=old.current_stage_id;
      select count(*) filter (where a.status<>'approved')
      into v_pending
      from public.project_change_request_approvals a
      where a.change_request_id=old.id and a.stage_id=old.current_stage_id
        and a.round_no=v_round;
      if v_result='approved' and coalesce(v_pending,0)>0 then
        raise exception 'All required approvals must be completed before advancing';
      end if;
    end if;
  end if;
  return new;
end;
$$;

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
  if not exists (select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;

  if tg_op='UPDATE' and
     (new.change_request_id,new.project_id,new.impact_dimension)
       is distinct from (old.change_request_id,old.project_id,old.impact_dimension) then
    raise exception 'Impact assessment identity fields cannot be reassigned';
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
