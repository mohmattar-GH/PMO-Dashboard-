
-- Migration 023: secure timeline read models.
-- These views are read models only; operational source records remain authoritative.
-- security_invoker ensures source-table grants and RLS policies remain in force.

create or replace view public.project_master_schedule_timeline
with (security_invoker = true)
as
select
  'activity:' || a.id::text || ':baseline' as event_id,
  a.project_id,
  'activity'::text as source_entity_type,
  a.id as source_record_id,
  'activity'::text as event_category,
  a.name as event_name,
  a.baseline_start_date as event_start_date,
  a.baseline_due_date as event_end_date,
  'baseline'::text as date_basis,
  a.status as record_status,
  null::text as severity,
  null::numeric as amount,
  null::character(3) as currency_code,
  a.assigned_to_user_id as owner_user_id,
  a.activity_code as source_reference,
  jsonb_build_object('milestone_id', a.milestone_id, 'workstream', a.workstream, 'progress_percent', a.progress_percent, 'verification_status', a.verification_status) as metadata
from public.project_activities a
where a.baseline_start_date is not null or a.baseline_due_date is not null
union all
select 'activity:' || a.id::text || ':approved_revised', a.project_id, 'activity', a.id, 'activity', a.name,
  a.approved_revised_start_date, a.approved_revised_due_date, 'approved_revised', a.status, null, null::numeric, null::character(3),
  a.assigned_to_user_id, a.activity_code,
  jsonb_build_object('milestone_id', a.milestone_id, 'workstream', a.workstream, 'progress_percent', a.progress_percent, 'verification_status', a.verification_status)
from public.project_activities a
where a.approved_revised_start_date is not null or a.approved_revised_due_date is not null
union all
select 'activity:' || a.id::text || ':forecast', a.project_id, 'activity', a.id, 'activity', a.name,
  a.forecast_start_date, a.forecast_due_date, 'forecast', a.status, null, null::numeric, null::character(3),
  a.assigned_to_user_id, a.activity_code,
  jsonb_build_object('milestone_id', a.milestone_id, 'workstream', a.workstream, 'progress_percent', a.progress_percent, 'verification_status', a.verification_status)
from public.project_activities a
where a.forecast_start_date is not null or a.forecast_due_date is not null
union all
select 'activity:' || a.id::text || ':actual', a.project_id, 'activity', a.id, 'activity', a.name,
  a.actual_start_date, a.actual_due_date, 'actual', a.status, null, null::numeric, null::character(3),
  a.assigned_to_user_id, a.activity_code,
  jsonb_build_object('milestone_id', a.milestone_id, 'workstream', a.workstream, 'progress_percent', a.progress_percent, 'verification_status', a.verification_status)
from public.project_activities a
where a.actual_start_date is not null or a.actual_due_date is not null
union all
select 'milestone:' || m.id::text || ':baseline', m.project_id, 'milestone', m.id, 'milestone', m.name,
  m.baseline_start_date, m.baseline_due_date, 'baseline', m.status, case when m.is_critical then 'critical' else null end,
  null::numeric, null::character(3), m.owner_user_id, m.milestone_code,
  jsonb_build_object('milestone_type',m.milestone_type,'is_critical',m.is_critical,'progress_percent',m.progress_percent)
from public.project_milestones m
where m.baseline_start_date is not null or m.baseline_due_date is not null
union all
select 'milestone:' || m.id::text || ':approved_revised', m.project_id, 'milestone', m.id, 'milestone', m.name,
  m.approved_revised_start_date, m.approved_revised_due_date, 'approved_revised', m.status, case when m.is_critical then 'critical' else null end,
  null::numeric, null::character(3), m.owner_user_id, m.milestone_code,
  jsonb_build_object('milestone_type',m.milestone_type,'is_critical',m.is_critical,'progress_percent',m.progress_percent)
from public.project_milestones m
where m.approved_revised_start_date is not null or m.approved_revised_due_date is not null
union all
select 'milestone:' || m.id::text || ':forecast', m.project_id, 'milestone', m.id, 'milestone', m.name,
  m.forecast_start_date, m.forecast_due_date, 'forecast', m.status, case when m.is_critical then 'critical' else null end,
  null::numeric, null::character(3), m.owner_user_id, m.milestone_code,
  jsonb_build_object('milestone_type',m.milestone_type,'is_critical',m.is_critical,'progress_percent',m.progress_percent)
from public.project_milestones m
where m.forecast_start_date is not null or m.forecast_due_date is not null
union all
select 'milestone:' || m.id::text || ':actual', m.project_id, 'milestone', m.id, 'milestone', m.name,
  m.actual_start_date, m.actual_due_date, 'actual', m.status, case when m.is_critical then 'critical' else null end,
  null::numeric, null::character(3), m.owner_user_id, m.milestone_code,
  jsonb_build_object('milestone_type',m.milestone_type,'is_critical',m.is_critical,'progress_percent',m.progress_percent)
from public.project_milestones m
where m.actual_start_date is not null or m.actual_due_date is not null
union all
select 'contract:' || c.id::text || ':commencement', c.project_id, 'contract', c.id, 'contract', c.contract_title,
  c.commencement_date, c.commencement_date, 'contractual', c.status, null, c.original_contract_value, c.currency_code,
  null::uuid, c.contract_reference, jsonb_build_object('contract_event','commencement')
from public.project_contracts c where c.commencement_date is not null
union all
select 'contract:' || c.id::text || ':end', c.project_id, 'contract', c.id, 'contract', c.contract_title,
  c.contractual_end_date, c.contractual_end_date, 'contractual', c.status, null, c.original_contract_value, c.currency_code,
  null::uuid, c.contract_reference, jsonb_build_object('contract_event','contractual_end')
from public.project_contracts c where c.contractual_end_date is not null
union all
select 'license:' || l.id::text || ':expiry', l.project_id, 'license', l.id, 'license', l.license_name,
  l.expiry_date, l.expiry_date, 'contractual', l.status, null, l.renewal_cost, l.currency_code,
  l.owner_user_id, l.license_reference, jsonb_build_object('license_type',l.license_type,'provider',l.provider,'license_event','expiry')
from public.project_licenses l where l.expiry_date is not null
union all
select 'license:' || l.id::text || ':renewal', l.project_id, 'license', l.id, 'license', l.license_name,
  l.renewal_notice_date, l.renewal_notice_date, 'contractual', l.status, null, l.renewal_cost, l.currency_code,
  l.owner_user_id, l.license_reference, jsonb_build_object('license_type',l.license_type,'provider',l.provider,'license_event','renewal_notice')
from public.project_licenses l where l.renewal_notice_date is not null
union all
select 'decision:' || d.id::text || ':required_by', d.project_id, 'management_decision', d.id, 'management_decision', d.title,
  d.required_by_date, d.required_by_date, 'forecast', d.status, d.priority, null::numeric, null::character(3),
  d.owner_user_id, d.decision_reference, jsonb_build_object('decision_type',d.decision_type,'requested_date',d.requested_date)
from public.project_management_decisions d where d.required_by_date is not null;

grant select on public.project_master_schedule_timeline to authenticated;

create or replace view public.project_payment_risk_timeline
with (security_invoker = true)
as
select
  'invoice:' || i.id::text || ':issued' as event_id,
  i.project_id,
  'invoice'::text as source_entity_type,
  i.id as source_record_id,
  'payment'::text as event_category,
  i.invoice_reference as event_name,
  i.issue_date as event_start_date,
  i.issue_date as event_end_date,
  'actual'::text as date_basis,
  i.status as record_status,
  null::text as severity,
  i.total_amount as amount,
  i.currency_code,
  null::uuid as owner_user_id,
  i.invoice_reference as source_reference,
  jsonb_build_object('invoice_event','issued','invoice_type',i.invoice_type) as metadata
from public.project_invoices i where i.issue_date is not null
union all
select 'invoice:' || i.id::text || ':due', i.project_id, 'invoice', i.id, 'payment', i.invoice_reference,
  i.due_date, i.due_date, 'contractual', i.status, null, i.total_amount, i.currency_code, null::uuid, i.invoice_reference,
  jsonb_build_object('invoice_event','due','invoice_type',i.invoice_type)
from public.project_invoices i where i.due_date is not null
union all
select 'cash:' || c.id::text, c.project_id, 'cash_transaction', c.id, 'payment', c.transaction_reference,
  c.transaction_date, c.transaction_date, 'actual', c.status, null, c.amount, c.currency_code, null::uuid, c.transaction_reference,
  jsonb_build_object('transaction_type',c.transaction_type,'payer_payee',c.payer_payee)
from public.project_cash_transactions c
union all
select 'risk:' || r.id::text, r.project_id, 'risk', r.id, 'risk', r.title,
  r.identified_date, coalesce(r.resolved_date,r.target_resolution_date), 'forecast', r.status,
  case when r.is_escalated then 'escalated' else null end,
  null::numeric, null::character(3), r.owner_user_id, r.risk_reference,
  jsonb_build_object('probability_level',r.probability_level,'impact_level',r.impact_level,'risk_score',r.risk_score,
    'trend',r.trend,'is_escalated',r.is_escalated,'target_resolution_date',r.target_resolution_date,'resolved_date',r.resolved_date)
from public.project_risks r
where r.identified_date is not null or r.target_resolution_date is not null or r.resolved_date is not null;

grant select on public.project_payment_risk_timeline to authenticated;

comment on view public.project_master_schedule_timeline is
'Read-only unified timeline projection of activities, milestones, contracts, licenses and management decision due dates. Source records remain authoritative; baseline/revised/forecast/actual scenarios are separate rows.';
comment on view public.project_payment_risk_timeline is
'Read-only unified timeline projection of invoice due/issue dates, cash transactions and risk exposure intervals. Source records remain authoritative.';
