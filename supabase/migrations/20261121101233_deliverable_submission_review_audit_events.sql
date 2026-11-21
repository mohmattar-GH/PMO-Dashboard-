create trigger contract_deliverable_submissions_audit
after insert or update on public.contract_deliverable_submissions
for each row execute function private.audit_project_operational_change();

create trigger contract_deliverable_reviews_audit
after insert on public.contract_deliverable_reviews
for each row execute function private.audit_project_operational_change();
