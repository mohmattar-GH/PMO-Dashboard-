-- Configurable CR approval execution engine and immutable workflow publication.
-- All state transitions and approval writes are performed atomically by guarded RPCs.

alter table public.ppm_workflow_stages
  add column approval_mode text not null default 'parallel'
    check (approval_mode in ('parallel','sequential'));

alter table public.project_change_request_approvals
  add column round_no integer not null default 1 check (round_no > 0);

create unique index project_cr_approval_round_sequence_uq
  on public.project_change_request_approvals(change_request_id, stage_id, round_no, approval_sequence);

create table public.ppm_workflow_impact_dimensions (
  id uuid primary key default gen_random_uuid(),
  workflow_version_id uuid not null references public.ppm_workflow_template_versions(id) on delete restrict,
  dimension_code text not null,
  dimension_label text not null,
  is_required boolean not null default true,
  sequence_no integer not null default 1,
  created_at timestamptz not null default now(),
  unique (workflow_version_id, dimension_code),
  unique (workflow_version_id, sequence_no)
);
alter table public.ppm_workflow_impact_dimensions enable row level security;
create policy ppm_workflow_impact_dimensions_read
  on public.ppm_workflow_impact_dimensions for select to authenticated
  using (exists (
    select 1 from public.ppm_workflow_template_versions v
    join public.ppm_workflow_templates t on t.id=v.template_id
    where v.id=workflow_version_id
      and (t.is_global or exists (
        select 1 from public.project_memberships pm
        where pm.project_id=t.project_id and pm.user_id=(select auth.uid())
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
      ) or exists (
        select 1 from public.user_global_role_assignments ura
        where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
          and ura.status='active' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now())
      ))
  ));
create policy ppm_workflow_impact_dimensions_admin_insert
  on public.ppm_workflow_impact_dimensions for insert to authenticated
  with check (exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ));
create policy ppm_workflow_impact_dimensions_admin_update
  on public.ppm_workflow_impact_dimensions for update to authenticated
  using (exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ))
  with check (exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ));
grant select, insert, update on public.ppm_workflow_impact_dimensions to authenticated;

alter table public.project_change_request_impacts
  add constraint project_cr_impact_assessed_metadata_ck
  check (
    assessment_status <> 'assessed'
    or (assessed_by is not null and assessed_at is not null
        and nullif(btrim(impact_summary),'') is not null)
  );

create or replace function private.guard_ppm_workflow_child_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_version_id uuid;
  v_status text;
begin
  v_version_id := case when tg_op='DELETE' then old.workflow_version_id else new.workflow_version_id end;
  select status into v_status
  from public.ppm_workflow_template_versions
  where id=v_version_id;
  if not found then
    raise exception 'Workflow version not found';
  end if;
  if v_status <> 'draft' then
    raise exception 'Published workflow definitions are immutable; create a new version';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create trigger ppm_workflow_stages_immutable_guard
before insert or update or delete on public.ppm_workflow_stages
for each row execute function private.guard_ppm_workflow_child_mutation();
create trigger ppm_workflow_transitions_immutable_guard
before insert or update or delete on public.ppm_workflow_transitions
for each row execute function private.guard_ppm_workflow_child_mutation();
create trigger ppm_workflow_impact_dimensions_immutable_guard
before insert or update or delete on public.ppm_workflow_impact_dimensions
for each row execute function private.guard_ppm_workflow_child_mutation();

create or replace function private.guard_ppm_workflow_version_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op='DELETE' then
    if old.status <> 'draft' then
      raise exception 'Published workflow versions cannot be deleted';
    end if;
    return old;
  end if;

  if old.status='draft' and new.status='published' then
    if current_setting('app.ppm_publish_workflow', true) <> 'on' then
      raise exception 'Publish workflow versions through the publication action';
    end if;
    return new;
  end if;

  if old.status='published' and new.status='retired' then
    if (to_jsonb(new)-array['status','effective_to'])
       is distinct from (to_jsonb(old)-array['status','effective_to'])
       or new.effective_to is null or new.effective_to > now() then
      raise exception 'Retirement may only close the effective period of a published version';
    end if;
    return new;
  end if;

  raise exception 'Workflow version is immutable; create a new draft version';
end;
$$;

create trigger ppm_workflow_versions_immutable_guard
before update or delete on public.ppm_workflow_template_versions
for each row execute function private.guard_ppm_workflow_version_mutation();

create or replace function public.publish_ppm_workflow_version(p_workflow_version_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_version public.ppm_workflow_template_versions%rowtype;
  v_module text;
  v_stage_count integer;
  v_transition_count integer;
  v_dimension_count integer;
  v_effective_from timestamptz;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists (select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;
  if not exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=v_uid and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) then raise exception 'Platform Administrator access required'; end if;

  select v.* into v_version
  from public.ppm_workflow_template_versions v
  where v.id=p_workflow_version_id
  for update;
  if not found then raise exception 'Workflow version not found'; end if;
  if v_version.status <> 'draft' then raise exception 'Only draft workflow versions can be published'; end if;

  select t.module_code into v_module
  from public.ppm_workflow_templates t where t.id=v_version.template_id;
  if v_module is null then raise exception 'Workflow template not found'; end if;

  select count(*) into v_stage_count
  from public.ppm_workflow_stages s where s.workflow_version_id=v_version.id;
  if v_stage_count < 1 then raise exception 'A workflow must contain at least one stage'; end if;

  select count(*) into v_transition_count
  from public.ppm_workflow_transitions tr where tr.workflow_version_id=v_version.id;
  if exists (
    select 1 from public.ppm_workflow_stages s
    where s.workflow_version_id=v_version.id and not s.is_terminal
      and not exists (
        select 1 from public.ppm_workflow_transitions tr
        where tr.workflow_version_id=v_version.id and tr.from_stage_id=s.id
      )
  ) then raise exception 'Every non-terminal stage must have at least one configured transition'; end if;

  if exists (
    select 1 from public.ppm_workflow_stages s
    cross join lateral unnest(s.required_role_codes) as r(role_code)
    where s.workflow_version_id=v_version.id
      and not (
        r.role_code in ('project_manager','finance','team_lead','project_viewer',
                        'platform_admin','executive_viewer','configuration_steward',
                        'configuration_approver','finance_admin')
      )
  ) then raise exception 'Workflow stages contain an unsupported role code'; end if;

  if exists (
    select 1 from public.ppm_workflow_transitions tr
    cross join lateral unnest(tr.allowed_role_codes) as r(role_code)
    where tr.workflow_version_id=v_version.id
      and not (
        r.role_code in ('project_manager','finance','team_lead','project_viewer',
                        'platform_admin','executive_viewer','configuration_steward',
                        'configuration_approver','finance_admin')
      )
  ) then raise exception 'Workflow transitions contain an unsupported role code'; end if;

  if v_module='change_request' then
    select count(*) into v_dimension_count
    from public.ppm_workflow_impact_dimensions d
    where d.workflow_version_id=v_version.id and d.is_required;
    if v_dimension_count < 1 then
      raise exception 'Configure at least one required impact dimension before publishing a Change Request workflow';
    end if;
  end if;

  if exists (
    select 1 from public.ppm_workflow_template_versions other
    where other.template_id=v_version.template_id and other.id<>v_version.id
      and other.status='published'
      and (other.effective_to is null or other.effective_to>coalesce(v_version.effective_from,now()))
  ) then
    raise exception 'Retire or close the currently published version before publishing another version';
  end if;

  v_effective_from := coalesce(v_version.effective_from, now());
  perform set_config('app.ppm_publish_workflow','on',true);
  update public.ppm_workflow_template_versions
  set status='published', effective_from=v_effective_from,
      published_by=v_uid, published_at=now()
  where id=v_version.id;

  return jsonb_build_object(
    'workflow_version_id',v_version.id,
    'version_no',v_version.version_no,
    'status','published',
    'published_at',now(),
    'stage_count',v_stage_count,
    'transition_count',v_transition_count,
    'required_impact_dimensions',v_dimension_count
  );
end;
$$;

create or replace function private.guard_project_change_request_workflow_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_setting('app.ppm_cr_transition',true)='on' then return new; end if;

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

  if old.status <> 'draft' and
     (to_jsonb(new)->array['title','description','justification','request_type','category','priority','contract_id','contract_variation_id'])
       is distinct from
     (to_jsonb(old)->array['title','description','justification','request_type','category','priority','contract_id','contract_variation_id']) then
    raise exception 'Submitted Change Request details are immutable; use a new Change Request or configured amendment process';
  end if;
  return new;
end;
$$;

create trigger project_change_requests_workflow_fields_guard
before update on public.project_change_requests
for each row execute function private.guard_project_change_request_workflow_fields();

create or replace function public.transition_project_change_request(
  p_change_request_id uuid,
  p_action_code text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_cr public.project_change_requests%rowtype;
  v_version public.ppm_workflow_template_versions%rowtype;
  v_stage public.ppm_workflow_stages%rowtype;
  v_to_stage public.ppm_workflow_stages%rowtype;
  v_transition public.ppm_workflow_transitions%rowtype;
  v_approval public.project_change_request_approvals%rowtype;
  v_actor_roles text[] := array[]::text[];
  v_round integer;
  v_stage_approval_count integer;
  v_pending_count integer;
  v_first_stage boolean;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists (select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;
  if p_action_code is null or p_action_code !~ '^[a-z][a-z0-9_]{1,63}$' then
    raise exception 'Invalid workflow action code';
  end if;
  if p_reason is not null and length(btrim(p_reason))>2000 then
    raise exception 'Reason cannot exceed 2000 characters';
  end if;

  select cr.* into v_cr
  from public.project_change_requests cr
  where cr.id=p_change_request_id
  for update;
  if not found then raise exception 'Change Request not found'; end if;

  select coalesce(array_agg(distinct role_code),array[]::text[]) into v_actor_roles
  from (
    select pm.project_role as role_code
    from public.project_memberships pm
    where pm.project_id=v_cr.project_id and pm.user_id=v_uid
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
    union all
    select ura.role_code
    from public.user_global_role_assignments ura
    where ura.user_id=v_uid and ura.status='active'
      and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) roles;

  if v_cr.status='draft' and p_action_code='submit' then
    if not (v_actor_roles && array['project_manager','platform_admin']::text[]) then
      raise exception 'Only an active Project Manager or Platform Administrator may submit a Change Request';
    end if;
    if v_cr.workflow_version_id is null then raise exception 'Select a published Change Request workflow before submission'; end if;

    select v.* into v_version
    from public.ppm_workflow_template_versions v
    join public.ppm_workflow_templates t on t.id=v.template_id
    where v.id=v_cr.workflow_version_id and t.module_code='change_request'
      and v.status='published'
      and v.effective_from<=now() and (v.effective_to is null or v.effective_to>now())
    for share of v;
    if not found then raise exception 'The selected Change Request workflow is not currently published and effective'; end if;

    if not exists (
      select 1 from public.ppm_workflow_impact_dimensions d
      where d.workflow_version_id=v_version.id and d.is_required
    ) then raise exception 'The workflow has no required impact dimensions'; end if;

    if exists (
      select 1
      from public.ppm_workflow_impact_dimensions d
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
    ) then raise exception 'Remove impact assessments that are not part of the selected workflow version'; end if;

    select s.* into v_stage
    from public.ppm_workflow_stages s
    where s.workflow_version_id=v_version.id
    order by s.sequence_no
    limit 1;
    if not found or v_stage.is_terminal then raise exception 'Workflow must start with a non-terminal stage'; end if;

    perform set_config('app.ppm_cr_transition','on',true);
    update public.project_change_requests
    set status=v_stage.stage_code, current_stage_id=v_stage.id, submitted_at=now(), updated_at=now()
    where id=v_cr.id;

    insert into public.project_change_request_approvals(
      change_request_id,project_id,stage_id,approval_sequence,round_no,
      approver_role_code,status
    )
    select v_cr.id,v_cr.project_id,v_stage.id,roles.ordinality::integer,1,
           roles.role_code,'pending'
    from unnest(v_stage.required_role_codes) with ordinality as roles(role_code,ordinality);

    insert into public.project_change_request_history(
      change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
    ) values (
      v_cr.id,v_cr.project_id,'submit',v_cr.status,v_stage.stage_code,v_uid,
      nullif(btrim(p_reason),''),jsonb_build_object('workflow_version_id',v_version.id,'stage_id',v_stage.id)
    );

    return jsonb_build_object('change_request_id',v_cr.id,'status',v_stage.stage_code,
      'stage_id',v_stage.id,'approval_mode',v_stage.approval_mode,'submitted_at',now());
  end if;

  if v_cr.current_stage_id is null or v_cr.workflow_version_id is null then
    raise exception 'Change Request has no active workflow stage';
  end if;

  select s.* into v_stage from public.ppm_workflow_stages s
  where s.id=v_cr.current_stage_id and s.workflow_version_id=v_cr.workflow_version_id;
  if not found then raise exception 'Current workflow stage is invalid'; end if;
  if v_stage.is_terminal then raise exception 'Change Request is already in a terminal stage'; end if;

  select tr.* into v_transition
  from public.ppm_workflow_transitions tr
  where tr.workflow_version_id=v_cr.workflow_version_id
    and tr.from_stage_id=v_stage.id and tr.action_code=p_action_code;
  if not found then raise exception 'This action is not configured for the current stage'; end if;
  if cardinality(v_transition.allowed_role_codes)=0
     or not (v_actor_roles && v_transition.allowed_role_codes) then
    raise exception 'Your active project/global roles are not permitted to perform this action';
  end if;
  if v_transition.requires_comment and length(btrim(coalesce(p_reason,'')))<8 then
    raise exception 'A reason of at least 8 characters is required for this action';
  end if;
  if v_transition.prevents_self_approval and v_cr.requested_by=v_uid then
    raise exception 'The Change Request requester cannot approve their own request';
  end if;

  select coalesce(max(a.round_no),0) into v_round
  from public.project_change_request_approvals a
  where a.change_request_id=v_cr.id and a.stage_id=v_stage.id;

  select count(*) into v_stage_approval_count
  from public.project_change_request_approvals a
  where a.change_request_id=v_cr.id and a.stage_id=v_stage.id and a.round_no=v_round;

  if p_action_code in ('approve','reject','return') and v_stage_approval_count>0 then
    select a.* into v_approval
    from public.project_change_request_approvals a
    where a.change_request_id=v_cr.id and a.stage_id=v_stage.id
      and a.round_no=v_round and a.status='pending'
      and (
        a.approver_user_id=v_uid
        or a.approver_role_code=any(v_actor_roles)
      )
      and (
        v_stage.approval_mode='parallel'
        or not exists (
          select 1 from public.project_change_request_approvals earlier
          where earlier.change_request_id=v_cr.id and earlier.stage_id=v_stage.id
            and earlier.round_no=v_round
            and earlier.approval_sequence<a.approval_sequence
            and earlier.status<>'approved'
        )
      )
    order by a.approval_sequence
    limit 1
    for update;
    if not found then raise exception 'No pending approval assigned to your active role, or an earlier sequential approval is outstanding'; end if;

    update public.project_change_request_approvals
    set status=case p_action_code when 'approve' then 'approved'
              when 'reject' then 'rejected' else 'returned' end,
        decision=p_action_code,
        decision_reason=nullif(btrim(p_reason),''),
        decided_at=now()
    where id=v_approval.id;

    if p_action_code='approve' then
      select count(*) into v_pending_count
      from public.project_change_request_approvals a
      where a.change_request_id=v_cr.id and a.stage_id=v_stage.id
        and a.round_no=v_round and a.status<>'approved';
      if v_pending_count>0 then
        insert into public.project_change_request_history(
          change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
        ) values (
          v_cr.id,v_cr.project_id,'approval_approved',v_cr.status,v_cr.status,v_uid,
          nullif(btrim(p_reason),''),jsonb_build_object('approval_id',v_approval.id,'remaining_approvals',v_pending_count)
        );
        return jsonb_build_object('change_request_id',v_cr.id,'status',v_cr.status,
          'stage_id',v_stage.id,'approval_complete',false,'remaining_approvals',v_pending_count);
      end if;
    end if;
  elsif p_action_code in ('approve','reject','return') and cardinality(v_stage.required_role_codes)>0 then
    raise exception 'Approval assignments are missing for this workflow stage';
  end if;

  select s.* into v_to_stage
  from public.ppm_workflow_stages s
  where s.id=v_transition.to_stage_id and s.workflow_version_id=v_cr.workflow_version_id;
  if not found then raise exception 'Configured target stage is missing'; end if;

  if 'implementation_owner_assigned'=any(v_to_stage.required_fields)
     and v_cr.implementation_owner_id is null then
    raise exception 'Assign an implementation owner before entering this stage';
  end if;
  if 'implementation_due_date_set'=any(v_to_stage.required_fields)
     and v_cr.implementation_due_date is null then
    raise exception 'Set an implementation due date before entering this stage';
  end if;
  if 'implementation_complete'=any(v_to_stage.required_fields)
     and v_cr.implementation_status is distinct from 'completed' then
    raise exception 'Implementation must be marked completed before entering this stage';
  end if;
  if 'verification_complete'=any(v_to_stage.required_fields)
     and (v_cr.verified_by is null or v_cr.verified_at is null) then
    raise exception 'Verification must be recorded before entering this stage';
  end if;
  if 'closure_evidence'=any(v_to_stage.required_fields)
     and nullif(btrim(coalesce(v_cr.closure_evidence,'')),'') is null then
    raise exception 'Closure evidence is required before entering this stage';
  end if;
  if exists (
    select 1 from unnest(v_to_stage.required_fields) f(field_code)
    where f.field_code not in ('impact_assessments_complete','implementation_owner_assigned',
      'implementation_due_date_set','implementation_complete','verification_complete','closure_evidence')
  ) then raise exception 'Target stage contains an unsupported required-field rule'; end if;

  perform set_config('app.ppm_cr_transition','on',true);
  update public.project_change_requests
  set status=v_to_stage.stage_code,
      current_stage_id=v_to_stage.id,
      decided_at=case when v_to_stage.is_terminal then coalesce(decided_at,now()) else decided_at end,
      closed_at=case when v_to_stage.is_terminal and v_to_stage.stage_code='closed' then now() else closed_at end,
      decision_reason=case when p_action_code in ('reject','return') then nullif(btrim(p_reason),'') else decision_reason end,
      verified_by=case when p_action_code='verify' then v_uid else verified_by end,
      verified_at=case when p_action_code='verify' then now() else verified_at end,
      implementation_status=case when p_action_code='start_implementation' then 'in_progress'
        when p_action_code='complete_implementation' then 'completed' else implementation_status end,
      closure_evidence=case when p_action_code='close' then nullif(btrim(p_reason),'') else closure_evidence end,
      updated_at=now()
  where id=v_cr.id;

  if not v_to_stage.is_terminal then
    select coalesce(max(a.round_no),0)+1 into v_round
    from public.project_change_request_approvals a
    where a.change_request_id=v_cr.id and a.stage_id=v_to_stage.id;

    insert into public.project_change_request_approvals(
      change_request_id,project_id,stage_id,approval_sequence,round_no,
      approver_role_code,status
    )
    select v_cr.id,v_cr.project_id,v_to_stage.id,roles.ordinality::integer,v_round,
           roles.role_code,'pending'
    from unnest(v_to_stage.required_role_codes) with ordinality as roles(role_code,ordinality);
  end if;

  insert into public.project_change_request_history(
    change_request_id,project_id,event_code,from_status,to_status,actor_user_id,event_reason,event_data
  ) values (
    v_cr.id,v_cr.project_id,p_action_code,v_cr.status,v_to_stage.stage_code,v_uid,
    nullif(btrim(p_reason),''),jsonb_build_object(
      'from_stage_id',v_stage.id,'to_stage_id',v_to_stage.id,
      'approval_id',case when v_approval.id is not null then v_approval.id else null end
    )
  );

  return jsonb_build_object('change_request_id',v_cr.id,'status',v_to_stage.stage_code,
    'stage_id',v_to_stage.id,'terminal',v_to_stage.is_terminal,'action',p_action_code);
end;
$$;

-- The workflow engine is the only writer of approval decisions and CR lifecycle fields.
drop policy if exists project_cr_approvals_assignee_update on public.project_change_request_approvals;
revoke insert, update, delete on public.project_change_request_approvals from anon, authenticated;
revoke insert, update, delete on public.project_change_request_history from anon, authenticated;
revoke all on function public.publish_ppm_workflow_version(uuid) from public, anon;
revoke all on function public.transition_project_change_request(uuid,text,text) from public, anon;
grant execute on function public.publish_ppm_workflow_version(uuid) to authenticated;
grant execute on function public.transition_project_change_request(uuid,text,text) to authenticated;
