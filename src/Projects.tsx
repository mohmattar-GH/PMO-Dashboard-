import { useCallback, useEffect, useMemo, useState } from "react";
import { AlertTriangle, ArrowLeft, BriefcaseBusiness, Layers3, Search, ShieldAlert, ShieldCheck } from "lucide-react";
import { supabase } from "./lib/supabase";

type Project = {
  id: string; project_code: string; name: string; client_id: string | null; portfolio_id: string | null;
  project_manager_id: string | null; team_lead_id: string | null; lifecycle_status: string;
  start_date: string | null; target_end_date: string | null; timezone: string; currency_code: string | null;
};
type Phase = { project_id: string; phase_name: string; progress_percent: number | null; planned_start_date: string | null; forecast_completion_date: string | null; actual_completion_date: string | null };
type Snapshot = { project_id: string; calculated_health: string | null; reported_health: string | null; created_at: string };
type Member = { project_id: string; user_id: string; project_role: string; display_name: string };
type Contract = { id: string; contract_reference: string; contract_title: string; contract_type: string; status: string; signed_date: string | null; commencement_date: string | null; contractual_end_date: string | null; duration_months: number | null; scope_summary: string | null; obligations: string | null; acceptance_criteria: string | null; penalties_terms: string | null; change_control_terms: string | null; payment_terms: string | null; currency_code: string | null; original_contract_value: number | null };
type Finance = { currency_code: string; original_contract_value: number; approved_variations: number; revised_contract_value: number | null; tax_rate: number | null; retention_rate: number | null; payment_terms: string | null; billing_notes: string | null };
type Milestone = { id: string; milestone_code: string; name: string; milestone_type: string; baseline_due_date: string | null; approved_revised_due_date: string | null; forecast_due_date: string | null; actual_due_date: string | null; progress_percent: number; status: string; weight: number | null; is_critical: boolean };
type ProjectActivity = { id: string; activity_code: string; name: string; workstream: string | null; baseline_due_date: string | null; approved_revised_due_date: string | null; forecast_due_date: string | null; actual_due_date: string | null; progress_percent: number; status: string; verification_status: string };
type Risk = { id: string; risk_reference: string; title: string; description: string; probability_level: number; impact_level: number; risk_score: number | null; status: string; trend: string; is_escalated: boolean; mitigation_plan: string | null; owner_user_id: string | null; target_resolution_date: string | null };
type License = { id: string; license_reference: string; license_name: string; license_type: string | null; provider: string | null; expiry_date: string | null; renewal_notice_date: string | null; status: string; renewal_cost: number | null; currency_code: string | null };
type Invoice = { id: string; invoice_reference: string; invoice_type: string; status: string; issue_date: string | null; submission_date: string | null; due_date: string | null; currency_code: string; total_amount: number; disputed_reason: string | null };
type Balance = { invoice_id: string; applied_amount: number; outstanding_amount: number; is_settled: boolean };
type Cash = { id: string; transaction_reference: string; transaction_type: string; status: string; transaction_date: string; currency_code: string; amount: number; payer_payee: string | null };

const label = (value: string | null | undefined) => value ? value.replace(/_/g, " ").replace(/\b\w/g, (s) => s.toUpperCase()) : "Not Reported";
const dateLabel = (value: string | null | undefined) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(value + (value.length === 10 ? "T00:00:00" : ""))) : "Not Reported";
const amount = (value: number | null | undefined, currency: string | null | undefined) => {
  if (value === null || value === undefined) return "Not Reported";
  if (!currency) return Number(value).toLocaleString() + " · Currency not reported";
  try { return new Intl.NumberFormat(undefined, { style: "currency", currency: currency.trim() }).format(Number(value)); }
  catch { return Number(value).toLocaleString() + " " + (currency || ""); }
};
const statusClass = (status: string | null | undefined) => (status || "not-reported").toLowerCase().replace(/[^a-z0-9]+/g, "-");

export default function Projects({ isPlatformAdmin }: { isPlatformAdmin: boolean }) {
  const [projects, setProjects] = useState<Project[]>([]);
  const [clients, setClients] = useState<Record<string, string>>({});
  const [portfolios, setPortfolios] = useState<Record<string, string>>({});
  const [phases, setPhases] = useState<Record<string, Phase>>({});
  const [snapshots, setSnapshots] = useState<Record<string, Snapshot>>({});
  const [members, setMembers] = useState<Member[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState("overview");
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailNotice, setDetailNotice] = useState("");
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [finance, setFinance] = useState<Finance | null>(null);
  const [milestones, setMilestones] = useState<Milestone[]>([]);
  const [activities, setActivities] = useState<ProjectActivity[]>([]);
  const [risks, setRisks] = useState<Risk[]>([]);
  const [licenses, setLicenses] = useState<License[]>([]);
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [balances, setBalances] = useState<Record<string, Balance>>({});
  const [cash, setCash] = useState<Cash[]>([]);

  const loadRegister = useCallback(async () => {
    if (!supabase) { setError("Supabase client is not configured."); setLoading(false); return; }
    setLoading(true); setError("");
    const [projectResult, clientResult, portfolioResult, phaseResult, snapshotResult] = await Promise.all([
      supabase.from("projects").select("id,project_code,name,client_id,portfolio_id,project_manager_id,team_lead_id,lifecycle_status,start_date,target_end_date,timezone,currency_code").order("project_code"),
      supabase.from("clients").select("id,name"),
      supabase.from("portfolios").select("id,name"),
      supabase.from("project_current_phase").select("project_id,phase_name,progress_percent,planned_start_date,forecast_completion_date,actual_completion_date"),
      supabase.from("project_snapshot_index").select("project_id,calculated_health,reported_health,created_at").order("created_at", { ascending: false })
    ]);
    if (projectResult.error) { setError(projectResult.error.message); setLoading(false); return; }
    setProjects((projectResult.data ?? []) as Project[]);
    setClients(Object.fromEntries((clientResult.data ?? []).map((row: { id: string; name: string }) => [row.id, row.name])));
    setPortfolios(Object.fromEntries((portfolioResult.data ?? []).map((row: { id: string; name: string }) => [row.id, row.name])));
    setPhases(Object.fromEntries(((phaseResult.data ?? []) as Phase[]).map((row) => [row.project_id, row])));
    const latest: Record<string, Snapshot> = {};
    for (const row of (snapshotResult.data ?? []) as Snapshot[]) if (!latest[row.project_id]) latest[row.project_id] = row;
    setSnapshots(latest);
    if (isPlatformAdmin) {
      const memberResult = await supabase.from("project_memberships").select("project_id,user_id,project_role").eq("status", "active").lte("effective_from", new Date().toISOString()).or("effective_to.is.null,effective_to.gt." + new Date().toISOString());
      const raw = (memberResult.data ?? []) as Omit<Member, "display_name">[];
      const ids = [...new Set(raw.map((member) => member.user_id))];
      const profileResult = ids.length ? await supabase.from("user_profiles").select("user_id,display_name").in("user_id", ids) : { data: [], error: null };
      const names = new Map((profileResult.data ?? []).map((profile: { user_id: string; display_name: string | null }) => [profile.user_id, profile.display_name || profile.user_id.slice(0, 8)]));
      setMembers(raw.map((member) => ({ ...member, display_name: names.get(member.user_id) ?? member.user_id.slice(0, 8) })));
    } else setMembers([]);
    setLoading(false);
  }, [isPlatformAdmin]);

  useEffect(() => { void loadRegister(); }, [loadRegister]);

  const selected = projects.find((project) => project.id === selectedId) ?? null;
  const memberName = (projectId: string, userId: string | null) => {
    if (!userId) return "Not assigned";
    if (!isPlatformAdmin) return "Assigned · name restricted by role";
    return members.find((member) => member.project_id === projectId && member.user_id === userId)?.display_name ?? "Name not available";
  };
  const filtered = useMemo(() => projects.filter((project) => {
    const phase = phases[project.id]?.phase_name ?? "";
    const health = snapshots[project.id]?.calculated_health ?? "not reported";
    const client = project.client_id ? clients[project.client_id] ?? "" : "";
    return [project.project_code, project.name, client, phase, health, project.lifecycle_status].join(" ").toLowerCase().includes(query.trim().toLowerCase());
  }), [projects, phases, snapshots, clients, query]);

  const loadDetail = useCallback(async (project: Project) => {
    if (!supabase) return;
    setSelectedId(project.id); setActiveTab("overview"); setDetailLoading(true); setDetailNotice("");
    const [contractResult, financeResult, milestoneResult, activityResult, riskResult, licenseResult, invoiceResult, balanceResult, cashResult] = await Promise.all([
      supabase.from("project_contracts").select("id,contract_reference,contract_title,contract_type,status,signed_date,commencement_date,contractual_end_date,duration_months,scope_summary,obligations,acceptance_criteria,penalties_terms,change_control_terms,payment_terms,currency_code,original_contract_value").eq("project_id", project.id).order("created_at", { ascending: false }),
      supabase.from("project_financial_terms").select("currency_code,original_contract_value,approved_variations,revised_contract_value,tax_rate,retention_rate,payment_terms,billing_notes").eq("project_id", project.id).order("created_at", { ascending: false }).limit(1),
      supabase.from("project_milestones").select("id,milestone_code,name,milestone_type,baseline_due_date,approved_revised_due_date,forecast_due_date,actual_due_date,progress_percent,status,weight,is_critical").eq("project_id", project.id).order("sequence_no"),
      supabase.from("project_activities").select("id,activity_code,name,workstream,baseline_due_date,approved_revised_due_date,forecast_due_date,actual_due_date,progress_percent,status,verification_status").eq("project_id", project.id).order("sequence_no"),
      supabase.from("project_risks").select("id,risk_reference,title,description,probability_level,impact_level,risk_score,status,trend,is_escalated,mitigation_plan,owner_user_id,target_resolution_date").eq("project_id", project.id).order("risk_score", { ascending: false, nullsFirst: false }).limit(5),
      supabase.from("project_licenses").select("id,license_reference,license_name,license_type,provider,expiry_date,renewal_notice_date,status,renewal_cost,currency_code").eq("project_id", project.id).order("expiry_date"),
      supabase.from("project_invoices").select("id,invoice_reference,invoice_type,status,issue_date,submission_date,due_date,currency_code,total_amount,disputed_reason").eq("project_id", project.id).order("issue_date", { ascending: false }),
      supabase.from("project_invoice_balances").select("invoice_id,applied_amount,outstanding_amount,is_settled").eq("project_id", project.id),
      supabase.from("project_cash_transactions").select("id,transaction_reference,transaction_type,status,transaction_date,currency_code,amount,payer_payee").eq("project_id", project.id).order("transaction_date", { ascending: false })
    ]);
    const errors = [contractResult.error, financeResult.error, milestoneResult.error, activityResult.error, riskResult.error, licenseResult.error, invoiceResult.error, balanceResult.error, cashResult.error].filter(Boolean);
    setDetailNotice(errors.length ? "Some sections could not be loaded because of data permissions or a service error. Restricted financial sections are not treated as zero." : "");
    setContracts((contractResult.data ?? []) as Contract[]);
    setFinance(((financeResult.data ?? [])[0] ?? null) as Finance | null);
    setMilestones((milestoneResult.data ?? []) as Milestone[]);
    setActivities((activityResult.data ?? []) as ProjectActivity[]);
    setRisks((riskResult.data ?? []) as Risk[]);
    setLicenses((licenseResult.data ?? []) as License[]);
    setInvoices((invoiceResult.data ?? []) as Invoice[]);
    setBalances(Object.fromEntries(((balanceResult.data ?? []) as Balance[]).map((balance) => [balance.invoice_id, balance])));
    setCash((cashResult.data ?? []) as Cash[]);
    setDetailLoading(false);
  }, []);

  const weightedProgress = useMemo(() => {
    if (!milestones.length) return null;
    const totalWeight = milestones.reduce((sum, milestone) => sum + Number(milestone.weight ?? 0), 0);
    if (totalWeight > 0) return milestones.reduce((sum, milestone) => sum + Number(milestone.progress_percent) * Number(milestone.weight ?? 0), 0) / totalWeight;
    return milestones.reduce((sum, milestone) => sum + Number(milestone.progress_percent), 0) / milestones.length;
  }, [milestones]);

  const tabs = [{ id: "overview", label: "Overview" }, { id: "contract", label: "Contract & Finance" }, { id: "schedule", label: "Schedule & Milestones" }, { id: "risk", label: "Risks & Licenses" }, { id: "payments", label: "Payments" }];
  const snapshot = selected ? snapshots[selected.id] : null;
  const phase = selected ? phases[selected.id] : null;

  if (loading) return <section className="project-module panel"><div className="module-loading">Loading project register…</div></section>;
  if (error) return <section className="project-module panel"><div className="module-error"><AlertTriangle size={18}/>{error}</div><button className="button-secondary small" onClick={() => void loadRegister()}>Retry</button></section>;

  return <section className="project-module">
    {!selected ? <>
      <div className="project-module-heading"><div><span className="module-eyebrow">PORTFOLIO DATA</span><h2>Project Register</h2><p>Live project profiles, delivery position and governance information.</p></div><div className="project-register-search"><Search size={15}/><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search project, client, phase or health"/></div></div>
      <div className="project-register-summary">
        <div><span>Visible projects</span><strong>{projects.length}</strong></div>
        <div><span>Active lifecycle</span><strong>{projects.filter((project) => !["closed","cancelled","completed"].includes(project.lifecycle_status)).length}</strong></div>
        <div><span>Calculated health reported</span><strong>{projects.filter((project) => Boolean(snapshots[project.id]?.calculated_health)).length}</strong></div>
        <div><span>Phase not reported</span><strong>{projects.filter((project) => !phases[project.id]?.phase_name).length}</strong></div>
      </div>
      {filtered.length ? <div className="project-register-grid">{filtered.map((project) => {
        const projectPhase = phases[project.id];
        const projectSnapshot = snapshots[project.id];
        return <button key={project.id} className="project-register-card" onClick={() => void loadDetail(project)}>
          <div className="project-card-top"><span>{project.project_code}</span><span className={"project-status-pill " + statusClass(project.lifecycle_status)}>{label(project.lifecycle_status)}</span></div>
          <h3>{project.name}</h3><p>{project.client_id ? clients[project.client_id] ?? "Client not reported" : "Client not reported"}</p>
          <div className="project-card-meta"><span><Layers3 size={13}/>{label(projectPhase?.phase_name)}</span><span><ShieldCheck size={13}/>{label(projectSnapshot?.calculated_health)}</span></div>
          <div className="project-card-dates"><span>Start <strong>{dateLabel(project.start_date)}</strong></span><span>Target end <strong>{dateLabel(project.target_end_date)}</strong></span></div>
          <div className="project-card-footer">Open project profile <ArrowLeft size={13}/></div>
        </button>;
      })}</div> : <div className="project-empty panel"><BriefcaseBusiness size={24}/><strong>{projects.length ? "No projects match this search." : "No projects are available to this account."}</strong><span>Project data is read live from the governed register; no demo records are shown.</span></div>}
    </> : <>
      <div className="project-detail-heading"><button className="button-secondary small" onClick={() => setSelectedId(null)}><ArrowLeft size={14}/> Back to register</button><div><span className="module-eyebrow">{selected.project_code}</span><h2>{selected.name}</h2><p>{selected.client_id ? clients[selected.client_id] ?? "Client not reported" : "Client not reported"} · {label(selected.lifecycle_status)}</p></div><span className={"project-status-pill " + statusClass(snapshot?.calculated_health)}>{label(snapshot?.calculated_health)}</span></div>
      <div className="project-profile-tabs">{tabs.map((tab) => <button key={tab.id} className={activeTab === tab.id ? "active" : ""} onClick={() => setActiveTab(tab.id)}>{tab.label}</button>)}</div>
      {detailNotice && <div className="project-detail-notice"><ShieldAlert size={15}/>{detailNotice}</div>}
      {detailLoading ? <div className="module-loading panel">Loading project profile…</div> : <>
        {activeTab === "overview" && <div className="project-detail-grid">
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Project Information</h3><span>Register profile</span></div><dl>
            <dt>Project code</dt><dd>{selected.project_code}</dd><dt>Client</dt><dd>{selected.client_id ? clients[selected.client_id] ?? "Not reported" : "Not reported"}</dd><dt>Portfolio</dt><dd>{selected.portfolio_id ? portfolios[selected.portfolio_id] ?? "Not reported" : "Not reported"}</dd><dt>Lifecycle status</dt><dd>{label(selected.lifecycle_status)}</dd><dt>Current phase</dt><dd>{label(phase?.phase_name)}</dd><dt>Project Manager</dt><dd>{memberName(selected.id, selected.project_manager_id)}</dd><dt>Team Lead</dt><dd>{memberName(selected.id, selected.team_lead_id)}</dd><dt>Start date</dt><dd>{dateLabel(selected.start_date)}</dd><dt>Target end date</dt><dd>{dateLabel(selected.target_end_date)}</dd><dt>Timezone</dt><dd>{selected.timezone || "Not Reported"}</dd>
          </dl></article>
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Performance Position</h3><span>Latest available snapshot</span></div><div className="project-kpi-grid">
            <div><small>PM-reported health</small><strong>{label(snapshot?.reported_health)}</strong></div><div><small>Calculated health</small><strong>{label(snapshot?.calculated_health)}</strong></div><div><small>Current phase progress</small><strong>{phase?.progress_percent == null ? "Not Reported" : Number(phase.progress_percent).toFixed(0) + "%"}</strong></div><div><small>Milestone accomplishment</small><strong>{weightedProgress == null ? "Not Reported" : weightedProgress.toFixed(1) + "%"}</strong></div>
          </div><p className="project-footnote">Reported health and calculated health remain separate. Missing snapshots are shown as Not Reported, not Green.</p></article>
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Contract Position</h3><span>Summary</span></div>{contracts.length ? contracts.map((contract) => <div className="project-compact-record" key={contract.id}><strong>{contract.contract_reference} · {contract.contract_title}</strong><span>{label(contract.status)} · {dateLabel(contract.commencement_date)} to {dateLabel(contract.contractual_end_date)}</span></div>) : <p className="project-empty-inline">No accessible contract record. It may not have been reported or the current role may not have contract access.</p>}</article>
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Delivery & Exposure</h3><span>Current records</span></div><div className="project-kpi-grid"><div><small>Milestones</small><strong>{milestones.length || "Not Reported"}</strong></div><div><small>Open risks</small><strong>{risks.filter((risk) => !["closed","resolved"].includes(risk.status)).length || "Not Reported"}</strong></div><div><small>Licenses</small><strong>{licenses.length || "Not Reported"}</strong></div><div><small>Invoices accessible</small><strong>{invoices.length || "Not Reported"}</strong></div></div></article>
        </div>}
        {activeTab === "contract" && <div className="project-detail-grid">
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Contractual Terms</h3><span>{contracts.length} records</span></div>{contracts.length ? contracts.map((contract) => <div className="project-contract-record" key={contract.id}><div className="project-contract-top"><strong>{contract.contract_reference} · {contract.contract_title}</strong><span className={"project-status-pill " + statusClass(contract.status)}>{label(contract.status)}</span></div><div className="project-kpi-grid"><div><small>Contract type</small><strong>{label(contract.contract_type)}</strong></div><div><small>Original value</small><strong>{amount(contract.original_contract_value, contract.currency_code)}</strong></div><div><small>Signed</small><strong>{dateLabel(contract.signed_date)}</strong></div><div><small>Contractual end</small><strong>{dateLabel(contract.contractual_end_date)}</strong></div></div><p><b>Scope:</b> {contract.scope_summary || "Not Reported"}</p><p><b>Obligations:</b> {contract.obligations || "Not Reported"}</p><p><b>Acceptance:</b> {contract.acceptance_criteria || "Not Reported"}</p><p><b>Payment terms:</b> {contract.payment_terms || "Not Reported"}</p><p><b>Change control:</b> {contract.change_control_terms || "Not Reported"}</p><p><b>Penalties:</b> {contract.penalties_terms || "Not Reported"}</p></div>) : <p className="project-empty-inline">No accessible contract record. It may not have been reported or the current role may not have contract access.</p>}</article>
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Financial Terms</h3><span>Restricted by role and project grant</span></div>{finance ? <><div className="project-kpi-grid"><div><small>Original contract value</small><strong>{amount(finance.original_contract_value, finance.currency_code)}</strong></div><div><small>Approved variations</small><strong>{amount(finance.approved_variations, finance.currency_code)}</strong></div><div><small>Revised contract value</small><strong>{amount(finance.revised_contract_value, finance.currency_code)}</strong></div><div><small>Retention rate</small><strong>{finance.retention_rate == null ? "Not Reported" : finance.retention_rate + "%"}</strong></div></div><p><b>Tax rate:</b> {finance.tax_rate == null ? "Not Reported" : finance.tax_rate + "%"}</p><p><b>Payment terms:</b> {finance.payment_terms || "Not Reported"}</p><p><b>Billing notes:</b> {finance.billing_notes || "Not Reported"}</p></> : <p className="project-empty-inline">No accessible financial terms. Financial data may be unreported or restricted to Finance, Project Manager, Platform Administrator, Finance Administrator or an explicitly granted Executive Viewer.</p>}</article>
        </div>}
        {activeTab === "schedule" && <div className="project-detail-grid">
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Milestone Tracker</h3><span>{milestones.length} milestones</span></div><div className="project-milestone-summary"><strong>{weightedProgress == null ? "Not Reported" : weightedProgress.toFixed(1) + "%"}</strong><span>{milestones.some((milestone) => Number(milestone.weight) > 0) ? "Weighted accomplishment" : "Simple average · weights not configured"}</span></div>{milestones.length ? milestones.map((milestone) => <div className="project-timeline-row" key={milestone.id}><div><strong>{milestone.milestone_code} · {milestone.name}</strong><small>{label(milestone.status)}{milestone.is_critical ? " · Critical" : ""} · {label(milestone.milestone_type)}</small><small>Baseline {dateLabel(milestone.baseline_due_date)} · Forecast {dateLabel(milestone.forecast_due_date)} · Actual {dateLabel(milestone.actual_due_date)}</small></div><div className="project-progress"><span>{Number(milestone.progress_percent).toFixed(0)}%</span><i><b style={{ width: Math.max(0, Math.min(100, Number(milestone.progress_percent))) + "%" }}/></i></div></div>) : <p className="project-empty-inline">Milestone data is not reported.</p>}</article>
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Main Schedule Activities</h3><span>{activities.length} activities</span></div>{activities.length ? activities.map((activity) => <div className="project-timeline-row" key={activity.id}><div><strong>{activity.activity_code} · {activity.name}</strong><small>{activity.workstream || "Workstream not reported"} · {label(activity.status)} · Verification {label(activity.verification_status)}</small><small>Baseline {dateLabel(activity.baseline_due_date)} · Forecast {dateLabel(activity.forecast_due_date)} · Actual {dateLabel(activity.actual_due_date)}</small></div><div className="project-progress"><span>{Number(activity.progress_percent).toFixed(0)}%</span><i><b style={{ width: Math.max(0, Math.min(100, Number(activity.progress_percent))) + "%" }}/></i></div></div>) : <p className="project-empty-inline">Schedule activity data is not reported.</p>}</article>
        </div>}
        {activeTab === "risk" && <div className="project-detail-grid">
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Top 5 Project Risks</h3><span>Highest recorded risk scores</span></div>{risks.length ? risks.map((risk) => <div className="project-risk-row" key={risk.id}><div className="project-risk-heading"><strong>{risk.risk_reference} · {risk.title}</strong><span className={"project-status-pill " + statusClass(risk.is_escalated ? "escalated" : risk.status)}>{risk.is_escalated ? "Escalated" : label(risk.status)}</span></div><p>{risk.description}</p><div className="project-risk-meta"><span>Probability {risk.probability_level}</span><span>Impact {risk.impact_level}</span><span>Score {risk.risk_score ?? "Not Reported"}</span><span>Trend {label(risk.trend)}</span><span>Target {dateLabel(risk.target_resolution_date)}</span></div><small>Mitigation: {risk.mitigation_plan || "Not Reported"}</small></div>) : <p className="project-empty-inline">Risk data is not reported.</p>}</article>
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>License Register</h3><span>{licenses.length} licenses</span></div>{licenses.length ? licenses.map((license) => <div className="project-compact-record" key={license.id}><strong>{license.license_reference} · {license.license_name}</strong><span>{label(license.status)} · {license.provider || "Provider not reported"}</span><span>Expiry {dateLabel(license.expiry_date)} · Renewal notice {dateLabel(license.renewal_notice_date)}</span>{license.renewal_cost != null && <span>Renewal cost {amount(license.renewal_cost, license.currency_code)}</span>}</div>) : <p className="project-empty-inline">License data is not reported.</p>}</article>
        </div>}
        {activeTab === "payments" && <div className="project-detail-grid">
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Invoices & Receivables</h3><span>Financial access controlled by RLS</span></div>{invoices.length ? <div className="project-invoice-list">{invoices.map((invoice) => { const balance = balances[invoice.id]; return <div className="project-invoice-row" key={invoice.id}><div><strong>{invoice.invoice_reference}</strong><small>{label(invoice.invoice_type)} · {label(invoice.status)} · Issued {dateLabel(invoice.issue_date)} · Due {dateLabel(invoice.due_date)}</small>{invoice.disputed_reason && <small className="project-dispute">Dispute: {invoice.disputed_reason}</small>}</div><div><strong>{amount(invoice.total_amount, invoice.currency_code)}</strong><small>Applied {amount(balance?.applied_amount, invoice.currency_code)}</small><small>Outstanding {amount(balance?.outstanding_amount, invoice.currency_code)}</small></div></div>; })}</div> : <p className="project-empty-inline">No accessible invoice records. They may be unreported or restricted by the current financial access grant.</p>}</article>
          <article className="panel project-info-panel"><div className="project-panel-heading"><h3>Cash Transactions</h3><span>Finance-controlled records</span></div>{cash.length ? cash.map((transaction) => <div className="project-invoice-row" key={transaction.id}><div><strong>{transaction.transaction_reference}</strong><small>{label(transaction.transaction_type)} · {label(transaction.status)} · {dateLabel(transaction.transaction_date)}</small><small>{transaction.payer_payee || "Counterparty not reported"}</small></div><strong>{amount(transaction.amount, transaction.currency_code)}</strong></div>) : <p className="project-empty-inline">No accessible cash transactions. They may be unreported or restricted by the current financial access grant.</p>}</article>
        </div>}
      </>}
    </>}
  </section>;
}
