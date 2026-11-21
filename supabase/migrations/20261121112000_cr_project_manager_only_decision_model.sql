
-- PM-only Change Request decision model.
-- Preserve historical approval rows but disable approval routing and client writes.

drop trigger if exists project_cr_approval_assignment_notifications on public.project_change_request_approvals;
drop trigger if exists project_cr_approval_self_approval_guard on public.project_change_request_approvals;
drop trigger if exists project_cr_apply_approved_changes on public.project_change_requests;

revoke insert, update, delete on public.project_change_request_approvals from anon, authenticated;

create or replace function private.guard_project_change_request_workflow_fields()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if (new.id,new.project_id,new.cr_reference,new.requested_by)
     is distinct from (old.id,old.project_id,old.cr_reference,old.requested_by) then
    raise exception 'Change Request identity and requester fields are immutable';
  end if;

  if coalesce(current_setting('app.ppm_cr_transition',true),'') <> 'on' then
    if (new.status,new.current_stage_id,new.submitted_at,new.decided_at,new.decided_by,new.closed_at,
        new.decision_reason,new.verified_by,new.verified_at,new.closure_evidence,new.implementation_status)
       is distinct from
       (old.status,old.current_stage_id,old.submitted_at,old.decided_at,old.decided_by,old.closed_at,
        old.decision_reason,old.verified_by,old.verified_at,old.closure_evidence,old.implementation_status) then
      raise exception 'Change Request lifecycle fields can only be changed through the PM-only CR actions';
    end if;
  end if;

  if old.status <> 'draft' and new.workflow_version_id is distinct from old.workflow_version_id then
    raise exception 'Impact-assessment configuration is fixed after submission';
  end if;
  if old.status <> 'draft' and
     (new.title,new.description,new.justification,new.request_type,new.category,new.priority,
      new.contract_id,new.contract_variation_id)
       is distinct from
     (old.title,old.description,old.justification,old.request_type,old.category,old.priority,
      old.contract_id,old.contract_variation_id) then
    raise exception 'Submitted Change Request details are immutable';
  end if;
  return new;
end;
$function$;

create or replace function private.transition_project_change_request(
  p_change_request_id uuid, p_action_code text, p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
begin
  raise exception 'CR approval routing is disabled. Use submit_project_change_request and decide_project_change_request.';
end;
$function$;

create or replace function private.submit_project_change_request(
  p_change_request_id uuid, p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_cr public.project_change_requests%rowtype;
  v_version public.ppm_workflow_template_versions%rowtype;
  v_pm uuid;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists (select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;

  select cr.* into v_cr
  from public.project_change_requests cr
  where cr.id=p_change_request_id
  for update;
  if not found then raise exception 'Change Request not found'; end if;
  if v_cr.status <> 'draft' then raise exception 'Only draft Change Requests can be submitted'; end if;
  if v_cr.requested_by <> v_uid and not exists (
    select 1 from public.project_memberships pm
    where pm.project_id=v_cr.project_id and pm.user_id=v_uid
      and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
  ) then
    raise exception 'Only the requester or an active Project Manager may submit this Change Request';
  end if;

  if v_cr.assigned_to is null then raise exception 'Assign the responsible Project Manager before submission'; end if;
  if not exists (
    select 1 from public.project_memberships pm
    where pm.project_id=v_cr.project_id and pm.user_id=v_cr.assigned_to
      and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
  ) then
    raise exception 'The assigned decision-maker must be an active Project Manager for this project';
  end if;

  if v_cr.workflow_version_id is null then raise exception 'Select an impact-assessment configuration before submission'; end if;
  select v.* into v_version
  from public.ppm_workflow_template_versions v
  join public.ppm_workflow_templates t on t.id=v.template_id
  where v.id=v_cr.workflow_version_id and t.module_code='change_request'
    and v.status='published' and v.effective_from<=now()
    and (v.effective_to is null or v.effective_to>now());
  if not found then raise exception 'The selected impact-assessment configuration is not published and effective'; end if;

  if not exists (
    select 1 from public.ppm_workflow_impact_dimensions d
    where d.workflow_version_id=v_version.id and d.is_required
  ) then raise exception 'The impact-assessment configuration has no required dimensions'; end if;

  if exists (
    select 1 from public.ppm_workflow_impact_dimensions d
    left join public.project_change_request_impacts i
      on i.change_request_id=v_cr.id and i.project_id=v_cr.project_id
     and i.impact_dimension=d.dimension_code
    where d.workflow_version_id=v_version.id and d.is_required
      and (i.id is null or i.assessment_status='not_assessed'
        or (i.assessment_status='assessed' and
            (i.assessed_by is null or i.assessed_at is null or nullif(btrim(i.impact_summary),'') is null))
        or (i.assessment_status='not_applicable' and nullif(btrim(i.not_applicable_reason),'') is null))
  ) then raise exception 'Every required impact dimension must be assessed or marked not applicable with a reason'; end if;

  if exists (
    select 1 from public.project_change_request_impacts i
    left join public.ppm_workflow_impact_dimensions d
      on d.workflow_version_id=v_version.id and d.dimension_code=i.impact_dimension
    where i.change_request_id=v_cr.id and i.project_id=v_cr.project_id and d.id is null
  ) then raise exception 'Remove impact assessments outside the selected configuration'; end if;

  perform set_config('app.ppm_cr_transition','on',true);
  update public.project_change_requests
  set status='submitted', current_stage_id=null, submitted_at=now(), updated_at=now()
  where id=v_cr.id;

  insert into public.project_change_request_history(
    change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
  ) values (
    v_cr.id,v_cr.project_id,'submitted',v_cr.status,'submitted',v_uid,
    nullif(btrim(p_reason),''),jsonb_build_object('assigned_project_manager',v_cr.assigned_to,
      'impact_configuration_version_id',v_version.id,'decision_model','project_manager_only')
  );

  return jsonb_build_object('change_request_id',v_cr.id,'status','submitted',
    'assigned_project_manager',v_cr.assigned_to,'submitted_at',now());
end;
$function$;

create or replace function private.decide_project_change_request(
  p_change_request_id uuid, p_decision text, p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_cr public.project_change_requests%rowtype;
  v_new_status text;
  v_financial_amount numeric(18,2);
  v_currency_count integer;
  v_currency char(3);
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_decision not in ('accept','reject') then raise exception 'Decision must be accept or reject'; end if;
  if length(btrim(coalesce(p_reason,''))) < 8 then raise exception 'A decision reason of at least 8 characters is required'; end if;
  if length(p_reason)>2000 then raise exception 'Decision reason cannot exceed 2000 characters'; end if;
  if not exists (select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;

  select cr.* into v_cr from public.project_change_requests cr
  where cr.id=p_change_request_id for update;
  if not found then raise exception 'Change Request not found'; end if;
  if v_cr.status <> 'submitted' then raise exception 'Only submitted Change Requests can receive a PM decision'; end if;
  if v_cr.assigned_to is distinct from v_uid then
    raise exception 'Only the assigned Project Manager may decide this Change Request';
  end if;
  if not exists (
    select 1 from public.project_memberships pm
    where pm.project_id=v_cr.project_id and pm.user_id=v_uid
      and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
  ) then
    raise exception 'An active Project Manager assignment is required to decide this Change Request';
  end if;
  if v_cr.requested_by=v_uid then raise exception 'The requester cannot decide their own Change Request'; end if;

  if p_decision='accept' then
    select coalesce(sum(i.cost_delta),0)::numeric(18,2),
      count(distinct upper(btrim(i.currency_code))),min(i.currency_code)
    into v_financial_amount,v_currency_count,v_currency
    from public.project_change_request_impacts i
    where i.change_request_id=v_cr.id and i.project_id=v_cr.project_id
      and i.assessment_status='assessed' and i.cost_delta is not null;

    if v_financial_amount<>0 then
      if v_cr.contract_id is null or v_cr.contract_variation_id is null or v_currency_count<>1 then
        raise exception 'A matching linked contract variation and one consistent currency are required for financial impact';
      end if;
      if not exists (
        select 1 from public.project_contract_variations v
        where v.id=v_cr.contract_variation_id and v.change_request_id=v_cr.id
          and v.project_id=v_cr.project_id and v.contract_id=v_cr.contract_id
          and v.status='draft' and v.amount_delta=v_financial_amount
          and upper(btrim(v.currency_code))=upper(btrim(v_currency))
      ) then raise exception 'The linked draft contract variation must match the assessed net impact and currency'; end if;
      if not exists (
        select 1 from public.project_contracts c
        join public.project_financial_terms ft on ft.project_id=c.project_id
        where c.id=v_cr.contract_id and c.project_id=v_cr.project_id
          and upper(btrim(c.currency_code))=upper(btrim(v_currency))
          and upper(btrim(ft.currency_code))=upper(btrim(v_currency))
      ) then raise exception 'Financial impact currency must match the contract and project financial terms'; end if;
    elsif v_cr.contract_variation_id is not null then
      raise exception 'A contract variation cannot be linked when the Change Request has no net financial impact';
    end if;
    v_new_status := 'accepted';
  else
    v_new_status := 'rejected';
  end if;

  perform set_config('app.ppm_cr_transition','on',true);
  update public.project_change_requests
  set status=v_new_status,current_stage_id=null,decided_by=v_uid,decided_at=now(),
      decision_reason=btrim(p_reason),updated_at=now()
  where id=v_cr.id;

  insert into public.project_change_request_history(
    change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
  ) values (
    v_cr.id,v_cr.project_id,'pm_'||p_decision,v_cr.status,v_new_status,v_uid,btrim(p_reason),
    jsonb_build_object('decision_model','project_manager_only','assigned_project_manager',v_cr.assigned_to)
  );

  return jsonb_build_object('change_request_id',v_cr.id,'status',v_new_status,
    'decided_by',v_uid,'decided_at',now(),'decision_model','project_manager_only');
end;
$function$;

create or replace function private.apply_pm_accepted_change_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_amount numeric(18,2);
  v_currency char(3);
  v_currency_count integer;
  v_schedule record;
  v_old_start date;
  v_old_due date;
  v_count integer := 0;
begin
  if old.status='accepted' or new.status<>'accepted' then return new; end if;
  if exists (select 1 from public.project_change_request_applications a where a.change_request_id=new.id) then
    raise exception 'This Change Request has already been applied';
  end if;

  select coalesce(sum(i.cost_delta),0)::numeric(18,2),
    count(distinct upper(btrim(i.currency_code))),min(i.currency_code)
  into v_amount,v_currency_count,v_currency
  from public.project_change_request_impacts i
  where i.change_request_id=new.id and i.project_id=new.project_id
    and i.assessment_status='assessed' and i.cost_delta is not null;

  if v_amount<>0 and (new.contract_variation_id is null or v_currency_count<>1) then
    raise exception 'A linked contract variation and one currency are required for financial impact';
  end if;
  if v_amount=0 and new.contract_variation_id is not null then
    raise exception 'A contract variation is linked but the Change Request has no net financial impact';
  end if;

  perform set_config('app.ppm_cr_apply','on',true);
  if new.contract_variation_id is not null then
    update public.project_contract_variations
    set status='approved',updated_at=now()
    where id=new.contract_variation_id and change_request_id=new.id
      and project_id=new.project_id and status='draft';
    if not found then raise exception 'Linked draft contract variation could not be approved'; end if;
  end if;

  for v_schedule in
    select * from public.project_change_request_schedule_changes
    where change_request_id=new.id and project_id=new.project_id and applied_at is null
    order by id for update
  loop
    if v_schedule.target_type='activity' then
      select approved_revised_start_date,approved_revised_due_date into v_old_start,v_old_due
      from public.project_activities where id=v_schedule.activity_id and project_id=new.project_id for update;
      if not found then raise exception 'Target activity no longer exists'; end if;
      update public.project_activities
      set approved_revised_start_date=coalesce(v_schedule.proposed_start_date,approved_revised_start_date),
          approved_revised_due_date=coalesce(v_schedule.proposed_due_date,approved_revised_due_date),
          updated_at=now()
      where id=v_schedule.activity_id and project_id=new.project_id;
    else
      select approved_revised_start_date,approved_revised_due_date into v_old_start,v_old_due
      from public.project_milestones where id=v_schedule.milestone_id and project_id=new.project_id for update;
      if not found then raise exception 'Target milestone no longer exists'; end if;
      update public.project_milestones
      set approved_revised_start_date=coalesce(v_schedule.proposed_start_date,approved_revised_start_date),
          approved_revised_due_date=coalesce(v_schedule.proposed_due_date,approved_revised_due_date),
          updated_at=now()
      where id=v_schedule.milestone_id and project_id=new.project_id;
    end if;
    update public.project_change_request_schedule_changes
    set previous_approved_revised_start_date=v_old_start,
        previous_approved_revised_due_date=v_old_due,applied_by=new.decided_by,applied_at=now()
    where id=v_schedule.id;
    v_count:=v_count+1;
  end loop;

  insert into public.project_change_request_applications(
    change_request_id,project_id,contract_variation_id,applied_by,financial_amount,currency_code,
    schedule_change_count,application_data
  ) values (
    new.id,new.project_id,new.contract_variation_id,new.decided_by,v_amount,
    case when v_amount<>0 then v_currency else null end,v_count,
    jsonb_build_object('decision_model','project_manager_only','decision_outcome','accepted',
      'schedule_changes_applied',v_count)
  );

  insert into public.project_change_request_history(
    change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
  ) values (
    new.id,new.project_id,'accepted_changes_applied',old.status,new.status,new.decided_by,
    'Accepted CR changes applied atomically',
    jsonb_build_object('contract_variation_id',new.contract_variation_id,
      'financial_amount',v_amount,'currency_code',v_currency,'schedule_change_count',v_count)
  );
  return new;
end;
$function$;

create trigger project_cr_apply_pm_acceptance
after update of status on public.project_change_requests
for each row execute function private.apply_pm_accepted_change_request();

create or replace function private.notify_change_request_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if old.status='draft' and new.status='submitted' then
    perform private.emit_ppm_notification(
      'change_request','cr_submitted',new.project_id,'project_change_requests',new.id,'submitted',
      'Change Request submitted',new.cr_reference||' — '||new.title,
      '/projects/'||new.project_id::text||'/change-requests/'||new.id::text,
      array[new.requested_by,new.assigned_to],auth.uid());
  elsif old.status='submitted' and new.status in ('accepted','rejected') then
    perform private.emit_ppm_notification(
      'change_request',case when new.status='accepted' then 'cr_accepted' else 'cr_rejected' end,
      new.project_id,'project_change_requests',new.id,new.status,
      case when new.status='accepted' then 'Change Request accepted' else 'Change Request rejected' end,
      new.cr_reference||' — '||new.title,
      '/projects/'||new.project_id::text||'/change-requests/'||new.id::text,
      array[new.requested_by],auth.uid());
  end if;
  return new;
end;
$function$;

create or replace function public.submit_project_change_request(
  p_change_request_id uuid, p_reason text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select private.submit_project_change_request(p_change_request_id,p_reason);
$function$;

create or replace function public.decide_project_change_request(
  p_change_request_id uuid, p_decision text, p_reason text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select private.decide_project_change_request(p_change_request_id,p_decision,p_reason);
$function$;

revoke all on function private.submit_project_change_request(uuid,text) from public, anon, authenticated;
revoke all on function private.decide_project_change_request(uuid,text,text) from public, anon, authenticated;
revoke all on function private.transition_project_change_request(uuid,text,text) from public, anon, authenticated;
grant execute on function public.submit_project_change_request(uuid,text) to authenticated;
grant execute on function public.decide_project_change_request(uuid,text,text) to authenticated;
revoke all on function public.transition_project_change_request(uuid,text,text) from public, anon, authenticated;

comment on function public.submit_project_change_request(uuid,text) is
'Submits a CR for review by its assigned Project Manager; no approval routing is created.';
comment on function public.decide_project_change_request(uuid,text,text) is
'Only the assigned active Project Manager may accept or reject a submitted CR. Finance/technical impact are inputs, not approvals.';
