-- Versioned notification rule configuration and event-driven in-app delivery.

alter table public.ppm_notification_rules
  add column updated_by uuid references auth.users(id) on delete restrict;

create table public.ppm_notification_rule_history (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid not null references public.ppm_notification_rules(id) on delete restrict,
  version_no integer not null check (version_no>0),
  rule_snapshot jsonb not null,
  changed_by uuid not null references auth.users(id) on delete restrict,
  changed_at timestamptz not null default now(),
  constraint ppm_notification_rule_history_version_uq unique(rule_id,version_no)
);
alter table public.ppm_notification_rule_history enable row level security;
create policy ppm_notification_rule_history_admin_read on public.ppm_notification_rule_history
for select to authenticated using (
  exists(select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now()))
);
grant select on public.ppm_notification_rule_history to authenticated;
revoke insert,update,delete on public.ppm_notification_rule_history from anon,authenticated;

create unique index ppm_user_notifications_recipient_dedupe_uq
  on public.ppm_user_notifications(recipient_user_id,deduplication_key)
  where deduplication_key is not null;
create index ppm_notification_rules_event_active_idx
  on public.ppm_notification_rules(module_code,event_code,is_enabled,effective_from,effective_to);

create or replace function private.validate_notification_rule_configuration()
returns trigger language plpgsql security invoker set search_path=''
as $$
declare v_key text; v_allowed text[]:=array['project_roles','global_roles','include_target_users','exclude_actor'];
begin
  if jsonb_typeof(new.recipient_rules)<>'object' then raise exception 'Recipient rules must be a JSON object'; end if;
  for v_key in select jsonb_object_keys(new.recipient_rules) loop
    if not v_key=any(v_allowed) then raise exception 'Unsupported recipient rule key: %',v_key; end if;
  end loop;
  if new.recipient_rules ? 'project_roles' and jsonb_typeof(new.recipient_rules->'project_roles')<>'array' then raise exception 'recipient_rules.project_roles must be an array'; end if;
  if new.recipient_rules ? 'global_roles' and jsonb_typeof(new.recipient_rules->'global_roles')<>'array' then raise exception 'recipient_rules.global_roles must be an array'; end if;
  if new.recipient_rules ? 'include_target_users' and jsonb_typeof(new.recipient_rules->'include_target_users')<>'boolean' then raise exception 'recipient_rules.include_target_users must be boolean'; end if;
  if new.recipient_rules ? 'exclude_actor' and jsonb_typeof(new.recipient_rules->'exclude_actor')<>'boolean' then raise exception 'recipient_rules.exclude_actor must be boolean'; end if;
  if jsonb_typeof(new.trigger_conditions)<>'object' or new.trigger_conditions<>'{}'::jsonb then
    raise exception 'This release supports immediate event rules only; trigger conditions are not yet evaluated';
  end if;
  if jsonb_typeof(new.escalation_rules)<>'object' or new.escalation_rules<>'{}'::jsonb
     or jsonb_typeof(new.quiet_hours)<>'object' or new.quiet_hours<>'{}'::jsonb
     or new.lead_time_minutes<>0 or new.repeat_interval_minutes is not null then
    raise exception 'Scheduled reminders, quiet hours and escalations are not enabled in this release';
  end if;
  if new.severity not in ('info','normal','warning','critical') then raise exception 'Unsupported notification severity'; end if;
  return new;
end;
$$;

create or replace function private.version_notification_rule()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if tg_op='INSERT' then
    new.version_no:=1; new.updated_by:=auth.uid(); new.updated_at:=now(); return new;
  end if;
  if (new.rule_code,new.rule_name,new.module_code,new.event_code,new.is_enabled,new.severity,
      new.trigger_conditions,new.recipient_rules,new.lead_time_minutes,new.repeat_interval_minutes,
      new.escalation_rules,new.timezone_mode,new.quiet_hours,new.requires_acknowledgement,
      new.effective_from,new.effective_to)
     is distinct from
     (old.rule_code,old.rule_name,old.module_code,old.event_code,old.is_enabled,old.severity,
      old.trigger_conditions,old.recipient_rules,old.lead_time_minutes,old.repeat_interval_minutes,
      old.escalation_rules,old.timezone_mode,old.quiet_hours,old.requires_acknowledgement,
      old.effective_from,old.effective_to) then
    insert into public.ppm_notification_rule_history(rule_id,version_no,rule_snapshot,changed_by)
    values(old.id,old.version_no,to_jsonb(old)-array['updated_by'],auth.uid());
    new.version_no:=old.version_no+1; new.updated_by:=auth.uid(); new.updated_at:=now();
  else
    new.version_no:=old.version_no; new.updated_by:=old.updated_by; new.updated_at:=old.updated_at;
  end if;
  return new;
end;
$$;
create trigger ppm_notification_rule_config_guard before insert or update on public.ppm_notification_rules
for each row execute function private.validate_notification_rule_configuration();
create trigger ppm_notification_rule_versioning before insert or update on public.ppm_notification_rules
for each row execute function private.version_notification_rule();

create or replace function private.emit_ppm_notification(
  p_module_code text,p_event_code text,p_project_id uuid,p_source_table text,p_source_record_id uuid,
  p_event_instance text,p_title text,p_message text,p_deep_link text,
  p_target_user_ids uuid[] default null,p_actor_user_id uuid default null
)
returns integer language plpgsql security definer set search_path=''
as $$
declare
  v_rule public.ppm_notification_rules%rowtype;
  v_recipient uuid;
  v_project_roles text[];
  v_global_roles text[];
  v_include_targets boolean;
  v_exclude_actor boolean;
  v_count integer:=0;
  v_dedupe text;
begin
  for v_rule in
    select r.* from public.ppm_notification_rules r
    where r.module_code=p_module_code and r.event_code=p_event_code and r.is_enabled
      and (r.effective_from is null or r.effective_from<=now())
      and (r.effective_to is null or r.effective_to>now())
    order by r.version_no desc,r.created_at
  loop
    select coalesce(array_agg(value),array[]::text[]) into v_project_roles
      from jsonb_array_elements_text(coalesce(v_rule.recipient_rules->'project_roles','[]'::jsonb));
    select coalesce(array_agg(value),array[]::text[]) into v_global_roles
      from jsonb_array_elements_text(coalesce(v_rule.recipient_rules->'global_roles','[]'::jsonb));
    v_include_targets:=coalesce((v_rule.recipient_rules->>'include_target_users')::boolean,false);
    v_exclude_actor:=coalesce((v_rule.recipient_rules->>'exclude_actor')::boolean,true);

    for v_recipient in
      select distinct candidates.user_id
      from (
        select pm.user_id from public.project_memberships pm
        where p_project_id is not null and pm.project_id=p_project_id
          and pm.project_role=any(v_project_roles) and pm.status='active'
          and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
        union
        select ura.user_id from public.user_global_role_assignments ura
        where ura.role_code=any(v_global_roles) and ura.status='active'
          and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now())
        union
        select unnest(coalesce(p_target_user_ids,array[]::uuid[])) where v_include_targets
      ) candidates
      join public.user_profiles up on up.user_id=candidates.user_id and up.is_active
      where (not v_exclude_actor or p_actor_user_id is null or candidates.user_id<>p_actor_user_id)
        and (p_project_id is null
          or exists(select 1 from public.project_memberships pm where pm.project_id=p_project_id
            and pm.user_id=candidates.user_id and pm.status='active'
            and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
          or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=candidates.user_id
            and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now())))
    loop
      v_dedupe:=v_rule.id::text||':'||v_rule.version_no::text||':'||p_event_code||':'||
        coalesce(p_source_table,'')||':'||coalesce(p_source_record_id::text,'')||':'||
        coalesce(p_event_instance,'')||':'||v_recipient::text;
      insert into public.ppm_user_notifications(
        recipient_user_id,project_id,rule_id,event_code,severity,title,message,
        source_table,source_record_id,deep_link,requires_acknowledgement,deduplication_key
      ) values (
        v_recipient,p_project_id,v_rule.id,p_event_code,v_rule.severity,p_title,p_message,
        p_source_table,p_source_record_id,p_deep_link,v_rule.requires_acknowledgement,v_dedupe
      )
      on conflict (recipient_user_id,deduplication_key) where deduplication_key is not null do nothing;
      if found then v_count:=v_count+1; end if;
    end loop;
  end loop;
  return v_count;
end;
$$;
revoke all on function private.emit_ppm_notification(text,text,uuid,text,uuid,text,text,text,text,uuid[],uuid) from public,anon,authenticated;

create or replace function private.notify_change_request_event()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_stage public.ppm_workflow_stages%rowtype; v_targets uuid[]; v_round integer;
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

    select coalesce(max(a.round_no),0) into v_round from public.project_change_request_approvals a
    where a.change_request_id=new.id and a.stage_id=new.current_stage_id;
    select array_agg(distinct candidates.user_id) into v_targets
    from (
      select a.approver_user_id as user_id from public.project_change_request_approvals a
      where a.change_request_id=new.id and a.stage_id=new.current_stage_id
        and a.round_no=v_round and a.status='pending' and a.approver_user_id is not null
      union
      select pm.user_id from public.project_change_request_approvals a
      join public.project_memberships pm on pm.project_id=a.project_id
        and pm.project_role=a.approver_role_code and pm.status='active'
        and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())
      where a.change_request_id=new.id and a.stage_id=new.current_stage_id
        and a.round_no=v_round and a.status='pending'
      union
      select ura.user_id from public.project_change_request_approvals a
      join public.user_global_role_assignments ura on ura.role_code=a.approver_role_code
        and ura.status='active' and ura.effective_from<=now()
        and (ura.effective_to is null or ura.effective_to>now())
      where a.change_request_id=new.id and a.stage_id=new.current_stage_id
        and a.round_no=v_round and a.status='pending'
    ) candidates;
    if coalesce(cardinality(v_targets),0)>0 then
      perform private.emit_ppm_notification('change_request','cr_approval_needed',new.project_id,
        'project_change_requests',new.id,new.current_stage_id::text||':'||v_round::text,
        'Approval required','Your approval is required for '||new.cr_reference||' — '||new.title,
        '/projects/'||new.project_id::text||'/change-requests/'||new.id::text,v_targets,auth.uid());
    end if;
  end if;
  return new;
end;
$$;
create trigger project_change_request_notifications after update on public.project_change_requests
for each row execute function private.notify_change_request_event();

create or replace function private.notify_deliverable_submission()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_deliverable public.contract_deliverables%rowtype;
begin
  select d.* into v_deliverable from public.contract_deliverables d where d.id=new.deliverable_id;
  if not found then return new; end if;
  perform private.emit_ppm_notification('deliverables','deliverable_submitted',new.project_id,
    'contract_deliverable_submissions',new.id,new.submission_no::text,
    'Deliverable submitted for review',v_deliverable.name||' has a new submission',
    '/projects/'||new.project_id::text||'/deliverables/'||new.deliverable_id::text,
    array[v_deliverable.reviewer_user_id,v_deliverable.owner_user_id],auth.uid());
  return new;
end;
$$;
create trigger contract_deliverable_submission_notifications after insert on public.contract_deliverable_submissions
for each row execute function private.notify_deliverable_submission();

create or replace function private.notify_deliverable_review()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_deliverable public.contract_deliverables%rowtype; v_event text; v_title text;
begin
  select d.* into v_deliverable from public.contract_deliverables d where d.id=new.deliverable_id;
  if not found then return new; end if;
  v_event:=case new.outcome when 'accepted' then 'deliverable_review_accepted'
    when 'changes_required' then 'deliverable_changes_required' else 'deliverable_rejected' end;
  v_title:=case new.outcome when 'accepted' then 'Deliverable review completed'
    when 'changes_required' then 'Changes requested' else 'Deliverable rejected' end;
  perform private.emit_ppm_notification('deliverables',v_event,new.project_id,
    'contract_deliverable_reviews',new.id,new.submission_id::text,v_title,
    v_deliverable.name||' review outcome: '||new.outcome,
    '/projects/'||new.project_id::text||'/deliverables/'||new.deliverable_id::text,
    array[v_deliverable.owner_user_id,v_deliverable.reviewer_user_id],auth.uid());
  return new;
end;
$$;
create trigger contract_deliverable_review_notifications after insert on public.contract_deliverable_reviews
for each row execute function private.notify_deliverable_review();

create or replace function private.notify_deliverable_acceptance()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if old.status is distinct from 'accepted' and new.status='accepted' then
    perform private.emit_ppm_notification('deliverables','deliverable_accepted',new.project_id,
      'contract_deliverables',new.id,coalesce(new.accepted_at::text,'accepted'),
      'Deliverable formally accepted',new.name||' has been formally accepted by the Project Manager',
      '/projects/'||new.project_id::text||'/deliverables/'||new.id::text,
      array[new.owner_user_id,new.reviewer_user_id],auth.uid());
  end if;
  return new;
end;
$$;
create trigger contract_deliverable_acceptance_notifications after update on public.contract_deliverables
for each row execute function private.notify_deliverable_acceptance();

create or replace function private.guard_notification_inbox_update()
returns trigger language plpgsql security invoker set search_path=''
as $$
begin
  if (new.id,new.recipient_user_id,new.project_id,new.rule_id,new.event_code,new.severity,new.title,
      new.message,new.source_table,new.source_record_id,new.deep_link,new.requires_acknowledgement,
      new.expires_at,new.deduplication_key,new.created_at)
     is distinct from
     (old.id,old.recipient_user_id,old.project_id,old.rule_id,old.event_code,old.severity,old.title,
      old.message,old.source_table,old.source_record_id,old.deep_link,old.requires_acknowledgement,
      old.expires_at,old.deduplication_key,old.created_at) then
    raise exception 'Notification content and recipient are immutable';
  end if;
  if new.is_read is distinct from old.is_read then
    new.read_at:=case when new.is_read then now() else null end;
  elsif new.read_at is distinct from old.read_at then
    raise exception 'Read timestamp is managed by the notification inbox action';
  end if;
  if new.acknowledged_at is distinct from old.acknowledged_at then
    if not new.requires_acknowledgement then raise exception 'This notification does not require acknowledgement'; end if;
    if old.acknowledged_at is not null then raise exception 'Notification acknowledgement is immutable'; end if;
    new.acknowledged_at:=now();
  end if;
  return new;
end;
$$;
create trigger ppm_user_notification_update_guard before update on public.ppm_user_notifications
for each row execute function private.guard_notification_inbox_update();
