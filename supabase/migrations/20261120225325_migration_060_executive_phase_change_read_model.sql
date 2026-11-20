-- RECOVERED SOURCE: reconstructed from pg_get_viewdef and pg_class.reloptions
-- on the live database. This is not the original historical file. Clean replay
-- verification is still required.
--
-- Security-invoker semantics are essential: underlying table grants and RLS
-- policies must continue to apply to the querying user.

create or replace view public.project_phase_change_log
with (security_invoker = true)
as
select
  h.id,
  h.project_id,
  pr.project_code,
  pr.name as project_name,
  prev.phase_name as previous_phase_name,
  next_phase.phase_name,
  h.entered_at,
  h.exited_at,
  h.change_reason
from public.project_phase_history h
join public.projects pr
  on pr.id = h.project_id
join public.project_lifecycle_phases next_phase
  on next_phase.id = h.phase_id
 and next_phase.version_id = h.version_id
 and next_phase.project_id is not distinct from h.template_scope_project_id
left join public.project_lifecycle_phases prev
  on prev.id = h.previous_phase_id
 and prev.version_id = h.version_id
 and prev.project_id is not distinct from h.template_scope_project_id
where h.previous_phase_id is not null;

grant select on public.project_phase_change_log to authenticated;
