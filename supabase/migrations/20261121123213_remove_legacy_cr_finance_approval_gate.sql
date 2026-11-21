
-- Remove the legacy submission-time Finance approval-stage prerequisite.
drop trigger if exists project_cr_financial_submission_guard on public.project_change_requests;

-- Trigger-only implementation helper is not a callable API.
revoke all on function private.apply_pm_accepted_change_request() from public, anon, authenticated, service_role;

-- Explicitly preserve historical approval rows while denying future client-side mutation.
revoke insert, update, delete on public.project_change_request_approvals from public, anon, authenticated;
