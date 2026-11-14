begin;
create or replace function private.enforce_contract_variation_workflow()
returns trigger
language plpgsql
set search_path=''
as $function$
declare
  v_is_pm boolean;
  v_is_finance boolean;
begin
  select exists(
    select 1 from public.project_memberships pm
    where pm.project_id=new.project_id and pm.user_id=(select auth.uid())
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='project_manager'
  ) or exists(
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid()) and ura.role_code='platform_admin'
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) into v_is_pm;

  select exists(
    select 1 from public.project_memberships pm
    where pm.project_id=new.project_id and pm.user_id=(select auth.uid())
      and pm.status='active' and pm.effective_from<=now()
      and (pm.effective_to is null or pm.effective_to>now())
      and pm.project_role='finance'
  ) or exists(
    select 1 from public.user_global_role_assignments ura
    where ura.user_id=(select auth.uid())
      and ura.role_code in ('platform_admin','finance_admin')
      and ura.status='active' and ura.effective_from<=now()
      and (ura.effective_to is null or ura.effective_to>now())
  ) into v_is_finance;

  if tg_op='INSERT' then
    if not v_is_pm or new.status<>'draft' or new.requested_by is distinct from auth.uid() then
      raise exception 'Only an authorized project manager may create a draft variation';
    end if;
    return new;
  end if;

  if old.status='draft' and new.status='submitted' then
    if not v_is_pm
       or (to_jsonb(new)-array['status','submitted_at','updated_at'])
          is distinct from (to_jsonb(old)-array['status','submitted_at','updated_at']) then
      raise exception 'Only a project manager may submit an unchanged draft variation';
    end if;
    new.submitted_at:=now();
    return new;
  end if;

  if old.status='submitted' and new.status in ('approved','rejected') then
    if not v_is_finance
       or (to_jsonb(new)-array['status','decided_by','decided_at','decision_reason','updated_at'])
          is distinct from (to_jsonb(old)-array['status','decided_by','decided_at','decision_reason','updated_at'])
       or new.decision_reason is null or length(btrim(new.decision_reason))<8 then
      raise exception 'Only finance approvers may decide a submitted variation with a reason';
    end if;
    new.decided_by:=auth.uid();
    new.decided_at:=now();
    return new;
  end if;

  raise exception 'Invalid contract variation state transition';
end;
$function$;
commit;