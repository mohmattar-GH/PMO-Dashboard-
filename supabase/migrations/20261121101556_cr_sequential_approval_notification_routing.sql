create or replace function private.notify_change_request_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_stage public.ppm_workflow_stages%rowtype;
begin
  if old.status='draft' and new.status<>'draft' then
    perform private.emit_ppm_notification(
      'change_request','cr_submitted',new.project_id,'project_change_requests',new.id,'submitted',
      'Change Request submitted',new.cr_reference||' — '||new.title,
      '/projects/'||new.project_id::text||'/change-requests/'||new.id::text,
      array[new.requested_by],auth.uid());
  end if;
  if new.current_stage_id is distinct from old.current_stage_id then
    select s.* into v_stage from public.ppm_workflow_stages s where s.id=new.current_stage_id;
    if found and v_stage.decision_outcome='approved' then
      perform private.emit_ppm_notification('change_request','cr_approved',new.project_id,
        'project_change_requests',new.id,new.current_stage_id::text,'Change Request approved',
        new.cr_reference||' has been approved',
        '/projects/'||new.project_id::text||'/change-requests/'||new.id::text,
        array[new.requested_by],auth.uid());
    elsif found and v_stage.decision_outcome='rejected' then
      perform private.emit_ppm_notification('change_request','cr_rejected',new.project_id,
        'project_change_requests',new.id,new.current_stage_id::text,'Change Request decision recorded',
        new.cr_reference||' has been rejected',
        '/projects/'||new.project_id::text||'/change-requests/'||new.id::text,
        array[new.requested_by],auth.uid());
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.notify_cr_approval_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mode text;
  v_cr public.project_change_requests%rowtype;
  v_next public.project_change_request_approvals%rowtype;
  v_targets uuid[];
begin
  select s.approval_mode into v_mode
  from public.ppm_workflow_stages s where s.id=new.stage_id;

  if tg_op='INSERT' and new.status='pending' then
    if v_mode='sequential' and exists (
      select 1 from public.project_change_request_approvals earlier
      where earlier.change_request_id=new.change_request_id and earlier.stage_id=new.stage_id
        and earlier.round_no=new.round_no and earlier.approval_sequence<new.approval_sequence
        and earlier.status<>'approved'
    ) then return new; end if;

    select cr.* into v_cr from public.project_change_requests cr where cr.id=new.change_request_id;
    select array_agg(distinct candidates.user_id) into v_targets
    from (
      select new.approver_user_id as user_id where new.approver_user_id is not null
      union
      select pm.user_id from public.project_memberships pm
      where pm.project_id=new.project_id and pm.project_role=new.approver_role_code
        and pm.status='active' and pm.effective_from<=now()
        and (pm.effective_to is null or pm.effective_to>now())
      union
      select ura.user_id from public.user_global_role_assignments ura
      where ura.role_code=new.approver_role_code and ura.status='active'
        and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now())
    ) candidates;
    if coalesce(cardinality(v_targets),0)>0 then
      perform private.emit_ppm_notification('change_request','cr_approval_needed',new.project_id,
        'project_change_request_approvals',new.id,
        new.stage_id::text||':'||new.round_no::text||':'||new.approval_sequence::text,
        'Approval required','Your approval is required for '||v_cr.cr_reference||' — '||v_cr.title,
        '/projects/'||new.project_id::text||'/change-requests/'||new.change_request_id::text,
        v_targets,auth.uid());
    end if;
  elsif tg_op='UPDATE' and old.status='pending' and new.status='approved' and v_mode='sequential' then
    select a.* into v_next
    from public.project_change_request_approvals a
    where a.change_request_id=new.change_request_id and a.stage_id=new.stage_id
      and a.round_no=new.round_no and a.status='pending'
      and a.approval_sequence>new.approval_sequence
    order by a.approval_sequence limit 1;
    if found then
      select cr.* into v_cr from public.project_change_requests cr where cr.id=new.change_request_id;
      select array_agg(distinct candidates.user_id) into v_targets
      from (
        select v_next.approver_user_id as user_id where v_next.approver_user_id is not null
        union
        select pm.user_id from public.project_memberships pm
        where pm.project_id=v_next.project_id and pm.project_role=v_next.approver_role_code
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
        union
        select ura.user_id from public.user_global_role_assignments ura
        where ura.role_code=v_next.approver_role_code and ura.status='active'
          and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now())
      ) candidates;
      if coalesce(cardinality(v_targets),0)>0 then
        perform private.emit_ppm_notification('change_request','cr_approval_needed',new.project_id,
          'project_change_request_approvals',v_next.id,
          v_next.stage_id::text||':'||v_next.round_no::text||':'||v_next.approval_sequence::text,
          'Approval required','Your approval is now required for '||v_cr.cr_reference||' — '||v_cr.title,
          '/projects/'||new.project_id::text||'/change-requests/'||new.change_request_id::text,
          v_targets,auth.uid());
      end if;
    end if;
  elsif tg_op='UPDATE' and old.status='pending' and new.status in ('rejected','returned') then
    select cr.* into v_cr from public.project_change_requests cr where cr.id=new.change_request_id;
    perform private.emit_ppm_notification('change_request',
      case new.status when 'rejected' then 'cr_approval_rejected' else 'cr_approval_returned' end,
      new.project_id,'project_change_request_approvals',new.id,
      new.stage_id::text||':'||new.round_no::text||':'||new.approval_sequence::text,
      'Change Request approval decision',v_cr.cr_reference||' received a '||new.status||' decision',
      '/projects/'||new.project_id::text||'/change-requests/'||new.change_request_id::text,
      array[v_cr.requested_by],auth.uid());
  end if;
  return new;
end;
$$;
create trigger project_cr_approval_assignment_notifications
after insert or update on public.project_change_request_approvals
for each row execute function private.notify_cr_approval_assignment();
