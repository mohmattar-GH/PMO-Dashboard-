begin;

create table public.project_documents (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  title text not null,
  description text,
  category text not null,
  classification text not null default 'project',
  document_date date,
  status text not null default 'active',
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(id,project_id),
  check (length(btrim(title)) between 1 and 250),
  check (length(btrim(category)) between 1 and 80),
  check (classification in ('project','management','finance','restricted')),
  check (status in ('active','archived'))
);

create table public.project_document_versions (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null,
  project_id uuid not null,
  version_number integer not null,
  file_name text not null,
  storage_path text not null unique,
  content_type text not null,
  file_size_bytes bigint not null,
  sha256_hex text,
  status text not null default 'pending',
  uploaded_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  uploaded_at timestamptz,
  failure_reason text,
  foreign key (document_id,project_id)
    references public.project_documents(id,project_id) on delete restrict,
  unique(document_id,version_number),
  check (version_number>0),
  check (length(btrim(file_name)) between 1 and 255),
  check (file_name !~ '[/\\]'),
  check (file_name not in ('.','..')),
  check (file_size_bytes between 1 and 52428800),
  check (content_type in (
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'image/jpeg','image/png','text/plain','text/csv'
  )),
  check (sha256_hex is null or sha256_hex ~ '^[0-9a-fA-F]{64}$'),
  check (status in ('pending','uploaded','failed')),
  check (
    storage_path = project_id::text || '/' || document_id::text || '/' || id::text || '/' || file_name
  ),
  check (
    (status='pending' and uploaded_at is null and failure_reason is null)
    or (status='uploaded' and uploaded_at is not null and failure_reason is null)
    or (status='failed' and uploaded_at is null and failure_reason is not null
      and length(btrim(failure_reason))>=8)
  )
);

create index project_documents_project_status_idx
  on public.project_documents(project_id,status,classification);
create index project_documents_created_by_idx on public.project_documents(created_by);
create index project_document_versions_project_document_idx
  on public.project_document_versions(project_id,document_id,version_number desc);
create index project_document_versions_uploaded_by_idx
  on public.project_document_versions(uploaded_by);

alter table public.project_documents enable row level security;
alter table public.project_document_versions enable row level security;

grant select,insert,update on public.project_documents to authenticated;
grant select,insert,update on public.project_document_versions to authenticated;
grant select,insert,update,delete on public.project_documents to service_role;
grant select,insert,update,delete on public.project_document_versions to service_role;
revoke delete on public.project_documents,public.project_document_versions from authenticated;

create or replace function public.can_access_project_document(
  p_project_id uuid,
  p_classification text,
  p_uploaded_by uuid,
  p_action text
)
returns boolean
language sql
stable
security invoker
set search_path=''
as $function$
  select case
    when auth.uid() is null then false
    when p_action='read' and p_classification='project' then
      exists(select 1 from public.project_memberships pm
        where pm.project_id=p_project_id and pm.user_id=auth.uid()
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now()))
      or exists(select 1 from public.user_global_role_assignments ura
        where ura.user_id=auth.uid() and ura.role_code in ('platform_admin','executive_viewer')
          and ura.status='active' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='read' and p_classification='management' then
      exists(select 1 from public.project_memberships pm
        where pm.project_id=p_project_id and pm.user_id=auth.uid()
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role='project_manager')
      or exists(select 1 from public.user_global_role_assignments ura
        where ura.user_id=auth.uid() and ura.role_code in ('platform_admin','executive_viewer')
          and ura.status='active' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='read' and p_classification='finance' then
      exists(select 1 from public.project_memberships pm
        where pm.project_id=p_project_id and pm.user_id=auth.uid()
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role in ('project_manager','finance'))
      or exists(select 1 from public.user_global_role_assignments ura
        where ura.user_id=auth.uid() and ura.role_code in ('platform_admin','finance_admin')
          and ura.status='active' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='read' and p_classification='restricted' then
      p_uploaded_by=auth.uid()
      or exists(select 1 from public.project_memberships pm
        where pm.project_id=p_project_id and pm.user_id=auth.uid()
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role='project_manager')
      or exists(select 1 from public.user_global_role_assignments ura
        where ura.user_id=auth.uid() and ura.role_code='platform_admin'
          and ura.status='active' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='write' and p_classification='project' then
      exists(select 1 from public.project_memberships pm
        where pm.project_id=p_project_id and pm.user_id=auth.uid()
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role in ('project_manager','team_lead'))
      or exists(select 1 from public.user_global_role_assignments ura
        where ura.user_id=auth.uid() and ura.role_code='platform_admin'
          and ura.status='active' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='write' and p_classification='management' then
      exists(select 1 from public.project_memberships pm
        where pm.project_id=p_project_id and pm.user_id=auth.uid()
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role='project_manager')
      or exists(select 1 from public.user_global_role_assignments ura
        where ura.user_id=auth.uid() and ura.role_code='platform_admin'
          and ura.status='active' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='write' and p_classification='finance' then
      exists(select 1 from public.project_memberships pm
        where pm.project_id=p_project_id and pm.user_id=auth.uid()
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role in ('project_manager','finance'))
      or exists(select 1 from public.user_global_role_assignments ura
        where ura.user_id=auth.uid() and ura.role_code in ('platform_admin','finance_admin')
          and ura.status='active' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='write' and p_classification='restricted' then
      exists(select 1 from public.project_memberships pm
        where pm.project_id=p_project_id and pm.user_id=auth.uid()
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now())
          and pm.project_role='project_manager')
      or exists(select 1 from public.user_global_role_assignments ura
        where ura.user_id=auth.uid() and ura.role_code='platform_admin'
          and ura.status='active' and ura.effective_from<=now()
          and (ura.effective_to is null or ura.effective_to>now()))
    else false
  end;
$function$;

revoke all on function public.can_access_project_document(uuid,text,uuid,text) from public,anon;
grant execute on function public.can_access_project_document(uuid,text,uuid,text) to authenticated;

create policy project_documents_read_classified
on public.project_documents for select to authenticated
using (status='active' and public.can_access_project_document(project_id,classification,created_by,'read'));

create policy project_documents_insert_authorized
on public.project_documents for insert to authenticated
with check (
  created_by=auth.uid()
  and status='active'
  and public.can_access_project_document(project_id,classification,created_by,'write')
);

create policy project_documents_update_authorized
on public.project_documents for update to authenticated
using (public.can_access_project_document(project_id,classification,created_by,'write'))
with check (public.can_access_project_document(project_id,classification,created_by,'write'));

create policy project_document_versions_read_classified
on public.project_document_versions for select to authenticated
using (
  exists(select 1 from public.project_documents d
    where d.id=project_document_versions.document_id
      and d.project_id=project_document_versions.project_id
      and d.status='active'
      and public.can_access_project_document(d.project_id,d.classification,d.created_by,'read'))
);

create policy project_document_versions_insert_authorized
on public.project_document_versions for insert to authenticated
with check (
  uploaded_by=auth.uid()
  and status='pending'
  and exists(select 1 from public.project_documents d
    where d.id=project_document_versions.document_id
      and d.project_id=project_document_versions.project_id
      and d.status='active'
      and public.can_access_project_document(d.project_id,d.classification,d.created_by,'write'))
);

create policy project_document_versions_update_authorized
on public.project_document_versions for update to authenticated
using (
  uploaded_by=auth.uid()
  and status='pending'
  and exists(select 1 from public.project_documents d
    where d.id=project_document_versions.document_id
      and d.project_id=project_document_versions.project_id
      and d.status='active'
      and public.can_access_project_document(d.project_id,d.classification,d.created_by,'write'))
)
with check (
  uploaded_by=auth.uid()
  and exists(select 1 from public.project_documents d
    where d.id=project_document_versions.document_id
      and d.project_id=project_document_versions.project_id
      and d.status='active'
      and public.can_access_project_document(d.project_id,d.classification,d.created_by,'write'))
);

create or replace function private.guard_project_document_updates()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if new.id is distinct from old.id
    or new.project_id is distinct from old.project_id
    or new.created_by is distinct from old.created_by
    or new.created_at is distinct from old.created_at
    or new.classification is distinct from old.classification then
    raise exception 'Document identity and classification are immutable; create a new document for reclassification';
  end if;
  if old.status='archived' or new.status not in (old.status,'archived') then
    raise exception 'Only active documents may be archived; archived documents are immutable';
  end if;
  return new;
end;
$function$;

create trigger project_documents_guard_updates
before update on public.project_documents
for each row execute function private.guard_project_document_updates();

create or replace function private.guard_project_document_version_updates()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if new.id is distinct from old.id
    or new.document_id is distinct from old.document_id
    or new.project_id is distinct from old.project_id
    or new.version_number is distinct from old.version_number
    or new.file_name is distinct from old.file_name
    or new.storage_path is distinct from old.storage_path
    or new.content_type is distinct from old.content_type
    or new.file_size_bytes is distinct from old.file_size_bytes
    or new.sha256_hex is distinct from old.sha256_hex
    or new.uploaded_by is distinct from old.uploaded_by
    or new.created_at is distinct from old.created_at then
    raise exception 'Document version metadata is immutable';
  end if;
  if old.status<>'pending' or new.status not in ('uploaded','failed') then
    raise exception 'Only pending document versions may be finalized once';
  end if;
  if new.status='uploaded' then
    if new.uploaded_at is null or new.failure_reason is not null
       or not exists(select 1 from storage.objects so
         where so.bucket_id='project-documents' and so.name=new.storage_path) then
      raise exception 'Uploaded document object must exist before finalization';
    end if;
  elsif new.status='failed' then
    if new.uploaded_at is not null or new.failure_reason is null
       or length(btrim(new.failure_reason))<8 then
      raise exception 'Failed upload requires a reason';
    end if;
  end if;
  return new;
end;
$function$;

create trigger project_document_versions_guard_updates
before update on public.project_document_versions
for each row execute function private.guard_project_document_version_updates();

create or replace function private.set_document_updated_at()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  new.updated_at:=now();
  return new;
end;
$function$;

create trigger project_documents_set_updated_at
before update on public.project_documents
for each row execute function private.set_document_updated_at();

create trigger project_documents_audit_changes
after insert or update on public.project_documents
for each row execute function private.audit_project_operational_change();

create trigger project_document_versions_audit_changes
after insert or update on public.project_document_versions
for each row execute function private.audit_project_operational_change();

create or replace view public.project_document_current_versions
with (security_invoker=true)
as
select distinct on (v.document_id)
  v.document_id,v.project_id,v.id as version_id,v.version_number,
  v.file_name,v.content_type,v.file_size_bytes,v.sha256_hex,
  v.uploaded_by,v.uploaded_at,v.storage_path
from public.project_document_versions v
join public.project_documents d on d.id=v.document_id and d.project_id=v.project_id
where v.status='uploaded' and d.status='active'
order by v.document_id,v.version_number desc;

grant select on public.project_document_current_versions to authenticated,service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values (
  'project-documents',
  'project-documents',
  false,
  52428800,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'image/jpeg','image/png','text/plain','text/csv'
  ]
)
on conflict(id) do update set
  name=excluded.name,
  public=false,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

create policy project_documents_storage_read
on storage.objects for select to authenticated
using (
  bucket_id='project-documents'
  and exists(select 1
    from public.project_document_versions v
    join public.project_documents d on d.id=v.document_id and d.project_id=v.project_id
    where v.storage_path=storage.objects.name
      and v.status='uploaded'
      and d.status='active'
      and public.can_access_project_document(d.project_id,d.classification,d.created_by,'read'))
);

create policy project_documents_storage_insert
on storage.objects for insert to authenticated
with check (
  bucket_id='project-documents'
  and exists(select 1
    from public.project_document_versions v
    join public.project_documents d on d.id=v.document_id and d.project_id=v.project_id
    where v.storage_path=storage.objects.name
      and v.status='pending'
      and v.uploaded_by=auth.uid()
      and d.status='active'
      and public.can_access_project_document(d.project_id,d.classification,d.created_by,'write'))
);

commit;