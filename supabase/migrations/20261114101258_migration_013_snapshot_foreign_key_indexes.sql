begin;
create index if not exists reporting_snapshot_job_runs_snapshot_idx
  on private.reporting_snapshot_job_runs(snapshot_id) where snapshot_id is not null;
create index if not exists portfolio_snapshots_generated_by_idx
  on public.portfolio_snapshots(generated_by) where generated_by is not null;
create index if not exists reporting_cycles_created_by_idx
  on public.reporting_cycles(created_by) where created_by is not null;
create index if not exists snapshot_corrections_approved_by_idx
  on public.snapshot_corrections(approved_by);
create index if not exists snapshot_corrections_replacement_snapshot_idx
  on public.snapshot_corrections(replacement_snapshot_id);
commit;
