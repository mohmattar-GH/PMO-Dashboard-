-- RECOVERED SOURCE: reconstructed from the live PostgreSQL pg_policies catalog.
-- This is not the original historical file. It preserves the live post-migration
-- policy behavior observed on 2026-11-21. Review and clean-replay verification
-- are required before treating this archive as a canonical migration.
--
-- Grant active Executive Viewer and Platform Administrator roles read access
-- to non-financial lifecycle configuration and project phase history.

alter policy lifecycle_templates_select
on public.project_lifecycle_templates
using (
  project_id is null
  or exists (
    select 1
    from public.project_memberships m
    where m.project_id = project_lifecycle_templates.project_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.effective_from <= now()
      and (m.effective_to is null or m.effective_to > now())
  )
  or exists (
    select 1
    from public.user_global_role_assignments r
    where r.user_id = (select auth.uid())
      and r.role_code = any (array['platform_admin','executive_viewer'])
      and r.status = 'active'
      and r.effective_from <= now()
      and (r.effective_to is null or r.effective_to > now())
  )
);

alter policy lifecycle_versions_select
on public.project_lifecycle_template_versions
using (
  exists (
    select 1
    from public.project_lifecycle_templates t
    where t.id = project_lifecycle_template_versions.template_id
      and (
        t.project_id is null
        or exists (
          select 1
          from public.project_memberships m
          where m.project_id = t.project_id
            and m.user_id = (select auth.uid())
            and m.status = 'active'
            and m.effective_from <= now()
            and (m.effective_to is null or m.effective_to > now())
        )
      )
  )
  or exists (
    select 1
    from public.user_global_role_assignments r
    where r.user_id = (select auth.uid())
      and r.role_code = any (array['platform_admin','executive_viewer'])
      and r.status = 'active'
      and r.effective_from <= now()
      and (r.effective_to is null or r.effective_to > now())
  )
);

alter policy lifecycle_phases_select
on public.project_lifecycle_phases
using (
  exists (
    select 1
    from public.project_lifecycle_template_versions v
    join public.project_lifecycle_templates t on t.id = v.template_id
    where v.id = project_lifecycle_phases.version_id
      and (
        t.project_id is null
        or exists (
          select 1
          from public.project_memberships m
          where m.project_id = t.project_id
            and m.user_id = (select auth.uid())
            and m.status = 'active'
            and m.effective_from <= now()
            and (m.effective_to is null or m.effective_to > now())
        )
      )
  )
  or exists (
    select 1
    from public.user_global_role_assignments r
    where r.user_id = (select auth.uid())
      and r.role_code = any (array['platform_admin','executive_viewer'])
      and r.status = 'active'
      and r.effective_from <= now()
      and (r.effective_to is null or r.effective_to > now())
  )
);

alter policy lifecycle_rules_select
on public.project_lifecycle_transition_rules
using (
  exists (
    select 1
    from public.project_lifecycle_template_versions v
    join public.project_lifecycle_templates t on t.id = v.template_id
    where v.id = project_lifecycle_transition_rules.version_id
      and (
        t.project_id is null
        or exists (
          select 1
          from public.project_memberships m
          where m.project_id = t.project_id
            and m.user_id = (select auth.uid())
            and m.status = 'active'
            and m.effective_from <= now()
            and (m.effective_to is null or m.effective_to > now())
        )
      )
  )
  or exists (
    select 1
    from public.user_global_role_assignments r
    where r.user_id = (select auth.uid())
      and r.role_code = any (array['platform_admin','executive_viewer'])
      and r.status = 'active'
      and r.effective_from <= now()
      and (r.effective_to is null or r.effective_to > now())
  )
);

alter policy lifecycle_assignments_select
on public.project_lifecycle_assignments
using (
  exists (
    select 1
    from public.project_memberships m
    where m.project_id = project_lifecycle_assignments.project_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.effective_from <= now()
      and (m.effective_to is null or m.effective_to > now())
  )
  or exists (
    select 1
    from public.user_global_role_assignments r
    where r.user_id = (select auth.uid())
      and r.role_code = any (array['platform_admin','executive_viewer'])
      and r.status = 'active'
      and r.effective_from <= now()
      and (r.effective_to is null or r.effective_to > now())
  )
);

alter policy phase_history_select
on public.project_phase_history
using (
  exists (
    select 1
    from public.project_memberships m
    where m.project_id = project_phase_history.project_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.effective_from <= now()
      and (m.effective_to is null or m.effective_to > now())
  )
  or exists (
    select 1
    from public.user_global_role_assignments r
    where r.user_id = (select auth.uid())
      and r.role_code = any (array['platform_admin','executive_viewer'])
      and r.status = 'active'
      and r.effective_from <= now()
      and (r.effective_to is null or r.effective_to > now())
  )
);
