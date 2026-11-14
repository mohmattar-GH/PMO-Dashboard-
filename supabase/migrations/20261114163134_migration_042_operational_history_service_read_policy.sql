begin;
create policy operational_history_coverage_service_read
on private.operational_history_coverage
for select to service_role
using (true);
create policy operational_record_history_service_read
on private.operational_record_history
for select to service_role
using (true);
drop index if exists private.operational_record_history_project_time_idx;
commit;