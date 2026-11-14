begin;

-- Risk scales and risk scoring are governed by the reporting configuration.
-- Store raw positive levels; do not impose a hard-coded 1..5 scale or formula.
drop index if exists public.project_risks_project_status_score_idx;
alter table public.project_risks drop column risk_score;
alter table public.project_risks
  add column risk_score numeric(14,4);
alter table public.project_risks
  drop constraint if exists project_risks_probability_level_check,
  drop constraint if exists project_risks_impact_level_check,
  add constraint project_risks_probability_level_positive check (probability_level>0),
  add constraint project_risks_impact_level_positive check (impact_level>0);
create index project_risks_project_status_score_idx
  on public.project_risks(project_id,status,risk_score desc);

-- Invoice status mappings remain configurable rather than being frozen in a
-- database CHECK constraint. Workflow and calculation validation is governed.
alter table public.project_invoices
  drop constraint if exists project_invoices_status_check;

-- Only trusted backend/database roles may set a calculated risk score.
create or replace function private.guard_calculated_risk_score()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if current_user not in ('service_role','postgres','supabase_admin') then
    if tg_op='INSERT' and new.risk_score is not null then
      raise exception 'Risk score is calculated by the governed reporting engine';
    end if;
    if tg_op='UPDATE' and new.risk_score is distinct from old.risk_score then
      raise exception 'Risk score is calculated by the governed reporting engine';
    end if;
  end if;
  return new;
end;
$function$;
revoke all on function private.guard_calculated_risk_score() from public,anon,authenticated,service_role;
create trigger project_risks_guard_calculated_score
before insert or update on public.project_risks
for each row execute function private.guard_calculated_risk_score();

commit;