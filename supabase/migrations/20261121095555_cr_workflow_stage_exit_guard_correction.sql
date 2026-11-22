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
  v_rejected integer;
begin
  if current_setting('app.ppm_cr_transition',true) <> 'on' then
    if (to_jsonb(new)->array[
        'status','current_stage_id','workflow_version_id','submitted_at','decided_at',
        'closed_at','decision_reason','verified_by','verified_at','closure_evidence',
        'implementation_status'
      ]) is distinct from
       (to_jsonb(old)->array[
        'status','current_stage_id','workflow_version_id','submitted_at','decided_at',
        'closed_at','decision_reason','verified_by','verified_at','closure_evidence',
        'implementation_status'
      ]) then
      raise exception 'Change Request workflow fields can only be changed through the workflow action';
    end if;
  end if;

  if old.status <> 'draft' and
     (to_jsonb(new)->array['title','description','justification','request_type','category','priority','contract_id','contract_variation_id'])
       is distinct from
     (to_jsonb(old)->array['title','description','justification','request_type','category','priority','contract_id','contract_variation_id']) then
    raise exception 'Submitted Change Request details are immutable; use a new Change Request or configured amendment process';
  end if;

  if old.current_stage_id is not null and new.current_stage_id is distinct from old.current_stage_id then
    select * into v_old_stage from public.ppm_workflow_stages where id=old.current_stage_id;
    if cardinality(v_old_stage.required_role_codes)>0 then
      select coalesce(max(a.round_no),0) into v_round
      from public.project_change_request_approvals a
      where a.change_request_id=old.id and a.stage_id=old.current_stage_id;
      select count(*) filter (where a.status<>'approved'),
             count(*) filter (where a.status in ('rejected','returned'))
      into v_pending,v_rejected
      from public.project_change_request_approvals a
      where a.change_request_id=old.id and a.stage_id=old.current_stage_id
        and a.round_no=v_round;
      if coalesce(v_rejected,0)=0 and coalesce(v_pending,0)>0 then
        raise exception 'A stage with required approvers can only be exited after all approvals or a recorded rejection/return';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop function if exists private.set_cr_transition_action_context();
