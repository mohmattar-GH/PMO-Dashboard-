begin;
create index if not exists reporting_configuration_audit_actor_user_id_idx on private.reporting_configuration_audit(actor_user_id);
create index if not exists reporting_configuration_audit_configuration_version_id_idx on private.reporting_configuration_audit(configuration_version_id);
create index if not exists reporting_configuration_sets_created_by_idx on public.reporting_configuration_sets(created_by);
create index if not exists reporting_configuration_versions_approved_by_idx on public.reporting_configuration_versions(approved_by);
create index if not exists reporting_configuration_versions_created_by_idx on public.reporting_configuration_versions(created_by);
create index if not exists reporting_configuration_versions_published_by_idx on public.reporting_configuration_versions(published_by);
create index if not exists reporting_configuration_versions_submitted_by_idx on public.reporting_configuration_versions(submitted_by);
create policy reporting_configuration_audit_deny_client_roles on private.reporting_configuration_audit
 for all to public, anon, authenticated using(false) with check(false);
create policy security_audit_events_deny_client_roles on private.security_audit_events
 for all to public, anon, authenticated using(false) with check(false);
commit;