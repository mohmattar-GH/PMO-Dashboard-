-- Allow recipients to update only their own read and acknowledgement flags.
-- The existing RLS policy scopes rows to auth.uid(), and the update guard
-- keeps notification content, recipient, timestamps and acknowledgement rules controlled.
grant update (is_read, acknowledged_at) on public.ppm_user_notifications to authenticated;
