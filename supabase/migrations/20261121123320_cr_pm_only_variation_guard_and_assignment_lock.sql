-- Align CR-linked contract variation enforcement with PM-only CR decisions.
create or replace function private.enforce_contract_variation_workflow()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_is_pm boolean;
  v_is_finance boolean;
  v_cr public.project_change_requests%rowtype;
  v_finance_approver uuid;
  v_total numeric(18,2);
  v_currency char(3);
begin
  select exists(
    select 1 from public.project_memberships pm
    where pm.project_id=new.project_id and pm.user_id=(select auth.uid())
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='project_manager'
  ) or exists(
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) into v_is_pm;

  select exists(
    select 1 from public.project_memberships pm
    where pm.project_id=new.project_id and pm.user_id=(select auth.uid())
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='finance'
  ) or exists(
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) into v_is_finance;

  if tg_op='INSERT' then
    if not v_is_pm or new.status<>'draft' or new.requested_by is distinct from auth.uid() then
      raise exception 'Only an authorized project manager may create a draft variation';
    end if;
    if new.change_request_id is not null then
      select * into v_cr from public.project_change_requests cr
      where cr.id=new.change_request_id and cr.project_id=new.project_id
        and cr.contract_id=new.contract_id and cr.status='draft';
      if not found then raise exception 'A CR-linked variation must reference a matching draft Change Request'; end if;
    end if;
    return new;
  end if;

  if old.change_request_id is not null then
    if new.change_request_id is distinct from old.change_request_id then
      raise exception 'A contract variation cannot be detached from its Change Request';
    end if;
    if coalesce(current_setting('app.ppm_cr_apply',true),'')='on'
       and old.status='draft' and new.status='approved' then
      select cr.* into v_cr
      from public.project_change_requests cr
      where cr.id=new.change_request_id and cr.project_id=new.project_id
        and cr.contract_id=new.contract_id and cr.contract_variation_id=new.id
        and cr.status='accepted' and cr.decided_by is not null
      for update;
      if not found then raise exception 'Only an accepted Change Request decided by its assigned Project Manager may approve this variation'; end if;

      select coalesce(sum(i.cost_delta),0)::numeric(18,2),min(i.currency_code)
      into v_total,v_currency
      from public.project_change_request_impacts i
      where i.change_request_id=v_cr.id and i.project_id=v_cr.project_id
        and i.assessment_status='assessed' and i.cost_delta is not null;
      if v_total<>new.amount_delta or upper(btrim(v_currency))<>upper(btrim(new.currency_code)) then
        raise exception 'Contract variation no longer matches the accepted CR financial impact';
      end if;

      if (new.project_id,new.contract_id,new.change_request_id,new.variation_reference,
          new.title,new.description,new.amount_delta,new.currency_code,new.requested_by,new.effective_date)
         is distinct from
         (old.project_id,old.contract_id,old.change_request_id,old.variation_reference,
          old.title,old.description,old.amount_delta,old.currency_code,old.requested_by,old.effective_date) then
        raise exception 'CR-linked variation terms are immutable during PM decision application';
      end if;
      new.submitted_at:=coalesce(new.submitted_at,v_cr.submitted_at);
      new.decided_by:=v_cr.decided_by;
      new.decided_at:=v_cr.decided_at;
      new.decision_reason:='Accepted through Change Request '||v_cr.cr_reference||' by assigned Project Manager';
      return new;
    end if;
    raise exception 'CR-linked variations can only be approved through their Change Request';
  end if;

  if old.status='draft' and new.status='submitted' then
    if not v_is_pm
       or (to_jsonb(new)-array['status','submitted_at','updated_at']) is distinct from
          (to_jsonb(old)-array['status','submitted_at','updated_at']) then
      raise exception 'Only a project manager may submit an unchanged draft variation';
    end if;
    new.submitted_at:=now();
    return new;
  end if;

  if old.status='submitted' and new.status in ('approved','rejected') then
    if not v_is_finance
       or (to_jsonb(new)-array['status','decided_by','decided_at','decision_reason','updated_at']) is distinct from
          (to_jsonb(old)-array['status','decided_by','decided_at','decision_reason','updated_at'])
       or new.decision_reason is null or length(btrim(new.decision_reason))<8 then
      raise exception 'Only finance approvers may decide a submitted variation with a reason';
    end if;
    new.decided_by:=auth.uid();
    new.decided_at:=now();
    return new;
  end if;

  raise exception 'Invalid contract variation state transition';
end;
$function$;

create or replace function private.guard_project_change_request_workflow_fields()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if (new.id,new.project_id,new.cr_reference,new.requested_by) is distinct from (old.id,old.project_id,old.cr_reference,old.requested_by) then raise exception 'Change Request identity and requester fields are immutable'; end if;
  if coalesce(current_setting('app.ppm_cr_transition',true),'') <> 'on' then
    if (new.status,new.current_stage_id,new.submitted_at,new.decided_at,new.decided_by,new.closed_at,new.decision_reason,new.verified_by,new.verified_at,new.closure_evidence,new.implementation_status) is distinct from (old.status,old.current_stage_id,old.submitted_at,old.decided_at,old.decided_by,old.closed_at,old.decision_reason,old.verified_by,old.verified_at,old.closure_evidence,old.implementation_status) then raise exception 'Change Request lifecycle fields can only be changed through PM-only CR actions'; end if;
  end if;
  if old.status <> 'draft' and new.assigned_to is distinct from old.assigned_to then raise exception 'The assigned Project Manager is immutable after submission'; end if;
  if old.status <> 'draft' and new.workflow_version_id is distinct from old.workflow_version_id then raise exception 'Impact-assessment configuration is fixed after submission'; end if;
  if old.status <> 'draft' and (new.title,new.description,new.justification,new.request_type,new.category,new.priority,new.contract_id,new.contract_variation_id) is distinct from (old.title,old.description,old.justification,old.request_type,old.category,old.priority,old.contract_id,old.contract_variation_id) then raise exception 'Submitted Change Request details are immutable'; end if;
  return new;
end;
$function$;

revoke all on function private.enforce_contract_variation_workflow() from public, anon, authenticated, service_role;
