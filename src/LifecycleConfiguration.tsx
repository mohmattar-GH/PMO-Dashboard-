import { useCallback, useEffect, useMemo, useState } from "react";
import { ArrowRight, CheckCircle2, Copy, Layers3, Plus, RefreshCw, ShieldCheck } from "lucide-react";
import { supabase } from "./lib/supabase";

type Template = { id: string; template_code: string; template_name: string; description: string | null; status: string; project_id: string | null };
type Version = { id: string; template_id: string; project_id: string | null; version_number: number; status: string; effective_from: string | null; effective_to: string | null; change_reason: string; published_at: string | null };
type Phase = { id: string; version_id: string; template_id: string; project_id: string | null; phase_code: string; phase_name: string; description: string | null; display_order: number; is_active: boolean };
type Rule = { id: string; version_id: string; from_phase_id: string | null; to_phase_id: string; reason_required: boolean };
type Project = { id: string; project_code: string; name: string };
type Assignment = { project_id: string; status: string };
const label = (value: string) => value.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
const statusClass = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, "-");

export default function LifecycleConfiguration({ isPlatformAdmin }: { isPlatformAdmin: boolean }) {
  const [templates, setTemplates] = useState<Template[]>([]);
  const [versions, setVersions] = useState<Version[]>([]);
  const [phases, setPhases] = useState<Phase[]>([]);
  const [rules, setRules] = useState<Rule[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [currentUserId, setCurrentUserId] = useState("");
  const [selectedTemplateId, setSelectedTemplateId] = useState("");
  const [selectedVersionId, setSelectedVersionId] = useState("");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [showTemplateForm, setShowTemplateForm] = useState(false);
  const [showVersionForm, setShowVersionForm] = useState(false);
  const [showPhaseForm, setShowPhaseForm] = useState(false);
  const [showRuleForm, setShowRuleForm] = useState(false);
  const [templateForm, setTemplateForm] = useState({ template_code: "", template_name: "", description: "" });
  const [versionReason, setVersionReason] = useState("");
  const [phaseForm, setPhaseForm] = useState({ phase_code: "", phase_name: "", description: "" });
  const [ruleForm, setRuleForm] = useState({ from_phase_id: "", to_phase_id: "", reason_required: true });
  const [phaseEdits, setPhaseEdits] = useState<Record<string, { phase_name: string; description: string; display_order: string; is_active: boolean }>>({});
  const [assignForm, setAssignForm] = useState({ project_id: "", initial_phase_id: "", reason: "Assign the selected lifecycle template to this project.", planned_start_date: "", forecast_completion_date: "" });

  const load = useCallback(async () => {
    if (!supabase) { setError("Supabase client is not configured."); setLoading(false); return; }
    setLoading(true); setError("");
    const [{ data: userData }, templateResult, versionResult, phaseResult, ruleResult, projectResult, assignmentResult] = await Promise.all([
      supabase.auth.getUser(),
      supabase.from("project_lifecycle_templates").select("id,template_code,template_name,description,status,project_id").order("template_name"),
      supabase.from("project_lifecycle_template_versions").select("id,template_id,project_id,version_number,status,effective_from,effective_to,change_reason,published_at").order("version_number", { ascending: false }),
      supabase.from("project_lifecycle_phases").select("id,version_id,template_id,project_id,phase_code,phase_name,description,display_order,is_active").order("display_order"),
      supabase.from("project_lifecycle_transition_rules").select("id,version_id,from_phase_id,to_phase_id,reason_required"),
      supabase.from("projects").select("id,project_code,name").order("project_code"),
      supabase.from("project_lifecycle_assignments").select("project_id,status").eq("status", "active")
    ]);
    setCurrentUserId(userData.user?.id ?? "");
    const failures = [templateResult.error, versionResult.error, phaseResult.error, ruleResult.error, projectResult.error, assignmentResult.error].filter(Boolean);
    if (failures.length) setError(failures.map((item) => item?.message).join(" · "));
    setTemplates((templateResult.data ?? []) as Template[]);
    setVersions((versionResult.data ?? []) as Version[]);
    setPhases((phaseResult.data ?? []) as Phase[]);
    setRules((ruleResult.data ?? []) as Rule[]);
    setProjects((projectResult.data ?? []) as Project[]);
    setAssignments((assignmentResult.data ?? []) as Assignment[]);
    setLoading(false);
  }, []);

  useEffect(() => { void load(); }, [load]);

  const globalTemplates = useMemo(() => templates.filter((template) => template.project_id === null && template.status === "active"), [templates]);
  const selectedTemplate = templates.find((template) => template.id === selectedTemplateId) ?? null;
  const templateVersions = useMemo(() => versions.filter((version) => version.template_id === selectedTemplateId), [versions, selectedTemplateId]);
  const selectedVersion = versions.find((version) => version.id === selectedVersionId) ?? null;
  const versionPhases = useMemo(() => phases.filter((phase) => phase.version_id === selectedVersionId).sort((a, b) => a.display_order - b.display_order), [phases, selectedVersionId]);
  const versionRules = useMemo(() => rules.filter((rule) => rule.version_id === selectedVersionId), [rules, selectedVersionId]);
  const initialRules = useMemo(() => versionRules.filter((rule) => rule.from_phase_id === null), [versionRules]);
  const globalTemplateIds = useMemo(() => new Set(globalTemplates.map((template) => template.id)), [globalTemplates]);
  const publishedVersions = useMemo(() => versions.filter((version) => globalTemplateIds.has(version.template_id) && version.project_id === null && version.status === "published" && version.effective_from && new Date(version.effective_from) <= new Date() && (!version.effective_to || new Date(version.effective_to) > new Date())), [versions, globalTemplateIds]);
  const activeProjectIds = useMemo(() => new Set(assignments.map((assignment) => assignment.project_id)), [assignments]);
  const unassignedProjects = useMemo(() => projects.filter((project) => !activeProjectIds.has(project.id)), [projects, activeProjectIds]);
  const fromPhaseName = (id: string | null) => id ? versionPhases.find((phase) => phase.id === id)?.phase_name ?? "Unknown phase" : "Project start";
  const toPhaseName = (id: string) => versionPhases.find((phase) => phase.id === id)?.phase_name ?? "Unknown phase";

  useEffect(() => {
    if (!selectedTemplateId && globalTemplates.length) setSelectedTemplateId(globalTemplates[0].id);
  }, [selectedTemplateId, globalTemplates]);
  useEffect(() => {
    if (!templateVersions.length) { setSelectedVersionId(""); return; }
    if (!templateVersions.some((version) => version.id === selectedVersionId)) {
      const preferred = templateVersions.find((version) => version.status === "draft") ?? templateVersions[0];
      setSelectedVersionId(preferred.id);
    }
  }, [templateVersions, selectedVersionId]);
  useEffect(() => {
    setPhaseEdits(Object.fromEntries(versionPhases.map((phase) => [phase.id, {
      phase_name: phase.phase_name, description: phase.description ?? "", display_order: String(phase.display_order), is_active: phase.is_active
    }])));
    const startRule = rules.find((rule) => rule.version_id === selectedVersionId && rule.from_phase_id === null);
    setAssignForm((form) => ({ ...form, initial_phase_id: startRule?.to_phase_id ?? "" }));
  }, [selectedVersionId, phases, rules]);

  const createTemplate = async () => {
    if (!supabase || !currentUserId) return;
    if (!templateForm.template_code.trim() || !templateForm.template_name.trim()) { setError("Template code and name are required."); return; }
    setBusy(true); setError(""); setMessage("");
    const { data, error: createError } = await supabase.from("project_lifecycle_templates").insert({
      project_id: null, template_code: templateForm.template_code.trim().toUpperCase(), template_name: templateForm.template_name.trim(),
      description: templateForm.description.trim() || null, status: "active", created_by: currentUserId
    }).select("id").single();
    if (createError) setError(createError.message);
    else { setSelectedTemplateId(data.id); setShowTemplateForm(false); setTemplateForm({ template_code: "", template_name: "", description: "" }); setMessage("Lifecycle template created. Create its first draft version to define phases and transitions."); await load(); }
    setBusy(false);
  };

  const createDraftVersion = async () => {
    if (!supabase || !selectedTemplate || !currentUserId) return;
    if (versionReason.trim().length < 8) { setError("Version change reason must be at least 8 characters."); return; }
    setBusy(true); setError(""); setMessage("");
    const latestPublished = templateVersions.find((version) => version.status === "published" || version.status === "retired");
    let newVersionId: string | null = null;
    if (latestPublished) {
      const { data, error: cloneError } = await supabase.rpc("clone_project_lifecycle_template_version", { p_source_version_id: latestPublished.id, p_change_reason: versionReason.trim() });
      if (cloneError) setError(cloneError.message); else newVersionId = data as string;
    } else {
      const nextNumber = Math.max(0, ...templateVersions.map((version) => version.version_number)) + 1;
      const { data, error: insertError } = await supabase.from("project_lifecycle_template_versions").insert({
        template_id: selectedTemplate.id, project_id: selectedTemplate.project_id, version_number: nextNumber,
        status: "draft", change_reason: versionReason.trim(), created_by: currentUserId
      }).select("id").single();
      if (insertError) setError(insertError.message); else newVersionId = data.id;
    }
    if (newVersionId) { setSelectedVersionId(newVersionId); setShowVersionForm(false); setVersionReason(""); setMessage("New draft version created. Published versions remain unchanged."); await load(); }
    setBusy(false);
  };

  const addPhase = async () => {
    if (!supabase || !selectedTemplate || !selectedVersion) return;
    if (!phaseForm.phase_code.trim() || !phaseForm.phase_name.trim()) { setError("Phase code and name are required."); return; }
    setBusy(true); setError(""); setMessage("");
    const { error: insertError } = await supabase.from("project_lifecycle_phases").insert({
      version_id: selectedVersion.id, template_id: selectedTemplate.id, project_id: selectedTemplate.project_id,
      phase_code: phaseForm.phase_code.trim().toUpperCase(), phase_name: phaseForm.phase_name.trim(),
      description: phaseForm.description.trim() || null, display_order: Math.max(0, ...versionPhases.map((phase) => phase.display_order)) + 1, is_active: true
    });
    if (insertError) setError(insertError.message);
    else { setPhaseForm({ phase_code: "", phase_name: "", description: "" }); setShowPhaseForm(false); setMessage("Phase added to the draft version."); await load(); }
    setBusy(false);
  };

  const savePhase = async (phase: Phase) => {
    if (!supabase || !selectedVersion) return;
    const edit = phaseEdits[phase.id];
    if (!edit || !edit.phase_name.trim() || !Number.isInteger(Number(edit.display_order)) || Number(edit.display_order) < 1) { setError("Phase name and a positive whole-number display order are required."); return; }
    setBusy(true); setError(""); setMessage("");
    const { error: updateError } = await supabase.from("project_lifecycle_phases").update({
      phase_name: edit.phase_name.trim(), description: edit.description.trim() || null,
      display_order: Number(edit.display_order), is_active: edit.is_active
    }).eq("id", phase.id);
    if (updateError) setError(updateError.message); else { setMessage("Phase definition saved."); await load(); }
    setBusy(false);
  };

  const addRule = async () => {
    if (!supabase || !selectedTemplate || !selectedVersion || !ruleForm.to_phase_id) { setError("Select a destination phase for the transition."); return; }
    if (ruleForm.from_phase_id && ruleForm.from_phase_id === ruleForm.to_phase_id) { setError("A phase cannot transition to itself."); return; }
    if (versionRules.some((rule) => rule.from_phase_id === (ruleForm.from_phase_id || null) && rule.to_phase_id === ruleForm.to_phase_id)) { setError("This transition already exists."); return; }
    setBusy(true); setError(""); setMessage("");
    const { error: insertError } = await supabase.from("project_lifecycle_transition_rules").insert({
      version_id: selectedVersion.id, template_id: selectedTemplate.id, project_id: selectedTemplate.project_id,
      from_phase_id: ruleForm.from_phase_id || null, to_phase_id: ruleForm.to_phase_id, reason_required: ruleForm.reason_required
    });
    if (insertError) setError(insertError.message); else { setRuleForm({ from_phase_id: "", to_phase_id: "", reason_required: true }); setShowRuleForm(false); setMessage("Transition rule added."); await load(); }
    setBusy(false);
  };

  const publishVersion = async () => {
    if (!supabase || !selectedVersion || !currentUserId) return;
    if (!versionPhases.some((phase) => phase.is_active) || !initialRules.some((rule) => versionPhases.some((phase) => phase.id === rule.to_phase_id && phase.is_active))) {
      setError("Publish requires at least one active phase and an allowed starting transition."); return;
    }
    setBusy(true); setError(""); setMessage("");
    const now = new Date().toISOString();
    const { error: publishError } = await supabase.from("project_lifecycle_template_versions").update({
      status: "published", effective_from: now, published_by: currentUserId, published_at: now
    }).eq("id", selectedVersion.id);
    if (publishError) setError(publishError.message); else { setMessage("Lifecycle version published. It is now immutable; create a new draft version for future changes."); await load(); }
    setBusy(false);
  };

  const assignLifecycle = async () => {
    if (!supabase || !selectedVersion || selectedVersion.status !== "published" || !publishedVersions.some((version) => version.id === selectedVersion.id) || !assignForm.project_id || !assignForm.initial_phase_id || assignForm.reason.trim().length < 8) {
      setError("Project, published version, initial phase and an assignment reason of at least 8 characters are required."); return;
    }
    setBusy(true); setError(""); setMessage("");
    const { error: assignError } = await supabase.rpc("assign_project_lifecycle", {
      p_project_id: assignForm.project_id, p_version_id: selectedVersion.id, p_initial_phase_id: assignForm.initial_phase_id,
      p_assignment_reason: assignForm.reason.trim(), p_entered_at: new Date().toISOString(),
      p_planned_start_date: assignForm.planned_start_date || null, p_forecast_completion_date: assignForm.forecast_completion_date || null
    });
    if (assignError) setError(assignError.message);
    else { setMessage("Lifecycle assigned. The project's current phase is now available to the Project Register and Executive Dashboard."); setAssignForm((form) => ({ ...form, project_id: "", planned_start_date: "", forecast_completion_date: "" })); await load(); }
    setBusy(false);
  };

  if (!isPlatformAdmin) return <section className="panel lifecycle-config-denied"><ShieldCheck size={22}/><strong>Platform Administrator access required</strong><span>Lifecycle templates, phase definitions and transition rules are administrator-controlled.</span></section>;
  if (loading) return <section className="panel module-loading">Loading lifecycle configuration…</section>;

  return <section className="lifecycle-config-module">
    <div className="lifecycle-config-heading"><div><span className="module-eyebrow">GOVERNANCE CONFIGURATION</span><h2>Project Lifecycle Configuration</h2><p>Versioned lifecycle templates, configurable phases and controlled phase transitions.</p></div><button className="button-secondary small" onClick={() => void load()}><RefreshCw size={13}/> Refresh</button></div>
    {error && <div className="lifecycle-config-alert error">{error}</div>}{message && <div className="lifecycle-config-alert success"><CheckCircle2 size={14}/>{message}</div>}
    <div className="lifecycle-config-layout">
      <aside className="panel lifecycle-template-list"><div className="lifecycle-panel-heading"><strong>Global Templates</strong><button className="icon-button" title="Create template" onClick={() => setShowTemplateForm(!showTemplateForm)}><Plus size={15}/></button></div>
        {globalTemplates.map((template) => <button key={template.id} className={"lifecycle-template-option " + (selectedTemplateId === template.id ? "active" : "")} onClick={() => setSelectedTemplateId(template.id)}><strong>{template.template_name}</strong><span>{template.template_code} · {versions.filter((version) => version.template_id === template.id).length} versions</span></button>)}
        {!globalTemplates.length && <p className="project-empty-inline">No global templates have been created.</p>}
      </aside>
      <div className="lifecycle-config-main">
        {showTemplateForm && <div className="panel lifecycle-editor-panel"><h3>Create Global Lifecycle Template</h3><div className="lifecycle-form-grid"><label>Template code<input value={templateForm.template_code} onChange={(e) => setTemplateForm((f) => ({ ...f, template_code: e.target.value.toUpperCase() }))}/></label><label>Template name<input value={templateForm.template_name} onChange={(e) => setTemplateForm((f) => ({ ...f, template_name: e.target.value }))}/></label><label className="wide">Description<textarea value={templateForm.description} onChange={(e) => setTemplateForm((f) => ({ ...f, description: e.target.value }))}/></label></div><div className="lifecycle-form-actions"><button className="button-secondary small" onClick={() => setShowTemplateForm(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={() => void createTemplate()}>Create template</button></div></div>}
        {selectedTemplate ? <>
          <div className="panel lifecycle-editor-panel"><div className="lifecycle-panel-heading"><div><span className="module-eyebrow">{selectedTemplate.template_code}</span><h3>{selectedTemplate.template_name}</h3><p>{selectedTemplate.description || "No description recorded."}</p></div><span className={"project-status-pill " + statusClass(selectedTemplate.status)}>{label(selectedTemplate.status)}</span></div>
            <div className="lifecycle-version-toolbar"><label>Template version<select value={selectedVersionId} onChange={(e) => setSelectedVersionId(e.target.value)}>{templateVersions.map((version) => <option key={version.id} value={version.id}>v{version.version_number} · {label(version.status)}</option>)}</select></label><div>{(selectedVersion?.status === "published" || templateVersions.length === 0) && <button className="button-secondary small" onClick={() => { setVersionReason(""); setShowVersionForm(true); }}><Copy size={13}/> {templateVersions.length ? "New version" : "Create first version"}</button>}</div></div>
            {selectedVersion && <div className="lifecycle-version-meta"><span className={"project-status-pill " + statusClass(selectedVersion.status)}>{label(selectedVersion.status)}</span><span>Version {selectedVersion.version_number}</span><span>{selectedVersion.effective_from ? "Effective " + new Date(selectedVersion.effective_from).toLocaleDateString() : "Not yet effective"}</span><span>{selectedVersion.change_reason}</span></div>}
          </div>
          {showVersionForm && <div className="panel lifecycle-editor-panel"><h3>Create a new draft version</h3><p>Published versions are immutable. A new draft copies all current phases and transition rules.</p><textarea value={versionReason} onChange={(e) => setVersionReason(e.target.value)} placeholder="Reason for the new version (8–1000 characters)"/><div className="lifecycle-form-actions"><button className="button-secondary small" onClick={() => setShowVersionForm(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={() => void createDraftVersion()}>Create draft version</button></div></div>}
          {selectedVersion && <div className="panel lifecycle-editor-panel"><div className="lifecycle-panel-heading"><div><h3>Lifecycle Phases</h3><p>Order and definitions are editable only while the version is Draft.</p></div>{selectedVersion.status === "draft" && <button className="button-secondary small" onClick={() => setShowPhaseForm(!showPhaseForm)}><Plus size={13}/> Add phase</button>}</div>
            {showPhaseForm && <div className="lifecycle-add-row"><input value={phaseForm.phase_code} onChange={(e) => setPhaseForm((f) => ({ ...f, phase_code: e.target.value.toUpperCase() }))} placeholder="Phase code"/><input value={phaseForm.phase_name} onChange={(e) => setPhaseForm((f) => ({ ...f, phase_name: e.target.value }))} placeholder="Phase name"/><input value={phaseForm.description} onChange={(e) => setPhaseForm((f) => ({ ...f, description: e.target.value }))} placeholder="Description"/><button className="button-primary small" disabled={busy} onClick={() => void addPhase()}>Add</button></div>}
            {versionPhases.map((phase) => { const edit = phaseEdits[phase.id] ?? { phase_name: phase.phase_name, description: phase.description ?? "", display_order: String(phase.display_order), is_active: phase.is_active }; return <div className="lifecycle-phase-row" key={phase.id}><span className="lifecycle-phase-order">{phase.display_order}</span><div className="lifecycle-phase-edit"><strong>{phase.phase_code}</strong>{selectedVersion.status === "draft" ? <><input value={edit.phase_name} onChange={(e) => setPhaseEdits((all) => ({ ...all, [phase.id]: { ...edit, phase_name: e.target.value } }))}/><input value={edit.description} onChange={(e) => setPhaseEdits((all) => ({ ...all, [phase.id]: { ...edit, description: e.target.value } }))} placeholder="Description"/><label><input type="checkbox" checked={edit.is_active} onChange={(e) => setPhaseEdits((all) => ({ ...all, [phase.id]: { ...edit, is_active: e.target.checked } }))}/> Active</label><input className="order-input" type="number" min="1" value={edit.display_order} onChange={(e) => setPhaseEdits((all) => ({ ...all, [phase.id]: { ...edit, display_order: e.target.value } }))}/><button className="button-secondary small" disabled={busy} onClick={() => void savePhase(phase)}>Save</button></> : <><span>{phase.phase_name}</span><small>{phase.description}</small><span className={"project-status-pill " + (phase.is_active ? "active" : "archived")}>{phase.is_active ? "Active" : "Inactive"}</span></>}</div></div>; })}
            {!versionPhases.length && <p className="project-empty-inline">No phases defined in this version.</p>}
          </div>}
          {selectedVersion && <div className="panel lifecycle-editor-panel"><div className="lifecycle-panel-heading"><div><h3>Allowed Transitions</h3><p>Only configured transitions are permitted by the lifecycle engine.</p></div>{selectedVersion.status === "draft" && <button className="button-secondary small" onClick={() => setShowRuleForm(!showRuleForm)}><Plus size={13}/> Add transition</button>}</div>
            {showRuleForm && <div className="lifecycle-add-row"><select value={ruleForm.from_phase_id} onChange={(e) => setRuleForm((f) => ({ ...f, from_phase_id: e.target.value }))}><option value="">Project start</option>{versionPhases.filter((phase) => phase.is_active).map((phase) => <option key={phase.id} value={phase.id}>{phase.phase_name}</option>)}</select><ArrowRight size={14}/><select value={ruleForm.to_phase_id} onChange={(e) => setRuleForm((f) => ({ ...f, to_phase_id: e.target.value }))}><option value="">To phase…</option>{versionPhases.filter((phase) => phase.is_active).map((phase) => <option key={phase.id} value={phase.id}>{phase.phase_name}</option>)}</select><label><input type="checkbox" checked={ruleForm.reason_required} onChange={(e) => setRuleForm((f) => ({ ...f, reason_required: e.target.checked }))}/> Reason required</label><button className="button-primary small" disabled={busy} onClick={() => void addRule()}>Add</button></div>}
            {versionRules.map((rule) => <div className="lifecycle-rule-row" key={rule.id}><span>{fromPhaseName(rule.from_phase_id)}</span><ArrowRight size={13}/><strong>{toPhaseName(rule.to_phase_id)}</strong><span>{rule.reason_required ? "Reason required" : "Reason optional"}</span></div>)}
            {!versionRules.length && <p className="project-empty-inline">No transition rules defined.</p>}
            {selectedVersion.status === "draft" && <div className="lifecycle-publish-footer"><span>Publishing freezes this version. Create a new version for future changes.</span><button className="button-primary small" disabled={busy || !versionPhases.some((phase) => phase.is_active) || !initialRules.length} onClick={() => void publishVersion()}><ShieldCheck size={13}/> Publish version</button></div>}
          </div>}
        </> : <div className="panel project-empty"><Layers3 size={22}/><strong>Select or create a lifecycle template.</strong></div>}
      </div>
    </div>
    <div className="panel lifecycle-assignment-panel"><div className="lifecycle-panel-heading"><div><h3>Assign a Published Lifecycle to a Project</h3><p>Assignment is a controlled Platform Administrator action and records the starting phase.</p></div><span className="project-status-pill active">{publishedVersions.length} effective published versions</span></div>
      <div className="lifecycle-assign-grid"><label>Project<select value={assignForm.project_id} onChange={(e) => setAssignForm((f) => ({ ...f, project_id: e.target.value }))}><option value="">Select unassigned project</option>{unassignedProjects.map((project) => <option key={project.id} value={project.id}>{project.project_code} · {project.name}</option>)}</select></label><label>Published lifecycle version<select value={selectedVersion?.status === "published" ? selectedVersion.id : ""} onChange={(e) => { const version = versions.find((item) => item.id === e.target.value); if (version) { setSelectedTemplateId(version.template_id); setSelectedVersionId(version.id); } }}><option value="">Select effective version</option>{publishedVersions.map((version) => <option key={version.id} value={version.id}>{templates.find((template) => template.id === version.template_id)?.template_name ?? "Template"} · v{version.version_number}</option>)}</select></label><label>Initial phase<select value={assignForm.initial_phase_id} onChange={(e) => setAssignForm((f) => ({ ...f, initial_phase_id: e.target.value }))}><option value="">Select starting phase</option>{selectedVersion?.status === "published" && phases.filter((phase) => phase.version_id === selectedVersion.id && phase.is_active && rules.some((rule) => rule.version_id === selectedVersion.id && rule.from_phase_id === null && rule.to_phase_id === phase.id)).map((phase) => <option key={phase.id} value={phase.id}>{phase.phase_name}</option>)}</select></label><label>Planned start<input type="date" value={assignForm.planned_start_date} onChange={(e) => setAssignForm((f) => ({ ...f, planned_start_date: e.target.value }))}/></label><label>Forecast completion<input type="date" value={assignForm.forecast_completion_date} onChange={(e) => setAssignForm((f) => ({ ...f, forecast_completion_date: e.target.value }))}/></label><label className="wide">Assignment reason<input value={assignForm.reason} onChange={(e) => setAssignForm((f) => ({ ...f, reason: e.target.value }))}/></label></div>
      <div className="lifecycle-form-actions"><button className="button-primary small" disabled={busy || !publishedVersions.length || !unassignedProjects.length} onClick={() => void assignLifecycle()}>Assign lifecycle</button></div>
    </div>
  </section>;
}
