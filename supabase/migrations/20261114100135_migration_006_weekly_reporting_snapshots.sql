begin;

create table public.reporting_cycles (
  id uuid primary key default gen_random_uuid(),
  cycle_code text not null unique check (length(btrim(cycle_code)) > 0),
  period_start date not null,
  period_end date not null,
  cutoff_at timestamptz not null,
  as_of_date date not null,
  timezone text not null,
  status text not null default 'draft'
    check (status in ('draft','open','closed','snapshotted','cancelled')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (period_end >= period_start),
  check (as_of_date between period_start and period_end)
);

create table public.portfolio_snapshots (
  id uuid primary key default gen_random_uuid(),
  reporting_cycle_id uuid not null unique references public.reporting_cycles(id) on delete restrict,
  generated_at timestamptz not null default now(),
  generated_by uuid references auth.users(id) on delete set null,
  snapshot_status text not null default 'building'
    check (snapshot_status in ('building','finalized')),
  source_watermark timestamptz,
  portfolio_summary jsonb not null default '{}'::jsonb
    check (jsonb_typeof(portfolio_summary) = 'object'),
  created_at timestamptz not null default now()
);

create table public.project_snapshots (
  id uuid primary key default gen_random_uuid(),
  portfolio_snapshot_id uuid not null references public.portfolio_snapshots(id) on delete restrict,
  project_id uuid not null references public.projects(id) on delete restrict,
  source_updated_at timestamptz,
  calculated_health text,
  reported_health text,
  snapshot_payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(snapshot_payload) = 'object'),
  created_at timestamptz not null default now(),
  unique (portfolio_snapshot_id, project_id)
);

create table public.snapshot_metric_values (
  id uuid primary key default gen_random_uuid(),
  project_snapshot_id uuid not null references public.project_snapshots(id) on delete restrict,
  kpi_code text not null check (length(btrim(kpi_code)) > 0),
  numeric_value numeric,
  text_value text,
  unit text,
  status text not null check (length(btrim(status)) > 0),
  source_lineage jsonb not null default '[]'::jsonb
    check (jsonb_typeof(source_lineage) = 'array'),
  created_at timestamptz not null default now(),
  unique (project_snapshot_id, kpi_code),
  check (numeric_value is null or text_value is null)
);

create table public.snapshot_config_links (
  id uuid primary key default gen_random_uuid(),
  portfolio_snapshot_id uuid not null references public.portfolio_snapshots(id) on delete restrict,
  configuration_version_id uuid not null references public.reporting_configuration_versions(id) on delete restrict,
  scope_type text not null check (scope_type in ('global','project')),
  scope_entity_id uuid,
  created_at timestamptz not null default now(),
  check (
    (scope_type = 'global' and scope_entity_id is null) or
    (scope_type = 'project' and scope_entity_id is not null)
  ),
  unique (portfolio_snapshot_id, configuration_version_id, scope_type, scope_entity_id)
);

create table public.snapshot_corrections (
  id uuid primary key default gen_random_uuid(),
  original_snapshot_id uuid not null references public.portfolio_snapshots(id) on delete restrict,
  replacement_snapshot_id uuid not null references public.portfolio_snapshots(id) on delete restrict,
  reason text not null check (length(btrim(reason)) between 8 and 1000),
  approved_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (original_snapshot_id <> replacement_snapshot_id),
  unique (original_snapshot_id, replacement_snapshot_id)
);

create index reporting_cycles_period_idx on public.reporting_cycles(period_start, period_end);
create index project_snapshots_project_idx on public.project_snapshots(project_id, created_at desc);
create index snapshot_metric_values_kpi_idx on public.snapshot_metric_values(kpi_code, status);
create index snapshot_config_links_version_idx on public.snapshot_config_links(configuration_version_id);

-- Keep reporting-cycle changes controlled once a snapshot exists.
create or replace function private.guard_reporting_cycle_mutation()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if exists (select 1 from public.portfolio_snapshots ps where ps.reporting_cycle_id = old.id) then
    raise exception 'A reporting cycle linked to a snapshot cannot be changed or deleted';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger reporting_cycles_guard_update
before update or delete on public.reporting_cycles
for each row execute function private.guard_reporting_cycle_mutation();

-- A snapshot may be assembled only while building, then finalized exactly once.
create or replace function private.guard_portfolio_snapshot_mutation()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Portfolio snapshots are append-only';
  end if;
  if old.snapshot_status <> 'building'
     or new.snapshot_status <> 'finalized'
     or (to_jsonb(new) - 'snapshot_status') <> (to_jsonb(old) - 'snapshot_status') then
    raise exception 'Only the building-to-finalized transition is permitted';
  end if;
  return new;
end;
$$;

create trigger portfolio_snapshots_immutable
before update or delete on public.portfolio_snapshots
for each row execute function private.guard_portfolio_snapshot_mutation();

-- Child records can be inserted only while the parent snapshot is building.
create or replace function private.guard_snapshot_child_insert()
returns trigger language plpgsql set search_path = ''
as $$
declare v_snapshot_id uuid;
begin
  if tg_table_name = 'project_snapshots' then
    v_snapshot_id := new.portfolio_snapshot_id;
  elsif tg_table_name = 'snapshot_config_links' then
    v_snapshot_id := new.portfolio_snapshot_id;
  elsif tg_table_name = 'snapshot_metric_values' then
    select portfolio_snapshot_id into v_snapshot_id
    from public.project_snapshots where id = new.project_snapshot_id;
  end if;
  if v_snapshot_id is null or not exists (
    select 1 from public.portfolio_snapshots
    where id = v_snapshot_id and snapshot_status = 'building'
  ) then
    raise exception 'Snapshot child records can only be added while the parent snapshot is building';
  end if;
  return new;
end;
$$;

create or replace function private.reject_snapshot_child_mutation()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'Snapshot records are immutable; create a replacement snapshot instead';
end;
$$;

create trigger project_snapshots_insert_guard
before insert on public.project_snapshots
for each row execute function private.guard_snapshot_child_insert();
create trigger project_snapshots_no_mutation
before update or delete on public.project_snapshots
for each row execute function private.reject_snapshot_child_mutation();

create trigger snapshot_metric_values_insert_guard
before insert on public.snapshot_metric_values
for each row execute function private.guard_snapshot_child_insert();
create trigger snapshot_metric_values_no_mutation
before update or delete on public.snapshot_metric_values
for each row execute function private.reject_snapshot_child_mutation();

create trigger snapshot_config_links_insert_guard
before insert on public.snapshot_config_links
for each row execute function private.guard_snapshot_child_insert();
create trigger snapshot_config_links_no_mutation
before update or delete on public.snapshot_config_links
for each row execute function private.reject_snapshot_child_mutation();

create trigger snapshot_corrections_no_mutation
before update or delete on public.snapshot_corrections
for each row execute function private.reject_snapshot_child_mutation();

alter table public.reporting_cycles enable row level security;
alter table public.portfolio_snapshots enable row level security;
alter table public.project_snapshots enable row level security;
alter table public.snapshot_metric_values enable row level security;
alter table public.snapshot_config_links enable row level security;
alter table public.snapshot_corrections enable row level security;

create policy reporting_cycles_read_authorized on public.reporting_cycles
for select to authenticated using (
  exists (
    select 1 from public.portfolio_snapshots ps
    where ps.reporting_cycle_id = reporting_cycles.id
      and (
        exists (select 1 from public.user_global_role_assignments ura
          where ura.user_id = (select auth.uid()) and ura.role_code in ('platform_admin','executive_viewer')
            and ura.status = 'active' and ura.effective_from <= now()
            and (ura.effective_to is null or ura.effective_to > now()))
      )
  )
);

create policy portfolio_snapshots_read_executives on public.portfolio_snapshots
for select to authenticated using (
  exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code in ('platform_admin','executive_viewer')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
);

create policy project_snapshots_read_authorized on public.project_snapshots
for select to authenticated using (
  exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code in ('platform_admin','executive_viewer')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
  or exists (select 1 from public.project_memberships pm
    where pm.project_id = project_snapshots.project_id and pm.user_id = (select auth.uid())
      and pm.status = 'active' and pm.effective_from <= now()
      and (pm.effective_to is null or pm.effective_to > now()))
);

create policy snapshot_metric_values_read_authorized on public.snapshot_metric_values
for select to authenticated using (
  exists (select 1 from public.project_snapshots pjs
    join public.user_global_role_assignments ura on ura.user_id = (select auth.uid())
    where pjs.id = snapshot_metric_values.project_snapshot_id
      and ura.role_code in ('platform_admin','executive_viewer')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
  or exists (select 1 from public.project_snapshots pjs
    join public.project_memberships pm on pm.project_id = pjs.project_id
    where pjs.id = snapshot_metric_values.project_snapshot_id
      and pm.user_id = (select auth.uid()) and pm.status = 'active'
      and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now()))
);

create policy snapshot_config_links_read_authorized on public.snapshot_config_links
for select to authenticated using (
  exists (select 1 from public.portfolio_snapshots ps
    join public.user_global_role_assignments ura on ura.user_id = (select auth.uid())
    where ps.id = snapshot_config_links.portfolio_snapshot_id
      and ura.role_code in ('platform_admin','executive_viewer')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
  or (scope_type = 'project' and exists (
    select 1 from public.project_memberships pm
    where pm.project_id = snapshot_config_links.scope_entity_id
      and pm.user_id = (select auth.uid()) and pm.status = 'active'
      and pm.effective_from <= now() and (pm.effective_to is null or pm.effective_to > now())
  ))
);

create policy snapshot_corrections_read_executives on public.snapshot_corrections
for select to authenticated using (
  exists (select 1 from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid()) and ura.role_code in ('platform_admin','executive_viewer')
      and ura.status = 'active' and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now()))
);

revoke all on public.reporting_cycles, public.portfolio_snapshots, public.project_snapshots,
  public.snapshot_metric_values, public.snapshot_config_links, public.snapshot_corrections
  from anon, authenticated;
grant select on public.reporting_cycles, public.portfolio_snapshots, public.project_snapshots,
  public.snapshot_metric_values, public.snapshot_config_links, public.snapshot_corrections
  to authenticated;
grant all on public.reporting_cycles, public.portfolio_snapshots, public.project_snapshots,
  public.snapshot_metric_values, public.snapshot_config_links, public.snapshot_corrections
  to service_role;

commit;