
create table public.ppm_dashboard_layouts (
  id uuid primary key default gen_random_uuid(),
  layout_code text not null unique check (layout_code = 'executive_overview'),
  layout_name text not null check (length(btrim(layout_name)) between 1 and 120),
  layout_config jsonb not null,
  version_no integer not null default 1 check (version_no > 0),
  created_by uuid references auth.users(id) on delete restrict,
  updated_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ppm_dashboard_layouts_config_object check (jsonb_typeof(layout_config) = 'object')
);

create table public.ppm_dashboard_layout_history (
  id uuid primary key default gen_random_uuid(),
  layout_id uuid not null references public.ppm_dashboard_layouts(id) on delete restrict,
  version_no integer not null check (version_no > 0),
  layout_snapshot jsonb not null,
  changed_by uuid references auth.users(id) on delete restrict,
  changed_at timestamptz not null default now(),
  unique (layout_id, version_no)
);

create index ppm_dashboard_layout_history_layout_version_idx
  on public.ppm_dashboard_layout_history(layout_id, version_no desc);

alter table public.ppm_dashboard_layouts enable row level security;
alter table public.ppm_dashboard_layout_history enable row level security;

create policy ppm_dashboard_layouts_read_active_profiles
on public.ppm_dashboard_layouts
for select to authenticated
using (
  exists (
    select 1 from public.user_profiles up
    where up.user_id = (select auth.uid()) and up.is_active
  )
);

create policy ppm_dashboard_layouts_insert_platform_admin
on public.ppm_dashboard_layouts
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and updated_by = (select auth.uid())
  and exists (
    select 1
    from public.user_profiles up
    join public.user_global_role_assignments ura on ura.user_id = up.user_id
    where up.user_id = (select auth.uid())
      and up.is_active
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

create policy ppm_dashboard_layouts_update_platform_admin
on public.ppm_dashboard_layouts
for update to authenticated
using (
  exists (
    select 1
    from public.user_profiles up
    join public.user_global_role_assignments ura on ura.user_id = up.user_id
    where up.user_id = (select auth.uid())
      and up.is_active
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
)
with check (
  updated_by = (select auth.uid())
  and exists (
    select 1
    from public.user_profiles up
    join public.user_global_role_assignments ura on ura.user_id = up.user_id
    where up.user_id = (select auth.uid())
      and up.is_active
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

create policy ppm_dashboard_layout_history_read_platform_admin
on public.ppm_dashboard_layout_history
for select to authenticated
using (
  exists (
    select 1
    from public.user_profiles up
    join public.user_global_role_assignments ura on ura.user_id = up.user_id
    where up.user_id = (select auth.uid())
      and up.is_active
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

grant select, insert, update on public.ppm_dashboard_layouts to authenticated;
grant select on public.ppm_dashboard_layout_history to authenticated;
revoke delete on public.ppm_dashboard_layouts, public.ppm_dashboard_layout_history from anon, authenticated;

create or replace function private.guard_ppm_dashboard_layout()
returns trigger
language plpgsql
set search_path to ''
as $function$
declare
  v_allowed text[] := array[
    'portfolio_summary',
    'project_health',
    'project_phase',
    'project_register',
    'data_quality'
  ];
  v_visible text[];
  v_order text[];
begin
  if jsonb_typeof(new.layout_config->'visible_widgets') <> 'array'
     or jsonb_typeof(new.layout_config->'widget_order') <> 'array' then
    raise exception 'Dashboard layout requires visible_widgets and widget_order arrays';
  end if;

  v_visible := array(select jsonb_array_elements_text(new.layout_config->'visible_widgets'));
  v_order := array(select jsonb_array_elements_text(new.layout_config->'widget_order'));

  if cardinality(v_visible) < 1
     or cardinality(v_visible) <> (select count(distinct x) from unnest(v_visible) as x)
     or cardinality(v_order) <> cardinality(v_allowed)
     or cardinality(v_order) <> (select count(distinct x) from unnest(v_order) as x)
     or not (v_visible <@ v_allowed)
     or not (v_order @> v_allowed and v_allowed @> v_order)
     or not (v_visible <@ v_order) then
    raise exception 'Dashboard layout contains invalid, duplicate or missing widget identifiers';
  end if;

  if tg_op = 'INSERT' then
    if new.version_no <> 1 then
      raise exception 'New dashboard layouts must start at version 1';
    end if;
    new.created_by := coalesce(new.created_by, auth.uid());
    new.updated_by := coalesce(new.updated_by, auth.uid());
    new.updated_at := now();
  else
    if new.id is distinct from old.id
       or new.layout_code is distinct from old.layout_code
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
      raise exception 'Dashboard layout identity and creator are immutable';
    end if;
    if new.layout_config is distinct from old.layout_config
       or new.layout_name is distinct from old.layout_name then
      new.version_no := old.version_no + 1;
      new.updated_by := auth.uid();
      new.updated_at := now();
    else
      new.version_no := old.version_no;
      new.updated_by := old.updated_by;
      new.updated_at := old.updated_at;
    end if;
  end if;
  return new;
end;
$function$;

create or replace function private.capture_ppm_dashboard_layout_history()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if tg_op = 'INSERT'
     or new.layout_config is distinct from old.layout_config
     or new.layout_name is distinct from old.layout_name then
    insert into public.ppm_dashboard_layout_history(
      layout_id, version_no, layout_snapshot, changed_by, changed_at
    ) values (
      new.id, new.version_no,
      jsonb_build_object(
        'layout_code', new.layout_code,
        'layout_name', new.layout_name,
        'layout_config', new.layout_config
      ),
      auth.uid(), now()
    );
  end if;
  return new;
end;
$function$;

revoke all on function private.guard_ppm_dashboard_layout() from public, anon, authenticated;
revoke all on function private.capture_ppm_dashboard_layout_history() from public, anon, authenticated;

create trigger ppm_dashboard_layouts_guard
before insert or update on public.ppm_dashboard_layouts
for each row execute function private.guard_ppm_dashboard_layout();

create trigger ppm_dashboard_layouts_history
after insert or update on public.ppm_dashboard_layouts
for each row execute function private.capture_ppm_dashboard_layout_history();

insert into public.ppm_dashboard_layouts(
  layout_code, layout_name, layout_config, version_no
) values (
  'executive_overview',
  'Executive Overview',
  '{
    "visible_widgets": ["portfolio_summary","project_health","project_phase","project_register","data_quality"],
    "widget_order": ["portfolio_summary","project_health","project_phase","project_register","data_quality"]
  }'::jsonb,
  1
);

comment on table public.ppm_dashboard_layouts is
  'Versioned administrator-managed visibility and ordering configuration for the Executive Overview dashboard.';
comment on table public.ppm_dashboard_layout_history is
  'Immutable snapshots of every saved Executive Overview layout version.';
