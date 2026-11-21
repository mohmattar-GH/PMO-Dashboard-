-- Apply an approved Change Request once to its linked contract variation and revised schedule.
-- Baseline dates remain immutable; only approved revised dates are updated.

alter table public.ppm_workflow_stages
  add column decision_outcome text
  check (decision_outcome in ('approved','rejected'));

alter table public.project_change_requests
  add column decided_by uuid references auth.users(id) on delete restrict;

alter table public.project_change_request_approvals
  add column decided_by uuid references auth.users(id) on delete restrict;

alter table public.project_contract_variations
  add column change_request_id uuid;

alter table public.project_contract_variations
  add constraint project_variations_change_request_project_fk
  foreign key (change_request_id,project_id)
  references public.project_change_requests(id,project_id) on delete restrict;

create unique index project_variations_change_request_uq
  on public.project_contract_variations(change_request_id)
  where change_request_id is not null;

create unique index project_variations_id_project_contract_uq
  on public.project_contract_variations(id,project_id,contract_id);

alter table public.project_change_requests
  drop constraint project_change_requests_variation_fk;
alter table public.project_change_requests
  add constraint project_change_requests_variation_scope_fk
  foreign key (contract_variation_id,project_id,contract_id)
  references public.project_contract_variations(id,project_id,contract_id)
  on delete restrict;
alter table public.project_change_requests
  add constraint project_cr_variation_requires_contract_ck
  check (contract_variation_id is null or contract_id is not null);

create table public.project_change_request_schedule_changes (
  id uuid primary key default gen_random_uuid(),
  change_request_id uuid not null,
  project_id uuid not null,
  target_type text not null check (target_type in ('activity','milestone')),
  activity_id uuid,
  milestone_id uuid,
  proposed_start_date date,
  proposed_due_date date,
  change_reason text not null,
  previous_approved_revised_start_date date,
  previous_approved_revised_due_date date,
  applied_by uuid references auth.users(id) on delete restrict,
  applied_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint cr_schedule_change_target_ck check (
    (target_type='activity' and activity_id is not null and milestone_id is null)
    or (target_type='milestone' and milestone_id is not null and activity_id is null)
  ),
  constraint cr_schedule_change_dates_ck check (
    (proposed_start_date is not null or proposed_due_date is not null)
    and (proposed_start_date is null or proposed_due_date is null or proposed_start_date<=proposed_due_date)
  ),
  constraint cr_schedule_change_application_ck check (
    (applied_at is null and applied_by is null)
    or (applied_at is not null and applied_by is not null)
  ),
  constraint cr_schedule_change_request_project_fk
    foreign key (change_request_id,project_id)
    references public.project_change_requests(id,project_id) on delete restrict,
  constraint cr_schedule_change_activity_project_fk
    foreign key (activity_id,project_id)
    references public.project_activities(id,project_id) on delete restrict,
  constraint cr_schedule_change_milestone_project_fk
    foreign key (milestone_id,project_id)
    references public.project_milestones(id,project_id) on delete restrict
);
create unique index cr_schedule_change_activity_uq
  on public.project_change_request_schedule_changes(change_request_id,activity_id)
  where activity_id is not null;
create unique index cr_schedule_change_milestone_uq
  on public.project_change_request_schedule_changes(change_request_id,milestone_id)
  where milestone_id is not null;
create index cr_schedule_change_project_idx
  on public.project_change_request_schedule_changes(project_id,change_request_id);

alter table public.project_change_request_schedule_changes enable row level security;
create policy cr_schedule_changes_read on public.project_change_request_schedule_changes
for select to authenticated using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id=project_change_request_schedule_changes.project_id
      and pm.user_id=(select auth.uid()) and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','executive_viewer')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  )
);
create policy cr_schedule_changes_insert_pm on public.project_change_request_schedule_changes
for insert to authenticated with check (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id=project_change_request_schedule_changes.project_id
      and pm.user_id=(select auth.uid()) and pm.project_role='project_manager'
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  )
);
grant select,insert on public.project_change_request_schedule_changes to authenticated;
revoke update,delete on public.project_change_request_schedule_changes from anon,authenticated;

create table public.project_change_request_applications (
  id uuid primary key default gen_random_uuid(),
  change_request_id uuid not null,
  project_id uuid not null,
  contract_variation_id uuid references public.project_contract_variations(id) on delete restrict,
  applied_by uuid not null references auth.users(id) on delete restrict,
  applied_at timestamptz not null default now(),
  financial_amount numeric(18,2) not null default 0,
  currency_code char(3),
  schedule_change_count integer not null default 0 check (schedule_change_count>=0),
  application_data jsonb not null default '{}'::jsonb,
  constraint cr_application_request_uq unique(change_request_id),
  constraint cr_application_request_project_fk
    foreign key (change_request_id,project_id)
    references public.project_change_requests(id,project_id) on delete restrict
);
create index cr_applications_project_applied_idx
  on public.project_change_request_applications(project_id,applied_at desc);
alter table public.project_change_request_applications enable row level security;
create policy cr_applications_read_finance_pm on public.project_change_request_applications
for select to authenticated using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id=project_change_request_applications.project_id
      and pm.user_id=(select auth.uid()) and pm.project_role in ('project_manager','finance')
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  )
);
grant select on public.project_change_request_applications to authenticated;
revoke insert,update,delete on public.project_change_request_applications from anon,authenticated;

create or replace function private.guard_cr_approval_self_approval()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_requester uuid;
begin
  if new.status in ('approved','rejected','returned')
     and old.status='pending' then
    select cr.requested_by into v_requester
    from public.project_change_requests cr
    where cr.id=new.change_request_id;
    if new.status='approved' and v_requester is not null and v_requester=auth.uid() then
      raise exception 'A Change Request requester cannot approve their own request';
    end if;
    new.decision := new.status;
    new.decided_by := auth.uid();
    perform set_config('app.ppm_cr_approval_result',new.status,true);
  end if;
  return new;
end;
$$;

create or replace function private.stamp_cr_decision_actor()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_outcome text;
begin
  if new.current_stage_id is distinct from old.current_stage_id then
    select s.decision_outcome into v_outcome
    from public.ppm_workflow_stages s
    where s.id=new.current_stage_id;
    if v_outcome is not null then
      new.decided_by := auth.uid();
      new.decided_at := now();
    end if;
  end if;
  return new;
end;
$$;
create trigger project_cr_decision_actor_stamp
before update on public.project_change_requests
for each row execute function private.stamp_cr_decision_actor();

create or replace function private.validate_cr_financial_submission()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_total numeric(18,2);
  v_currency_count integer;
  v_currency char(3);
  v_terms_currency char(3);
  v_contract_currency char(3);
  v_variation public.project_contract_variations%rowtype;
begin
  if old.status='draft' and new.status<>'draft' then
    select coalesce(sum(i.cost_delta),0)::numeric(18,2),
           count(distinct upper(btrim(i.currency_code))),
           min(i.currency_code)
    into v_total,v_currency_count,v_currency
    from public.project_change_request_impacts i
    where i.change_request_id=new.id and i.project_id=new.project_id
      and i.assessment_status='assessed' and i.cost_delta is not null;

    if v_total<>0 then
      if new.contract_id is null or new.contract_variation_id is null then
        raise exception 'Create and link a contract variation before submitting a financially impactful Change Request';
      end if;
      if v_currency_count<>1 then raise exception 'Financial impacts must use one consistent currency'; end if;
      if not exists (
        select 1 from public.ppm_workflow_stages s
        where s.workflow_version_id=new.workflow_version_id
          and s.required_role_codes && array['finance','finance_admin']::text[]
      ) then raise exception 'A financially impactful Change Request requires a Finance approval stage'; end if;

      select currency_code into v_terms_currency
      from public.project_financial_terms where project_id=new.project_id;
      select currency_code into v_contract_currency
      from public.project_contracts where id=new.contract_id and project_id=new.project_id;
      if v_terms_currency is null or v_contract_currency is null
         or upper(btrim(v_terms_currency))<>upper(btrim(v_currency))
         or upper(btrim(v_contract_currency))<>upper(btrim(v_currency)) then
        raise exception 'Financial impact currency must match the contract and project financial terms';
      end if;

      select * into v_variation
      from public.project_contract_variations v
      where v.id=new.contract_variation_id
        and v.change_request_id=new.id
        and v.project_id=new.project_id and v.contract_id=new.contract_id
        and v.status='draft'
      for update;
      if not found or v_variation.amount_delta<>v_total
         or upper(btrim(v_variation.currency_code))<>upper(btrim(v_currency)) then
        raise exception 'Linked draft variation must match the Change Request net financial impact and currency';
      end if;
    elsif new.contract_variation_id is not null then
      raise exception 'A contract variation cannot be linked when the Change Request has no net financial impact';
    end if;
  end if;
  return new;
end;
$$;
create trigger project_cr_financial_submission_guard
before update on public.project_change_requests
for each row execute function private.validate_cr_financial_submission();

create or replace function private.guard_cr_schedule_change_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text;
  v_uid uuid := auth.uid();
begin
  if tg_op='DELETE' then raise exception 'Change Request schedule changes are retained for audit'; end if;
  if tg_op='INSERT' then
    if not exists (select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
      raise exception 'Active application profile required';
    end if;
    select status into v_status from public.project_change_requests
    where id=new.change_request_id and project_id=new.project_id;
    if not found or v_status<>'draft' then
      raise exception 'Schedule impacts can only be added to a draft Change Request';
    end if;
    if not (
      exists (select 1 from public.project_memberships pm where pm.project_id=new.project_id
        and pm.user_id=v_uid and pm.project_role='project_manager' and pm.status='active'
        and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
      or exists (select 1 from public.user_global_role_assignments ura where ura.user_id=v_uid
        and ura.role_code='platform_admin' and ura.status='active' and ura.effective_from<=now()
        and (ura.effective_to is null or ura.effective_to>now()))
    ) then raise exception 'Active Project Manager or Platform Administrator access required'; end if;
    new.created_by:=v_uid;
    return new;
  end if;

  if coalesce(current_setting('app.ppm_cr_apply',true),'')<>'on' then
    raise exception 'Schedule change records can only be updated by the approved CR application';
  end if;
  if (new.id,new.change_request_id,new.project_id,new.target_type,new.activity_id,new.milestone_id,
      new.proposed_start_date,new.proposed_due_date,new.change_reason,new.created_by,new.created_at)
     is distinct from
     (old.id,old.change_request_id,old.project_id,old.target_type,old.activity_id,old.milestone_id,
      old.proposed_start_date,old.proposed_due_date,old.change_reason,old.created_by,old.created_at) then
    raise exception 'Only application metadata may be updated on an approved schedule change';
  end if;
  return new;
end;
$$;
create trigger cr_schedule_change_mutation_guard
before insert or update or delete on public.project_change_request_schedule_changes
for each row execute function private.guard_cr_schedule_change_mutation();

create or replace function private.guard_approved_revised_schedule_dates()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (new.approved_revised_start_date,new.approved_revised_due_date)
     is distinct from (old.approved_revised_start_date,old.approved_revised_due_date)
     and coalesce(current_setting('app.ppm_cr_apply',true),'')<>'on'
     and coalesce(current_setting('app.ppm_milestone_rebaseline',true),'')<>'on' then
    raise exception 'Approved revised dates can only be changed through an approved Change Request or re-baseline action';
  end if;
  return new;
end;
$$;
create trigger project_activities_approved_revised_guard
before update on public.project_activities
for each row execute function private.guard_approved_revised_schedule_dates();
create trigger project_milestones_approved_revised_guard
before update on public.project_milestones
for each row execute function private.guard_approved_revised_schedule_dates();

create or replace function private.enforce_contract_variation_workflow()
returns trigger
language plpgsql
set search_path = ''
as $$
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
      join public.ppm_workflow_stages s on s.id=cr.current_stage_id
      where cr.id=new.change_request_id and cr.project_id=new.project_id
        and cr.contract_id=new.contract_id and cr.contract_variation_id=new.id
        and s.decision_outcome='approved'
      for update of cr;
      if not found then raise exception 'Only a Change Request in its configured approved decision stage may approve this variation'; end if;

      select coalesce(sum(i.cost_delta),0)::numeric(18,2),min(i.currency_code)
      into v_total,v_currency
      from public.project_change_request_impacts i
      where i.change_request_id=v_cr.id and i.project_id=v_cr.project_id
        and i.assessment_status='assessed' and i.cost_delta is not null;
      if v_total<>new.amount_delta or upper(btrim(v_currency))<>upper(btrim(new.currency_code)) then
        raise exception 'Contract variation no longer matches the approved CR financial impact';
      end if;

      if exists (
        select 1 from public.project_change_request_approvals a
        where a.change_request_id=v_cr.id
          and a.round_no=(select max(latest.round_no) from public.project_change_request_approvals latest
                         where latest.change_request_id=a.change_request_id and latest.stage_id=a.stage_id)
          and a.status<>'approved'
      ) then raise exception 'Every required approval round must be complete before applying a variation'; end if;

      select a.decided_by into v_finance_approver
      from public.project_change_request_approvals a
      where a.change_request_id=v_cr.id
        and a.approver_role_code in ('finance','finance_admin')
        and a.status='approved' and a.decided_by is not null
        and a.round_no=(select max(latest.round_no) from public.project_change_request_approvals latest
                       where latest.change_request_id=a.change_request_id and latest.stage_id=a.stage_id)
      order by a.decided_at desc,a.id
      limit 1;
      if v_finance_approver is null then
        raise exception 'A Finance approval is required before applying a contract variation';
      end if;

      if (new.project_id,new.contract_id,new.change_request_id,new.variation_reference,
          new.title,new.description,new.amount_delta,new.currency_code,new.requested_by,new.effective_date)
         is distinct from
         (old.project_id,old.contract_id,old.change_request_id,old.variation_reference,
          old.title,old.description,old.amount_delta,old.currency_code,old.requested_by,old.effective_date) then
        raise exception 'CR-linked variation terms are immutable during approval';
      end if;

      new.submitted_at:=coalesce(new.submitted_at,v_cr.submitted_at);
      new.decided_by:=v_finance_approver;
      new.decided_at:=coalesce(v_cr.decided_at,now());
      new.decision_reason:='Approved through Change Request '||v_cr.cr_reference;
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
$$;

create or replace function private.create_change_request_contract_variation(p_change_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid:=auth.uid();
  v_cr public.project_change_requests%rowtype;
  v_total numeric(18,2);
  v_currency_count integer;
  v_currency char(3);
  v_terms_currency char(3);
  v_contract_currency char(3);
  v_variation_id uuid;
  v_variation_ref text;
begin
  if v_uid is null or not exists(select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;
  select cr.* into v_cr from public.project_change_requests cr
  where cr.id=p_change_request_id for update;
  if not found or v_cr.status<>'draft' then raise exception 'Only a draft Change Request can create a linked variation'; end if;
  if not (
    exists(select 1 from public.project_memberships pm where pm.project_id=v_cr.project_id
      and pm.user_id=v_uid and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
    or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=v_uid
      and ura.role_code='platform_admin' and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now()))
  ) then raise exception 'Active Project Manager or Platform Administrator access required'; end if;
  if v_cr.contract_id is null then raise exception 'Select a contract before creating a contract variation'; end if;

  select coalesce(sum(i.cost_delta),0)::numeric(18,2),
         count(distinct upper(btrim(i.currency_code))),min(i.currency_code)
  into v_total,v_currency_count,v_currency
  from public.project_change_request_impacts i
  where i.change_request_id=v_cr.id and i.project_id=v_cr.project_id
    and i.assessment_status='assessed' and i.cost_delta is not null;
  if v_total=0 then raise exception 'This Change Request has no net financial impact'; end if;
  if v_currency_count<>1 then raise exception 'Financial impacts must use one consistent currency'; end if;

  select currency_code into v_terms_currency from public.project_financial_terms where project_id=v_cr.project_id;
  select currency_code into v_contract_currency from public.project_contracts where id=v_cr.contract_id and project_id=v_cr.project_id;
  if v_terms_currency is null or v_contract_currency is null
     or upper(btrim(v_terms_currency))<>upper(btrim(v_currency))
     or upper(btrim(v_contract_currency))<>upper(btrim(v_currency)) then
    raise exception 'Financial impact currency must match the contract and project financial terms';
  end if;

  if v_cr.contract_variation_id is not null then
    select id into v_variation_id from public.project_contract_variations
    where id=v_cr.contract_variation_id and change_request_id=v_cr.id and status='draft';
    if not found then raise exception 'The Change Request already references a different variation'; end if;
    return jsonb_build_object('change_request_id',v_cr.id,'contract_variation_id',v_variation_id,'amount_delta',v_total,'currency_code',v_currency);
  end if;

  v_variation_ref:='CR-'||v_cr.cr_reference;
  if exists(select 1 from public.project_contract_variations where project_id=v_cr.project_id and variation_reference=v_variation_ref) then
    raise exception 'Variation reference % already exists in this project',v_variation_ref;
  end if;

  insert into public.project_contract_variations(
    project_id,contract_id,variation_reference,title,description,amount_delta,currency_code,
    status,requested_by,change_request_id
  ) values (
    v_cr.project_id,v_cr.contract_id,v_variation_ref,v_cr.title,
    'Linked to Change Request '||v_cr.cr_reference||': '||coalesce(v_cr.description,''),
    v_total,v_currency,'draft',v_uid,v_cr.id
  ) returning id into v_variation_id;

  update public.project_change_requests set contract_variation_id=v_variation_id,updated_at=now()
  where id=v_cr.id;

  return jsonb_build_object('change_request_id',v_cr.id,'contract_variation_id',v_variation_id,
    'variation_reference',v_variation_ref,'amount_delta',v_total,'currency_code',v_currency);
end;
$$;

create or replace function public.create_change_request_contract_variation(p_change_request_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.create_change_request_contract_variation(p_change_request_id);
$$;
revoke all on function public.create_change_request_contract_variation(uuid) from public,anon;
grant execute on function public.create_change_request_contract_variation(uuid) to authenticated;
revoke all on function private.create_change_request_contract_variation(uuid) from public,anon;
grant execute on function private.create_change_request_contract_variation(uuid) to authenticated;

create or replace function private.guard_cr_schedule_change_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text;
  v_uid uuid:=auth.uid();
begin
  if tg_op='DELETE' then raise exception 'Change Request schedule changes are retained for audit'; end if;
  if tg_op='INSERT' then
    if not exists(select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
      raise exception 'Active application profile required';
    end if;
    select status into v_status from public.project_change_requests
    where id=new.change_request_id and project_id=new.project_id;
    if not found or v_status<>'draft' then
      raise exception 'Schedule impacts can only be added to a draft Change Request';
    end if;
    if not (
      exists(select 1 from public.project_memberships pm where pm.project_id=new.project_id
        and pm.user_id=v_uid and pm.project_role='project_manager' and pm.status='active'
        and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
      or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=v_uid
        and ura.role_code='platform_admin' and ura.status='active' and ura.effective_from<=now()
        and (ura.effective_to is null or ura.effective_to>now()))
    ) then raise exception 'Active Project Manager or Platform Administrator access required'; end if;
    new.created_by:=v_uid;
    return new;
  end if;

  if coalesce(current_setting('app.ppm_cr_apply',true),'')<>'on' then
    raise exception 'Schedule change records can only be updated by the approved CR application';
  end if;
  if (new.id,new.change_request_id,new.project_id,new.target_type,new.activity_id,new.milestone_id,
      new.proposed_start_date,new.proposed_due_date,new.change_reason,new.created_by,new.created_at)
     is distinct from
     (old.id,old.change_request_id,old.project_id,old.target_type,old.activity_id,old.milestone_id,
      old.proposed_start_date,old.proposed_due_date,old.change_reason,old.created_by,old.created_at) then
    raise exception 'Only application metadata may be updated on an approved schedule change';
  end if;
  return new;
end;
$$;

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
  if not found or v_stage.decision_outcome<>'approved' then return new; end if;

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
    where change_request_id=new.id and project_id=new.project_id
      and applied_at is null
    order by id
    for update
  loop
    if v_schedule.target_type='activity' then
      select approved_revised_start_date,approved_revised_due_date
      into v_old_start,v_old_due
      from public.project_activities
      where id=v_schedule.activity_id and project_id=new.project_id
      for update;
      if not found then raise exception 'Target activity no longer exists'; end if;
      update public.project_activities
      set approved_revised_start_date=coalesce(v_schedule.proposed_start_date,approved_revised_start_date),
          approved_revised_due_date=coalesce(v_schedule.proposed_due_date,approved_revised_due_date),
          updated_at=now()
      where id=v_schedule.activity_id and project_id=new.project_id;
    else
      select approved_revised_start_date,approved_revised_due_date
      into v_old_start,v_old_due
      from public.project_milestones
      where id=v_schedule.milestone_id and project_id=new.project_id
      for update;
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
        applied_by=new.decided_by,
        applied_at=now()
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
create trigger project_cr_apply_approved_changes
after update on public.project_change_requests
for each row execute function private.apply_approved_change_request_changes();

create or replace function private.validate_cr_approval_outcome_configuration()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare v_module text;
begin
  if old.status='draft' and new.status='published' then
    select module_code into v_module from public.ppm_workflow_templates where id=new.template_id;
    if v_module='change_request' and not exists (
      select 1 from public.ppm_workflow_stages s
      where s.workflow_version_id=new.id and s.decision_outcome='approved'
    ) then
      raise exception 'A Change Request workflow must define an approved decision outcome stage';
    end if;
  end if;
  return new;
end;
$$;
create trigger ppm_workflow_cr_approval_outcome_publish_guard
before update on public.ppm_workflow_template_versions
for each row execute function private.validate_cr_approval_outcome_configuration();

create or replace function private.guard_approved_revised_schedule_dates()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (new.approved_revised_start_date,new.approved_revised_due_date)
     is distinct from (old.approved_revised_start_date,old.approved_revised_due_date)
     and coalesce(current_setting('app.ppm_cr_apply',true),'')<>'on'
     and coalesce(current_setting('app.ppm_milestone_rebaseline',true),'')<>'on' then
    raise exception 'Approved revised dates can only be changed through an approved Change Request or re-baseline action';
  end if;
  return new;
end;
$$;

create or replace function private.enforce_contract_variation_workflow()
returns trigger
language plpgsql
set search_path = ''
as $$
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
      join public.ppm_workflow_stages s on s.id=cr.current_stage_id
      where cr.id=new.change_request_id and cr.project_id=new.project_id
        and cr.contract_id=new.contract_id and cr.contract_variation_id=new.id
        and s.decision_outcome='approved'
      for update of cr;
      if not found then raise exception 'Only a Change Request in its configured approved decision stage may approve this variation'; end if;

      select coalesce(sum(i.cost_delta),0)::numeric(18,2),min(i.currency_code)
      into v_total,v_currency
      from public.project_change_request_impacts i
      where i.change_request_id=v_cr.id and i.project_id=v_cr.project_id
        and i.assessment_status='assessed' and i.cost_delta is not null;
      if v_total<>new.amount_delta or upper(btrim(v_currency))<>upper(btrim(new.currency_code)) then
        raise exception 'Contract variation no longer matches the approved CR financial impact';
      end if;

      if exists (
        select 1 from public.project_change_request_approvals a
        where a.change_request_id=v_cr.id
          and a.round_no=(select max(latest.round_no) from public.project_change_request_approvals latest
                         where latest.change_request_id=a.change_request_id and latest.stage_id=a.stage_id)
          and a.status<>'approved'
      ) then raise exception 'Every required approval round must be complete before applying a variation'; end if;

      select a.decided_by into v_finance_approver
      from public.project_change_request_approvals a
      where a.change_request_id=v_cr.id
        and a.approver_role_code in ('finance','finance_admin')
        and a.status='approved' and a.decided_by is not null
        and a.round_no=(select max(latest.round_no) from public.project_change_request_approvals latest
                       where latest.change_request_id=a.change_request_id and latest.stage_id=a.stage_id)
      order by a.decided_at desc,a.id limit 1;
      if v_finance_approver is null then raise exception 'A Finance approval is required before applying a contract variation'; end if;

      if (new.project_id,new.contract_id,new.change_request_id,new.variation_reference,
          new.title,new.description,new.amount_delta,new.currency_code,new.requested_by,new.effective_date)
         is distinct from
         (old.project_id,old.contract_id,old.change_request_id,old.variation_reference,
          old.title,old.description,old.amount_delta,old.currency_code,old.requested_by,old.effective_date) then
        raise exception 'CR-linked variation terms are immutable during approval';
      end if;
      new.submitted_at:=coalesce(new.submitted_at,v_cr.submitted_at);
      new.decided_by:=v_finance_approver;
      new.decided_at:=coalesce(v_cr.decided_at,now());
      new.decision_reason:='Approved through Change Request '||v_cr.cr_reference;
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
$$;
