-- Close historical snapshot financial-data exposure.
-- Executive viewers retain snapshot metadata and project health, but cannot
-- read opaque JSON payloads, portfolio summary JSON, or unclassified KPI values.

-- Restrict project snapshot columns: snapshot_payload is intentionally withheld
-- until a typed, sensitivity-filtered snapshot API is implemented.
revoke select on table public.project_snapshots from authenticated;
grant select (
  id, portfolio_snapshot_id, project_id, source_updated_at,
  calculated_health, reported_health, created_at
) on table public.project_snapshots to authenticated;

-- Portfolio summary is JSON and its key/value sensitivity has not yet been
-- classified. Keep snapshot metadata accessible, but withhold summary JSON.
revoke select on table public.portfolio_snapshots from authenticated;
grant select (
  id, reporting_cycle_id, generated_at, generated_by,
  snapshot_status, source_watermark, created_at
) on table public.portfolio_snapshots to authenticated;

-- Executive users must not read unclassified metric values. Preserve existing
-- project-membership and platform-admin paths, while removing executive role.
drop policy if exists snapshot_metric_values_read_authorized on public.snapshot_metric_values;
create policy snapshot_metric_values_read_authorized
on public.snapshot_metric_values for select to authenticated
using (
  exists (
    select 1 from public.project_snapshots pjs
    join public.user_global_role_assignments ura on ura.user_id = (select auth.uid())
    where pjs.id = snapshot_metric_values.project_snapshot_id
      and ura.role_code = 'platform_admin'
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
  or exists (
    select 1 from public.project_snapshots pjs
    join public.project_memberships pm on pm.project_id = pjs.project_id
    where pjs.id = snapshot_metric_values.project_snapshot_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active' and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
  )
);

-- Ensure the two JSON-bearing snapshot columns cannot be read through the
-- authenticated Data API, even if a broad SELECT policy exists.
