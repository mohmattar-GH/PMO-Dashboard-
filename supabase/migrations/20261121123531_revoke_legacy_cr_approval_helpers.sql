-- Revoke client execution of obsolete CR approval and finance trigger helpers.
revoke all on function private.apply_approved_change_request_changes() from public, anon, authenticated, service_role;
revoke all on function private.guard_cr_approval_self_approval() from public, anon, authenticated, service_role;
revoke all on function private.notify_cr_approval_assignment() from public, anon, authenticated, service_role;
revoke all on function private.validate_cr_financial_submission() from public, anon, authenticated, service_role;
