-- 058: Correct lifecycle scope keys so global templates can be assigned to projects.
-- A template's scope (NULL for global) is distinct from the actual project using it.

alter table public.project_lifecycle_template_versions
 add constraint lifecycle_version_template_scope_fk foreign key(template_id,project_id)
 references public.project_lifecycle_templates(id,project_id) on delete restrict;

alter table public.project_lifecycle_assignments
 drop constraint project_lifecycle_assignments_version_id_template_id_proje_fkey,
 drop constraint project_lifecycle_assignments_current_phase_id_version_id__fkey,
 add column template_scope_project_id uuid,
 add constraint lifecycle_assignment_scope_match_ck check(template_scope_project_id is null or template_scope_project_id=project_id),
 add constraint lifecycle_assignment_version_scope_fk foreign key(version_id,template_id,template_scope_project_id)
 references public.project_lifecycle_template_versions(id,template_id,project_id) on delete restrict,
 add constraint lifecycle_assignment_current_phase_scope_fk foreign key(current_phase_id,version_id,template_scope_project_id)
 references public.project_lifecycle_phases(id,version_id,project_id) on delete restrict;

alter table public.project_phase_history
 drop constraint project_phase_history_phase_id_version_id_project_id_fkey,
 drop constraint project_phase_history_previous_phase_id_version_id_project_fkey,
 add column template_scope_project_id uuid,
 add constraint lifecycle_history_scope_match_ck check(template_scope_project_id is null or template_scope_project_id=project_id),
 add constraint lifecycle_history_phase_scope_fk foreign key(phase_id,version_id,template_scope_project_id)
 references public.project_lifecycle_phases(id,version_id,project_id) on delete restrict,
 add constraint lifecycle_history_previous_phase_scope_fk foreign key(previous_phase_id,version_id,template_scope_project_id)
 references public.project_lifecycle_phases(id,version_id,project_id) on delete restrict;

-- The assignment RPC stores the lifecycle template scope separately from the project ID.
-- The phase-history RPC carries that scope into phase foreign keys for both global and
-- project-specific templates. Their authorization checks remain unchanged.
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
 insert into public.project_lifecycle_assignments(project_id,template_id,version_id,template_scope_project_id,assigned_by,assignment_reason)
 values(p_project_id,v_template_id,p_version_id,v_scope,v_uid,p_assignment_reason) returning id into v_assignment_id;
 insert into public.project_phase_history(assignment_id,project_id,version_id,template_scope_project_id,phase_id,entered_at,planned_start_date,forecast_completion_date,entered_by,change_reason)
 values(v_assignment_id,p_project_id,p_version_id,v_scope,p_initial_phase_id,coalesce(p_entered_at,now()),p_planned_start_date,p_forecast_completion_date,v_uid,p_assignment_reason);
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
 insert into public.project_phase_history(assignment_id,project_id,version_id,template_scope_project_id,previous_phase_id,phase_id,entered_at,planned_start_date,forecast_completion_date,progress_percent,entered_by,change_reason)
 values(v_assignment.id,p_project_id,v_assignment.version_id,v_assignment.template_scope_project_id,v_assignment.current_phase_id,p_to_phase_id,p_transition_at,p_planned_start_date,p_forecast_completion_date,p_progress_percent,v_uid,p_reason)
 returning id into v_history_id;
 update public.project_lifecycle_assignments set current_phase_id=p_to_phase_id,current_phase_started_at=p_transition_at where id=v_assignment.id;
 return v_history_id;
end $$;
