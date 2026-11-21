
drop view public.project_master_schedule_timeline;

alter table public.project_custom_timeline_events
  drop constraint project_custom_timeline_event_amount_check,
  drop constraint project_custom_timeline_event_currency_check,
  drop column amount,
  drop column currency_code;

create or replace function private.guard_project_custom_timeline_event()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  new.event_code := btrim(new.event_code);
  new.event_name := btrim(new.event_name);
  if length(new.event_code) = 0 or length(new.event_name) = 0 then
    raise exception 'Custom timeline event code and name are required';
  end if;
  if new.start_date is null and new.end_date is null then
    raise exception 'A custom timeline event requires a start date or end date';
  end if;
  if new.start_date is not null and new.end_date is not null and new.start_date > new.end_date then
    raise exception 'Custom timeline event start date cannot be later than its end date';
  end if;

  if tg_op = 'INSERT' then
    new.version_no := 1;
    new.created_by := auth.uid();
    new.updated_by := auth.uid();
    new.updated_at := now();
  else
    if new.id is distinct from old.id
       or new.project_id is distinct from old.project_id
       or new.event_code is distinct from old.event_code
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
      raise exception 'Custom timeline event identity and creator are immutable';
    end if;
    if row(new.event_name,new.event_description,new.event_subtype,new.start_date,new.end_date,new.date_basis,new.status,new.severity,new.owner_user_id,new.is_active)
       is distinct from
       row(old.event_name,old.event_description,old.event_subtype,old.start_date,old.end_date,old.date_basis,old.status,old.severity,old.owner_user_id,old.is_active) then
      new.version_no := old.version_no + 1;
    else
      new.version_no := old.version_no;
    end if;
    new.updated_by := auth.uid();
    new.updated_at := now();
  end if;
  return new;
end;
$function$;

create or replace function private.capture_project_custom_timeline_event_history()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if tg_op = 'INSERT' or new.version_no is distinct from old.version_no then
    insert into public.project_custom_timeline_event_history(
      custom_event_id, project_id, version_no, event_snapshot, changed_by, changed_at
    ) values (
      new.id, new.project_id, new.version_no,
      jsonb_build_object(
        'event_code',new.event_code,'event_name',new.event_name,'event_description',new.event_description,
        'event_subtype',new.event_subtype,'start_date',new.start_date,'end_date',new.end_date,
        'date_basis',new.date_basis,'status',new.status,'severity',new.severity,
        'owner_user_id',new.owner_user_id,'is_active',new.is_active
      ),
      auth.uid(), now()
    );
  end if;
  return new;
end;
$function$;

create view public.project_master_schedule_timeline
with (security_invoker = true)
as
select * from public.project_master_schedule_timeline_core
union all
select
  ('custom_event:' || e.id::text || ':current') as event_id,
  e.project_id,
  'custom_timeline_event'::text as source_entity_type,
  e.id as source_record_id,
  'custom_event'::text as event_category,
  e.event_name as event_name,
  e.start_date as event_start_date,
  e.end_date as event_end_date,
  e.date_basis as date_basis,
  e.status as record_status,
  e.severity as severity,
  null::numeric as amount,
  null::character(3) as currency_code,
  e.owner_user_id as owner_user_id,
  e.event_code as source_reference,
  jsonb_build_object(
    'event_subtype',e.event_subtype,
    'event_description',e.event_description,
    'version_no',e.version_no
  ) as metadata
from public.project_custom_timeline_events e
where e.is_active;

revoke all on public.project_master_schedule_timeline from anon;
grant select on public.project_master_schedule_timeline to authenticated;
revoke all on function private.guard_project_custom_timeline_event() from public, anon, authenticated;
revoke all on function private.capture_project_custom_timeline_event_history() from public, anon, authenticated;
