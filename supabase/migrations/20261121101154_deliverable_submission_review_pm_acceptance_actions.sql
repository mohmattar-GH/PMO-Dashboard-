-- Controlled deliverable submission, review and PM acceptance actions.

create unique index contract_deliverable_reviews_submission_once_uq
  on public.contract_deliverable_reviews(submission_id);

create or replace function private.guard_deliverable_lifecycle_fields()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_submit text:=coalesce(current_setting('app.ppm_deliverable_submit',true),'');
  v_review text:=coalesce(current_setting('app.ppm_deliverable_review',true),'');
  v_accept text:=coalesce(current_setting('app.ppm_deliverable_accept',true),'');
begin
  if old.status='accepted' or old.acceptance_status='accepted' then
    if new.status is distinct from old.status
       or new.acceptance_status is distinct from old.acceptance_status
       or new.accepted_by is distinct from old.accepted_by
       or new.accepted_at is distinct from old.accepted_at
       or new.actual_submission_date is distinct from old.actual_submission_date then
      raise exception 'A formally accepted deliverable is immutable';
    end if;
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.status='submitted' and v_submit='on' then null;
    elsif new.status in ('reviewed','changes_required','rejected') and v_review='on' then null;
    elsif new.status='accepted' and v_accept='on' then null;
    elsif new.status in ('submitted','reviewed','changes_required','rejected','accepted') then
      raise exception 'Deliverable submission, review and acceptance states can only be changed through their workflow actions';
    end if;
  end if;

  if new.acceptance_status is distinct from old.acceptance_status then
    if new.acceptance_status='accepted' and v_accept='on' then null;
    elsif new.acceptance_status in ('unaccepted','rejected') and v_review='on' then null;
    elsif new.acceptance_status='unaccepted' and v_submit='on' then null;
    else raise exception 'Deliverable acceptance status can only be changed through the workflow actions';
    end if;
  end if;

  if new.actual_submission_date is distinct from old.actual_submission_date and v_submit<>'on' then
    raise exception 'Actual submission date is stamped by the submission action';
  end if;
  if (new.accepted_by,new.accepted_at) is distinct from (old.accepted_by,old.accepted_at)
     and v_accept<>'on' then
    raise exception 'Acceptance actor and timestamp are stamped by the PM acceptance action';
  end if;
  return new;
end;
$$;
create trigger contract_deliverables_lifecycle_guard
before update on public.contract_deliverables
for each row execute function private.guard_deliverable_lifecycle_fields();

create or replace function public.enforce_contract_deliverable_pm_acceptance()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_is_active_pm boolean;
begin
  if tg_op='UPDATE' and (old.status='accepted' or old.acceptance_status='accepted') then
    if new.status<>'accepted' or new.acceptance_status<>'accepted'
       or new.accepted_by is distinct from old.accepted_by
       or new.accepted_at is distinct from old.accepted_at then
      raise exception 'A recorded deliverable acceptance is immutable';
    end if;
    return new;
  end if;

  if new.status='accepted' or new.acceptance_status='accepted' then
    if tg_op<>'UPDATE' then
      raise exception 'A deliverable must be created unaccepted and accepted through the PM review action';
    end if;
    if coalesce(current_setting('app.ppm_deliverable_accept',true),'')<>'on' then
      raise exception 'Use the formal PM deliverable acceptance action';
    end if;

    select exists(select 1 from public.user_profiles up
      where up.user_id=v_actor and up.is_active=true)
      and exists(select 1 from public.project_memberships pm
      where pm.project_id=new.project_id and pm.user_id=v_actor
        and pm.project_role='project_manager' and pm.status='active'
        and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
    into v_is_active_pm;
    if not coalesce(v_is_active_pm,false) then
      raise exception 'Only an active Project Manager assigned to this project may accept a deliverable';
    end if;
    new.status:='accepted';
    new.acceptance_status:='accepted';
    new.accepted_by:=v_actor;
    new.accepted_at:=now();
  end if;
  return new;
end;
$$;

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
  raise exception 'Deliverable submission records are immutable';
end;
$$;
create trigger deliverable_submission_immutable_guard
before insert or update or delete on public.contract_deliverable_submissions
for each row execute function private.guard_deliverable_submission_mutation();

create or replace function private.guard_deliverable_review_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op='INSERT' then
    if coalesce(current_setting('app.ppm_deliverable_review',true),'')<>'on' then
      raise exception 'Create deliverable reviews through the review action';
    end if;
    new.reviewer_user_id:=auth.uid();
    new.reviewed_at:=now();
    return new;
  end if;
  raise exception 'Deliverable review records are immutable';
end;
$$;
create trigger deliverable_review_immutable_guard
before insert or update or delete on public.contract_deliverable_reviews
for each row execute function private.guard_deliverable_review_mutation();

create or replace function private.submit_contract_deliverable(
  p_deliverable_id uuid,
  p_document_id uuid default null,
  p_document_version_id uuid default null,
  p_submission_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid:=auth.uid();
  v_deliverable public.contract_deliverables%rowtype;
  v_doc public.project_documents%rowtype;
  v_submission_no integer;
  v_submission_id uuid;
  v_is_pm boolean;
  v_is_owner boolean;
begin
  if v_uid is null or not exists(select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;
  if length(coalesce(p_submission_notes,''))>4000 then raise exception 'Submission notes cannot exceed 4000 characters'; end if;
  if (p_document_id is null)<>(p_document_version_id is null) then
    raise exception 'Select both a project document and its uploaded version, or neither';
  end if;

  select d.* into v_deliverable
  from public.contract_deliverables d where d.id=p_deliverable_id for update;
  if not found then raise exception 'Deliverable not found'; end if;
  if v_deliverable.status in ('accepted','rejected','waived')
     or v_deliverable.acceptance_status in ('accepted','waived') then
    raise exception 'This deliverable is not open for submission';
  end if;
  if v_deliverable.status not in ('planned','in_progress','changes_required') then
    raise exception 'The deliverable must be planned, in progress or returned for changes before submission';
  end if;

  select exists(select 1 from public.project_memberships pm
    where pm.project_id=v_deliverable.project_id and pm.user_id=v_uid
      and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
    into v_is_pm;
  select v_deliverable.owner_user_id=v_uid and exists(
    select 1 from public.project_memberships pm
    where pm.project_id=v_deliverable.project_id and pm.user_id=v_uid
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
  ) into v_is_owner;
  if not coalesce(v_is_pm,false) and not coalesce(v_is_owner,false) then
    raise exception 'Only the assigned deliverable owner or an active Project Manager may submit this deliverable';
  end if;

  if p_document_id is not null then
    select d.* into v_doc from public.project_documents d
    where d.id=p_document_id and d.project_id=v_deliverable.project_id and d.status='active';
    if not found then raise exception 'The selected document is not active in this project'; end if;
    if not public.can_access_project_document(v_doc.project_id,v_doc.classification,v_doc.created_by,'read') then
      raise exception 'You do not have permission to reference this classified document';
    end if;
    if not exists(select 1 from public.project_document_versions dv
      where dv.id=p_document_version_id and dv.document_id=p_document_id
        and dv.project_id=v_deliverable.project_id and dv.status='uploaded') then
      raise exception 'The selected document version is not uploaded or does not belong to the document';
    end if;
  end if;

  select coalesce(max(s.submission_no),0)+1 into v_submission_no
  from public.contract_deliverable_submissions s where s.deliverable_id=v_deliverable.id;

  perform set_config('app.ppm_deliverable_submit','on',true);
  insert into public.contract_deliverable_submissions(
    deliverable_id,project_id,submission_no,submitted_by,document_id,document_version_id,submission_notes,status
  ) values (
    v_deliverable.id,v_deliverable.project_id,v_submission_no,v_uid,p_document_id,p_document_version_id,
    nullif(btrim(p_submission_notes),''),'submitted'
  ) returning id into v_submission_id;

  update public.contract_deliverables
  set status='submitted',acceptance_status='unaccepted',
      actual_submission_date=current_date,updated_at=now()
  where id=v_deliverable.id;

  return jsonb_build_object('deliverable_id',v_deliverable.id,'submission_id',v_submission_id,
    'submission_no',v_submission_no,'status','submitted','acceptance_status','unaccepted');
end;
$$;

create or replace function private.review_contract_deliverable_submission(
  p_submission_id uuid,
  p_outcome text,
  p_comments text default null,
  p_rejection_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid:=auth.uid();
  v_submission public.contract_deliverable_submissions%rowtype;
  v_deliverable public.contract_deliverables%rowtype;
  v_review_id uuid;
  v_is_pm boolean;
begin
  if v_uid is null or not exists(select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;
  if p_outcome not in ('accepted','changes_required','rejected') then
    raise exception 'Review outcome must be accepted, changes_required or rejected';
  end if;
  if length(coalesce(p_comments,''))>4000 or length(coalesce(p_rejection_reason,''))>2000 then
    raise exception 'Review text exceeds the allowed length';
  end if;
  if p_outcome='rejected' and length(btrim(coalesce(p_rejection_reason,'')))<8 then
    raise exception 'A rejection reason of at least 8 characters is required';
  end if;

  select s.* into v_submission from public.contract_deliverable_submissions s
  where s.id=p_submission_id for update;
  if not found then raise exception 'Deliverable submission not found'; end if;
  if v_submission.status<>'submitted' then raise exception 'Only a submitted deliverable version can be reviewed'; end if;

  select d.* into v_deliverable from public.contract_deliverables d
  where d.id=v_submission.deliverable_id and d.project_id=v_submission.project_id for update;
  if not found or v_deliverable.status<>'submitted' then raise exception 'The deliverable is not awaiting review'; end if;
  if exists(select 1 from public.contract_deliverable_reviews r where r.submission_id=v_submission.id) then
    raise exception 'This submission already has a review decision';
  end if;

  select exists(select 1 from public.project_memberships pm
    where pm.project_id=v_deliverable.project_id and pm.user_id=v_uid
      and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now()))
    into v_is_pm;
  if not coalesce(v_is_pm,false) and
     (v_deliverable.reviewer_user_id is distinct from v_uid
      or not exists(select 1 from public.project_memberships pm
        where pm.project_id=v_deliverable.project_id and pm.user_id=v_uid
          and pm.status='active' and pm.effective_from<=now()
          and (pm.effective_to is null or pm.effective_to>now()))) then
    raise exception 'Only the assigned reviewer or an active Project Manager may review this deliverable';
  end if;

  perform set_config('app.ppm_deliverable_review','on',true);
  insert into public.contract_deliverable_reviews(
    submission_id,deliverable_id,project_id,reviewer_user_id,outcome,comments,rejection_reason
  ) values (
    v_submission.id,v_deliverable.id,v_deliverable.project_id,v_uid,p_outcome,
    nullif(btrim(p_comments),''),nullif(btrim(p_rejection_reason),'')
  ) returning id into v_review_id;

  update public.contract_deliverable_submissions
  set status=case p_outcome when 'accepted' then 'reviewed'
    when 'changes_required' then 'changes_required' else 'rejected' end
  where id=v_submission.id;

  update public.contract_deliverables
  set status=case p_outcome when 'accepted' then 'reviewed'
    when 'changes_required' then 'changes_required' else 'rejected' end,
    acceptance_status=case when p_outcome='rejected' then 'rejected' else 'unaccepted' end,
    updated_at=now()
  where id=v_deliverable.id;

  return jsonb_build_object('review_id',v_review_id,'submission_id',v_submission.id,
    'outcome',p_outcome,'deliverable_status',case p_outcome when 'accepted' then 'reviewed'
      when 'changes_required' then 'changes_required' else 'rejected' end,
    'acceptance_status',case when p_outcome='rejected' then 'rejected' else 'unaccepted' end);
end;
$$;

create or replace function private.accept_contract_deliverable(p_deliverable_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid:=auth.uid();
  v_deliverable public.contract_deliverables%rowtype;
  v_submission public.contract_deliverable_submissions%rowtype;
  v_review public.contract_deliverable_reviews%rowtype;
begin
  if v_uid is null or not exists(select 1 from public.user_profiles up where up.user_id=v_uid and up.is_active) then
    raise exception 'Active application profile required';
  end if;
  select d.* into v_deliverable from public.contract_deliverables d
  where d.id=p_deliverable_id for update;
  if not found then raise exception 'Deliverable not found'; end if;
  if not exists(select 1 from public.project_memberships pm
    where pm.project_id=v_deliverable.project_id and pm.user_id=v_uid
      and pm.project_role='project_manager' and pm.status='active'
      and pm.effective_from<=now() and (pm.effective_to is null or pm.effective_to>now())) then
    raise exception 'Only an active Project Manager assigned to this project may accept a deliverable';
  end if;
  if v_deliverable.status='accepted' or v_deliverable.acceptance_status='accepted' then
    raise exception 'Deliverable has already been formally accepted';
  end if;

  select s.* into v_submission from public.contract_deliverable_submissions s
  where s.deliverable_id=v_deliverable.id
  order by s.submission_no desc limit 1;
  if not found or v_submission.status<>'reviewed' then
    raise exception 'The latest deliverable submission must first receive an accepted review outcome';
  end if;
  select r.* into v_review from public.contract_deliverable_reviews r
  where r.submission_id=v_submission.id
  order by r.reviewed_at desc,r.id desc limit 1;
  if not found or v_review.outcome<>'accepted' then
    raise exception 'The latest submission has not been approved by its assigned reviewer';
  end if;

  perform set_config('app.ppm_deliverable_accept','on',true);
  update public.contract_deliverables
  set status='accepted',acceptance_status='accepted',updated_at=now()
  where id=v_deliverable.id;

  return jsonb_build_object('deliverable_id',v_deliverable.id,'status','accepted',
    'acceptance_status','accepted','accepted_by',v_uid,'accepted_at',now());
end;
$$;

create or replace function public.submit_contract_deliverable(
  p_deliverable_id uuid,p_document_id uuid default null,
  p_document_version_id uuid default null,p_submission_notes text default null
)
returns jsonb language sql security invoker set search_path=''
as $$ select private.submit_contract_deliverable(p_deliverable_id,p_document_id,p_document_version_id,p_submission_notes); $$;

create or replace function public.review_contract_deliverable_submission(
  p_submission_id uuid,p_outcome text,p_comments text default null,p_rejection_reason text default null
)
returns jsonb language sql security invoker set search_path=''
as $$ select private.review_contract_deliverable_submission(p_submission_id,p_outcome,p_comments,p_rejection_reason); $$;

create or replace function public.accept_contract_deliverable(p_deliverable_id uuid)
returns jsonb language sql security invoker set search_path=''
as $$ select private.accept_contract_deliverable(p_deliverable_id); $$;

revoke all on function public.submit_contract_deliverable(uuid,uuid,uuid,text) from public,anon;
revoke all on function public.review_contract_deliverable_submission(uuid,text,text,text) from public,anon;
revoke all on function public.accept_contract_deliverable(uuid) from public,anon;
grant execute on function public.submit_contract_deliverable(uuid,uuid,uuid,text) to authenticated;
grant execute on function public.review_contract_deliverable_submission(uuid,text,text,text) to authenticated;
grant execute on function public.accept_contract_deliverable(uuid) to authenticated;

revoke all on function private.submit_contract_deliverable(uuid,uuid,uuid,text) from public,anon;
revoke all on function private.review_contract_deliverable_submission(uuid,text,text,text) from public,anon;
revoke all on function private.accept_contract_deliverable(uuid) from public,anon;
grant execute on function private.submit_contract_deliverable(uuid,uuid,uuid,text) to authenticated;
grant execute on function private.review_contract_deliverable_submission(uuid,text,text,text) to authenticated;
grant execute on function private.accept_contract_deliverable(uuid) to authenticated;

revoke insert,update,delete on public.contract_deliverable_submissions from anon,authenticated;
revoke insert,update,delete on public.contract_deliverable_reviews from anon,authenticated;
grant select on public.contract_deliverable_submissions,public.contract_deliverable_reviews to authenticated;
