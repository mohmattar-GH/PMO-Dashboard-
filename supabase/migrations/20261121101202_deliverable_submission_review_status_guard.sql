create or replace function private.guard_deliverable_submission_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op='INSERT' then
    if coalesce(current_setting('app.ppm_deliverable_submit',true),'')<>'on' then
      raise exception 'Create deliverable submissions through the submission action';
    end if;
    new.submitted_by:=auth.uid();
    new.submitted_at:=now();
    new.status:='submitted';
    return new;
  end if;

  if tg_op='UPDATE'
     and coalesce(current_setting('app.ppm_deliverable_review',true),'')='on'
     and (to_jsonb(new)-'status') is not distinct from (to_jsonb(old)-'status') then
    return new;
  end if;

  raise exception 'Deliverable submission records are immutable except for controlled review status updates';
end;
$$;
