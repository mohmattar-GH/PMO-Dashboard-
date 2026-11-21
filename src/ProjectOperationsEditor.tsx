import { useState } from "react";
import { FileCheck2, Pencil, Plus, ShieldAlert } from "lucide-react";
import { supabase } from "./lib/supabase";

type TeamMember = { user_id: string; project_role: string; display_name: string; job_title: string | null };
type Milestone = { id: string; milestone_code: string; name: string };
type Activity = {
  id: string; project_id: string; milestone_id: string | null; activity_code: string; name: string; description: string | null;
  workstream: string | null; sequence_no: number | null; weight: number | null; baseline_start_date: string | null;
  baseline_due_date: string | null; approved_revised_start_date: string | null; approved_revised_due_date: string | null;
  forecast_start_date: string | null; forecast_due_date: string | null; actual_start_date: string | null; actual_due_date: string | null;
  progress_percent: number; status: string; assigned_to_user_id: string | null; verification_status: string; notes: string | null;
};
type Risk = {
  id: string; project_id: string; risk_reference: string; title: string; description: string; category: string | null;
  cause: string | null; consequence: string | null; probability_level: number; impact_level: number; risk_score: number | null;
  response_strategy: string | null; mitigation_plan: string | null; contingency_plan: string | null; owner_user_id: string | null;
  identified_date: string; review_date: string | null; target_resolution_date: string | null; resolved_date: string | null;
  status: string; trend: string; is_escalated: boolean;
};
type License = {
  id: string; project_id: string; license_reference: string; license_name: string; license_type: string | null;
  provider: string | null; quantity: number | null; unit_of_measure: string | null; start_date: string | null;
  expiry_date: string | null; renewal_notice_date: string | null; renewal_cost: number | null; currency_code: string | null;
  owner_user_id: string | null; status: string; notes: string | null;
};
const today = () => new Date().toISOString().slice(0,10);
const dateLabel = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(value + (value.length === 10 ? "T00:00:00" : ""))) : "Not Reported";
const money = (value: number | null, currency: string | null) => {
  if (value == null) return "Not Reported";
  if (!currency) return Number(value).toLocaleString() + " · Currency not reported";
  try { return new Intl.NumberFormat(undefined, { style: "currency", currency }).format(value); }
  catch { return Number(value).toLocaleString() + " " + currency; }
};
const label = (value: string | null | undefined) => value ? value.replace(/_/g," ").replace(/\b\w/g,(letter)=>letter.toUpperCase()) : "Not Reported";

export default function ProjectOperationsEditor({
  mode, projectId, activities, risks, licenses, milestones, teamMembers, currentUserId, canManageProject, onSaved
}: {
  mode: "activities" | "risks"; projectId: string; activities: Activity[]; risks: Risk[]; licenses: License[];
  milestones: Milestone[]; teamMembers: TeamMember[]; currentUserId: string; canManageProject: boolean; onSaved: () => Promise<void>;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [activityFormOpen, setActivityFormOpen] = useState(false);
  const [editingActivity, setEditingActivity] = useState<Activity | null>(null);
  const [riskFormOpen, setRiskFormOpen] = useState(false);
  const [editingRisk, setEditingRisk] = useState<Risk | null>(null);
  const [licenseFormOpen, setLicenseFormOpen] = useState(false);
  const [editingLicense, setEditingLicense] = useState<License | null>(null);
  const [activityForm, setActivityForm] = useState({
    activity_code:"",name:"",description:"",workstream:"",milestone_id:"",sequence_no:"",weight:"",
    baseline_start_date:"",baseline_due_date:"",forecast_start_date:"",forecast_due_date:"",
    actual_start_date:"",actual_due_date:"",progress_percent:"0",status:"not_started",
    assigned_to_user_id:"",verification_status:"unverified",notes:""
  });
  const [riskForm, setRiskForm] = useState({
    risk_reference:"",title:"",description:"",category:"",cause:"",consequence:"",
    probability_level:"3",impact_level:"3",response_strategy:"",mitigation_plan:"",contingency_plan:"",
    owner_user_id:"",identified_date:today(),review_date:"",target_resolution_date:"",resolved_date:"",
    status:"open",trend:"stable",is_escalated:false
  });
  const [licenseForm, setLicenseForm] = useState({
    license_reference:"",license_name:"",license_type:"",provider:"",quantity:"",unit_of_measure:"",
    start_date:"",expiry_date:"",renewal_notice_date:"",renewal_cost:"",currency_code:"",
    owner_user_id:"",status:"active",notes:""
  });

  const startActivity = (activity?: Activity, assignedOnly = false) => {
    setEditingActivity(activity ?? null);
    setActivityForm(activity ? {
      activity_code:activity.activity_code,name:activity.name,description:activity.description ?? "",workstream:activity.workstream ?? "",
      milestone_id:activity.milestone_id ?? "",sequence_no:activity.sequence_no == null ? "" : String(activity.sequence_no),
      weight:activity.weight == null ? "" : String(activity.weight),
      baseline_start_date:activity.baseline_start_date ?? "",baseline_due_date:activity.baseline_due_date ?? "",
      forecast_start_date:activity.forecast_start_date ?? "",forecast_due_date:activity.forecast_due_date ?? "",
      actual_start_date:activity.actual_start_date ?? "",actual_due_date:activity.actual_due_date ?? "",
      progress_percent:String(activity.progress_percent),status:activity.status,assigned_to_user_id:activity.assigned_to_user_id ?? "",
      verification_status:activity.verification_status,notes:activity.notes ?? ""
    } : { activity_code:"",name:"",description:"",workstream:"",milestone_id:"",sequence_no:String(activities.length+1),weight:"",
      baseline_start_date:"",baseline_due_date:"",forecast_start_date:"",forecast_due_date:"",actual_start_date:"",actual_due_date:"",
      progress_percent:"0",status:"not_started",assigned_to_user_id:"",verification_status:"unverified",notes:"" });
    setError(""); setMessage(""); setActivityFormOpen(true);
    if (assignedOnly && activity) setActivityForm((form) => ({ ...form, activity_code: activity.activity_code }));
  };

  const saveActivity = async () => {
    if (!supabase) return;
    if (!activityForm.activity_code.trim() || !activityForm.name.trim()) { setError("Activity code and name are required."); return; }
    const pct = Number(activityForm.progress_percent);
    if (!Number.isFinite(pct) || pct < 0 || pct > 100) { setError("Progress must be between 0 and 100."); return; }
    if (activityForm.sequence_no && (!Number.isInteger(Number(activityForm.sequence_no)) || Number(activityForm.sequence_no) <= 0)) { setError("Activity sequence must be a positive whole number."); return; }
    if (activityForm.weight && (!Number.isFinite(Number(activityForm.weight)) || Number(activityForm.weight) < 0 || Number(activityForm.weight) > 1)) { setError("Activity weight must be between 0 and 1."); return; }
    for (const [start,end,name] of [["baseline_start_date","baseline_due_date","Baseline"],["forecast_start_date","forecast_due_date","Forecast"],["actual_start_date","actual_due_date","Actual"]] as const) {
      if (activityForm[start] && activityForm[end] && activityForm[start] > activityForm[end]) { setError(name + " start date cannot be later than its due date."); return; }
    }
    setBusy(true); setError(""); setMessage("");
    const payload: Record<string, unknown> = {
      project_id:projectId,activity_code:activityForm.activity_code.trim(),name:activityForm.name.trim(),
      description:activityForm.description.trim()||null,workstream:activityForm.workstream.trim()||null,
      milestone_id:activityForm.milestone_id||null,progress_percent:pct,status:activityForm.status,
      forecast_start_date:activityForm.forecast_start_date||null,forecast_due_date:activityForm.forecast_due_date||null,
      actual_start_date:activityForm.actual_start_date||null,actual_due_date:activityForm.actual_due_date||null,
      verification_status:activityForm.verification_status,notes:activityForm.notes.trim()||null
    };
    if (!editingActivity) {
      payload.created_by = currentUserId;
      payload.sequence_no = activityForm.sequence_no ? Number(activityForm.sequence_no) : null;
      payload.weight = activityForm.weight ? Number(activityForm.weight) : null;
      payload.baseline_start_date = activityForm.baseline_start_date||null;
      payload.baseline_due_date = activityForm.baseline_due_date||null;
      payload.assigned_to_user_id = activityForm.assigned_to_user_id||null;
    } else if (canManageProject) {
      payload.assigned_to_user_id = activityForm.assigned_to_user_id||null;
      payload.sequence_no = activityForm.sequence_no ? Number(activityForm.sequence_no) : null;
      payload.weight = activityForm.weight ? Number(activityForm.weight) : null;
    }
    const result = editingActivity
      ? await supabase.from("project_activities").update(payload).eq("id",editingActivity.id).select("id").single()
      : await supabase.from("project_activities").insert(payload).select("id").single();
    if (result.error) setError(result.error.message);
    else { setActivityFormOpen(false); setMessage(editingActivity ? "Activity updated and audited." : "Activity created and added to the schedule."); setBusy(false); await onSaved(); return; }
    setBusy(false);
  };

  const startRisk = (risk?: Risk) => {
    setEditingRisk(risk ?? null);
    setRiskForm(risk ? {
      risk_reference:risk.risk_reference,title:risk.title,description:risk.description,category:risk.category??"",
      cause:risk.cause??"",consequence:risk.consequence??"",probability_level:String(risk.probability_level),
      impact_level:String(risk.impact_level),response_strategy:risk.response_strategy??"",mitigation_plan:risk.mitigation_plan??"",
      contingency_plan:risk.contingency_plan??"",owner_user_id:risk.owner_user_id??"",identified_date:risk.identified_date,
      review_date:risk.review_date??"",target_resolution_date:risk.target_resolution_date??"",resolved_date:risk.resolved_date??"",
      status:risk.status,trend:risk.trend,is_escalated:risk.is_escalated
    } : { risk_reference:"",title:"",description:"",category:"",cause:"",consequence:"",probability_level:"3",impact_level:"3",
      response_strategy:"",mitigation_plan:"",contingency_plan:"",owner_user_id:"",identified_date:today(),review_date:"",
      target_resolution_date:"",resolved_date:"",status:"open",trend:"stable",is_escalated:false });
    setError(""); setMessage(""); setRiskFormOpen(true);
  };
  const saveRisk = async () => {
    if (!supabase) return;
    if (!riskForm.risk_reference.trim() || !riskForm.title.trim() || !riskForm.description.trim()) { setError("Risk reference, title and description are required."); return; }
    if (!Number.isInteger(Number(riskForm.probability_level)) || !Number.isInteger(Number(riskForm.impact_level)) || Number(riskForm.probability_level) <= 0 || Number(riskForm.impact_level) <= 0) { setError("Probability and impact must be positive whole numbers."); return; }
    if (riskForm.resolved_date && riskForm.resolved_date < riskForm.identified_date) { setError("Resolved date cannot precede the identified date."); return; }
    setBusy(true); setError(""); setMessage("");
    const payload = {
      project_id:projectId,risk_reference:riskForm.risk_reference.trim(),title:riskForm.title.trim(),description:riskForm.description.trim(),
      category:riskForm.category.trim()||null,cause:riskForm.cause.trim()||null,consequence:riskForm.consequence.trim()||null,
      probability_level:Number(riskForm.probability_level),impact_level:Number(riskForm.impact_level),
      response_strategy:riskForm.response_strategy.trim()||null,mitigation_plan:riskForm.mitigation_plan.trim()||null,
      contingency_plan:riskForm.contingency_plan.trim()||null,owner_user_id:riskForm.owner_user_id||null,
      identified_date:riskForm.identified_date,review_date:riskForm.review_date||null,
      target_resolution_date:riskForm.target_resolution_date||null,resolved_date:riskForm.resolved_date||null,
      status:riskForm.status,trend:riskForm.trend,is_escalated:riskForm.is_escalated
    };
    const result = editingRisk
      ? await supabase.from("project_risks").update(payload).eq("id",editingRisk.id).select("id").single()
      : await supabase.from("project_risks").insert({ ...payload, created_by: currentUserId }).select("id").single();
    if (result.error) setError(result.error.message);
    else { setRiskFormOpen(false); setMessage(editingRisk ? "Risk updated and audited." : "Risk registered. Risk score remains Not Reported until the risk-scoring process is connected."); setBusy(false); await onSaved(); return; }
    setBusy(false);
  };

  const startLicense = (license?: License) => {
    setEditingLicense(license ?? null);
    setLicenseForm(license ? {
      license_reference:license.license_reference,license_name:license.license_name,license_type:license.license_type??"",
      provider:license.provider??"",quantity:license.quantity==null?"":String(license.quantity),unit_of_measure:license.unit_of_measure??"",
      start_date:license.start_date??"",expiry_date:license.expiry_date??"",renewal_notice_date:license.renewal_notice_date??"",
      renewal_cost:license.renewal_cost==null?"":String(license.renewal_cost),currency_code:license.currency_code??"",
      owner_user_id:license.owner_user_id??"",status:license.status,notes:license.notes??""
    } : { license_reference:"",license_name:"",license_type:"",provider:"",quantity:"",unit_of_measure:"",
      start_date:"",expiry_date:"",renewal_notice_date:"",renewal_cost:"",currency_code:"",owner_user_id:"",status:"active",notes:"" });
    setError(""); setMessage(""); setLicenseFormOpen(true);
  };
  const saveLicense = async () => {
    if (!supabase) return;
    if (!licenseForm.license_reference.trim() || !licenseForm.license_name.trim()) { setError("License reference and name are required."); return; }
    if (licenseForm.start_date && licenseForm.expiry_date && licenseForm.start_date > licenseForm.expiry_date) { setError("License expiry cannot precede its start date."); return; }
    if (licenseForm.quantity && Number(licenseForm.quantity) < 0) { setError("License quantity cannot be negative."); return; }
    if (licenseForm.renewal_cost && Number(licenseForm.renewal_cost) < 0) { setError("Renewal cost cannot be negative."); return; }
    if (licenseForm.renewal_cost && !/^[A-Z]{3}$/.test(licenseForm.currency_code.trim().toUpperCase())) { setError("Enter a three-letter currency code for renewal cost."); return; }
    setBusy(true); setError(""); setMessage("");
    const payload = {
      project_id:projectId,license_reference:licenseForm.license_reference.trim(),license_name:licenseForm.license_name.trim(),
      license_type:licenseForm.license_type.trim()||null,provider:licenseForm.provider.trim()||null,
      quantity:licenseForm.quantity?Number(licenseForm.quantity):null,unit_of_measure:licenseForm.unit_of_measure.trim()||null,
      start_date:licenseForm.start_date||null,expiry_date:licenseForm.expiry_date||null,renewal_notice_date:licenseForm.renewal_notice_date||null,
      renewal_cost:licenseForm.renewal_cost?Number(licenseForm.renewal_cost):null,currency_code:licenseForm.currency_code.trim().toUpperCase()||null,
      owner_user_id:licenseForm.owner_user_id||null,status:licenseForm.status,notes:licenseForm.notes.trim()||null
    };
    const result = editingLicense
      ? await supabase.from("project_licenses").update(payload).eq("id",editingLicense.id).select("id").single()
      : await supabase.from("project_licenses").insert({ ...payload, created_by: currentUserId }).select("id").single();
    if (result.error) setError(result.error.message);
    else { setLicenseFormOpen(false); setMessage(editingLicense ? "License updated and audited." : "License registered and audited."); setBusy(false); await onSaved(); return; }
    setBusy(false);
  };

  const memberName = (userId: string | null) => teamMembers.find((member) => member.user_id === userId)?.display_name ?? "Unassigned";
  const myAssignedActivities = activities.filter((activity) => activity.assigned_to_user_id === currentUserId);
  const visibleActivities = canManageProject ? activities : myAssignedActivities;
  const topFiveScoredRisks = risks.filter((risk) => risk.risk_score !== null && risk.risk_score !== undefined).slice(0, 5);

  if (mode === "activities") return <article className="panel project-info-panel"><div className="project-panel-heading"><div><h3><FileCheck2 size={13}/> Main Schedule Activities</h3><span>{activities.length} activities</span></div>{canManageProject && <button className="button-secondary small" onClick={() => startActivity()}><Plus size={12}/> Add activity</button>}</div>
    {error && <div className="project-create-error">{error}</div>}{message && <div className="project-create-success">{message}</div>}
    {visibleActivities.length ? visibleActivities.map((activity) => <div className="project-timeline-row" key={activity.id}><div><strong>{activity.activity_code} · {activity.name}</strong><small>{activity.workstream || "Workstream not reported"} · {label(activity.status)} · Verification {label(activity.verification_status)}</small><small>Baseline {dateLabel(activity.baseline_due_date)} · Forecast {dateLabel(activity.forecast_due_date)} · Actual {dateLabel(activity.actual_due_date)}</small><small>Assigned to {memberName(activity.assigned_to_user_id)}</small></div><div className="project-progress"><span>{Number(activity.progress_percent).toFixed(0)}%</span><i><b style={{width:Math.max(0,Math.min(100,Number(activity.progress_percent)))+"%"}}/></i></div>{(canManageProject || activity.assigned_to_user_id === currentUserId) && <button className="icon-button" title="Edit activity" onClick={() => startActivity(activity,!canManageProject)}><Pencil size={12}/></button>}</div>) : <p className="project-empty-inline">{canManageProject ? "No schedule activities have been reported." : "No activities are assigned to this Team Lead account."}</p>}
    {activityFormOpen && <div className="operations-form"><div className="commercial-form-heading"><strong>{editingActivity ? "Update Activity" : "Add Schedule Activity"}</strong><button className="icon-button" onClick={() => setActivityFormOpen(false)}>×</button></div><div className="operations-form-grid">
      {canManageProject && <><label>Activity code<input disabled={Boolean(editingActivity)} value={activityForm.activity_code} onChange={(e)=>setActivityForm((f)=>({...f,activity_code:e.target.value.toUpperCase()}))}/></label><label>Activity name<input value={activityForm.name} onChange={(e)=>setActivityForm((f)=>({...f,name:e.target.value}))}/></label><label>Workstream<input value={activityForm.workstream} onChange={(e)=>setActivityForm((f)=>({...f,workstream:e.target.value}))}/></label><label>Milestone<select value={activityForm.milestone_id} onChange={(e)=>setActivityForm((f)=>({...f,milestone_id:e.target.value}))}><option value="">Not linked</option>{milestones.map((m)=> <option key={m.id} value={m.id}>{m.milestone_code} · {m.name}</option>)}</select></label><label>Sequence<input type="number" min="1" value={activityForm.sequence_no} onChange={(e)=>setActivityForm((f)=>({...f,sequence_no:e.target.value}))}/></label><label>Weight (0–1)<input type="number" min="0" max="1" step="0.01" value={activityForm.weight} onChange={(e)=>setActivityForm((f)=>({...f,weight:e.target.value}))}/></label><label>Assigned owner<select value={activityForm.assigned_to_user_id} onChange={(e)=>setActivityForm((f)=>({...f,assigned_to_user_id:e.target.value}))}><option value="">Unassigned</option>{teamMembers.map((m)=><option key={m.user_id} value={m.user_id}>{m.display_name} · {label(m.project_role)}</option>)}</select></label><label className="wide">Description<textarea value={activityForm.description} onChange={(e)=>setActivityForm((f)=>({...f,description:e.target.value}))}/></label><label>Baseline start<input type="date" disabled={Boolean(editingActivity)} value={activityForm.baseline_start_date} onChange={(e)=>setActivityForm((f)=>({...f,baseline_start_date:e.target.value}))}/></label><label>Baseline due<input type="date" disabled={Boolean(editingActivity)} value={activityForm.baseline_due_date} onChange={(e)=>setActivityForm((f)=>({...f,baseline_due_date:e.target.value}))}/></label></>}
      <label>Forecast start<input type="date" value={activityForm.forecast_start_date} onChange={(e)=>setActivityForm((f)=>({...f,forecast_start_date:e.target.value}))}/></label><label>Forecast due<input type="date" value={activityForm.forecast_due_date} onChange={(e)=>setActivityForm((f)=>({...f,forecast_due_date:e.target.value}))}/></label><label>Actual start<input type="date" value={activityForm.actual_start_date} onChange={(e)=>setActivityForm((f)=>({...f,actual_start_date:e.target.value}))}/></label><label>Actual due<input type="date" value={activityForm.actual_due_date} onChange={(e)=>setActivityForm((f)=>({...f,actual_due_date:e.target.value}))}/></label><label>Progress %<input type="number" min="0" max="100" value={activityForm.progress_percent} onChange={(e)=>setActivityForm((f)=>({...f,progress_percent:e.target.value}))}/></label><label>Status<input value={activityForm.status} onChange={(e)=>setActivityForm((f)=>({...f,status:e.target.value}))} placeholder="Enter configured activity status"/></label><label>Verification status<input value={activityForm.verification_status} onChange={(e)=>setActivityForm((f)=>({...f,verification_status:e.target.value}))} placeholder="Enter configured verification status"/></label><label className="wide">Notes<textarea value={activityForm.notes} onChange={(e)=>setActivityForm((f)=>({...f,notes:e.target.value}))}/></label>
    </div><div className="commercial-form-note">Baseline dates are captured at creation and cannot be overwritten. Approved revised dates are managed through governed change control.</div><div className="commercial-form-actions"><button className="button-secondary small" onClick={()=>setActivityFormOpen(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={()=>void saveActivity()}>{busy?"Saving…":"Save activity"}</button></div></div>}
  </article>;

  return <div className="project-detail-grid">
    <article className="panel project-info-panel project-top-risk-panel"><div className="project-panel-heading"><div><h3><ShieldAlert size={13}/> Top 5 Risk Watchlist</h3><span>Displays only system-calculated risk scores; no manual or hardcoded fallback ranking is applied.</span></div><span>{topFiveScoredRisks.length}/5 scored risks</span></div>
      {topFiveScoredRisks.length ? <div className="project-top-risk-list">{topFiveScoredRisks.map((risk,index)=><div className="project-top-risk-row" key={risk.id}><b>{index+1}</b><div><strong>{risk.risk_reference} · {risk.title}</strong><small>{label(risk.status)} · Owner {memberName(risk.owner_user_id)} · Target {dateLabel(risk.target_resolution_date)}</small></div><span>{risk.risk_score}</span></div>)}</div> : <p className="project-empty-inline">Risk-score calculation is not yet connected to the risk register. The top-five ranking remains Not Reported until a configurable per-risk scoring process is implemented.</p>}
    </article>
    <article className="panel project-info-panel"><div className="project-panel-heading"><div><h3><ShieldAlert size={13}/> Project Risks</h3><span>Highest recorded scores first · {risks.length} records shown</span></div>{canManageProject && <button className="button-secondary small" onClick={()=>startRisk()}><Plus size={12}/> Add risk</button>}</div>
      {error && <div className="project-create-error">{error}</div>}{message && <div className="project-create-success">{message}</div>}
      {risks.length ? risks.map((risk)=><div className="project-risk-row" key={risk.id}><div className="project-risk-heading"><strong>{risk.risk_reference} · {risk.title}</strong><span className={"project-status-pill "+(risk.is_escalated?"escalated":risk.status.replace(/[^a-z0-9]+/gi,"-").toLowerCase())}>{risk.is_escalated?"Escalated":label(risk.status)}</span></div><p>{risk.description}</p><div className="project-risk-meta"><span>Probability {risk.probability_level}</span><span>Impact {risk.impact_level}</span><span>Score {risk.risk_score??"Not Reported"}</span><span>Trend {label(risk.trend)}</span><span>Target {dateLabel(risk.target_resolution_date)}</span><span>Owner {memberName(risk.owner_user_id)}</span></div><small>Mitigation: {risk.mitigation_plan||"Not Reported"}</small>{canManageProject&&<button className="button-secondary small" onClick={()=>startRisk(risk)}><Pencil size={11}/> Edit risk</button>}</div>) : <p className="project-empty-inline">Risk data is not reported.</p>}
      {riskFormOpen && <div className="operations-form"><div className="commercial-form-heading"><strong>{editingRisk?"Edit Risk":"Register Risk"}</strong><button className="icon-button" onClick={()=>setRiskFormOpen(false)}>×</button></div><div className="operations-form-grid">
        <label>Risk reference<input disabled={Boolean(editingRisk)} value={riskForm.risk_reference} onChange={(e)=>setRiskForm((f)=>({...f,risk_reference:e.target.value.toUpperCase()}))}/></label><label>Title<input value={riskForm.title} onChange={(e)=>setRiskForm((f)=>({...f,title:e.target.value}))}/></label><label>Category<input value={riskForm.category} onChange={(e)=>setRiskForm((f)=>({...f,category:e.target.value}))}/></label><label>Owner<select value={riskForm.owner_user_id} onChange={(e)=>setRiskForm((f)=>({...f,owner_user_id:e.target.value}))}><option value="">Unassigned</option>{teamMembers.map((m)=><option key={m.user_id} value={m.user_id}>{m.display_name}</option>)}</select></label><label>Probability<input type="number" min="1" value={riskForm.probability_level} onChange={(e)=>setRiskForm((f)=>({...f,probability_level:e.target.value}))}/></label><label>Impact<input type="number" min="1" value={riskForm.impact_level} onChange={(e)=>setRiskForm((f)=>({...f,impact_level:e.target.value}))}/></label><label>Status<input value={riskForm.status} onChange={(e)=>setRiskForm((f)=>({...f,status:e.target.value}))} placeholder="Enter configured risk status"/></label><label>Trend<select value={riskForm.trend} onChange={(e)=>setRiskForm((f)=>({...f,trend:e.target.value}))}>{["increasing","stable","decreasing"].map((v)=><option key={v} value={v}>{label(v)}</option>)}</select></label><label>Identified date<input type="date" value={riskForm.identified_date} onChange={(e)=>setRiskForm((f)=>({...f,identified_date:e.target.value}))}/></label><label>Review date<input type="date" value={riskForm.review_date} onChange={(e)=>setRiskForm((f)=>({...f,review_date:e.target.value}))}/></label><label>Target resolution<input type="date" value={riskForm.target_resolution_date} onChange={(e)=>setRiskForm((f)=>({...f,target_resolution_date:e.target.value}))}/></label><label>Resolved date<input type="date" value={riskForm.resolved_date} onChange={(e)=>setRiskForm((f)=>({...f,resolved_date:e.target.value}))}/></label><label className="wide">Description<textarea value={riskForm.description} onChange={(e)=>setRiskForm((f)=>({...f,description:e.target.value}))}/></label><label className="wide">Cause<textarea value={riskForm.cause} onChange={(e)=>setRiskForm((f)=>({...f,cause:e.target.value}))}/></label><label className="wide">Consequence<textarea value={riskForm.consequence} onChange={(e)=>setRiskForm((f)=>({...f,consequence:e.target.value}))}/></label><label className="wide">Response strategy<textarea value={riskForm.response_strategy} onChange={(e)=>setRiskForm((f)=>({...f,response_strategy:e.target.value}))}/></label><label className="wide">Mitigation plan<textarea value={riskForm.mitigation_plan} onChange={(e)=>setRiskForm((f)=>({...f,mitigation_plan:e.target.value}))}/></label><label className="wide">Contingency plan<textarea value={riskForm.contingency_plan} onChange={(e)=>setRiskForm((f)=>({...f,contingency_plan:e.target.value}))}/></label><label className="wide"><input type="checkbox" checked={riskForm.is_escalated} onChange={(e)=>setRiskForm((f)=>({...f,is_escalated:e.target.checked}))}/> Escalate this risk</label>
      </div><div className="commercial-form-note">Risk score is calculated by the configured database rule. It is not manually editable.</div><div className="commercial-form-actions"><button className="button-secondary small" onClick={()=>setRiskFormOpen(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={()=>void saveRisk()}>{busy?"Saving…":"Save risk"}</button></div></div>}
    </article>
    <article className="panel project-info-panel"><div className="project-panel-heading"><div><h3>License Register</h3><span>{licenses.length} licenses</span></div>{canManageProject&&<button className="button-secondary small" onClick={()=>startLicense()}><Plus size={12}/> Add license</button>}</div>
      {licenses.length?licenses.map((license)=><div className="project-compact-record" key={license.id}><div className="project-contract-top"><strong>{license.license_reference} · {license.license_name}</strong><div><span className="project-status-pill">{label(license.status)}</span>{canManageProject&&<button className="icon-button" onClick={()=>startLicense(license)} title="Edit license"><Pencil size={12}/></button>}</div></div><span>{label(license.license_type)} · {license.provider||"Provider not reported"}</span><span>Expiry {dateLabel(license.expiry_date)} · Renewal notice {dateLabel(license.renewal_notice_date)}</span><span>Quantity {license.quantity??"Not Reported"} {license.unit_of_measure||""} · Owner {memberName(license.owner_user_id)}</span>{license.renewal_cost!=null&&<span>Renewal cost {money(license.renewal_cost,license.currency_code)}</span>}</div>):<p className="project-empty-inline">License data is not reported.</p>}
      {licenseFormOpen&&<div className="operations-form"><div className="commercial-form-heading"><strong>{editingLicense?"Edit License":"Register License"}</strong><button className="icon-button" onClick={()=>setLicenseFormOpen(false)}>×</button></div><div className="operations-form-grid">
        <label>License reference<input disabled={Boolean(editingLicense)} value={licenseForm.license_reference} onChange={(e)=>setLicenseForm((f)=>({...f,license_reference:e.target.value.toUpperCase()}))}/></label><label>License name<input value={licenseForm.license_name} onChange={(e)=>setLicenseForm((f)=>({...f,license_name:e.target.value}))}/></label><label>Type<input value={licenseForm.license_type} onChange={(e)=>setLicenseForm((f)=>({...f,license_type:e.target.value}))}/></label><label>Provider<input value={licenseForm.provider} onChange={(e)=>setLicenseForm((f)=>({...f,provider:e.target.value}))}/></label><label>Quantity<input type="number" min="0" value={licenseForm.quantity} onChange={(e)=>setLicenseForm((f)=>({...f,quantity:e.target.value}))}/></label><label>Unit of measure<input value={licenseForm.unit_of_measure} onChange={(e)=>setLicenseForm((f)=>({...f,unit_of_measure:e.target.value}))}/></label><label>Start date<input type="date" value={licenseForm.start_date} onChange={(e)=>setLicenseForm((f)=>({...f,start_date:e.target.value}))}/></label><label>Expiry date<input type="date" value={licenseForm.expiry_date} onChange={(e)=>setLicenseForm((f)=>({...f,expiry_date:e.target.value}))}/></label><label>Renewal notice date<input type="date" value={licenseForm.renewal_notice_date} onChange={(e)=>setLicenseForm((f)=>({...f,renewal_notice_date:e.target.value}))}/></label><label>Renewal cost<input type="number" min="0" value={licenseForm.renewal_cost} onChange={(e)=>setLicenseForm((f)=>({...f,renewal_cost:e.target.value}))}/></label><label>Currency<input maxLength={3} value={licenseForm.currency_code} onChange={(e)=>setLicenseForm((f)=>({...f,currency_code:e.target.value.toUpperCase()}))}/></label><label>Owner<select value={licenseForm.owner_user_id} onChange={(e)=>setLicenseForm((f)=>({...f,owner_user_id:e.target.value}))}><option value="">Unassigned</option>{teamMembers.map((m)=><option key={m.user_id} value={m.user_id}>{m.display_name}</option>)}</select></label><label>Status<input value={licenseForm.status} onChange={(e)=>setLicenseForm((f)=>({...f,status:e.target.value}))} placeholder="Enter configured license status"/></label><label className="wide">Notes<textarea value={licenseForm.notes} onChange={(e)=>setLicenseForm((f)=>({...f,notes:e.target.value}))}/></label>
      </div><div className="commercial-form-actions"><button className="button-secondary small" onClick={()=>setLicenseFormOpen(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={()=>void saveLicense()}>{busy?"Saving…":"Save license"}</button></div></div>}
    </article>
  </div>;
}
