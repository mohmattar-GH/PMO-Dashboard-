import { useCallback, useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import { AlertCircle, CheckCircle2, FilePlus2, LoaderCircle, Search, ShieldCheck, X } from "lucide-react";
import { supabase } from "./lib/supabase";

type Project = { id: string; project_code: string; name: string };
type Contract = { id: string; project_id: string; contract_reference: string; contract_title: string; currency_code: string | null; status: string };
type Variation = { id: string; variation_reference: string; title: string; amount_delta: number; currency_code: string; status: string; effective_date: string | null };
type Member = { project_id: string; user_id: string; display_name: string; project_role: string };
type WorkflowVersion = { id: string; version_no: number; template_id: string; template_name: string; project_id: string | null; is_global: boolean };
type CR = {
  id: string; project_id: string; cr_reference: string; title: string; description: string;
  justification: string; request_type: string | null; category: string | null; priority: string | null;
  status: string; workflow_version_id: string | null; contract_id: string | null; contract_variation_id: string | null; requested_by: string; assigned_to: string | null;
  submitted_at: string | null; decided_at: string | null; decision_reason: string | null;
  implementation_owner_id: string | null; implementation_due_date: string | null;
  implementation_status: string | null; verified_at: string | null; closed_at: string | null; created_at: string;
};
type ImpactDimension = { id: string; dimension_code: string; dimension_label: string; is_required: boolean };
type Impact = { id?: string; impact_dimension: string; assessment_status: "not_assessed" | "assessed" | "not_applicable"; impact_summary: string | null; schedule_impact_days: number | null; cost_delta?: number | null; currency_code?: string | null; not_applicable_reason: string | null };
type History = { id: string; event_code: string; from_status: string | null; to_status: string | null; actor_user_id: string | null; event_reason: string | null; created_at: string };

const label = (value: string) => value.replace(/_/g, " ").replace(/\b\w/g, (s) => s.toUpperCase());
const dateTime = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : "Not recorded";
const statusTone = (status: string) => ["accepted", "implemented", "verified", "closed"].includes(status) ? "success" : ["rejected"].includes(status) ? "danger" : ["submitted", "in_implementation"].includes(status) ? "warning" : "neutral";

export default function ChangeRequests({ canManage }: { canManage: boolean }) {
  const [projects, setProjects] = useState<Project[]>([]);
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [variation, setVariation] = useState<Variation | null>(null);
  const [members, setMembers] = useState<Member[]>([]);
  const [versions, setVersions] = useState<WorkflowVersion[]>([]);
  const [records, setRecords] = useState<CR[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [projectFilter, setProjectFilter] = useState("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [dimensions, setDimensions] = useState<ImpactDimension[]>([]);
  const [impacts, setImpacts] = useState<Impact[]>([]);
  const [history, setHistory] = useState<History[]>([]);
  const [detailLoading, setDetailLoading] = useState(false);
  const [currentUserId, setCurrentUserId] = useState("");
  const [showCreate, setShowCreate] = useState(false);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");
  const [decisionReason, setDecisionReason] = useState("");
  const [submitReason, setSubmitReason] = useState("");
  const [form, setForm] = useState({ project_id: "", contract_id: "", title: "", description: "", justification: "", priority: "medium", assigned_to: "", workflow_version_id: "" });

  const loadRegister = useCallback(async () => {
    if (!supabase) { setError("Supabase is not configured."); setLoading(false); return; }
    setLoading(true); setError("");
    const [{ data: userData }, projectResult, crResult, memberResult, templateResult, contractResult] = await Promise.all([
      supabase.auth.getUser(),
      supabase.from("projects").select("id,project_code,name").order("project_code"),
      supabase.from("project_change_requests").select("id,project_id,cr_reference,title,description,justification,request_type,category,priority,status,workflow_version_id,contract_id,contract_variation_id,requested_by,assigned_to,submitted_at,decided_at,decision_reason,implementation_owner_id,implementation_due_date,implementation_status,verified_at,closed_at,created_at").order("created_at", { ascending: false }),
      supabase.from("project_memberships").select("project_id,user_id,project_role").eq("project_role", "project_manager").eq("status", "active").lte("effective_from", new Date().toISOString()).or(`effective_to.is.null,effective_to.gt.${new Date().toISOString()}`),
      supabase.from("ppm_workflow_templates").select("id,template_name,project_id,is_global").eq("module_code", "change_request").eq("is_active", true),
      supabase.from("project_contracts").select("id,project_id,contract_reference,contract_title,currency_code,status").order("contract_reference")
    ]);
    if (projectResult.error || crResult.error) {
      setError(projectResult.error?.message || crResult.error?.message || "Unable to load Change Requests.");
      setLoading(false); return;
    }
    setCurrentUserId(userData.user?.id ?? "");
    const projectRows = (projectResult.data ?? []) as Project[];
    setProjects(projectRows);
    setRecords((crResult.data ?? []) as CR[]);
    setContracts((contractResult.data ?? []) as Contract[]);
    const rawMembers = (memberResult.data ?? []) as Omit<Member, "display_name">[];
    const memberIds = [...new Set(rawMembers.map((m) => m.user_id))];
    const profileResult = memberIds.length ? await supabase.from("user_profiles").select("user_id,display_name").in("user_id", memberIds) : { data: [], error: null };
    const names = new Map((profileResult.data ?? []).map((p: { user_id: string; display_name: string | null }) => [p.user_id, p.display_name || p.user_id.slice(0, 8)]));
    setMembers(rawMembers.map((m) => ({ ...m, display_name: names.get(m.user_id) ?? m.user_id.slice(0, 8) })));
    const templateRows = templateResult.data ?? [];
    const templateIds = templateRows.map((t: { id: string }) => t.id);
    if (templateIds.length) {
      const versionResult = await supabase.from("ppm_workflow_template_versions").select("id,version_no,template_id").in("template_id", templateIds).eq("status", "published").lte("effective_from", new Date().toISOString()).or(`effective_to.is.null,effective_to.gt.${new Date().toISOString()}`).order("version_no", { ascending: false });
      const templateNames = new Map(templateRows.map((t: { id: string; template_name: string }) => [t.id, t.template_name]));
      setVersions((versionResult.data ?? []).map((v: { id: string; version_no: number; template_id: string }) => { const t = templateRows.find((item: { id: string }) => item.id === v.template_id) as { project_id: string | null; is_global: boolean } | undefined; return { ...v, template_name: templateNames.get(v.template_id) ?? "Impact configuration", project_id: t?.project_id ?? null, is_global: t?.is_global ?? false }; }));
    } else setVersions([]);
    setLoading(false);
  }, []);

  useEffect(() => { void loadRegister(); }, [loadRegister]);

  const selected = records.find((r) => r.id === selectedId) ?? null;
  const projectName = (id: string) => projects.find((p) => p.id === id)?.name ?? "Project";
  const membersFor = (projectId: string) => members.filter((m) => m.project_id === projectId);
  const canDecide = Boolean(selected && selected.status === "submitted" && selected.assigned_to === currentUserId && selected.requested_by !== currentUserId && membersFor(selected.project_id).some((m) => m.user_id === currentUserId));
  const filtered = useMemo(() => records.filter((r) =>
    (statusFilter === "all" || r.status === statusFilter) &&
    (projectFilter === "all" || r.project_id === projectFilter) &&
    [r.cr_reference, r.title, projectName(r.project_id)].join(" ").toLowerCase().includes(query.trim().toLowerCase())
  ), [records, statusFilter, projectFilter, query, projects]);

  const loadDetail = useCallback(async (record: CR) => {
    if (!supabase) return;
    setSelectedId(record.id); setDetailLoading(true); setDecisionReason(""); setSubmitReason(""); setVariation(null);
    const [dimensionResult, impactResult, historyResult, variationResult] = await Promise.all([
      record.workflow_version_id ? supabase.from("ppm_workflow_impact_dimensions").select("id,dimension_code,dimension_label,is_required").eq("workflow_version_id", record.workflow_version_id).order("sequence_no") : Promise.resolve({ data: [], error: null }),
      supabase.from("project_change_request_impacts").select("id,impact_dimension,assessment_status,impact_summary,schedule_impact_days,not_applicable_reason,cost_delta,currency_code").eq("change_request_id", record.id),
      supabase.from("project_change_request_history").select("id,event_code,from_status,to_status,actor_user_id,event_reason,created_at").eq("change_request_id", record.id).order("created_at", { ascending: false }),
      record.contract_variation_id ? supabase.from("project_contract_variations").select("id,variation_reference,title,amount_delta,currency_code,status,effective_date").eq("id", record.contract_variation_id).maybeSingle() : Promise.resolve({ data: null, error: null })
    ]);
    if (dimensionResult.error) setNotice("Impact configuration could not be loaded: " + dimensionResult.error.message);
    else setDimensions((dimensionResult.data ?? []) as ImpactDimension[]);
    if (impactResult.error) setNotice("Impact details are not available to this role: " + impactResult.error.message);
    else setImpacts((impactResult.data ?? []) as Impact[]);
    setHistory((historyResult.data ?? []) as History[]);
    setVariation((variationResult.data ?? null) as Variation | null);
    setDetailLoading(false);
  }, []);

  const saveImpact = async (dimension: ImpactDimension, patch: Partial<Impact>) => {
    if (!supabase || !selected || selected.status !== "draft") return;
    const existing = impacts.find((i) => i.impact_dimension === dimension.dimension_code);
    const next: Impact = {
      impact_dimension: dimension.dimension_code,
      assessment_status: patch.assessment_status ?? existing?.assessment_status ?? "not_assessed",
      impact_summary: patch.impact_summary ?? existing?.impact_summary ?? "",
      schedule_impact_days: patch.schedule_impact_days ?? existing?.schedule_impact_days ?? null,
      cost_delta: patch.cost_delta !== undefined ? patch.cost_delta : existing?.cost_delta ?? null,
      currency_code: patch.currency_code !== undefined ? patch.currency_code : existing?.currency_code ?? null,
      not_applicable_reason: patch.not_applicable_reason ?? existing?.not_applicable_reason ?? null,
      ...(patch.cost_delta !== undefined ? { cost_delta: patch.cost_delta } : existing?.cost_delta !== undefined ? { cost_delta: existing.cost_delta } : {}),
      ...(patch.currency_code !== undefined ? { currency_code: patch.currency_code } : existing?.currency_code ? { currency_code: existing.currency_code } : {})
    };
    setImpacts((current) => [...current.filter((i) => i.impact_dimension !== dimension.dimension_code), next]);
    const { data: user } = await supabase.auth.getUser();
    const { error: saveError } = await supabase.from("project_change_request_impacts").upsert({
      change_request_id: selected.id, project_id: selected.project_id, ...next,
      assessed_by: next.assessment_status === "assessed" ? user.user?.id : null,
      assessed_at: next.assessment_status === "assessed" ? new Date().toISOString() : null
    }, { onConflict: "change_request_id,impact_dimension" });
    if (saveError) setNotice("Assessment was not saved: " + saveError.message);
    else setNotice("Impact assessment saved.");
  };

  const createCR = async (event: FormEvent) => {
    event.preventDefault(); if (!supabase) return;
    setBusy(true); setNotice("");
    const { data: user } = await supabase.auth.getUser();
    const reference = `CR-${new Date().getFullYear()}-${Date.now().toString().slice(-6)}`;
    const { data, error: createError } = await supabase.from("project_change_requests").insert({
      project_id: form.project_id, cr_reference: reference, title: form.title.trim(),
      description: form.description.trim(), justification: form.justification.trim(),
      priority: form.priority, contract_id: form.contract_id || null, requested_by: user.user?.id, assigned_to: form.assigned_to,
      workflow_version_id: form.workflow_version_id, status: "draft"
    }).select("id").single();
    if (createError) setNotice("Could not create the Change Request: " + createError.message);
    else { setShowCreate(false); setForm({ project_id: "", contract_id: "", title: "", description: "", justification: "", priority: "medium", assigned_to: "", workflow_version_id: "" }); await loadRegister(); setNotice("Draft Change Request created."); if (data?.id) setSelectedId(data.id); }
    setBusy(false);
  };

  const createLinkedVariation = async () => {
    if (!supabase || !selected || selected.status !== "draft") return;
    if (!selected.contract_id) { setNotice("Select a contract on the draft Change Request first."); return; }
    setBusy(true); setNotice("");
    const { data, error: variationError } = await supabase.rpc("create_change_request_contract_variation", { p_change_request_id: selected.id });
    if (variationError) setNotice("Linked contract variation was not created: " + variationError.message);
    else { setNotice("Linked contract variation created. Its approval follows the PM-only Change Request decision."); await loadRegister(); await loadDetail({ ...selected, contract_variation_id: (data as { contract_variation_id?: string } | null)?.contract_variation_id ?? selected.contract_variation_id }); }
    setBusy(false);
  };

  const submitCR = async () => {
    if (!supabase || !selected) return;
    setBusy(true); setNotice("");
    const { error: submitError } = await supabase.rpc("submit_project_change_request", { p_change_request_id: selected.id, p_reason: submitReason.trim() || null });
    if (submitError) setNotice(submitError.message);
    else { setNotice("Change Request submitted to its assigned Project Manager."); await loadRegister(); const updated = { ...selected, status: "submitted" }; await loadDetail(updated); }
    setBusy(false);
  };

  const decideCR = async (decision: "accept" | "reject") => {
    if (!supabase || !selected) return;
    if (decisionReason.trim().length < 8) { setNotice("Enter a decision reason of at least 8 characters."); return; }
    setBusy(true); setNotice("");
    const { error: decisionError } = await supabase.rpc("decide_project_change_request", { p_change_request_id: selected.id, p_decision: decision, p_reason: decisionReason.trim() });
    if (decisionError) setNotice(decisionError.message);
    else { setNotice(`Your ${decision} decision has been recorded.`); await loadRegister(); await loadDetail({ ...selected, status: decision === "accept" ? "accepted" : "rejected" }); }
    setBusy(false);
  };

  const refreshSelected = () => { if (selected) void loadDetail(selected); };
  const assignedPM = selected?.assigned_to ? members.find((m) => m.user_id === selected.assigned_to && m.project_id === selected.project_id)?.display_name ?? selected.assigned_to.slice(0, 8) : "Not assigned";

  return <div className="cr-module">
    <div className="cr-register-toolbar">
      <div className="cr-search"><Search size={15}/><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search reference, title or project"/></div>
      <select value={projectFilter} onChange={(e) => setProjectFilter(e.target.value)}><option value="all">All projects</option>{projects.map((p) => <option key={p.id} value={p.id}>{p.project_code} · {p.name}</option>)}</select>
      <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}><option value="all">All statuses</option>{["draft","submitted","accepted","rejected","in_implementation","implemented","verified","closed"].map((s) => <option key={s} value={s}>{label(s)}</option>)}</select>
      <span className="cr-toolbar-spacer"/>
      {canManage && <button className="button-primary" onClick={() => setShowCreate(true)}><FilePlus2 size={15}/> New Change Request</button>}
    </div>

    <div className="cr-summary-row">
      {[["Open", records.filter((r) => ["draft","submitted","accepted","in_implementation","implemented","verified"].includes(r.status)).length],["Awaiting PM decision", records.filter((r) => r.status === "submitted").length],["Accepted", records.filter((r) => r.status === "accepted").length],["Rejected", records.filter((r) => r.status === "rejected").length]].map(([name, count]) => <article key={String(name)}><span>{name}</span><strong>{loading ? "—" : count}</strong></article>)}
    </div>

    {error && <div className="cr-message error"><AlertCircle size={16}/>{error}</div>}
    {notice && <div className="cr-message"><CheckCircle2 size={16}/><span>{notice}</span><button onClick={() => setNotice("")} aria-label="Dismiss"><X size={14}/></button></div>}

    <div className="cr-content-grid">
      <section className="panel cr-register-panel">
        <div className="panel-heading"><div><h3>Change Request Register</h3><span className="panel-subtitle">Project-scoped records · visibility enforced by Supabase RLS</span></div><span className="cr-count">{loading ? "Loading…" : `${filtered.length} records`}</span></div>
        {loading ? <div className="cr-empty"><LoaderCircle className="spin" size={20}/> Loading Change Requests…</div> :
          filtered.length === 0 ? <div className="cr-empty"><FilePlus2 size={22}/><strong>No Change Requests found</strong><span>No records match the selected filters or are visible to this account.</span></div> :
          <div className="cr-list">{filtered.map((record) => <button key={record.id} className={selectedId === record.id ? "cr-list-row selected" : "cr-list-row"} onClick={() => void loadDetail(record)}>
            <span className="cr-list-main"><strong>{record.cr_reference} · {record.title}</strong><small>{projectName(record.project_id)} · PM: {members.find((m) => m.user_id === record.assigned_to && m.project_id === record.project_id)?.display_name ?? "Unassigned"}</small></span>
            <span className={`cr-status ${statusTone(record.status)}`}>{label(record.status)}</span>
            <small className="cr-date">{dateTime(record.submitted_at ?? record.created_at)}</small>
          </button>)}</div>}
      </section>

      <section className="panel cr-detail-panel">
        {!selected ? <div className="cr-empty cr-detail-empty"><ShieldCheck size={26}/><strong>Change Request workspace</strong><span>Select a record to review its impact assessment, PM decision and audit history.</span></div> :
          detailLoading ? <div className="cr-empty"><LoaderCircle className="spin" size={20}/> Loading record…</div> :
          <div className="cr-detail">
            <div className="cr-detail-header"><div><span className="cr-reference">{selected.cr_reference}</span><span className={`cr-status ${statusTone(selected.status)}`}>{label(selected.status)}</span><h2>{selected.title}</h2><p>{projectName(selected.project_id)} · Assigned PM: {assignedPM}</p></div><button className="icon-button" onClick={() => setSelectedId(null)} aria-label="Close detail"><X size={17}/></button></div>
            <div className="cr-lifecycle">{["Draft","Submitted","PM decision","Implementation","Verification","Closed"].map((stage, index) => {
              const current = selected.status === "draft" ? 0 : selected.status === "submitted" ? 1 : selected.status === "rejected" ? 2 : ["accepted","in_implementation","implemented"].includes(selected.status) ? 3 : selected.status === "verified" ? 4 : selected.status === "closed" ? 5 : 2;
              return <div key={stage} className={index < current ? "done" : index === current ? "current" : ""}><i/>{stage}</div>;
            })}</div>
            <div className="cr-detail-section"><h3>Request summary</h3><p>{selected.description}</p><div className="cr-meta-grid"><div><small>Priority</small><strong>{label(selected.priority ?? "not reported")}</strong></div><div><small>Requested by</small><strong>{selected.requested_by.slice(0, 8)}</strong></div><div><small>Submitted</small><strong>{dateTime(selected.submitted_at)}</strong></div><div><small>Decision date</small><strong>{dateTime(selected.decided_at)}</strong></div></div><div className="cr-justification"><small>Business justification</small><p>{selected.justification}</p></div></div>

            <div className="cr-detail-section"><div className="cr-section-title"><div><h3>Impact assessment</h3><p>Assessment inputs for the Project Manager's decision — not approval steps.</p></div>{selected.status === "draft" && <span className="cr-edit-hint">Editable before submission</span>}</div>
              {dimensions.length === 0 ? <div className="cr-inline-empty">No published impact-assessment dimensions are linked to this record.</div> : <div className="cr-impact-list">{dimensions.map((dimension) => {
                const impact = impacts.find((i) => i.impact_dimension === dimension.dimension_code);
                return <div className="cr-impact-card" key={dimension.id}><div className="cr-impact-heading"><strong>{dimension.dimension_label}</strong>{dimension.is_required && <span>Required</span>}</div>
                  {selected.status === "draft" ? <div className="cr-impact-fields">
                    <select value={impact?.assessment_status ?? "not_assessed"} onChange={(e) => void saveImpact(dimension, { assessment_status: e.target.value as Impact["assessment_status"] })}><option value="not_assessed">Not assessed</option><option value="assessed">Assessed</option><option value="not_applicable">Not applicable</option></select>
                    <textarea value={impact?.assessment_status === "not_applicable" ? impact?.not_applicable_reason ?? "" : impact?.impact_summary ?? ""} placeholder={impact?.assessment_status === "not_applicable" ? "Reason for not applicable" : "Assessment summary / evidence"} onChange={(e) => setImpacts((current) => [...current.filter((i) => i.impact_dimension !== dimension.dimension_code), { ...(impact ?? { impact_dimension: dimension.dimension_code, assessment_status: "not_assessed" as const, impact_summary: "", schedule_impact_days: null, not_applicable_reason: null }), ...(impact?.assessment_status === "not_applicable" ? { not_applicable_reason: e.target.value } : { impact_summary: e.target.value }) }])} onBlur={(e) => void saveImpact(dimension, impact?.assessment_status === "not_applicable" ? { not_applicable_reason: e.target.value } : { impact_summary: e.target.value })}/>
                    <input type="number" placeholder="Schedule impact (days)" value={impact?.schedule_impact_days ?? ""} onChange={(e) => setImpacts((current) => [...current.filter((i) => i.impact_dimension !== dimension.dimension_code), { ...(impact ?? { impact_dimension: dimension.dimension_code, assessment_status: "not_assessed" as const, impact_summary: "", schedule_impact_days: null, not_applicable_reason: null }), schedule_impact_days: e.target.value === "" ? null : Number(e.target.value) }])} onBlur={(e) => void saveImpact(dimension, { schedule_impact_days: e.target.value === "" ? null : Number(e.target.value) })}/>
                    <div className="cr-financial-impact"><input type="number" step="0.01" placeholder="Cost impact (+ / −)" disabled={impact?.assessment_status !== "assessed"} value={impact?.cost_delta ?? ""} onChange={(e) => setImpacts((current) => [...current.filter((i) => i.impact_dimension !== dimension.dimension_code), { ...(impact ?? { impact_dimension: dimension.dimension_code, assessment_status: "not_assessed" as const, impact_summary: "", schedule_impact_days: null, not_applicable_reason: null }), cost_delta: e.target.value === "" ? null : Number(e.target.value) }])} onBlur={(e) => void saveImpact(dimension, { cost_delta: e.target.value === "" ? null : Number(e.target.value), currency_code: impact?.currency_code ?? contracts.find((item) => item.id === selected.contract_id)?.currency_code ?? null })}/><input disabled={impact?.assessment_status !== "assessed"} maxLength={3} placeholder="Currency (e.g. JOD)" value={impact?.currency_code ?? contracts.find((item) => item.id === selected.contract_id)?.currency_code ?? ""} onChange={(e) => setImpacts((current) => [...current.filter((i) => i.impact_dimension !== dimension.dimension_code), { ...(impact ?? { impact_dimension: dimension.dimension_code, assessment_status: "not_assessed" as const, impact_summary: "", schedule_impact_days: null, not_applicable_reason: null }), currency_code: e.target.value.toUpperCase() }])} onBlur={(e) => void saveImpact(dimension, { currency_code: e.target.value.trim().toUpperCase() })}/></div>
                  </div> : <div className="cr-impact-read"><span className={`cr-status ${impact?.assessment_status === "assessed" ? "success" : "neutral"}`}>{label(impact?.assessment_status ?? "not_assessed")}</span><p>{impact?.assessment_status === "not_applicable" ? impact.not_applicable_reason : impact?.impact_summary ?? "No assessment recorded."}</p>{impact?.schedule_impact_days !== null && impact?.schedule_impact_days !== undefined && <small>Schedule impact: {impact.schedule_impact_days} days</small>}{impact?.cost_delta !== null && impact?.cost_delta !== undefined && <small>Financial impact: {impact.cost_delta} {impact.currency_code ?? ""}</small>}</div>}
                </div>;
              })}</div>}
            </div>

            {selected.status === "draft" && <div className="cr-detail-section cr-variation-section"><div className="cr-section-title"><div><h3>Contract variation</h3><p>Financial impact is converted into one linked draft variation after currency and contract checks.</p></div></div>{variation ? <div className="cr-variation-summary"><strong>{variation.variation_reference} · {variation.title}</strong><span>{Number(variation.amount_delta).toLocaleString()} {variation.currency_code} · {label(variation.status)}</span></div> : <div className="cr-variation-actions"><span>{selected.contract_id ? `Contract: ${contracts.find((item) => item.id === selected.contract_id)?.contract_reference ?? "Selected contract"}` : "No contract linked to this Change Request."}</span><button className="button-secondary" disabled={busy || !selected.contract_id || !impacts.some((i) => i.assessment_status === "assessed" && Number(i.cost_delta ?? 0) !== 0)} onClick={() => void createLinkedVariation()}>{busy ? "Creating…" : "Create linked variation"}</button></div>}</div>}

            {selected.status === "draft" && <div className="cr-action-box"><div><strong>Submit for PM decision</strong><p>All required impact dimensions must be assessed or marked not applicable with a reason.</p></div><input value={submitReason} onChange={(e) => setSubmitReason(e.target.value)} placeholder="Optional submission note"/><button className="button-primary" disabled={busy || !selected.assigned_to || dimensions.some((d) => d.is_required && !["assessed","not_applicable"].includes(impacts.find((i) => i.impact_dimension === d.dimension_code)?.assessment_status ?? "not_assessed"))} onClick={() => void submitCR()}>{busy ? "Submitting…" : "Submit to assigned PM"}</button></div>}

            {canDecide && <div className="cr-action-box decision"><div><strong>Project Manager decision</strong><p>You are the assigned PM. Review the impact assessments, then accept or reject with a mandatory reason.</p></div><textarea value={decisionReason} onChange={(e) => setDecisionReason(e.target.value)} placeholder="Decision reason (minimum 8 characters)"/><div className="cr-decision-actions"><button className="button-secondary" disabled={busy || decisionReason.trim().length < 8} onClick={() => void decideCR("reject")}>Reject request</button><button className="button-primary" disabled={busy || decisionReason.trim().length < 8} onClick={() => void decideCR("accept")}>Accept request</button></div></div>}

            {["accepted","in_implementation","implemented","verified","closed"].includes(selected.status) && <div className="cr-outcome"><CheckCircle2 size={17}/><div><strong>PM decision: {label(selected.status)}</strong><p>{selected.decision_reason || "Decision recorded."}</p><small>Decision timestamp: {dateTime(selected.decided_at)}</small></div></div>}
            {selected.status === "rejected" && <div className="cr-outcome rejected"><AlertCircle size={17}/><div><strong>PM decision: Rejected</strong><p>{selected.decision_reason || "No reason recorded."}</p><small>Decision timestamp: {dateTime(selected.decided_at)}</small></div></div>}

            <div className="cr-detail-section"><div className="cr-section-title"><div><h3>Decision and audit history</h3><p>Recorded events and accountable actors.</p></div><button className="text-action" onClick={refreshSelected}>Refresh</button></div>
              {history.length === 0 ? <div className="cr-inline-empty">No history events are available.</div> : <div className="cr-history">{history.map((event) => <div key={event.id}><span className="cr-history-dot"/><div><strong>{label(event.event_code)}</strong><small>{dateTime(event.created_at)} · {event.actor_user_id?.slice(0, 8) ?? "System"}</small>{event.event_reason && <p>{event.event_reason}</p>}</div><span className="cr-history-transition">{event.from_status ? label(event.from_status) + " → " : ""}{label(event.to_status ?? event.event_code)}</span></div>)}</div>}
            </div>
          </div>}
      </section>
    </div>

    {showCreate && <div className="cr-modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setShowCreate(false); }}><form className="cr-create-modal" onSubmit={createCR}>
      <div className="cr-modal-heading"><div><span>NEW RECORD</span><h2>Create Change Request</h2><p>Assign the single Project Manager who will make the decision.</p></div><button type="button" className="icon-button" onClick={() => setShowCreate(false)}><X size={18}/></button></div>
      <label>Project<select required value={form.project_id} onChange={(e) => setForm((f) => ({ ...f, project_id: e.target.value, contract_id: "", assigned_to: "" }))}><option value="">Select project</option>{projects.map((p) => <option key={p.id} value={p.id}>{p.project_code} · {p.name}</option>)}</select></label>
      <label>Contract<select value={form.contract_id} onChange={(e) => setForm((f) => ({ ...f, contract_id: e.target.value }))}><option value="">No contract variation required</option>{contracts.filter((item) => item.project_id === form.project_id).map((item) => <option key={item.id} value={item.id}>{item.contract_reference} · {item.contract_title} ({item.currency_code ?? "Currency not set"})</option>)}</select></label>
      <label>Title<input required maxLength={250} value={form.title} onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}/></label>
      <label>Description<textarea required value={form.description} onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}/></label>
      <label>Business justification<textarea required value={form.justification} onChange={(e) => setForm((f) => ({ ...f, justification: e.target.value }))}/></label>
      <div className="cr-form-two"><label>Priority<select value={form.priority} onChange={(e) => setForm((f) => ({ ...f, priority: e.target.value }))}><option value="low">Low</option><option value="medium">Medium</option><option value="high">High</option><option value="critical">Critical</option></select></label>
      <label>Assigned Project Manager<select required value={form.assigned_to} onChange={(e) => setForm((f) => ({ ...f, assigned_to: e.target.value }))}><option value="">Select active project PM</option>{membersFor(form.project_id).map((m) => <option key={m.user_id} value={m.user_id}>{m.display_name}</option>)}</select></label></div>
      <label>Impact-assessment configuration<select required value={form.workflow_version_id} onChange={(e) => setForm((f) => ({ ...f, workflow_version_id: e.target.value }))}><option value="">Select published configuration</option>{versions.filter((v) => v.is_global || v.project_id === form.project_id).map((v) => <option key={v.id} value={v.id}>{v.template_name} · v{v.version_no}</option>)}</select></label>
      <div className="cr-modal-footer"><button type="button" className="button-secondary" onClick={() => setShowCreate(false)}>Cancel</button><button className="button-primary" disabled={busy || !membersFor(form.project_id).some((m) => m.user_id === form.assigned_to)}>{busy ? <LoaderCircle className="spin" size={15}/> : <FilePlus2 size={15}/>} Create draft</button></div>
    </form></div>}
  </div>;
}
