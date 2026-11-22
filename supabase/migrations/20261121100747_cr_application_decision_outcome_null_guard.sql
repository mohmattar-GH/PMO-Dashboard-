create or replace function private.apply_approved_change_request_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_stage public.ppm_workflow_stages%rowtype;
  v_financial_amount numeric(18,2);
  v_currency char(3);
  v_currency_count integer;
  v_finance_approver uuid;
  v_schedule record;
  v_old_start date;
  v_old_due date;
  v_schedule_count integer:=0;
begin
  if new.current_stage_id is not distinct from old.current_stage_id then return new; end if;
  select s.* into v_stage from public.ppm_workflow_stages s where s.id=new.current_stage_id;
  if not found or coalesce(v_stage.decision_outcome,'')<>'approved' then return new; end if;

  if exists(select 1 from public.project_change_request_applications a where a.change_request_id=new.id) then
    return new;
  end if;

  if exists (
    select 1 from public.project_change_request_approvals a
    where a.change_request_id=new.id
      and a.round_no=(select max(latest.round_no) from public.project_change_request_approvals latest
                     where latest.change_request_id=a.change_request_id and latest.stage_id=a.stage_id)
      and a.status<>'approved'
  ) then raise exception 'All configured approval stages must be complete before applying an approved Change Request'; end if;

  select coalesce(sum(i.cost_delta),0)::numeric(18,2),
         count(distinct upper(btrim(i.currency_code))),min(i.currency_code)
  into v_financial_amount,v_currency_count,v_currency
  from public.project_change_request_impacts i
  where i.change_request_id=new.id and i.project_id=new.project_id
    and i.assessment_status='assessed' and i.cost_delta is not null;

  if v_financial_amount<>0 then
    if new.contract_variation_id is null or v_currency_count<>1 then
      raise exception 'A matching linked contract variation and one currency are required to apply financial impact';
    end if;
    select a.decided_by into v_finance_approver
    from public.project_change_request_approvals a
    where a.change_request_id=new.id
      and a.approver_role_code in ('finance','finance_admin')
      and a.status='approved' and a.decided_by is not null
      and a.round_no=(select max(latest.round_no) from public.project_change_request_approvals latest
                     where latest.change_request_id=a.change_request_id and latest.stage_id=a.stage_id)
    order by a.decided_at desc,a.id limit 1;
    if v_finance_approver is null then raise exception 'A recorded Finance approval is required for financial CR application'; end if;
  elsif new.contract_variation_id is not null then
    raise exception 'A contract variation is linked but the approved CR has no net financial impact';
  end if;

  perform set_config('app.ppm_cr_apply','on',true);

  if new.contract_variation_id is not null then
    update public.project_contract_variations
    set status='approved',updated_at=now()
    where id=new.contract_variation_id and change_request_id=new.id and status='draft';
    if not found then raise exception 'The linked draft contract variation could not be approved'; end if;
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
        previous_approved_revised_due_date=v_old_due,
        applied_by=new.decided_by,applied_at=now()
    where id=v_schedule.id;
    v_schedule_count:=v_schedule_count+1;
  end loop;

  insert into public.project_change_request_applications(
    change_request_id,project_id,contract_variation_id,applied_by,financial_amount,currency_code,
    schedule_change_count,application_data
  ) values (
    new.id,new.project_id,new.contract_variation_id,new.decided_by,v_financial_amount,
    case when v_financial_amount<>0 then v_currency else null end,
    v_schedule_count,
    jsonb_build_object('decision_stage_id',new.current_stage_id,'decision_outcome','approved',
      'finance_approver_id',v_finance_approver,'schedule_changes_applied',v_schedule_count)
  );

  insert into public.project_change_request_history(
    change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
  ) values (
    new.id,new.project_id,'approved_changes_applied',old.status,new.status,new.decided_by,
    'Approved CR changes applied atomically',
    jsonb_build_object('contract_variation_id',new.contract_variation_id,
      'financial_amount',v_financial_amount,'currency_code',v_currency,
      'schedule_change_count',v_schedule_count)
  );
  return new;
end;
$$;
