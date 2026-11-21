-- Enforce the explicit PM-only acceptance decision at the database boundary.
alter table public.contract_deliverables
  drop constraint contract_deliverable_pm_acceptance_ck;
alter table public.contract_deliverables
  add constraint contract_deliverable_pm_acceptance_ck
  check (
    (status = 'accepted') = (acceptance_status = 'accepted')
    and (acceptance_status <> 'accepted' or (accepted_by is not null and accepted_at is not null))
  );

create or replace function public.enforce_contract_deliverable_pm_acceptance()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_is_active_pm boolean;
begin
  if tg_op = 'UPDATE' and (old.status = 'accepted' or old.acceptance_status = 'accepted') then
    if new.status <> 'accepted' or new.acceptance_status <> 'accepted'
       or new.accepted_by is distinct from old.accepted_by
       or new.accepted_at is distinct from old.accepted_at then
      raise exception 'A recorded deliverable acceptance is immutable';
    end if;
    return new;
  end if;

  if new.status = 'accepted' or new.acceptance_status = 'accepted' then
    if tg_op <> 'UPDATE' then
      raise exception 'A deliverable must be created unaccepted and accepted through the PM review action';
    end if;

    select exists (
      select 1
      from public.user_profiles up
      where up.user_id = v_actor and up.is_active = true
    ) and exists (
      select 1
      from public.project_memberships pm
      where pm.project_id = new.project_id
        and pm.user_id = v_actor
        and pm.project_role = 'project_manager'
        and pm.status = 'active'
        and pm.effective_from <= now()
        and (pm.effective_to is null or pm.effective_to > now())
    ) into v_is_active_pm;

    if not coalesce(v_is_active_pm, false) then
      raise exception 'Only an active Project Manager assigned to this project may accept a deliverable';
    end if;

    new.status := 'accepted';
    new.acceptance_status := 'accepted';
    new.accepted_by := v_actor;
    new.accepted_at := now();
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_contract_deliverable_pm_acceptance() from public, anon, authenticated, service_role;
create trigger contract_deliverables_pm_acceptance_guard
before insert or update on public.contract_deliverables
for each row execute function public.enforce_contract_deliverable_pm_acceptance();
