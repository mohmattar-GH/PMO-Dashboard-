-- Keep privileged workflow execution outside the exposed API schema.
-- Public RPC wrappers are SECURITY INVOKER; the private implementations validate auth.uid()
-- and run with the narrowly scoped database-owner privileges needed for atomic writes.

alter function public.publish_ppm_workflow_version(uuid) set schema private;
alter function public.transition_project_change_request(uuid,text,text) set schema private;

grant usage on schema private to authenticated;
grant execute on function private.publish_ppm_workflow_version(uuid) to authenticated;
grant execute on function private.transition_project_change_request(uuid,text,text) to authenticated;

create or replace function public.publish_ppm_workflow_version(p_workflow_version_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.publish_ppm_workflow_version(p_workflow_version_id);
$$;

create or replace function public.transition_project_change_request(
  p_change_request_id uuid,
  p_action_code text,
  p_reason text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.transition_project_change_request(p_change_request_id,p_action_code,p_reason);
$$;

revoke all on function public.publish_ppm_workflow_version(uuid) from public, anon;
revoke all on function public.transition_project_change_request(uuid,text,text) from public, anon;
grant execute on function public.publish_ppm_workflow_version(uuid) to authenticated;
grant execute on function public.transition_project_change_request(uuid,text,text) to authenticated;

create or replace function private.guard_project_change_request_workflow_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_old_stage public.ppm_workflow_stages%rowtype;
  v_action text;
  v_pending integer;
  v_round integer;
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
      v_action := current_setting('app.ppm_cr_action',true);
      if v_action not in ('approve','reject','return') then
        raise exception 'A stage with required approvers can only be exited through an approval decision';
      end if;
      if v_action='approve' then
        select coalesce(max(a.round_no),0) into v_round
        from public.project_change_request_approvals a
        where a.change_request_id=old.id and a.stage_id=old.current_stage_id;
        select count(*) into v_pending
        from public.project_change_request_approvals a
        where a.change_request_id=old.id and a.stage_id=old.current_stage_id
          and a.round_no=v_round and a.status<>'approved';
        if v_pending>0 then raise exception 'All required approvals must be completed before advancing'; end if;
      end if;
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.guard_cr_approval_self_approval()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_requester uuid;
begin
  if new.status='approved' and old.status is distinct from 'approved' then
    select cr.requested_by into v_requester
    from public.project_change_requests cr
    where cr.id=new.change_request_id;
    if v_requester is not null and v_requester=auth.uid() then
      raise exception 'A Change Request requester cannot approve their own request';
    end if;
  end if;
  return new;
end;
$$;

create trigger project_cr_approval_self_approval_guard
before update on public.project_change_request_approvals
for each row execute function private.guard_cr_approval_self_approval();

-- Store the action code in transaction-local context so the row guard can enforce stage exits.
create or replace function private.set_cr_transition_action_context()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_setting('app.ppm_cr_transition',true)='on' then
    perform set_config('app.ppm_cr_action',coalesce(current_setting('app.ppm_cr_action',true),''),true);
  end if;
  return new;
end;
$$;

-- Add the action context immediately before the RPC changes the stage.
-- The RPC wrapper's private implementation sets this value through the guarded action path.
