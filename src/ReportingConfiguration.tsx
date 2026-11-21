import { useCallback, useEffect, useMemo, useState } from "react";
import { AlertCircle, CheckCircle2, FilePlus2, LoaderCircle, RefreshCw, Save, ShieldCheck } from "lucide-react";
import { supabase } from "./lib/supabase";

type ConfigSet = { id: string; scope_type: "global" | "project"; project_id: string | null; configuration_code: string; name: string; description: string | null; created_at: string };
type ConfigVersion = { id: string; configuration_set_id: string; version_number: number; status: string; effective_from: string | null; effective_to: string | null; change_summary: string; created_at: string; created_by: string | null; submitted_by: string | null; submitted_at: string | null; approved_by: string | null; approved_at: string | null; published_by: string | null; published_at: string | null };
type Project = { id: string; project_code: string; name: string };
type Dimension = { id: string; dimension_code: string; name: string; description: string | null; display_order: number; weight: number | null; is_active: boolean; missing_data_status: string };
type KPI = { id: string; dimension_id: string | null; kpi_code: string; name: string; description: string | null; calculation_method: string; formula_template: string; source_mapping: Record<string, unknown>; parameters: Record<string, unknown>; unit: string | null; weight: number | null; is_active: boolean; display_order: number };
type RuleParameter = { id: string; rule_code: string; parameter_code: string; parameter_value: unknown; value_type: string; description: string | null; validation_definition: Record<string, unknown> };

const formulaCatalog = [
  { code: "count_v1", method: "count", description: "Count qualifying source records", required: ["source"] },
  { code: "date_variance_v1", method: "date_variance", description: "Date difference using a configured calendar basis", required: ["baseline_date", "comparison_date", "day_basis"] },
  { code: "manual_input_v1", method: "manual_input", description: "Human-entered value with provenance", required: ["input_field"] },
  { code: "ratio_v1", method: "ratio", description: "Ratio of validated numerator and denominator values", required: ["numerator", "denominator"] },
  { code: "threshold_status_v1", method: "threshold_status", description: "Status mapping using configured numeric thresholds", required: ["value", "thresholds"] },
  { code: "weighted_sum_v1", method: "weighted_sum", description: "Weighted aggregation of validated source values", required: ["values", "weights"] }
];

const validateRiskScoringParameters = (parameters: unknown[]) => {
  const rows = parameters.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object" && (item as Record<string, unknown>).rule_code === "risk_scoring");
  if (!rows.length) return;
  const values = new Map<string, Record<string, unknown>>(rows.map((row) => [String(row.parameter_code), row] as const));
  const readNumber = (key: string) => {
    const row = values.get(key);
    if (!row || row.value_type !== "number" || typeof row.parameter_value !== "number" || !Number.isFinite(row.parameter_value)) {
      throw new Error("Risk scoring parameter " + key + " must be a numeric rule parameter.");
    }
    return row.parameter_value;
  };
  const probabilityMax = readNumber("probability_scale_max");
  const impactMax = readNumber("impact_scale_max");
  const probabilityWeight = readNumber("probability_weight");
  const impactWeight = readNumber("impact_weight");
  const multiplier = values.has("score_multiplier") ? readNumber("score_multiplier") : 100;
  if (!Number.isInteger(probabilityMax) || probabilityMax <= 0 || !Number.isInteger(impactMax) || impactMax <= 0) throw new Error("Risk scoring scale maxima must be positive whole numbers.");
  if (probabilityWeight < 0 || probabilityWeight > 1 || impactWeight < 0 || impactWeight > 1 || Math.abs(probabilityWeight + impactWeight - 1) > 0.000001) throw new Error("Risk scoring probability and impact weights must each be between 0 and 1 and total 1.");
  if (multiplier <= 0) throw new Error("Risk scoring multiplier must be greater than zero.");
};

const pretty = (value: unknown) => JSON.stringify(value, null, 2) ?? "[]";
const parseArray = (value: string, label: string) => {
  const parsed = JSON.parse(value);
  if (!Array.isArray(parsed)) throw new Error(label + " must be a JSON array.");
  return parsed;
};
const dateTime = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : "Not recorded";
const label = (value: string) => value.replace(/_/g, " ").replace(/\b\w/g, (s) => s.toUpperCase());

export default function ReportingConfiguration({ globalRoles }: { globalRoles: string[] }) {
  const isAdmin = globalRoles.includes("platform_admin");
  const canSteward = isAdmin || globalRoles.includes("configuration_steward");
  const canApprove = isAdmin || globalRoles.includes("configuration_approver");
  const canAccess = canSteward || canApprove;
  const [sets, setSets] = useState<ConfigSet[]>([]);
  const [versions, setVersions] = useState<ConfigVersion[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [selectedSetId, setSelectedSetId] = useState("");
  const [selectedVersionId, setSelectedVersionId] = useState("");
  const [dimensionsJson, setDimensionsJson] = useState("[]");
  const [kpisJson, setKpisJson] = useState("[]");
  const [parametersJson, setParametersJson] = useState("[]");
  const [reason, setReason] = useState("");
  const [createOpen, setCreateOpen] = useState(false);
  const [createForm, setCreateForm] = useState({ useExistingSet: false, scope_type: "global" as "global" | "project", project_id: "", configuration_code: "", name: "", description: "", effective_from: "", effective_to: "" });
  const [projectIds, setProjectIds] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const selectedSet = useMemo(() => sets.find((item) => item.id === selectedSetId) ?? null, [sets, selectedSetId]);
  const selectedVersion = useMemo(() => versions.find((item) => item.id === selectedVersionId) ?? null, [versions, selectedVersionId]);
  const canEditDraft = Boolean(selectedVersion?.status === "draft" && canSteward);
  const allowedProjects = useMemo(() => isAdmin ? projects : projects.filter((project) => projectIds.includes(project.id)), [projects, projectIds, isAdmin]);

  const loadBase = useCallback(async () => {
    if (!supabase) { setError("Supabase is not configured."); setLoading(false); return; }
    setLoading(true); setError("");
    const [{ data: user }, setResult, projectResult] = await Promise.all([
      supabase.auth.getUser(),
      supabase.from("reporting_configuration_sets").select("id,scope_type,project_id,configuration_code,name,description,created_at").order("created_at", { ascending: false }),
      supabase.from("projects").select("id,project_code,name").order("project_code")
    ]);
    if (setResult.error) setError(setResult.error.message);
    if (projectResult.error) setError(projectResult.error.message);
    const userId = user.user?.id ?? "";
    setSets((setResult.data ?? []) as ConfigSet[]);
    setProjects((projectResult.data ?? []) as Project[]);
    if (userId) {
      const membershipResult = await supabase.from("project_memberships").select("project_id").eq("user_id", userId).eq("status", "active").lte("effective_from", new Date().toISOString()).or(`effective_to.is.null,effective_to.gt.${new Date().toISOString()}`);
      setProjectIds((membershipResult.data ?? []).map((row: { project_id: string }) => row.project_id));
    }
    setLoading(false);
  }, []);

  const loadVersions = useCallback(async (setId: string, preferredVersionId?: string) => {
    if (!supabase || !setId) { setVersions([]); setSelectedVersionId(""); return; }
    const { data, error: versionError } = await supabase.from("reporting_configuration_versions")
      .select("id,configuration_set_id,version_number,status,effective_from,effective_to,change_summary,created_at,created_by,submitted_by,submitted_at,approved_by,approved_at,published_by,published_at")
      .eq("configuration_set_id", setId).order("version_number", { ascending: false });
    if (versionError) { setError(versionError.message); return; }
    const rows = (data ?? []) as ConfigVersion[];
    setVersions(rows);
    const next = preferredVersionId && rows.some((row) => row.id === preferredVersionId) ? preferredVersionId : rows[0]?.id ?? "";
    setSelectedVersionId(next);
  }, []);

  const loadVersionDetails = useCallback(async (versionId: string) => {
    if (!supabase || !versionId) return;
    setDetailLoading(true); setError("");
    const [dimensionResult, kpiResult, parameterResult] = await Promise.all([
      supabase.from("reporting_dimensions").select("id,dimension_code,name,description,display_order,weight,is_active,missing_data_status").eq("configuration_version_id", versionId).order("display_order"),
      supabase.from("kpi_definitions").select("id,dimension_id,kpi_code,name,description,calculation_method,formula_template,source_mapping,parameters,unit,weight,is_active,display_order").eq("configuration_version_id", versionId).order("display_order"),
      supabase.from("reporting_rule_parameters").select("id,rule_code,parameter_code,parameter_value,value_type,description,validation_definition").eq("configuration_version_id", versionId).order("rule_code").order("parameter_code")
    ]);
    const dimensions = (dimensionResult.data ?? []) as Dimension[];
    const kpis = (kpiResult.data ?? []) as KPI[];
    const parameters = (parameterResult.data ?? []) as RuleParameter[];
    if (dimensionResult.error || kpiResult.error || parameterResult.error) {
      setError(dimensionResult.error?.message || kpiResult.error?.message || parameterResult.error?.message || "Configuration details could not be loaded.");
    } else {
      setDimensionsJson(pretty(dimensions.map(({ id, ...item }) => item)));
      setKpisJson(pretty(kpis.map(({ id, dimension_id, ...item }) => ({ ...item, dimension_code: dimensions.find((d) => d.id === dimension_id)?.dimension_code ?? null }))));
      setParametersJson(pretty(parameters.map(({ id, ...item }) => item)));
    }
    setDetailLoading(false);
  }, []);

  useEffect(() => { void loadBase(); }, [loadBase]);
  useEffect(() => { if (selectedSetId) void loadVersions(selectedSetId); else { setVersions([]); setSelectedVersionId(""); } }, [selectedSetId, loadVersions]);
  useEffect(() => { if (selectedVersionId) void loadVersionDetails(selectedVersionId); else { setDimensionsJson("[]"); setKpisJson("[]"); setParametersJson("[]"); } }, [selectedVersionId, loadVersionDetails]);

  const invokeGovernance = async (action: string, payload: Record<string, unknown>, actionReason: string) => {
    if (!supabase) return null;
    if (actionReason.trim().length < 8) { setError("Enter a reason of at least 8 characters."); return null; }
    setBusy(true); setError(""); setNotice("");
    const { data, error: invokeError } = await supabase.functions.invoke("reporting-config-governance", {
      body: { action, reason: actionReason.trim(), ...payload }
    });
    if (invokeError) {
      setError(invokeError.message || "Configuration action failed.");
      setBusy(false); return null;
    }
    const response = data as { error?: string } | null;
    if (response?.error) {
      setError(response.error); setBusy(false); return null;
    }
    setNotice("Configuration action recorded. Version and audit metadata were updated.");
    setBusy(false);
    return data as Record<string, unknown>;
  };

  const createDraft = async () => {
    const useExisting = createForm.useExistingSet && Boolean(selectedSet);
    if (useExisting && detailLoading) { setError("Wait for the selected version's rules to finish loading."); return; }
    if (useExisting && versions.length > 0 && !selectedVersion) { setError("Select the latest version before creating its successor."); return; }
    if (useExisting && selectedVersion && (["draft","submitted","approved"].includes(selectedVersion.status) || selectedVersion.id !== versions[0]?.id)) {
      setError("Finish the latest version lifecycle before creating its successor.");
      return;
    }
    if (!useExisting && createForm.scope_type === "project" && !createForm.project_id) { setError("Select a project for project-scoped configuration."); return; }
    if (!createForm.effective_from) { setError("Effective-from date is required before a reporting version can be published."); return; }
    if (!useExisting && (!createForm.configuration_code.trim() || !createForm.name.trim())) { setError("Configuration code and name are required."); return; }
    const payload = useExisting && selectedSet
      ? { configuration_set_id: selectedSet.id, scope_type: selectedSet.scope_type, project_id: selectedSet.project_id, configuration_code: selectedSet.configuration_code, name: selectedSet.name, description: selectedSet.description, effective_from: createForm.effective_from ? new Date(createForm.effective_from).toISOString() : null, effective_to: createForm.effective_to ? new Date(createForm.effective_to).toISOString() : null }
      : { scope_type: createForm.scope_type, project_id: createForm.scope_type === "project" ? createForm.project_id : null, configuration_code: createForm.configuration_code.trim(), name: createForm.name.trim(), description: createForm.description.trim() || null, effective_from: createForm.effective_from ? new Date(createForm.effective_from).toISOString() : null, effective_to: createForm.effective_to ? new Date(createForm.effective_to).toISOString() : null };
    if (createForm.effective_from && createForm.effective_to && createForm.effective_to <= createForm.effective_from) { setError("Effective-to must be later than effective-from."); return; }
    const reasonText = reason.trim();
    const result = await invokeGovernance("create_draft", payload, reasonText);
    if (!result) return;
    const setId = String(result.configuration_set_id ?? "");
    const version = result.version as { id?: string } | undefined;
    setCreateOpen(false);
    setCreateForm({ useExistingSet: false, scope_type: "global", project_id: "", configuration_code: "", name: "", description: "", effective_from: "", effective_to: "" });
    await loadBase();
    if (setId) {
      setSelectedSetId(setId);
      let copyFailure = "";
      if (useExisting && selectedVersion && version?.id) {
        try {
          const dimensions = parseArray(dimensionsJson, "Dimensions");
          const kpis = parseArray(kpisJson, "KPIs");
          const parameters = parseArray(parametersJson, "Rule parameters");
          const copyReason = (reasonText + " (copied from version " + selectedVersion.version_number + ")").slice(0, 1000);
          const copied = await invokeGovernance("save_draft_rules", { configuration_version_id: version.id, dimensions, kpis, parameters }, copyReason);
          if (!copied) copyFailure = "The successor draft was created, but copying the previous rules failed.";
        } catch (copyError) {
          copyFailure = copyError instanceof Error ? copyError.message : "The successor draft was created, but its rule copy failed.";
        }
      }
      await loadVersions(setId, version?.id);
      if (version?.id) await loadVersionDetails(version.id);
      if (copyFailure) setError(copyFailure);
    }
    setReason("");
  };
  const saveDraftRules = async () => {
    if (!selectedVersion) return;
    try {
      const dimensions = parseArray(dimensionsJson, "Dimensions");
      const kpis = parseArray(kpisJson, "KPIs");
      const parameters = parseArray(parametersJson, "Rule parameters");
      validateRiskScoringParameters(parameters);
      const result = await invokeGovernance("save_draft_rules", { configuration_version_id: selectedVersion.id, dimensions, kpis, parameters }, reason);
      if (result) { setReason(""); await loadVersionDetails(selectedVersion.id); }
    } catch (parseError) {
      setError(parseError instanceof Error ? parseError.message : "The JSON configuration is invalid.");
    }
  };

  const insertRiskScoringStarter = () => {
    try {
      const current = parseArray(parametersJson, "Rule parameters") as Record<string, unknown>[];
      const starter = [
        { rule_code: "risk_scoring", parameter_code: "probability_scale_max", parameter_value: 5, value_type: "number", description: "Maximum probability level on the approved scale", validation_definition: { min: 1, max: 10 } },
        { rule_code: "risk_scoring", parameter_code: "impact_scale_max", parameter_value: 5, value_type: "number", description: "Maximum impact level on the approved scale", validation_definition: { min: 1, max: 10 } },
        { rule_code: "risk_scoring", parameter_code: "probability_weight", parameter_value: 0.5, value_type: "number", description: "Probability contribution to weighted risk score", validation_definition: { min: 0, max: 1 } },
        { rule_code: "risk_scoring", parameter_code: "impact_weight", parameter_value: 0.5, value_type: "number", description: "Impact contribution to weighted risk score", validation_definition: { min: 0, max: 1 } },
        { rule_code: "risk_scoring", parameter_code: "score_multiplier", parameter_value: 100, value_type: "number", description: "Multiplier applied to normalized weighted score", validation_definition: { min: 1, max: 1000 } }
      ];
      const existing = new Set(current.filter((row) => row.rule_code === "risk_scoring").map((row) => String(row.parameter_code)));
      const additions = starter.filter((row) => !existing.has(row.parameter_code));
      setParametersJson(pretty([...current, ...additions]));
      setNotice(additions.length ? "Starter risk-scoring parameters added to the draft. Review the example scale and weights before saving and publishing." : "Risk-scoring parameters already exist; edit their values in the JSON editor.");
      setError("");
    } catch (insertError) {
      setError(insertError instanceof Error ? insertError.message : "Could not add starter risk-scoring parameters.");
    }
  };

  const transition = async (action: "submit" | "approve" | "publish" | "supersede") => {
    if (!selectedVersion) return;
    const result = await invokeGovernance(action, { configuration_version_id: selectedVersion.id }, reason);
    if (result) { setReason(""); await loadVersions(selectedSetId, selectedVersion.id); }
  };

  const selectedSetTitle = selectedSet ? `${selectedSet.configuration_code} · ${selectedSet.name}` : "Select a configuration set";

  if (!canAccess) return <div className="reporting-config-denied"><ShieldCheck size={24}/><strong>Reporting configuration access is restricted</strong><span>Requires Platform Administrator, Configuration Steward or Configuration Approver role.</span></div>;

  return <div className="reporting-config-module">
    <div className="reporting-config-heading"><div><span className="module-eyebrow">GOVERNED REPORTING</span><h2>Reporting Configuration</h2><p>Versioned KPI formulas, weights, thresholds, source mappings and rule parameters. Published versions are immutable.</p></div><div className="reporting-config-heading-actions"><button className="button-secondary small" onClick={() => void loadBase()}><RefreshCw size={13}/> Refresh</button>{canSteward && <button className="button-primary small" onClick={() => { setCreateOpen((v) => !v); setError(""); }}><FilePlus2 size={13}/> New configuration</button>}</div></div>
    {error && <div className="reporting-config-message error"><AlertCircle size={15}/>{error}</div>}
    {notice && <div className="reporting-config-message"><CheckCircle2 size={15}/>{notice}</div>}
    <div className="reporting-config-layout">
      <aside className="panel reporting-config-list"><div className="reporting-config-panel-title"><strong>Configuration sets</strong><span>{sets.length}</span></div>
        {loading ? <div className="reporting-config-empty"><LoaderCircle className="spin" size={18}/> Loading…</div> : sets.length ? sets.map((item) => <button key={item.id} className={selectedSetId === item.id ? "reporting-config-set selected" : "reporting-config-set"} onClick={() => setSelectedSetId(item.id)}><strong>{item.configuration_code}</strong><span>{item.name}</span><small>{item.scope_type === "global" ? "Global" : projects.find((p) => p.id === item.project_id)?.project_code ?? "Project scope"}</small></button>) : <div className="reporting-config-empty">No reporting configurations have been created.</div>}
      </aside>
      <section className="panel reporting-config-workspace">
        <div className="reporting-config-panel-title"><div><strong>{selectedSetTitle}</strong><span>{selectedSet ? (selectedSet.scope_type === "global" ? "Global configuration" : "Project-scoped configuration") : "Versioned configuration workspace"}</span></div>{selectedSet && <span>{versions.length} versions</span>}</div>
        {!selectedSet ? <div className="reporting-config-empty large">Create or select a configuration set to manage dimensions, KPI definitions and rule parameters.</div> : <>
          <div className="reporting-config-version-bar"><label>Version<select value={selectedVersionId} onChange={(e) => setSelectedVersionId(e.target.value)}><option value="">Select version</option>{versions.map((version) => <option key={version.id} value={version.id}>v{version.version_number} · {label(version.status)}</option>)}</select></label><div className="reporting-config-version-meta">{selectedVersion && <><span>Change reason: {selectedVersion.change_summary}</span><span>Created {dateTime(selectedVersion.created_at)} · {selectedVersion.created_by?.slice(0,8) ?? "Unknown actor"}</span><span>Submitted {dateTime(selectedVersion.submitted_at)} · {selectedVersion.submitted_by?.slice(0,8) ?? "—"}</span><span>Approved {dateTime(selectedVersion.approved_at)} · {selectedVersion.approved_by?.slice(0,8) ?? "—"}</span><span>Published {dateTime(selectedVersion.published_at)} · {selectedVersion.published_by?.slice(0,8) ?? "—"}</span></>}</div></div>
          {detailLoading ? <div className="reporting-config-empty"><LoaderCircle className="spin" size={18}/> Loading configuration version…</div> : selectedVersion && <>
            <div className="reporting-config-json-grid">
              <label><span>Reporting dimensions JSON</span><small>Active dimension weights must all be set or all omitted; if set, they must total 1.0. Missing-data status is Not Reported or Insufficient Data.</small><textarea spellCheck={false} disabled={!canEditDraft} value={dimensionsJson} onChange={(e) => setDimensionsJson(e.target.value)}/></label>
              <label><span>KPI definitions JSON</span><small>Each KPI selects an allowlisted formula template, source mapping and parameters. Active KPI weights within each dimension must total 1.0 when used.</small><textarea spellCheck={false} disabled={!canEditDraft} value={kpisJson} onChange={(e) => setKpisJson(e.target.value)}/></label>
              <label><span>Rule parameters JSON</span><small>Configure thresholds, date basis, weights and other rule values. Validation is enforced by the database.</small><textarea spellCheck={false} disabled={!canEditDraft} value={parametersJson} onChange={(e) => setParametersJson(e.target.value)}/></label>
            </div>
            <div className="reporting-risk-scoring-guide"><div><strong>Per-risk scoring (optional)</strong><small>To activate the Top 5 Risk Watchlist, add the `risk_scoring` parameters below. The score is a weighted sum of probability and impact normalized to their configured scale maxima, multiplied by score_multiplier. Starter values are examples only; set the scales, weights and multiplier to the approved PMO model. Project-specific scoring overrides the global rule; more than one active rule set at the same scope leaves scores Not Reported.</small></div>{canEditDraft && <button className="button-secondary small" onClick={insertRiskScoringStarter}>Insert starter parameters</button>}</div>
            <div className="reporting-config-templates"><strong>Available formula templates</strong><div>{formulaCatalog.map((template) => <article key={template.code}><span>{template.code}</span><b>{label(template.method)}</b><small>{template.description}</small><small>Required: {template.required.join(", ")}</small></article>)}</div></div>
            {canEditDraft && <div className="reporting-config-actions"><label>Change reason<input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Minimum 8 characters"/></label><button className="button-primary small" disabled={busy || reason.trim().length < 8} onClick={() => void saveDraftRules()}><Save size={13}/> Save draft rules</button><button className="button-secondary small" disabled={busy || reason.trim().length < 8} onClick={() => void transition("submit")}>Submit for approval</button></div>}
            {selectedVersion.status === "submitted" && canApprove && <div className="reporting-config-actions"><label>Approval reason<input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Minimum 8 characters"/></label><button className="button-primary small" disabled={busy || reason.trim().length < 8} onClick={() => void transition("approve")}>Approve version</button></div>}
            {selectedVersion.status === "approved" && canApprove && <div className="reporting-config-actions"><label>Publication reason<input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Minimum 8 characters"/></label><button className="button-primary small" disabled={busy || reason.trim().length < 8 || !selectedVersion.effective_from} onClick={() => void transition("publish")}>Publish version</button></div>}
            {selectedVersion.status === "published" && canApprove && <div className="reporting-config-actions"><label>Supersede reason<input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Minimum 8 characters"/></label><button className="button-secondary small" disabled={busy || reason.trim().length < 8} onClick={() => void transition("supersede")}>Supersede version</button></div>}
            {!canEditDraft && <div className="reporting-config-readonly"><ShieldCheck size={14}/> This version is read-only. Draft edits are available to Configuration Stewards; approval and publication are restricted to Configuration Approvers.</div>}
          </>}
        </>}
      </section>
    </div>
    {createOpen && <div className="reporting-config-create panel"><div className="reporting-config-panel-title"><div><strong>Create reporting configuration draft</strong><span>Start a new set or create the next version; existing rules are copied into successor drafts.</span></div></div>
      {selectedSet && <label className="reporting-config-checkbox"><input type="checkbox" checked={createForm.useExistingSet} onChange={(e) => setCreateForm((f) => ({ ...f, useExistingSet: e.target.checked }))}/> Create the next version of {selectedSet.configuration_code}</label>}
      <div className="reporting-config-create-grid">
      {!createForm.useExistingSet && <><label>Scope<select value={createForm.scope_type} onChange={(e) => setCreateForm((f) => ({ ...f, scope_type: e.target.value as "global" | "project", project_id: "" }))}><option value="global">Global</option><option value="project">Project-specific</option></select></label>
      {createForm.scope_type === "project" && <label>Project<select value={createForm.project_id} onChange={(e) => setCreateForm((f) => ({ ...f, project_id: e.target.value }))}><option value="">Select project</option>{allowedProjects.map((project) => <option key={project.id} value={project.id}>{project.project_code} · {project.name}</option>)}</select></label>}
      <label>Configuration code<input value={createForm.configuration_code} onChange={(e) => setCreateForm((f) => ({ ...f, configuration_code: e.target.value.toUpperCase() }))}/></label>
      <label>Name<input value={createForm.name} onChange={(e) => setCreateForm((f) => ({ ...f, name: e.target.value }))}/></label>
      <label className="wide">Description<textarea value={createForm.description} onChange={(e) => setCreateForm((f) => ({ ...f, description: e.target.value }))}/></label></>}
      <label>Effective from<input type="datetime-local" value={createForm.effective_from} onChange={(e) => setCreateForm((f) => ({ ...f, effective_from: e.target.value }))}/></label>
      <label>Effective to<input type="datetime-local" value={createForm.effective_to} onChange={(e) => setCreateForm((f) => ({ ...f, effective_to: e.target.value }))}/></label>
    </div><div className="reporting-config-actions"><label>Creation reason<input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Minimum 8 characters"/></label><button className="button-primary small" disabled={busy || detailLoading || reason.trim().length < 8 || !createForm.effective_from || (createForm.useExistingSet ? !selectedSet : !createForm.configuration_code.trim() || !createForm.name.trim() || (createForm.scope_type === "project" && !createForm.project_id))} onClick={() => void createDraft()}>{busy ? "Creating…" : "Create draft version"}</button></div></div>}
  </div>;
}
