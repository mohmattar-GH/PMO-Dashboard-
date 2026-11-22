create or replace function public.can_access_project_document(
  p_project_id uuid,
  p_classification text,
  p_uploaded_by uuid,
  p_action text
)
returns boolean
language sql stable security invoker set search_path=''
as $function$
  select case
    when auth.uid() is null then false
    when p_action='read' and p_classification='project' then
      exists(select 1 from public.project_memberships pm where pm.project_id=p_project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
      or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code in ('platform_admin','executive_viewer') and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='read' and p_classification='management' then
      exists(select 1 from public.project_memberships pm where pm.project_id=p_project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()) and pm.project_role='project_manager')
      or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code in ('platform_admin','executive_viewer') and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='read' and p_classification='finance' then
      exists(select 1 from public.project_memberships pm where pm.project_id=p_project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()) and pm.project_role in ('project_manager','finance'))
      or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code in ('platform_admin','finance_admin') and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='read' and p_classification='restricted' then
      (exists(select 1 from public.project_memberships pm where pm.project_id=p_project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()) and (p_uploaded_by=(select auth.uid()) or pm.project_role='project_manager')))
      or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin' and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='write' and p_classification='project' then
      exists(select 1 from public.project_memberships pm where pm.project_id=p_project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()) and pm.project_role in ('project_manager','team_lead'))
      or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin' and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='write' and p_classification='management' then
      exists(select 1 from public.project_memberships pm where pm.project_id=p_project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()) and pm.project_role='project_manager')
      or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin' and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='write' and p_classification='finance' then
      exists(select 1 from public.project_memberships pm where pm.project_id=p_project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()) and pm.project_role in ('project_manager','finance'))
      or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code in ('platform_admin','finance_admin') and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
    when p_action='write' and p_classification='restricted' then
      exists(select 1 from public.project_memberships pm where pm.project_id=p_project_id and pm.user_id=(select auth.uid()) and pm.status='active' and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()) and pm.project_role='project_manager')
      or exists(select 1 from public.user_global_role_assignments ura where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin' and ura.status='active' and ura.effective_from<=now() and (ura.effective_to is null or ura.effective_to>now()))
    else false
  end;
$function$;

create index if not exists project_document_versions_document_project_fk_idx
  on public.project_document_versions(document_id,project_id);

drop policy if exists project_documents_insert_authorized on public.project_documents;
create policy project_documents_insert_authorized on public.project_documents
for insert to authenticated
with check (created_by=(select auth.uid()) and status='active'
  and public.can_access_project_document(project_id,classification,created_by,'write'));

drop policy if exists project_document_versions_insert_authorized on public.project_document_versions;
create policy project_document_versions_insert_authorized on public.project_document_versions
for insert to authenticated
with check (uploaded_by=(select auth.uid()) and status='pending'
  and exists(select 1 from public.project_documents d where d.id=project_document_versions.document_id
    and d.project_id=project_document_versions.project_id and d.status='active'
    and public.can_access_project_document(d.project_id,d.classification,d.created_by,'write')));

drop policy if exists project_document_versions_update_authorized on public.project_document_versions;
create policy project_document_versions_update_authorized on public.project_document_versions
for update to authenticated
using (uploaded_by=(select auth.uid()) and status='pending'
  and exists(select 1 from public.project_documents d where d.id=project_document_versions.document_id
    and d.project_id=project_document_versions.project_id and d.status='active'
    and public.can_access_project_document(d.project_id,d.classification,d.created_by,'write')))
with check (uploaded_by=(select auth.uid())
  and exists(select 1 from public.project_documents d where d.id=project_document_versions.document_id
    and d.project_id=project_document_versions.project_id and d.status='active'
    and public.can_access_project_document(d.project_id,d.classification,d.created_by,'write')));

create or replace function private.guard_project_document_version_updates()
returns trigger language plpgsql set search_path=''
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
    new.uploaded_at:=now();
    new.failure_reason:=null;
    if not exists(select 1 from storage.objects so where so.bucket_id='project-documents' and so.name=new.storage_path) then
      raise exception 'Uploaded document object must exist before finalization';
    end if;
  elsif new.status='failed' then
    new.uploaded_at:=null;
    if new.failure_reason is null or length(btrim(new.failure_reason))<8 then
      raise exception 'Failed upload requires a reason';
    end if;
  end if;
  return new;
end;
$function$;