begin;
create table public.reporting_configuration_sets (
 id uuid primary key default gen_random_uuid(),
 scope_type text not null check(scope_type in ('global','project')),
 project_id uuid references public.projects(id) on delete restrict,
 configuration_code text not null, name text not null, description text,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 check((scope_type='global' and project_id is null) or (scope_type='project' and project_id is not null)),
 check(length(btrim(configuration_code))>0), check(length(btrim(name))>0)
);
create unique index reporting_configuration_global_code_uq on public.reporting_configuration_sets(configuration_code) where scope_type='global';
create unique index reporting_configuration_project_code_uq on public.reporting_configuration_sets(project_id,configuration_code) where scope_type='project';
create index reporting_configuration_project_idx on public.reporting_configuration_sets(project_id);

create table public.reporting_configuration_versions (
 id uuid primary key default gen_random_uuid(),
 configuration_set_id uuid not null references public.reporting_configuration_sets(id) on delete restrict,
 version_number integer not null check(version_number>0),
 status text not null default 'draft' check(status in ('draft','submitted','approved','published','rejected','superseded')),
 effective_from timestamptz, effective_to timestamptz,
 change_summary text not null,
 created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
 submitted_by uuid references auth.users(id) on delete set null, submitted_at timestamptz,
 approved_by uuid references auth.users(id) on delete set null, approved_at timestamptz,
 published_by uuid references auth.users(id) on delete set null, published_at timestamptz,
 unique(configuration_set_id,version_number),
 check(effective_to is null or effective_from is null or effective_to>effective_from),
 check((approved_at is null and approved_by is null) or (approved_at is not null and approved_by is not null)),
 check((published_at is null and published_by is null) or (published_at is not null and published_by is not null))
);
create unique index reporting_configuration_one_published_uq on public.reporting_configuration_versions(configuration_set_id) where status='published';
create index reporting_configuration_versions_effective_idx on public.reporting_configuration_versions(configuration_set_id,status,effective_from,effective_to);

create table public.reporting_dimensions (
 id uuid primary key default gen_random_uuid(),
 configuration_version_id uuid not null references public.reporting_configuration_versions(id) on delete restrict,
 dimension_code text not null, name text not null, description text,
 display_order integer not null default 0,
 weight numeric(9,6) check(weight is null or weight between 0 and 1),
 is_active boolean not null default true,
 missing_data_status text not null default 'not_reported' check(missing_data_status in ('not_reported','insufficient_data')),
 created_at timestamptz not null default now(),
 unique(configuration_version_id,dimension_code), check(length(btrim(dimension_code))>0)
);
create table public.kpi_definitions (
 id uuid primary key default gen_random_uuid(),
 configuration_version_id uuid not null references public.reporting_configuration_versions(id) on delete restrict,
 dimension_id uuid references public.reporting_dimensions(id) on delete restrict,
 kpi_code text not null, name text not null, description text,
 calculation_method text not null, formula_template text not null,
 source_mapping jsonb not null default '{}'::jsonb, parameters jsonb not null default '{}'::jsonb,
 unit text, weight numeric(9,6) check(weight is null or weight between 0 and 1),
 is_active boolean not null default true, display_order integer not null default 0,
 created_at timestamptz not null default now(),
 unique(configuration_version_id,kpi_code),
 check(jsonb_typeof(source_mapping)='object'), check(jsonb_typeof(parameters)='object'),
 check(length(btrim(formula_template))>0)
);
create index kpi_definitions_dimension_idx on public.kpi_definitions(dimension_id);
create table public.reporting_rule_parameters (
 id uuid primary key default gen_random_uuid(),
 configuration_version_id uuid not null references public.reporting_configuration_versions(id) on delete restrict,
 rule_code text not null, parameter_code text not null, parameter_value jsonb not null,
 value_type text not null check(value_type in ('number','integer','text','boolean','date','duration','json')),
 description text, validation_definition jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 unique(configuration_version_id,rule_code,parameter_code),
 check(jsonb_typeof(validation_definition)='object')
);
create index reporting_rule_parameters_rule_idx on public.reporting_rule_parameters(configuration_version_id,rule_code);
create table private.reporting_configuration_audit (
 id uuid primary key default gen_random_uuid(),
 configuration_set_id uuid not null references public.reporting_configuration_sets(id) on delete restrict,
 configuration_version_id uuid references public.reporting_configuration_versions(id) on delete restrict,
 actor_user_id uuid references auth.users(id) on delete set null,
 action text not null, reason text not null, before_data jsonb, after_data jsonb,
 created_at timestamptz not null default now()
);
create index reporting_configuration_audit_set_created_idx on private.reporting_configuration_audit(configuration_set_id,created_at desc);

create function private.guard_reporting_version_header()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
 if old.status='published' then
   if tg_op='UPDATE' and old.status='published' and new.status='superseded'
      and (to_jsonb(new)-'status')=(to_jsonb(old)-'status') then
     return new;
   end if;
   raise exception 'Published reporting configuration versions are immutable except for superseding';
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end; $$;
create function private.guard_published_reporting_child()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
declare v_id uuid; v_status text;
begin
 if tg_op='DELETE' then v_id:=old.configuration_version_id; else v_id:=new.configuration_version_id; end if;
 select status into v_status from public.reporting_configuration_versions where id=v_id;
 if v_status in ('published','superseded') then
   raise exception 'Rules belonging to a published configuration version are immutable';
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end; $$;
revoke all on function private.guard_reporting_version_header() from public,anon,authenticated;
revoke all on function private.guard_published_reporting_child() from public,anon,authenticated;
create trigger reporting_configuration_versions_immutable before update or delete on public.reporting_configuration_versions for each row execute function private.guard_reporting_version_header();
create trigger reporting_dimensions_immutable before insert or update or delete on public.reporting_dimensions for each row execute function private.guard_published_reporting_child();
create trigger kpi_definitions_immutable before insert or update or delete on public.kpi_definitions for each row execute function private.guard_published_reporting_child();
create trigger reporting_rule_parameters_immutable before insert or update or delete on public.reporting_rule_parameters for each row execute function private.guard_published_reporting_child();

alter table public.reporting_configuration_sets enable row level security;
alter table public.reporting_configuration_versions enable row level security;
alter table public.reporting_dimensions enable row level security;
alter table public.kpi_definitions enable row level security;
alter table public.reporting_rule_parameters enable row level security;
alter table private.reporting_configuration_audit enable row level security;

create policy reporting_configuration_sets_read_authorized on public.reporting_configuration_sets for select to authenticated using (
 (scope_type='global' and exists(select 1 from public.reporting_configuration_versions v where v.configuration_set_id=id and v.status='published'))
 or (scope_type='project' and exists(select 1 from public.project_memberships pm where pm.project_id=reporting_configuration_sets.project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())))
 or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code in ('platform_admin','configuration_steward','configuration_approver') and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
);
create policy reporting_configuration_versions_read_authorized on public.reporting_configuration_versions for select to authenticated using (
 (status='published' and exists(select 1 from public.reporting_configuration_sets s where s.id=configuration_set_id and s.scope_type='global'))
 or exists(select 1 from public.reporting_configuration_sets s join public.project_memberships pm on pm.project_id=s.project_id where s.id=reporting_configuration_versions.configuration_set_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
 or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code in ('platform_admin','configuration_steward','configuration_approver') and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
);
create policy reporting_dimensions_read_authorized on public.reporting_dimensions for select to authenticated using (exists(
 select 1 from public.reporting_configuration_versions v join public.reporting_configuration_sets s on s.id=v.configuration_set_id
 where v.id=reporting_dimensions.configuration_version_id and (
 (v.status='published' and s.scope_type='global')
 or (s.scope_type='project' and exists(select 1 from public.project_memberships pm where pm.project_id=s.project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())))
 or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code in ('platform_admin','configuration_steward','configuration_approver') and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
 )));
create policy kpi_definitions_read_authorized on public.kpi_definitions for select to authenticated using (exists(
 select 1 from public.reporting_configuration_versions v join public.reporting_configuration_sets s on s.id=v.configuration_set_id
 where v.id=kpi_definitions.configuration_version_id and (
 (v.status='published' and s.scope_type='global')
 or (s.scope_type='project' and exists(select 1 from public.project_memberships pm where pm.project_id=s.project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())))
 or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code in ('platform_admin','configuration_steward','configuration_approver') and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
 )));
create policy reporting_rule_parameters_read_authorized on public.reporting_rule_parameters for select to authenticated using (exists(
 select 1 from public.reporting_configuration_versions v join public.reporting_configuration_sets s on s.id=v.configuration_set_id
 where v.id=reporting_rule_parameters.configuration_version_id and (
 (v.status='published' and s.scope_type='global')
 or (s.scope_type='project' and exists(select 1 from public.project_memberships pm where pm.project_id=s.project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())))
 or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code in ('platform_admin','configuration_steward','configuration_approver') and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
 )));
revoke all on table public.reporting_configuration_sets,public.reporting_configuration_versions,public.reporting_dimensions,public.kpi_definitions,public.reporting_rule_parameters from public,anon,authenticated;
grant usage on schema public to authenticated,service_role;
grant select on table public.reporting_configuration_sets,public.reporting_configuration_versions,public.reporting_dimensions,public.kpi_definitions,public.reporting_rule_parameters to authenticated;
grant all on table public.reporting_configuration_sets,public.reporting_configuration_versions,public.reporting_dimensions,public.kpi_definitions,public.reporting_rule_parameters to service_role;
revoke all on table private.reporting_configuration_audit from public,anon,authenticated;
grant select,insert on table private.reporting_configuration_audit to service_role;
commit;