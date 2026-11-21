import { useState } from "react";
import { Pencil, Plus, ShieldAlert } from "lucide-react";
import { supabase } from "./lib/supabase";

type Risk = {
  id: string; risk_reference: string; title: string; description: string;
  probability_level: number; impact_level: number; risk_score: number | null;
  status: string; trend: string; is_escalated: boolean; mitigation_plan: string | null;
  owner_user_id: string | null; target_resolution_date: string | null;
  category?: string | null; cause?: string | null; consequence?: string | null;
  response_strategy?: string | null; contingency_plan?: string | null;
  identified_date?: string; review_date?: string | null;
};
type License = {
  id: string; license_reference: string; license_name: string; license_type: string | null;
  provider: string | null; expiry_date: string | null; renewal_notice_date: string | null;
  status: string; renewal_cost: number | null; currency_code: string | null;
  quantity?: number | null; unit_of_measure?: string | null; start_date?: string | null;
  owner_user_id?: string | null; notes?: string | null;
};
type Activity = {
  id: string; activity_code: string; name: string; workstream: string | null;
  baseline_start_date?: string | null; baseline_due_date: string | null;
  approved_revised_start_date?: string | null; approved_revised_due_date?: string | null;
  forecast_start_date?: string | null; forecast_due_date: string | null;
  actual_start_date?: string | null; actual_due_date: string | null;
  progress_percent: number; status: string; verification_status: string;
  description?: string | null; sequence_no?: number | null; weight?: number | null;
  assigned_to_user_id?: string | null; milestone_id?: string | null; notes?: string | null;
};
const dateValue = (value?: string | null) => value ?? "";
const nullable = (value: string) => value.trim() || null;
const displayDate = (value?: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(value + "T00:00:00")) : "Not reported";

export default function ProjectDeliveryEditor({ projectId, risks, licenses, activities, canManage, onSaved }: {
  projectId: string; risks: Risk[]; licenses: License[]; activities: Activity[];
  canManage: boolean; onSaved: () => Promise<void>;
}) {
  const [kind, setKind] = useState<"risk" | "license" | "activity">("risk");
  const [riskId, setRiskId] = useState<string | null>(null);
  const [licenseId, setLicenseId] = useState<string | null>(null);
  const [activityId, setActivityId] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [riskForm, setRiskForm] = useState({
    risk_reference: "", title: "", description: "", category: "", cause: "", consequence: "",
    probability_level: "1", impact_level: "1", response_strategy: "", mitigation_plan: "",
    contingency_plan: "", owner_user_id: "", identified_date: new Date().toISOString().slice(0, 10),
    review_date: "", target_resolution_date: "", status: "open", trend: "stable", is_escalated: false
  });
  const [licenseForm, setLicenseForm] = useState({
    license_reference: "", license_name: "", license_type: "", provider: "", quantity: "",
    unit_of_measure: "", start_date: "", expiry_date: "", renewal_notice_date: "",
    renewal_cost: "", currency_code: "", owner_user_id: "", status: "active", notes: ""
  });
  const [activityForm, setActivityForm] = useState({
    activity_code: "", name: "", description: "", workstream: "", sequence_no: "",
    weight: "", baseline_start_date: "", baseline_due_date: "", forecast_start_date: "",
    forecast_due_date: "", actual_start_date: "", actual_due_date: "", progress_percent: "0",
    status: "not_started", assigned_to_user_id: "", notes: ""
  });
  const reset = () => { setShowForm(false); setRiskId(null); setLicenseId(null); setActivityId(null); setError(""); };
  const beginRisk = (risk?: Risk) => {
    setKind("risk"); setRiskId(risk?.id ?? null); setLicenseId(null); setActivityId(null);
    setRiskForm(risk ? {
      risk_reference: risk.risk_reference, title: risk.title, description: risk.description,
      category: risk.category ?? "", cause: risk.cause ?? "", consequence: risk.consequence ?? "",
      probability_level: String(risk.probability_level), impact_level: String(risk.impact_level),
      response_strategy: risk.response_strategy ?? "", mitigation_plan: risk.mitigation_plan ?? "",
      contingency_plan: risk.contingency_plan ?? "", owner_user_id: risk.owner_user_id ?? "",
      identified_date: risk.identified_date ?? "", review_date: risk.review_date ?? "",
      target_resolution_date: risk.target_resolution_date ?? "", status: risk.status, trend: risk.trend,
      is_escalated: risk.is_escalated
    } : { risk_reference: "", title: "", description: "", category: "", cause: "", consequence: "", probability_level: "1", impact_level: "1", response_strategy: "", mitigation_plan: "", contingency_plan: "", owner_user_id: "", identified_date: new Date().toISOString().slice(0, 10), review_date: "", target_resolution_date: "", status: "open", trend: "stable", is_escalated: false });
    setError(""); setMessage(""); setShowForm(true);
  };
  const beginLicense = (license?: License) => {
    setKind("license"); setRiskId(null); setLicenseId(license?.id ?? null); setActivityId(null);
    setLicenseForm(license ? {
      license_reference: license.license_reference, license_name: license.license_name,
      license_type: license.license_type ?? "", provider: license.provider ?? "",
      quantity: license.quantity == null ? "" : String(license.quantity), unit_of_measure: license.unit_of_measure ?? "",
      start_date: dateValue(license.start_date), expiry_date: dateValue(license.expiry_date),
      renewal_notice_date: dateValue(license.renewal_notice_date), renewal_cost: license.renewal_cost == null ? "" : String(license.renewal_cost),
      currency_code: license.currency_code ?? "", owner_user_id: license.owner_user_id ?? "",
      status: license.status, notes: license.notes ?? ""
    } : { license_reference: "", license_name: "", license_type: "", provider: "", quantity: "", unit_of_measure: "", start_date: "", expiry_date: "", renewal_notice_date: "", renewal_cost: "", currency_code: "", owner_user_id: "", status: "active", notes: "" });
    setError(""); setMessage(""); setShowForm(true);
  };
  const beginActivity = (activity?: Activity) => {
    setKind("activity"); setRiskId(null); setLicenseId(null); setActivityId(activity?.id ?? null);
    setActivityForm(activity ? {
      activity_code: activity.activity_code, name: activity.name, description: activity.description ?? "",
      workstream: activity.workstream ?? "", sequence_no: activity.sequence_no == null ? "" : String(activity.sequence_no),
      weight: activity.weight == null ? "" : String(activity.weight), baseline_start_date: dateValue(activity.baseline_start_date),
      baseline_due_date: dateValue(activity.baseline_due_date), forecast_start_date: dateValue(activity.forecast_start_date),
      forecast_due_date: dateValue(activity.forecast_due_date), actual_start_date: dateValue(activity.actual_start_date),
      actual_due_date: dateValue(activity.actual_due_date), progress_percent: String(activity.progress_percent),
      status: activity.status, assigned_to_user_id: activity.assigned_to_user_id ?? "", notes: activity.notes ?? ""
    } : { activity_code: "", name: "", description: "", workstream: "", sequence_no: "", weight: "", baseline_start_date: "", baseline_due_date: "", forecast_start_date: "", forecast_due_date: "", actual_start_date: "", actual_due_date: "", progress_percent: "0", status: "not_started", assigned_to_user_id: "", notes: "" });
    setError(""); setMessage(""); setShowForm(true);
  };
  const save = async () => {
    if (!supabase || !canManage) return;
    setBusy(true); setError(""); setMessage("");
    let result: { error: { message: string } | null } | null = null;
    if (kind === "risk") {
      const probability = Number(riskForm.probability_level), impact = Number(riskForm.impact_level);
      if (!riskForm.risk_reference.trim() || !riskForm.title.trim() || !riskForm.description.trim()) { setError("Risk reference, title and description are required."); setBusy(false); return; }
      if (!Number.isFinite(probability) || probability <= 0 || !Number.isFinite(impact) || impact <= 0) { setError("Probability and impact must be positive numbers."); setBusy(false); return; }
      const payload = {
        project_id: projectId, risk_reference: riskForm.risk_reference.trim(), title: riskForm.title.trim(),
        description: riskForm.description.trim(), category: nullable(riskForm.category), cause: nullable(riskForm.cause),
        consequence: nullable(riskForm.consequence), probability_level: probability, impact_level: impact,
        response_strategy: nullable(riskForm.response_strategy), mitigation_plan: nullable(riskForm.mitigation_plan),
        contingency_plan: nullable(riskForm.contingency_plan), owner_user_id: riskForm.owner_user_id || null,
        identified_date: riskForm.identified_date || new Date().toISOString().slice(0, 10),
        review_date: riskForm.review_date || null, target_resolution_date: riskForm.target_resolution_date || null,
        status: riskForm.status.trim(), trend: riskForm.trend, is_escalated: riskForm.is_escalated
      };
      result = riskId ? await supabase.from("project_risks").update(payload).eq("id", riskId) : await supabase.from("project_risks").insert(payload);
    } else if (kind === "license") {
      if (!licenseForm.license_reference.trim() || !licenseForm.license_name.trim()) { setError("License reference and name are required."); setBusy(false); return; }
      if (licenseForm.start_date && licenseForm.expiry_date && licenseForm.expiry_date < licenseForm.start_date) { setError("License expiry cannot precede its start date."); setBusy(false); return; }
      if (licenseForm.renewal_cost && Number(licenseForm.renewal_cost) < 0) { setError("Renewal cost cannot be negative."); setBusy(false); return; }
      if (licenseForm.renewal_cost && !/^[A-Z]{3}$/.test(licenseForm.currency_code.trim().toUpperCase())) { setError("Enter a three-letter currency code for the renewal cost."); setBusy(false); return; }
      const payload = {
        project_id: projectId, license_reference: licenseForm.license_reference.trim(), license_name: licenseForm.license_name.trim(),
        license_type: nullable(licenseForm.license_type), provider: nullable(licenseForm.provider),
        quantity: licenseForm.quantity ? Number(licenseForm.quantity) : null, unit_of_measure: nullable(licenseForm.unit_of_measure),
        start_date: licenseForm.start_date || null, expiry_date: licenseForm.expiry_date || null,
        renewal_notice_date: licenseForm.renewal_notice_date || null, renewal_cost: licenseForm.renewal_cost ? Number(licenseForm.renewal_cost) : null,
        currency_code: licenseForm.currency_code.trim().toUpperCase() || null, owner_user_id: licenseForm.owner_user_id || null,
        status: licenseForm.status.trim(), notes: nullable(licenseForm.notes)
      };
      result = licenseId ? await supabase.from("project_licenses").update(payload).eq("id", licenseId) : await supabase.from("project_licenses").insert(payload);
    } else {
      const progress = Number(activityForm.progress_percent);
      if (!activityForm.activity_code.trim() || !activityForm.name.trim()) { setError("Activity code and name are required."); setBusy(false); return; }
      if (!Number.isFinite(progress) || progress < 0 || progress > 100) { setError("Progress must be between 0 and 100."); setBusy(false); return; }
      if (activityForm.baseline_start_date && activityForm.baseline_due_date && activityForm.baseline_due_date < activityForm.baseline_start_date) { setError("Baseline due date cannot precede baseline start date."); setBusy(false); return; }
      if (activityForm.forecast_start_date && activityForm.forecast_due_date && activityForm.forecast_due_date < activityForm.forecast_start_date) { setError("Forecast due date cannot precede forecast start date."); setBusy(false); return; }
      if (activityForm.actual_start_date && activityForm.actual_due_date && activityForm.actual_due_date < activityForm.actual_start_date) { setError("Actual due date cannot precede actual start date."); setBusy(false); return; }
      if (activityForm.weight && (Number(activityForm.weight) < 0 || Number(activityForm.weight) > 1)) { setError("Activity weight must be between 0 and 1."); setBusy(false); return; }
      const payload: Record<string, unknown> = {
        project_id: projectId, activity_code: activityForm.activity_code.trim(), name: activityForm.name.trim(),
        description: nullable(activityForm.description), workstream: nullable(activityForm.workstream),
        sequence_no: activityForm.sequence_no ? Number(activityForm.sequence_no) : null,
        weight: activityForm.weight ? Number(activityForm.weight) : null,
        forecast_start_date: activityForm.forecast_start_date || null, forecast_due_date: activityForm.forecast_due_date || null,
        actual_start_date: activityForm.actual_start_date || null, actual_due_date: activityForm.actual_due_date || null,
        progress_percent: progress, status: activityForm.status.trim(), assigned_to_user_id: activityForm.assigned_to_user_id || null,
        notes: nullable(activityForm.notes)
      };
      if (!activityId) {
        payload.baseline_start_date = activityForm.baseline_start_date || null;
        payload.baseline_due_date = activityForm.baseline_due_date || null;
      }
      result = activityId
        ? await supabase.from("project_activities").update(payload).eq("id", activityId)
        : await supabase.from("project_activities").insert(payload);
    }
    if (result?.error) { setError(result.error.message); setBusy(false); return; }
    setMessage("Record saved. Database audit and history triggers captured the change.");
    setShowForm(false); setBusy(false);
    await onSaved();
  };

  return <div className="project-delivery-editor">
    <div className="project-delivery-tabs">
      <button className={kind === "risk" ? "active" : ""} onClick={() => { setKind("risk"); reset(); }}>Risks ({risks.length})</button>
      <button className={kind === "license" ? "active" : ""} onClick={() => { setKind("license"); reset(); }}>Licenses ({licenses.length})</button>
      <button className={kind === "activity" ? "active" : ""} onClick={() => { setKind("activity"); reset(); }}>Activities ({activities.length})</button>
    </div>
    {message && <div className="project-create-success">{message}</div>}
    {error && <div className="module-error"><ShieldAlert size={16}/>{error}</div>}
    {canManage && <div className="project-delivery-actions"><button className="button-primary small" onClick={() => kind === "risk" ? beginRisk() : kind === "license" ? beginLicense() : beginActivity()}><Plus size={13}/> Add {kind}</button></div>}
    {showForm && <section className="panel project-create-form">
      <div className="project-panel-heading"><h3>{riskId || licenseId || activityId ? "Update" : "New"} {kind}</h3><span>Changes are recorded in the project audit history</span></div>
      {kind === "risk" && <div className="project-create-grid">
        <label>Risk reference<input value={riskForm.risk_reference} onChange={e => setRiskForm(f => ({...f,risk_reference:e.target.value}))}/></label>
        <label>Title<input value={riskForm.title} onChange={e => setRiskForm(f => ({...f,title:e.target.value}))}/></label>
        <label className="wide">Description<textarea value={riskForm.description} onChange={e => setRiskForm(f => ({...f,description:e.target.value}))}/></label>
        <label>Category<input value={riskForm.category} onChange={e => setRiskForm(f => ({...f,category:e.target.value}))}/></label>
        <label>Cause<input value={riskForm.cause} onChange={e => setRiskForm(f => ({...f,cause:e.target.value}))}/></label>
        <label>Consequence<input value={riskForm.consequence} onChange={e => setRiskForm(f => ({...f,consequence:e.target.value}))}/></label>
        <label>Probability level<input type="number" min="1" value={riskForm.probability_level} onChange={e => setRiskForm(f => ({...f,probability_level:e.target.value}))}/></label>
        <label>Impact level<input type="number" min="1" value={riskForm.impact_level} onChange={e => setRiskForm(f => ({...f,impact_level:e.target.value}))}/></label>
        <label>Response strategy<input value={riskForm.response_strategy} onChange={e => setRiskForm(f => ({...f,response_strategy:e.target.value}))}/></label>
        <label className="wide">Mitigation plan<textarea value={riskForm.mitigation_plan} onChange={e => setRiskForm(f => ({...f,mitigation_plan:e.target.value}))}/></label>
        <label className="wide">Contingency plan<textarea value={riskForm.contingency_plan} onChange={e => setRiskForm(f => ({...f,contingency_plan:e.target.value}))}/></label>
        <label>Owner user ID<input value={riskForm.owner_user_id} onChange={e => setRiskForm(f => ({...f,owner_user_id:e.target.value}))} placeholder="UUID (optional)"/></label>
        <label>Status<input value={riskForm.status} onChange={e => setRiskForm(f => ({...f,status:e.target.value}))}/></label>
        <label>Trend<select value={riskForm.trend} onChange={e => setRiskForm(f => ({...f,trend:e.target.value}))}><option value="increasing">Increasing</option><option value="stable">Stable</option><option value="decreasing">Decreasing</option></select></label>
        <label>Identified date<input type="date" value={riskForm.identified_date} onChange={e => setRiskForm(f => ({...f,identified_date:e.target.value}))}/></label>
        <label>Review date<input type="date" value={riskForm.review_date} onChange={e => setRiskForm(f => ({...f,review_date:e.target.value}))}/></label>
        <label>Target resolution<input type="date" value={riskForm.target_resolution_date} onChange={e => setRiskForm(f => ({...f,target_resolution_date:e.target.value}))}/></label>
        <label className="wide"><span><input type="checkbox" checked={riskForm.is_escalated} onChange={e => setRiskForm(f => ({...f,is_escalated:e.target.checked}))}/> Escalated to management</span></label>
      </div>}
      {kind === "license" && <div className="project-create-grid">
        <label>License reference<input value={licenseForm.license_reference} onChange={e => setLicenseForm(f => ({...f,license_reference:e.target.value}))}/></label>
        <label>License name<input value={licenseForm.license_name} onChange={e => setLicenseForm(f => ({...f,license_name:e.target.value}))}/></label>
        <label>License type<input value={licenseForm.license_type} onChange={e => setLicenseForm(f => ({...f,license_type:e.target.value}))}/></label>
        <label>Provider<input value={licenseForm.provider} onChange={e => setLicenseForm(f => ({...f,provider:e.target.value}))}/></label>
        <label>Quantity<input type="number" min="0" value={licenseForm.quantity} onChange={e => setLicenseForm(f => ({...f,quantity:e.target.value}))}/></label>
        <label>Unit of measure<input value={licenseForm.unit_of_measure} onChange={e => setLicenseForm(f => ({...f,unit_of_measure:e.target.value}))}/></label>
        <label>Start date<input type="date" value={licenseForm.start_date} onChange={e => setLicenseForm(f => ({...f,start_date:e.target.value}))}/></label>
        <label>Expiry date<input type="date" value={licenseForm.expiry_date} onChange={e => setLicenseForm(f => ({...f,expiry_date:e.target.value}))}/></label>
        <label>Renewal notice date<input type="date" value={licenseForm.renewal_notice_date} onChange={e => setLicenseForm(f => ({...f,renewal_notice_date:e.target.value}))}/></label>
        <label>Renewal cost<input type="number" min="0" value={licenseForm.renewal_cost} onChange={e => setLicenseForm(f => ({...f,renewal_cost:e.target.value}))}/></label>
        <label>Currency code<input maxLength={3} value={licenseForm.currency_code} onChange={e => setLicenseForm(f => ({...f,currency_code:e.target.value.toUpperCase()}))}/></label>
        <label>Owner user ID<input value={licenseForm.owner_user_id} onChange={e => setLicenseForm(f => ({...f,owner_user_id:e.target.value}))} placeholder="UUID (optional)"/></label>
        <label>Status<input value={licenseForm.status} onChange={e => setLicenseForm(f => ({...f,status:e.target.value}))}/></label>
        <label className="wide">Notes<textarea value={licenseForm.notes} onChange={e => setLicenseForm(f => ({...f,notes:e.target.value}))}/></label>
      </div>}
      {kind === "activity" && <div className="project-create-grid">
        <label>Activity code<input value={activityForm.activity_code} onChange={e => setActivityForm(f => ({...f,activity_code:e.target.value}))}/></label>
        <label>Activity name<input value={activityForm.name} onChange={e => setActivityForm(f => ({...f,name:e.target.value}))}/></label>
        <label>Workstream<input value={activityForm.workstream} onChange={e => setActivityForm(f => ({...f,workstream:e.target.value}))}/></label>
        <label>Sequence<input type="number" value={activityForm.sequence_no} onChange={e => setActivityForm(f => ({...f,sequence_no:e.target.value}))}/></label>
        <label className="wide">Description<textarea value={activityForm.description} onChange={e => setActivityForm(f => ({...f,description:e.target.value}))}/></label>
        <label>Baseline start<input type="date" disabled={Boolean(activityId)} value={activityForm.baseline_start_date} onChange={e => setActivityForm(f => ({...f,baseline_start_date:e.target.value}))}/></label>
        <label>Baseline due<input type="date" disabled={Boolean(activityId)} value={activityForm.baseline_due_date} onChange={e => setActivityForm(f => ({...f,baseline_due_date:e.target.value}))}/></label>
        <label>Forecast start<input type="date" value={activityForm.forecast_start_date} onChange={e => setActivityForm(f => ({...f,forecast_start_date:e.target.value}))}/></label>
        <label>Forecast due<input type="date" value={activityForm.forecast_due_date} onChange={e => setActivityForm(f => ({...f,forecast_due_date:e.target.value}))}/></label>
        <label>Actual start<input type="date" value={activityForm.actual_start_date} onChange={e => setActivityForm(f => ({...f,actual_start_date:e.target.value}))}/></label>
        <label>Actual due<input type="date" value={activityForm.actual_due_date} onChange={e => setActivityForm(f => ({...f,actual_due_date:e.target.value}))}/></label>
        <label>Weight (0–1)<input type="number" min="0" max="1" step="0.01" value={activityForm.weight} onChange={e => setActivityForm(f => ({...f,weight:e.target.value}))}/></label>
        <label>Progress %<input type="number" min="0" max="100" value={activityForm.progress_percent} onChange={e => setActivityForm(f => ({...f,progress_percent:e.target.value}))}/></label>
        <label>Status<input value={activityForm.status} onChange={e => setActivityForm(f => ({...f,status:e.target.value}))}/></label>
        <label>Assigned user ID<input value={activityForm.assigned_to_user_id} onChange={e => setActivityForm(f => ({...f,assigned_to_user_id:e.target.value}))} placeholder="UUID (optional)"/></label>
        <label className="wide">Notes<textarea value={activityForm.notes} onChange={e => setActivityForm(f => ({...f,notes:e.target.value}))}/></label>
        {activityId && <p className="project-empty-inline wide">Baseline dates are immutable after creation. Use the governed rebaseline workflow for approved baseline changes.</p>}
      </div>}
      <div className="commercial-form-actions"><button className="button-secondary small" onClick={reset}>Cancel</button><button className="button-primary small" disabled={busy} onClick={() => void save()}>{busy ? "Saving…" : "Save record"}</button></div>
    </section>}
    {kind === "risk" && <div className="project-record-list">{risks.length ? risks.map(risk => <article className="project-info-panel" key={risk.id}><div className="project-panel-heading"><h3>{risk.risk_reference} · {risk.title}</h3><span>{risk.status} · {risk.trend}</span></div><p>{risk.description}</p><div className="project-inline-meta"><span>Probability {risk.probability_level}</span><span>Impact {risk.impact_level}</span><span>Calculated score {risk.risk_score ?? "Not reported"}</span><span>Target {displayDate(risk.target_resolution_date)}</span><span>{risk.is_escalated ? "Escalated" : "Not escalated"}</span></div>{risk.mitigation_plan && <p>Mitigation: {risk.mitigation_plan}</p>}{canManage && <button className="button-secondary small" onClick={() => beginRisk(risk)}><Pencil size={13}/> Edit risk</button>}</article>) : <p className="project-empty-inline">No risk records have been reported.</p>}</div>}
    {kind === "license" && <div className="project-record-list">{licenses.length ? licenses.map(license => <article className="project-info-panel" key={license.id}><div className="project-panel-heading"><h3>{license.license_reference} · {license.license_name}</h3><span>{license.status} · {license.provider || "Provider not reported"}</span></div><div className="project-inline-meta"><span>Expiry {displayDate(license.expiry_date)}</span><span>Renewal notice {displayDate(license.renewal_notice_date)}</span><span>Renewal cost {license.renewal_cost == null ? "Not reported" : license.renewal_cost + " " + (license.currency_code ?? "")}</span></div>{canManage && <button className="button-secondary small" onClick={() => beginLicense(license)}><Pencil size={13}/> Edit license</button>}</article>) : <p className="project-empty-inline">No license records have been reported.</p>}</div>}
    {kind === "activity" && <div className="project-record-list">{activities.length ? activities.map(activity => <article className="project-info-panel" key={activity.id}><div className="project-panel-heading"><h3>{activity.activity_code} · {activity.name}</h3><span>{activity.status} · {activity.progress_percent}%</span></div><div className="project-inline-meta"><span>Baseline {displayDate(activity.baseline_due_date)}</span><span>Forecast {displayDate(activity.forecast_due_date)}</span><span>Actual {displayDate(activity.actual_due_date)}</span><span>Verification {activity.verification_status}</span></div>{canManage && <button className="button-secondary small" onClick={() => beginActivity(activity)}><Pencil size={13}/> Edit activity</button>}</article>) : <p className="project-empty-inline">No activity records have been reported.</p>}</div>}
  </div>;
}
