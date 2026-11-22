-- Provide stable API surfaces for safe snapshot metadata.
-- SECURITY INVOKER ensures base-table grants and RLS are evaluated as caller.
create or replace view public.project_snapshot_index
with (security_invoker = true)
as
select id, portfolio_snapshot_id, project_id, source_updated_at,
       calculated_health, reported_health, created_at
from public.project_snapshots;

create or replace view public.portfolio_snapshot_index
with (security_invoker = true)
as
select id, reporting_cycle_id, generated_at, generated_by,
       snapshot_status, source_watermark, created_at
from public.portfolio_snapshots;

grant select on public.project_snapshot_index to authenticated;
grant select on public.portfolio_snapshot_index to authenticated;
