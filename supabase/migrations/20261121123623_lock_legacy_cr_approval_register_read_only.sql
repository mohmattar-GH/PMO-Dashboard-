-- The legacy CR approval register is retained for audit/history only; no API role may add or alter approval rows.
revoke insert, update, delete on public.project_change_request_approvals from service_role;
