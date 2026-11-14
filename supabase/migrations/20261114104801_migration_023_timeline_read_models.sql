-- Migration 023: secure timeline read models.
-- Read-only projections; operational source records remain authoritative.
-- security_invoker preserves source-table grants and RLS for the calling user.

create or replace view public.project_master_schedule_timeline
with (security_invoker = true)
as
 SELECT (('activity:'::text || (a.id)::text) || ':baseline'::text) AS event_id,
    a.project_id,
    'activity'::text AS source_entity_type,
    a.id AS source_record_id,
    'activity'::text AS event_category,
    a.name AS event_name,
    a.baseline_start_date AS event_start_date,
    a.baseline_due_date AS event_end_date,
    'baseline'::text AS date_basis,
    a.status AS record_status,
    NULL::text AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    a.assigned_to_user_id AS owner_user_id,
    a.activity_code AS source_reference,
    jsonb_build_object('milestone_id', a.milestone_id, 'workstream', a.workstream, 'progress_percent', a.progress_percent, 'verification_status', a.verification_status) AS metadata
   FROM project_activities a
  WHERE ((a.baseline_start_date IS NOT NULL) OR (a.baseline_due_date IS NOT NULL))
UNION ALL
 SELECT (('activity:'::text || (a.id)::text) || ':approved_revised'::text) AS event_id,
    a.project_id,
    'activity'::text AS source_entity_type,
    a.id AS source_record_id,
    'activity'::text AS event_category,
    a.name AS event_name,
    a.approved_revised_start_date AS event_start_date,
    a.approved_revised_due_date AS event_end_date,
    'approved_revised'::text AS date_basis,
    a.status AS record_status,
    NULL::text AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    a.assigned_to_user_id AS owner_user_id,
    a.activity_code AS source_reference,
    jsonb_build_object('milestone_id', a.milestone_id, 'workstream', a.workstream, 'progress_percent', a.progress_percent, 'verification_status', a.verification_status) AS metadata
   FROM project_activities a
  WHERE ((a.approved_revised_start_date IS NOT NULL) OR (a.approved_revised_due_date IS NOT NULL))
UNION ALL
 SELECT (('activity:'::text || (a.id)::text) || ':forecast'::text) AS event_id,
    a.project_id,
    'activity'::text AS source_entity_type,
    a.id AS source_record_id,
    'activity'::text AS event_category,
    a.name AS event_name,
    a.forecast_start_date AS event_start_date,
    a.forecast_due_date AS event_end_date,
    'forecast'::text AS date_basis,
    a.status AS record_status,
    NULL::text AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    a.assigned_to_user_id AS owner_user_id,
    a.activity_code AS source_reference,
    jsonb_build_object('milestone_id', a.milestone_id, 'workstream', a.workstream, 'progress_percent', a.progress_percent, 'verification_status', a.verification_status) AS metadata
   FROM project_activities a
  WHERE ((a.forecast_start_date IS NOT NULL) OR (a.forecast_due_date IS NOT NULL))
UNION ALL
 SELECT (('activity:'::text || (a.id)::text) || ':actual'::text) AS event_id,
    a.project_id,
    'activity'::text AS source_entity_type,
    a.id AS source_record_id,
    'activity'::text AS event_category,
    a.name AS event_name,
    a.actual_start_date AS event_start_date,
    a.actual_due_date AS event_end_date,
    'actual'::text AS date_basis,
    a.status AS record_status,
    NULL::text AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    a.assigned_to_user_id AS owner_user_id,
    a.activity_code AS source_reference,
    jsonb_build_object('milestone_id', a.milestone_id, 'workstream', a.workstream, 'progress_percent', a.progress_percent, 'verification_status', a.verification_status) AS metadata
   FROM project_activities a
  WHERE ((a.actual_start_date IS NOT NULL) OR (a.actual_due_date IS NOT NULL))
UNION ALL
 SELECT (('milestone:'::text || (m.id)::text) || ':baseline'::text) AS event_id,
    m.project_id,
    'milestone'::text AS source_entity_type,
    m.id AS source_record_id,
    'milestone'::text AS event_category,
    m.name AS event_name,
    m.baseline_start_date AS event_start_date,
    m.baseline_due_date AS event_end_date,
    'baseline'::text AS date_basis,
    m.status AS record_status,
        CASE
            WHEN m.is_critical THEN 'critical'::text
            ELSE NULL::text
        END AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    m.owner_user_id,
    m.milestone_code AS source_reference,
    jsonb_build_object('milestone_type', m.milestone_type, 'is_critical', m.is_critical, 'progress_percent', m.progress_percent) AS metadata
   FROM project_milestones m
  WHERE ((m.baseline_start_date IS NOT NULL) OR (m.baseline_due_date IS NOT NULL))
UNION ALL
 SELECT (('milestone:'::text || (m.id)::text) || ':approved_revised'::text) AS event_id,
    m.project_id,
    'milestone'::text AS source_entity_type,
    m.id AS source_record_id,
    'milestone'::text AS event_category,
    m.name AS event_name,
    m.approved_revised_start_date AS event_start_date,
    m.approved_revised_due_date AS event_end_date,
    'approved_revised'::text AS date_basis,
    m.status AS record_status,
        CASE
            WHEN m.is_critical THEN 'critical'::text
            ELSE NULL::text
        END AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    m.owner_user_id,
    m.milestone_code AS source_reference,
    jsonb_build_object('milestone_type', m.milestone_type, 'is_critical', m.is_critical, 'progress_percent', m.progress_percent) AS metadata
   FROM project_milestones m
  WHERE ((m.approved_revised_start_date IS NOT NULL) OR (m.approved_revised_due_date IS NOT NULL))
UNION ALL
 SELECT (('milestone:'::text || (m.id)::text) || ':forecast'::text) AS event_id,
    m.project_id,
    'milestone'::text AS source_entity_type,
    m.id AS source_record_id,
    'milestone'::text AS event_category,
    m.name AS event_name,
    m.forecast_start_date AS event_start_date,
    m.forecast_due_date AS event_end_date,
    'forecast'::text AS date_basis,
    m.status AS record_status,
        CASE
            WHEN m.is_critical THEN 'critical'::text
            ELSE NULL::text
        END AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    m.owner_user_id,
    m.milestone_code AS source_reference,
    jsonb_build_object('milestone_type', m.milestone_type, 'is_critical', m.is_critical, 'progress_percent', m.progress_percent) AS metadata
   FROM project_milestones m
  WHERE ((m.forecast_start_date IS NOT NULL) OR (m.forecast_due_date IS NOT NULL))
UNION ALL
 SELECT (('milestone:'::text || (m.id)::text) || ':actual'::text) AS event_id,
    m.project_id,
    'milestone'::text AS source_entity_type,
    m.id AS source_record_id,
    'milestone'::text AS event_category,
    m.name AS event_name,
    m.actual_start_date AS event_start_date,
    m.actual_due_date AS event_end_date,
    'actual'::text AS date_basis,
    m.status AS record_status,
        CASE
            WHEN m.is_critical THEN 'critical'::text
            ELSE NULL::text
        END AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    m.owner_user_id,
    m.milestone_code AS source_reference,
    jsonb_build_object('milestone_type', m.milestone_type, 'is_critical', m.is_critical, 'progress_percent', m.progress_percent) AS metadata
   FROM project_milestones m
  WHERE ((m.actual_start_date IS NOT NULL) OR (m.actual_due_date IS NOT NULL))
UNION ALL
 SELECT (('contract:'::text || (c.id)::text) || ':commencement'::text) AS event_id,
    c.project_id,
    'contract'::text AS source_entity_type,
    c.id AS source_record_id,
    'contract'::text AS event_category,
    c.contract_title AS event_name,
    c.commencement_date AS event_start_date,
    c.commencement_date AS event_end_date,
    'contractual'::text AS date_basis,
    c.status AS record_status,
    NULL::text AS severity,
    c.original_contract_value AS amount,
    c.currency_code,
    NULL::uuid AS owner_user_id,
    c.contract_reference AS source_reference,
    jsonb_build_object('contract_event', 'commencement') AS metadata
   FROM project_contracts c
  WHERE (c.commencement_date IS NOT NULL)
UNION ALL
 SELECT (('contract:'::text || (c.id)::text) || ':end'::text) AS event_id,
    c.project_id,
    'contract'::text AS source_entity_type,
    c.id AS source_record_id,
    'contract'::text AS event_category,
    c.contract_title AS event_name,
    c.contractual_end_date AS event_start_date,
    c.contractual_end_date AS event_end_date,
    'contractual'::text AS date_basis,
    c.status AS record_status,
    NULL::text AS severity,
    c.original_contract_value AS amount,
    c.currency_code,
    NULL::uuid AS owner_user_id,
    c.contract_reference AS source_reference,
    jsonb_build_object('contract_event', 'contractual_end') AS metadata
   FROM project_contracts c
  WHERE (c.contractual_end_date IS NOT NULL)
UNION ALL
 SELECT (('license:'::text || (l.id)::text) || ':expiry'::text) AS event_id,
    l.project_id,
    'license'::text AS source_entity_type,
    l.id AS source_record_id,
    'license'::text AS event_category,
    l.license_name AS event_name,
    l.expiry_date AS event_start_date,
    l.expiry_date AS event_end_date,
    'contractual'::text AS date_basis,
    l.status AS record_status,
    NULL::text AS severity,
    l.renewal_cost AS amount,
    l.currency_code,
    l.owner_user_id,
    l.license_reference AS source_reference,
    jsonb_build_object('license_type', l.license_type, 'provider', l.provider, 'license_event', 'expiry') AS metadata
   FROM project_licenses l
  WHERE (l.expiry_date IS NOT NULL)
UNION ALL
 SELECT (('license:'::text || (l.id)::text) || ':renewal'::text) AS event_id,
    l.project_id,
    'license'::text AS source_entity_type,
    l.id AS source_record_id,
    'license'::text AS event_category,
    l.license_name AS event_name,
    l.renewal_notice_date AS event_start_date,
    l.renewal_notice_date AS event_end_date,
    'contractual'::text AS date_basis,
    l.status AS record_status,
    NULL::text AS severity,
    l.renewal_cost AS amount,
    l.currency_code,
    l.owner_user_id,
    l.license_reference AS source_reference,
    jsonb_build_object('license_type', l.license_type, 'provider', l.provider, 'license_event', 'renewal_notice') AS metadata
   FROM project_licenses l
  WHERE (l.renewal_notice_date IS NOT NULL)
UNION ALL
 SELECT (('decision:'::text || (d.id)::text) || ':required_by'::text) AS event_id,
    d.project_id,
    'management_decision'::text AS source_entity_type,
    d.id AS source_record_id,
    'management_decision'::text AS event_category,
    d.title AS event_name,
    d.required_by_date AS event_start_date,
    d.required_by_date AS event_end_date,
    'forecast'::text AS date_basis,
    d.status AS record_status,
    d.priority AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    d.owner_user_id,
    d.decision_reference AS source_reference,
    jsonb_build_object('decision_type', d.decision_type, 'requested_date', d.requested_date) AS metadata
   FROM project_management_decisions d
  WHERE (d.required_by_date IS NOT NULL);;

grant select on public.project_master_schedule_timeline to authenticated;

create or replace view public.project_payment_risk_timeline
with (security_invoker = true)
as
 SELECT (('invoice:'::text || (i.id)::text) || ':issued'::text) AS event_id,
    i.project_id,
    'invoice'::text AS source_entity_type,
    i.id AS source_record_id,
    'payment'::text AS event_category,
    i.invoice_reference AS event_name,
    i.issue_date AS event_start_date,
    i.issue_date AS event_end_date,
    'actual'::text AS date_basis,
    i.status AS record_status,
    NULL::text AS severity,
    i.total_amount AS amount,
    i.currency_code,
    NULL::uuid AS owner_user_id,
    i.invoice_reference AS source_reference,
    jsonb_build_object('invoice_event', 'issued', 'invoice_type', i.invoice_type) AS metadata
   FROM project_invoices i
  WHERE (i.issue_date IS NOT NULL)
UNION ALL
 SELECT (('invoice:'::text || (i.id)::text) || ':due'::text) AS event_id,
    i.project_id,
    'invoice'::text AS source_entity_type,
    i.id AS source_record_id,
    'payment'::text AS event_category,
    i.invoice_reference AS event_name,
    i.due_date AS event_start_date,
    i.due_date AS event_end_date,
    'contractual'::text AS date_basis,
    i.status AS record_status,
    NULL::text AS severity,
    i.total_amount AS amount,
    i.currency_code,
    NULL::uuid AS owner_user_id,
    i.invoice_reference AS source_reference,
    jsonb_build_object('invoice_event', 'due', 'invoice_type', i.invoice_type) AS metadata
   FROM project_invoices i
  WHERE (i.due_date IS NOT NULL)
UNION ALL
 SELECT ('cash:'::text || (c.id)::text) AS event_id,
    c.project_id,
    'cash_transaction'::text AS source_entity_type,
    c.id AS source_record_id,
    'payment'::text AS event_category,
    c.transaction_reference AS event_name,
    c.transaction_date AS event_start_date,
    c.transaction_date AS event_end_date,
    'actual'::text AS date_basis,
    c.status AS record_status,
    NULL::text AS severity,
    c.amount,
    c.currency_code,
    NULL::uuid AS owner_user_id,
    c.transaction_reference AS source_reference,
    jsonb_build_object('transaction_type', c.transaction_type, 'payer_payee', c.payer_payee) AS metadata
   FROM project_cash_transactions c
UNION ALL
 SELECT ('risk:'::text || (r.id)::text) AS event_id,
    r.project_id,
    'risk'::text AS source_entity_type,
    r.id AS source_record_id,
    'risk'::text AS event_category,
    r.title AS event_name,
    r.identified_date AS event_start_date,
    COALESCE(r.resolved_date, r.target_resolution_date) AS event_end_date,
    'forecast'::text AS date_basis,
    r.status AS record_status,
        CASE
            WHEN r.is_escalated THEN 'escalated'::text
            ELSE NULL::text
        END AS severity,
    NULL::numeric AS amount,
    NULL::character(3) AS currency_code,
    r.owner_user_id,
    r.risk_reference AS source_reference,
    jsonb_build_object('probability_level', r.probability_level, 'impact_level', r.impact_level, 'risk_score', r.risk_score, 'trend', r.trend, 'is_escalated', r.is_escalated, 'target_resolution_date', r.target_resolution_date, 'resolved_date', r.resolved_date) AS metadata
   FROM project_risks r
  WHERE ((r.identified_date IS NOT NULL) OR (r.target_resolution_date IS NOT NULL) OR (r.resolved_date IS NOT NULL));;

grant select on public.project_payment_risk_timeline to authenticated;

comment on view public.project_master_schedule_timeline is
'Read-only unified timeline projection of activities, milestones, contracts, licenses and management decision due dates. Source records remain authoritative; baseline/revised/forecast/actual scenarios are separate rows.';

comment on view public.project_payment_risk_timeline is
'Read-only unified timeline projection of invoice due/issue dates, cash transactions and risk exposure intervals. Source records remain authoritative.';
