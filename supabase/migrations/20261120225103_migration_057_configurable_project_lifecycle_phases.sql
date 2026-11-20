
-- 057: Configurable, versioned project lifecycle and phase history.
-- Deliberately seeds no template or phase labels.

create table public.project_lifecycle_templates (
 id uuid primary key default gen_random_uuid(),
 project_id uuid references public.projects(id) on delete restrict,
 template_code text not null check(length(btrim(template_code)) between 1 and 80),
 template_name text not null check(length(btrim(template_name)) between 1 and 160),
 description text,
 status text not null default 'active' check(status in ('active','archived')),
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 unique(id,project_id)
);
create unique index lifecycle_template_global_code_uq on public.project_lifecycle_templates(lower(template_code)) where project_id is null;
create unique index lifecycle_template_project_code_uq on public.project_lifecycle_templates(project_id,lower(template_code)) where project_id is not null;

create table public.project_lifecycle_template_versions (
 id uuid primary key default gen_random_uuid(),
 template_id uuid not null references public.project_lifecycle_templates(id) on delete restrict,
 project_id uuid references public.projects(id) on delete restrict,
 version_number integer not null check(version_number>0),
 status text not null default 'draft' check(status in ('draft','published','retired')),
 effective_from timestamptz,
 effective_to timestamptz,
 change_reason text not null check(length(btrim(change_reason)) between 8 and 1000),
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 published_by uuid references auth.users(id) on delete set null,
 published_at timestamptz,
 unique(template_id,version_number),
 unique(id,template_id,project_id),
 unique(id,project_id),
 check(effective_to is null or effective_from is null or effective_to>effective_from),
 check(status<>'published' or (published_at is not null and published_by is not null and effective_from is not null))
);

create table public.project_lifecycle_phases (
 id uuid primary key default gen_random_uuid(),
 version_id uuid not null,
 template_id uuid not null,
 project_id uuid,
 phase_code text not null check(length(btrim(phase_code)) between 1 and 80),
 phase_name text not null check(length(btrim(phase_name)) between 1 and 160),
 description text,
 display_order integer not null check(display_order>0),
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 unique(id,version_id,project_id),
 unique(version_id,display_order),
 foreign key(version_id,template_id,project_id) references public.project_lifecycle_template_versions(id,template_id,project_id) on delete restrict
);
create unique index lifecycle_phase_code_uq on public.project_lifecycle_phases(version_id,lower(phase_code));

create table public.project_lifecycle_transition_rules (
 id uuid primary key default gen_random_uuid(),
 version_id uuid not null,
 template_id uuid not null,
 project_id uuid,
 from_phase_id uuid,
 to_phase_id uuid not null,
 reason_required boolean not null default true,
 created_at timestamptz not null default now(),
 unique nulls not distinct(version_id,from_phase_id,to_phase_id),
 foreign key(version_id,template_id,project_id) references public.project_lifecycle_template_versions(id,template_id,project_id) on delete restrict,
 foreign key(from_phase_id,version_id,project_id) references public.project_lifecycle_phases(id,version_id,project_id) on delete restrict,
 foreign key(to_phase_id,version_id,project_id) references public.project_lifecycle_phases(id,version_id,project_id) on delete restrict,
 check(from_phase_id is null or from_phase_id<>to_phase_id)
);

create table public.project_lifecycle_assignments (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.projects(id) on delete restrict,
 template_id uuid not null,
 version_id uuid not null,
 status text not null default 'active' check(status in ('active','superseded')),
 current_phase_id uuid,
 current_phase_started_at timestamptz,
 assigned_by uuid references auth.users(id) on delete set null,
 assigned_at timestamptz not null default now(),
 assignment_reason text not null check(length(btrim(assignment_reason)) between 8 and 1000),
 unique(id,project_id),
 foreign key(version_id,template_id,project_id) references public.project_lifecycle_template_versions(id,template_id,project_id) on delete restrict,
 foreign key(current_phase_id,version_id,project_id) references public.project_lifecycle_phases(id,version_id,project_id) on delete restrict,
 check((current_phase_id is null and current_phase_started_at is null) or (current_phase_id is not null and current_phase_started_at is not null))
);
create unique index lifecycle_one_active_assignment_uq on public.project_lifecycle_assignments(project_id) where status='active';

create table public.project_phase_history (
 id uuid primary key default gen_random_uuid(),
 assignment_id uuid not null,
 project_id uuid not null,
 version_id uuid not null,
 previous_phase_id uuid,
 phase_id uuid not null,
 entered_at timestamptz not null,
 exited_at timestamptz,
 planned_start_date date,
 forecast_completion_date date,
 actual_completion_date date,
 progress_percent numeric(5,2) check(progress_percent between 0 and 100),
 entered_by uuid references auth.users(id) on delete set null,
 change_reason text check(change_reason is null or length(btrim(change_reason)) between 8 and 1000),
 created_at timestamptz not null default now(),
 foreign key(assignment_id,project_id) references public.project_lifecycle_assignments(id,project_id) on delete restrict,
 foreign key(phase_id,version_id,project_id) references public.project_lifecycle_phases(id,version_id,project_id) on delete restrict,
 foreign key(previous_phase_id,version_id,project_id) references public.project_lifecycle_phases(id,version_id,project_id) on delete restrict,
 check(exited_at is null or exited_at>=entered_at),
 check(forecast_completion_date is null or planned_start_date is null or forecast_completion_date>=planned_start_date),
 check(actual_completion_date is null or planned_start_date is null or actual_completion_date>=planned_start_date)
);
create unique index lifecycle_one_current_phase_uq on public.project_phase_history(assignment_id) where exited_at is null;
create index lifecycle_history_project_date_idx on public.project_phase_history(project_id,entered_at desc);
create index lifecycle_history_assignment_date_idx on public.project_phase_history(assignment_id,entered_at desc);

alter table public.project_lifecycle_templates enable row level security;
alter table public.project_lifecycle_template_versions enable row level security;
alter table public.project_lifecycle_phases enable row level security;
alter table public.project_lifecycle_transition_rules enable row level security;
alter table public.project_lifecycle_assignments enable row level security;
alter table public.project_phase_history enable row level security;

-- Supabase's 2026 Data API exposure default is opt-in; grant only required authenticated access.
grant select,insert,update on public.project_lifecycle_templates,public.project_lifecycle_template_versions,public.project_lifecycle_phases,public.project_lifecycle_transition_rules to authenticated;
grant select on public.project_lifecycle_assignments,public.project_phase_history to authenticated;
grant all on public.project_lifecycle_templates,public.project_lifecycle_template_versions,public.project_lifecycle_phases,public.project_lifecycle_transition_rules,public.project_lifecycle_assignments,public.project_phase_history to service_role;

create policy lifecycle_templates_select on public.project_lifecycle_templates for select to authenticated using (
 project_id is null
 or exists(select 1 from public.project_memberships m where m.project_id=project_lifecycle_templates.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);
create policy lifecycle_templates_admin_insert on public.project_lifecycle_templates for insert to authenticated with check (
 created_by=(select auth.uid()) and exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
);
create policy lifecycle_templates_admin_update on public.project_lifecycle_templates for update to authenticated using (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
) with check (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
);

-- Child definitions are visible through their parent template; writes are administrator-only.
create policy lifecycle_versions_select on public.project_lifecycle_template_versions for select to authenticated using (
 exists(select 1 from public.project_lifecycle_templates t where t.id=template_id and (t.project_id is null or exists(select 1 from public.project_memberships m where m.project_id=t.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);
create policy lifecycle_versions_admin_insert on public.project_lifecycle_template_versions for insert to authenticated with check (
 created_by=(select auth.uid()) and exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
);
create policy lifecycle_versions_admin_update on public.project_lifecycle_template_versions for update to authenticated using (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
) with check (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
);

create policy lifecycle_phases_select on public.project_lifecycle_phases for select to authenticated using (
 exists(select 1 from public.project_lifecycle_template_versions v join public.project_lifecycle_templates t on t.id=v.template_id where v.id=version_id and (t.project_id is null or exists(select 1 from public.project_memberships m where m.project_id=t.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);
create policy lifecycle_phases_admin_insert on public.project_lifecycle_phases for insert to authenticated with check (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
);
create policy lifecycle_phases_admin_update on public.project_lifecycle_phases for update to authenticated using (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
) with check (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
);

create policy lifecycle_rules_select on public.project_lifecycle_transition_rules for select to authenticated using (
 exists(select 1 from public.project_lifecycle_template_versions v join public.project_lifecycle_templates t on t.id=v.template_id where v.id=version_id and (t.project_id is null or exists(select 1 from public.project_memberships m where m.project_id=t.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);
create policy lifecycle_rules_admin_insert on public.project_lifecycle_transition_rules for insert to authenticated with check (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
);
create policy lifecycle_rules_admin_update on public.project_lifecycle_transition_rules for update to authenticated using (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
) with check (
 exists(select 1 from public.user_global_role_assignments r join public.user_profiles u on u.user_id=r.user_id where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and u.is_active)
);

create policy lifecycle_assignments_select on public.project_lifecycle_assignments for select to authenticated using (
 exists(select 1 from public.project_memberships m where m.project_id=project_lifecycle_assignments.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);
create policy phase_history_select on public.project_phase_history for select to authenticated using (
 exists(select 1 from public.project_memberships m where m.project_id=project_phase_history.project_id and m.user_id=(select auth.uid()) and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))
 or exists(select 1 from public.user_global_role_assignments r where r.user_id=(select auth.uid()) and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
);

-- Draft definitions can be edited; published/retired versions and their children cannot.
create or replace function private.guard_lifecycle_version_mutation()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_status text;
begin
 if tg_table_name='project_lifecycle_template_versions' then
  if tg_op='DELETE' then
   if old.status<>'draft' then raise exception 'Only draft versions may be deleted'; end if;
   return old;
  end if;
  if old.status in ('published','retired') then
   if old.status='published' and new.status='retired' and (to_jsonb(new)-'status')=(to_jsonb(old)-'status') then return new; end if;
   raise exception 'Published and retired lifecycle versions are immutable';
  end if;
  if old.status='draft' and new.status='published' then
   if new.published_at is null or new.published_by is distinct from auth.uid() or new.effective_from is null then raise exception 'Publishing requires actor and effective date'; end if;
   if not exists(select 1 from public.project_lifecycle_phases p where p.version_id=old.id and p.is_active) then raise exception 'At least one active phase is required'; end if;
   if not exists(select 1 from public.project_lifecycle_transition_rules r join public.project_lifecycle_phases p on p.id=r.to_phase_id where r.version_id=old.id and r.from_phase_id is null and p.is_active) then raise exception 'At least one allowed starting phase is required'; end if;
  end if;
  return new;
 end if;
 if tg_op='DELETE' then v_status=(select v.status from public.project_lifecycle_template_versions v where v.id=old.version_id);
 else v_status=(select v.status from public.project_lifecycle_template_versions v where v.id=new.version_id); end if;
 if v_status is distinct from 'draft' then raise exception 'Phase and transition definitions can only change in draft versions'; end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
create trigger lifecycle_version_guard before update or delete on public.project_lifecycle_template_versions for each row execute function private.guard_lifecycle_version_mutation();
create trigger lifecycle_phase_guard before insert or update or delete on public.project_lifecycle_phases for each row execute function private.guard_lifecycle_version_mutation();
create trigger lifecycle_rule_guard before insert or update or delete on public.project_lifecycle_transition_rules for each row execute function private.guard_lifecycle_version_mutation();

create or replace function private.audit_project_lifecycle_change()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_row jsonb; v_before jsonb; v_after jsonb; v_id uuid; v_project_id uuid; v_reason text; v_action text;
begin
 if tg_op='INSERT' then
  v_row=to_jsonb(new); v_after=v_row; v_id=(v_row->>'id')::uuid; v_project_id=nullif(v_row->>'project_id','')::uuid;
  v_reason=coalesce(v_row->>'change_reason',v_row->>'assignment_reason',v_row->>'reason'); v_action='insert';
 elsif tg_op='UPDATE' then
  v_before=to_jsonb(old); v_after=to_jsonb(new); v_id=(v_after->>'id')::uuid; v_project_id=nullif(v_after->>'project_id','')::uuid;
  v_reason=coalesce(v_after->>'change_reason',v_after->>'assignment_reason',v_after->>'reason'); v_action='update';
 else
  v_before=to_jsonb(old); v_id=(v_before->>'id')::uuid; v_project_id=nullif(v_before->>'project_id','')::uuid;
  v_reason=coalesce(v_before->>'change_reason',v_before->>'assignment_reason',v_before->>'reason'); v_action='delete';
 end if;
 insert into private.security_audit_events(actor_user_id,action,entity_schema,entity_table,entity_id,project_id,reason,before_data,after_data)
 values(auth.uid(),'project_lifecycle_'||v_action,'public',tg_table_name,v_id,v_project_id,v_reason,v_before,v_after);
 if tg_op='DELETE' then return old; end if; return new;
end $$;

create trigger lifecycle_template_audit after insert or update or delete on public.project_lifecycle_templates for each row execute function private.audit_project_lifecycle_change();
create trigger lifecycle_version_audit after insert or update or delete on public.project_lifecycle_template_versions for each row execute function private.audit_project_lifecycle_change();
create trigger lifecycle_phase_audit after insert or update or delete on public.project_lifecycle_phases for each row execute function private.audit_project_lifecycle_change();
create trigger lifecycle_rule_audit after insert or update or delete on public.project_lifecycle_transition_rules for each row execute function private.audit_project_lifecycle_change();
create trigger lifecycle_assignment_audit after insert or update or delete on public.project_lifecycle_assignments for each row execute function private.audit_project_lifecycle_change();
create trigger phase_history_audit after insert or update or delete on public.project_phase_history for each row execute function private.audit_project_lifecycle_change();

create or replace function public.assign_project_lifecycle(
 p_project_id uuid,p_version_id uuid,p_initial_phase_id uuid,p_assignment_reason text,
 p_entered_at timestamptz default now(),p_planned_start_date date default null,p_forecast_completion_date date default null
) returns uuid language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_template_id uuid; v_scope uuid; v_assignment_id uuid;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if length(btrim(coalesce(p_assignment_reason,''))) not between 8 and 1000 then raise exception 'Assignment reason must be 8 to 1000 characters'; end if;
 if not exists(select 1 from public.user_profiles u join public.user_global_role_assignments r on r.user_id=u.user_id where u.user_id=v_uid and u.is_active and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now())) then raise exception 'Platform administrator role required'; end if;
 select template_id,project_id into v_template_id,v_scope from public.project_lifecycle_template_versions
 where id=p_version_id and status='published' and effective_from<=coalesce(p_entered_at,now()) and (effective_to is null or effective_to>coalesce(p_entered_at,now())) for share;
 if not found then raise exception 'Published lifecycle version is not effective at assignment time'; end if;
 if v_scope is not null and v_scope<>p_project_id then raise exception 'Project-scoped lifecycle does not match project'; end if;
 if not exists(select 1 from public.project_lifecycle_phases p join public.project_lifecycle_transition_rules r on r.to_phase_id=p.id and r.version_id=p.version_id where p.id=p_initial_phase_id and p.version_id=p_version_id and p.is_active and r.from_phase_id is null) then raise exception 'Initial phase is not an allowed starting phase'; end if;
 insert into public.project_lifecycle_assignments(project_id,template_id,version_id,assigned_by,assignment_reason)
 values(p_project_id,v_template_id,p_version_id,v_uid,p_assignment_reason) returning id into v_assignment_id;
 insert into public.project_phase_history(assignment_id,project_id,version_id,phase_id,entered_at,planned_start_date,forecast_completion_date,entered_by,change_reason)
 values(v_assignment_id,p_project_id,p_version_id,p_initial_phase_id,coalesce(p_entered_at,now()),p_planned_start_date,p_forecast_completion_date,v_uid,p_assignment_reason);
 update public.project_lifecycle_assignments set current_phase_id=p_initial_phase_id,current_phase_started_at=coalesce(p_entered_at,now()) where id=v_assignment_id;
 return v_assignment_id;
end $$;

create or replace function public.transition_project_phase(
 p_project_id uuid,p_to_phase_id uuid default null,p_transition_at timestamptz default now(),
 p_planned_start_date date default null,p_forecast_completion_date date default null,
 p_actual_completion_date date default null,p_progress_percent numeric default null,p_reason text default null
) returns uuid language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_assignment public.project_lifecycle_assignments%rowtype;
 v_current public.project_phase_history%rowtype; v_reason_required boolean; v_history_id uuid;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if not exists(select 1 from public.user_profiles u where u.user_id=v_uid and u.is_active) then raise exception 'Active application profile required'; end if;
 if not (
  exists(select 1 from public.user_global_role_assignments r where r.user_id=v_uid and r.role_code='platform_admin' and r.status='active' and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()))
  or exists(select 1 from public.project_memberships m where m.project_id=p_project_id and m.user_id=v_uid and m.project_role='project_manager' and m.status='active' and m.effective_from<=now() and (m.effective_to is null or m.effective_to>now()))
 ) then raise exception 'Project Manager or Platform Administrator access required'; end if;
 select * into v_assignment from public.project_lifecycle_assignments a where a.project_id=p_project_id and a.status='active' for update;
 if not found then raise exception 'No active lifecycle assignment'; end if;
 select * into v_current from public.project_phase_history h where h.assignment_id=v_assignment.id and h.exited_at is null for update;
 if not found then raise exception 'Active phase history row missing'; end if;
 if p_progress_percent is not null and p_progress_percent not between 0 and 100 then raise exception 'Progress must be between 0 and 100'; end if;
 if p_forecast_completion_date is not null and p_planned_start_date is not null and p_forecast_completion_date<p_planned_start_date then raise exception 'Forecast completion precedes planned start'; end if;
 if p_actual_completion_date is not null and p_planned_start_date is not null and p_actual_completion_date<p_planned_start_date then raise exception 'Actual completion precedes planned start'; end if;
 if p_to_phase_id is null then
  if p_reason is not null and length(btrim(p_reason)) not between 8 and 1000 then raise exception 'Reason must be 8 to 1000 characters'; end if;
  update public.project_phase_history set planned_start_date=p_planned_start_date,forecast_completion_date=p_forecast_completion_date,actual_completion_date=p_actual_completion_date,progress_percent=p_progress_percent,change_reason=coalesce(p_reason,change_reason) where id=v_current.id returning id into v_history_id;
  return v_history_id;
 end if;
 if p_transition_at<=v_current.entered_at then raise exception 'Transition must occur after current phase entry'; end if;
 select r.reason_required into v_reason_required from public.project_lifecycle_transition_rules r join public.project_lifecycle_phases p on p.id=r.to_phase_id and p.version_id=r.version_id
 where r.version_id=v_assignment.version_id and r.from_phase_id=v_assignment.current_phase_id and r.to_phase_id=p_to_phase_id and p.is_active;
 if not found then raise exception 'Transition is not configured or target phase is inactive'; end if;
 if v_reason_required and length(btrim(coalesce(p_reason,'')))<8 then raise exception 'A documented transition reason is required'; end if;
 if p_reason is not null and length(btrim(p_reason))>1000 then raise exception 'Reason cannot exceed 1000 characters'; end if;
 update public.project_phase_history set exited_at=p_transition_at,actual_completion_date=coalesce(p_actual_completion_date,actual_completion_date),change_reason=coalesce(p_reason,change_reason) where id=v_current.id;
 insert into public.project_phase_history(assignment_id,project_id,version_id,previous_phase_id,phase_id,entered_at,planned_start_date,forecast_completion_date,progress_percent,entered_by,change_reason)
 values(v_assignment.id,p_project_id,v_assignment.version_id,v_assignment.current_phase_id,p_to_phase_id,p_transition_at,p_planned_start_date,p_forecast_completion_date,p_progress_percent,v_uid,p_reason)
 returning id into v_history_id;
 update public.project_lifecycle_assignments set current_phase_id=p_to_phase_id,current_phase_started_at=p_transition_at where id=v_assignment.id;
 return v_history_id;
end $$;

revoke all on function public.assign_project_lifecycle(uuid,uuid,uuid,text,timestamptz,date,date) from public,anon;
revoke all on function public.transition_project_phase(uuid,uuid,timestamptz,date,date,date,numeric,text) from public,anon;
grant execute on function public.assign_project_lifecycle(uuid,uuid,uuid,text,timestamptz,date,date) to authenticated;
grant execute on function public.transition_project_phase(uuid,uuid,timestamptz,date,date,date,numeric,text) to authenticated;

create or replace view public.project_current_phase with(security_invoker=true) as
select a.project_id,a.id assignment_id,a.template_id,a.version_id,p.id phase_id,p.phase_code,p.phase_name,p.display_order,
 h.entered_at phase_entered_at,h.planned_start_date,h.forecast_completion_date,h.actual_completion_date,h.progress_percent,h.change_reason
from public.project_lifecycle_assignments a
join public.project_phase_history h on h.assignment_id=a.id and h.exited_at is null
join public.project_lifecycle_phases p on p.id=h.phase_id and p.version_id=h.version_id
where a.status='active';
grant select on public.project_current_phase to authenticated;
