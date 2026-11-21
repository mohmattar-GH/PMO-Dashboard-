
create table public.project_custom_timeline_events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  event_code text not null,
  event_name text not null,
  event_description text,
  event_subtype text,
  start_date date,
  end_date date,
  date_basis text not null default 'forecast',
  status text not null default 'planned',
  severity text,
  amount numeric(18,2),
  currency_code character(3),
  owner_user_id uuid references auth.users(id) on delete set null,
  version_no integer not null default 1 check (version_no > 0),
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  updated_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint project_custom_timeline_event_code_check check (length(btrim(event_code)) between 1 and 50),
  constraint project_custom_timeline_event_name_check check (length(btrim(event_name)) between 1 and 180),
  constraint project_custom_timeline_event_dates_check check (start_date is not null or end_date is not null),
  constraint project_custom_timeline_event_date_order_check check (start_date is null or end_date is null or start_date <= end_date),
  constraint project_custom_timeline_event_basis_check check (date_basis = any(array['baseline','approved_revised','forecast','actual','contractual']::text[])),
  constraint project_custom_timeline_event_status_check check (status = any(array['planned','in_progress','completed','cancelled']::text[])),
  constraint project_custom_timeline_event_severity_check check (severity is null or severity = any(array['low','medium','high','critical']::text[])),
  constraint project_custom_timeline_event_amount_check check (amount is null or amount >= 0),
  constraint project_custom_timeline_event_currency_check check (amount is null or currency_code is not null),
  unique (project_id, event_code)
);

create table public.project_custom_timeline_event_history (
  id uuid primary key default gen_random_uuid(),
  custom_event_id uuid not null references public.project_custom_timeline_events(id) on delete restrict,
  project_id uuid not null references public.projects(id) on delete restrict,
  version_no integer not null check (version_no > 0),
  event_snapshot jsonb not null,
  changed_by uuid references auth.users(id) on delete restrict,
  changed_at timestamptz not null default now(),
  unique (custom_event_id, version_no)
);

create index project_custom_timeline_events_project_dates_idx
  on public.project_custom_timeline_events(project_id, start_date, end_date)
  where is_active;

create index project_custom_timeline_events_owner_idx
  on public.project_custom_timeline_events(owner_user_id)
  where owner_user_id is not null;

create index project_custom_timeline_event_history_event_version_idx
  on public.project_custom_timeline_event_history(custom_event_id, version_no desc);

create index project_custom_timeline_event_history_project_idx
  on public.project_custom_timeline_event_history(project_id, changed_at desc);

create index project_custom_timeline_event_history_actor_idx
  on public.project_custom_timeline_event_history(changed_by)
  where changed_by is not null;

alter table public.project_custom_timeline_events enable row level security;
alter table public.project_custom_timeline_event_history enable row level security;

create policy project_custom_timeline_events_read_project_scope
on public.project_custom_timeline_events
for select to authenticated
using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id = project_custom_timeline_events.project_id
      and pm.user_id = (select auth.uid())
      and pm.status = 'active'
      and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code = any(array['platform_admin','executive_viewer']::text[])
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

create policy project_custom_timeline_events_insert_pm_admin
on public.project_custom_timeline_events
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and updated_by = (select auth.uid())
  and (
    exists (
      select 1 from public.project_memberships pm
      where pm.project_id = project_custom_timeline_events.project_id
        and pm.user_id = (select auth.uid())
        and pm.project_role = 'project_manager'
        and pm.status = 'active'
        and pm.effective_from <= now()
        and (pm.effective_to is null or pm.effective_to > now())
    )
    or exists (
      select 1 from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid())
        and ura.role_code = 'platform_admin'
        and ura.status = 'active'
        and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
  )
);

create policy project_custom_timeline_events_update_pm_admin
on public.project_custom_timeline_events
for update to authenticated
using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id = project_custom_timeline_events.project_id
      and pm.user_id = (select auth.uid())
      and pm.project_role = 'project_manager'
      and pm.status = 'active'
      and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
)
with check (
  updated_by = (select auth.uid())
  and (
    exists (
      select 1 from public.project_memberships pm
      where pm.project_id = project_custom_timeline_events.project_id
        and pm.user_id = (select auth.uid())
        and pm.project_role = 'project_manager'
        and pm.status = 'active'
        and pm.effective_from <= now()
        and (pm.effective_to is null or pm.effective_to > now())
    )
    or exists (
      select 1 from public.user_global_role_assignments ura
      where ura.user_id = (select auth.uid())
        and ura.role_code = 'platform_admin'
        and ura.status = 'active'
        and ura.effective_from <= now()
        and (ura.effective_to is null or ura.effective_to > now())
    )
  )
);

create policy project_custom_timeline_event_history_read_pm_admin
on public.project_custom_timeline_event_history
for select to authenticated
using (
  exists (
    select 1 from public.project_memberships pm
    where pm.project_id = project_custom_timeline_event_history.project_id
      and pm.user_id = (select auth.uid())
      and pm.project_role = 'project_manager'
      and pm.status = 'active'
      and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now())
  )
  or exists (
    select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

grant select, insert, update on public.project_custom_timeline_events to authenticated;
grant select on public.project_custom_timeline_event_history to authenticated;
revoke delete on public.project_custom_timeline_events, public.project_custom_timeline_event_history from anon, authenticated;

create or replace function private.guard_project_custom_timeline_event()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if length(btrim(new.event_code)) = 0 or length(btrim(new.event_name)) = 0 then
    raise exception 'Custom timeline event code and name are required';
  end if;
  if new.start_date is null and new.end_date is null then
    raise exception 'A custom timeline event requires a start date or end date';
  end if;
  if new.start_date is not null and new.end_date is not null and new.start_date > new.end_date then
    raise exception 'Custom timeline event start date cannot be later than its end date';
  end if;
  if new.amount is not null and new.currency_code is null then
    raise exception 'A currency code is required when an amount is entered';
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
    if row(new.event_name,new.event_description,new.event_subtype,new.start_date,new.end_date,new.date_basis,new.status,new.severity,new.amount,new.currency_code,new.owner_user_id,new.is_active)
       is distinct from
       row(old.event_name,old.event_description,old.event_subtype,old.start_date,old.end_date,old.date_basis,old.status,old.severity,old.amount,old.currency_code,old.owner_user_id,old.is_active) then
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
        'date_basis',new.date_basis,'status',new.status,'severity',new.severity,'amount',new.amount,
        'currency_code',new.currency_code,'owner_user_id',new.owner_user_id,'is_active',new.is_active
      ),
      auth.uid(), now()
    );
  end if;
  return new;
end;
$function$;

revoke all on function private.guard_project_custom_timeline_event() from public, anon, authenticated;
revoke all on function private.capture_project_custom_timeline_event_history() from public, anon, authenticated;

create trigger project_custom_timeline_events_guard
before insert or update on public.project_custom_timeline_events
for each row execute function private.guard_project_custom_timeline_event();

create trigger project_custom_timeline_events_history
after insert or update on public.project_custom_timeline_events
for each row execute function private.capture_project_custom_timeline_event_history();

alter view public.project_master_schedule_timeline rename to project_master_schedule_timeline_core;

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
  e.amount as amount,
  e.currency_code as currency_code,
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

comment on table public.project_custom_timeline_events is
  'PM-managed custom schedule events included in the master schedule timeline.';
comment on table public.project_custom_timeline_event_history is
  'Immutable, versioned audit snapshots for custom master schedule events.';
