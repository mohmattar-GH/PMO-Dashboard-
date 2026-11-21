create or replace function private.guard_cr_approval_self_approval()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_requester uuid;
begin
  if new.status in ('approved','rejected','returned')
     and old.status='pending' then
    select cr.requested_by into v_requester
    from public.project_change_requests cr
    where cr.id=new.change_request_id;
    if new.status='approved' and v_requester is not null and v_requester=auth.uid() then
      raise exception 'A Change Request requester cannot approve their own request';
    end if;
    -- Store the constrained decision vocabulary, not the UI action verb.
    new.decision := new.status;
    perform set_config('app.ppm_cr_approval_result',new.status,true);
  end if;
  return new;
end;
$$;
