import { useCallback, useEffect, useMemo, useState } from "react";
import { AlertCircle, Archive, CheckCircle2, Clock3, FilePlus2, LoaderCircle, RefreshCw, ShieldCheck } from "lucide-react";
import { supabase } from "./lib/supabase";

type Cycle = { id: string; cycle_code: string; period_start: string; period_end: string; cutoff_at: string; as_of_date: string; timezone: string; status: string; created_at: string; closed_at: string | null };
type Snapshot = { id: string; reporting_cycle_id: string; generated_at: string; generated_by: string | null; snapshot_status: string; source_watermark: string | null; portfolio_summary: Record<string, unknown> };
type ProjectSnapshot = { id: string; project_id: string; source_updated_at: string | null; calculated_health: string | null; reported_health: string | null; snapshot_payload: Record<string, unknown> };
type Project = { id: string; project_code: string; name: string };
type ConfigVersion = { configuration_set_id: string; status: string; effective_from: string | null; effective_to: string | null; published_at: string | null };

const dateLabel = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(value + (value.length === 10 ? "T00:00:00" : ""))) : "Not reported";
const dateTime = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : "Not recorded";
const label = (value: string) => value.replace(/_/g, " ").replace(/\b\w/g, (s) => s.toUpperCase());
const statusClass = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, "-");
const asObject = (value: unknown): Record<string, unknown> => value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};

export default function ReportsSnapshots({ globalRoles }: { globalRoles: string[] }) {
  const isAdmin = globalRoles.includes("platform_admin");
  const canView = isAdmin || globalRoles.includes("executive_viewer");
  const [cycles, setCycles] = useState<Cycle[]>([]);
  const [snapshots, setSnapshots] = useState<Snapshot[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [configVersions, setConfigVersions] = useState<ConfigVersion[]>([]);
  const [projectSnapshots, setProjectSnapshots] = useState<ProjectSnapshot[]>([]);
  const [selectedSnapshotId, setSelectedSnapshotId] = useState("");
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [reason, setReason] = useState("");
  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState({ cycle_code: "", period_start: "", period_end: "", as_of_date: "", cutoff_at: "", timezone: "UTC" });

  const selectedSnapshot = useMemo(() => snapshots.find((item) => item.id === selectedSnapshotId) ?? null, [snapshots, selectedSnapshotId]);
  const snapshotByCycle = useMemo(() => new Map(snapshots.map((item) => [item.reporting_cycle_id, item])), [snapshots]);

  const loadData = useCallback(async () => {
    if (!supabase) { setError("Supabase is not configured."); setLoading(false); return; }
    setLoading(true); setError("");
    const [cycleResult, snapshotResult, projectResult, configSetResult] = await Promise.all([
      supabase.from("reporting_cycles").select("id,cycle_code,period_start,period_end,cutoff_at,as_of_date,timezone,status,created_at,closed_at").order("period_start", { ascending: false }),
      supabase.from("portfolio_snapshots").select("id,reporting_cycle_id,generated_at,generated_by,snapshot_status,source_watermark,portfolio_summary").order("generated_at", { ascending: false }),
      supabase.from("projects").select("id,project_code,name").order("project_code"),
      supabase.from("reporting_configuration_sets").select("id").eq("scope_type", "global")
    ]);
    if (cycleResult.error) setError(cycleResult.error.message);
    if (snapshotResult.error) setError(snapshotResult.error.message);
    if (projectResult.error) setError(projectResult.error.message);
    setCycles((cycleResult.data ?? []) as Cycle[]);
    setSnapshots((snapshotResult.data ?? []) as Snapshot[]);
    setProjects((projectResult.data ?? []) as Project[]);
    const setIds = (configSetResult.data ?? []).map((row: { id: string }) => row.id);
    if (setIds.length) {
      const versions = await supabase.from("reporting_configuration_versions").select("configuration_set_id,status,effective_from,effective_to,published_at").in("configuration_set_id", setIds).eq("status", "published");
      setConfigVersions((versions.data ?? []) as ConfigVersion[]);
    } else setConfigVersions([]);
    setSelectedSnapshotId((current) => (snapshotResult.data ?? []).some((item: Snapshot) => item.id === current) ? current : (snapshotResult.data?.[0]?.id ?? ""));
    setLoading(false);
  }, []);

  const loadSnapshotDetails = useCallback(async (snapshotId: string) => {
    if (!supabase || !snapshotId) { setProjectSnapshots([]); return; }
    setDetailLoading(true);
    const { data, error: detailError } = await supabase.from("project_snapshots")
      .select("id,project_id,source_updated_at,calculated_health,reported_health,snapshot_payload")
      .eq("portfolio_snapshot_id", snapshotId).order("project_id");
    if (detailError) setError(detailError.message);
    setProjectSnapshots((data ?? []) as ProjectSnapshot[]);
    setDetailLoading(false);
  }, []);

  useEffect(() => { if (canView) void loadData(); else setLoading(false); }, [canView, loadData]);
  useEffect(() => { if (selectedSnapshotId) void loadSnapshotDetails(selectedSnapshotId); else setProjectSnapshots([]); }, [selectedSnapshotId, loadSnapshotDetails]);

  const invokeAction = async (action: string, payload: Record<string, unknown>, actionReason: string) => {
    if (!supabase) return null;
    if (actionReason.trim().length < 8) { setError("Enter a reason of at least 8 characters."); return null; }
    setBusy(true); setError(""); setNotice("");
    const { data, error: actionError } = await supabase.functions.invoke("weekly-reporting-snapshots", { body: { action, reason: actionReason.trim(), ...payload } });
    if (actionError) { setError(actionError.message || "Reporting action failed."); setBusy(false); return null; }
    const response = data as { error?: string } | null;
    if (response?.error) { setError(response.error); setBusy(false); return null; }
    setNotice("Reporting action completed. The audit record was written.");
    setBusy(false);
    return data as Record<string, unknown>;
  };

  const createCycle = async () => {
    if (!form.cycle_code.trim() || !form.period_start || !form.period_end || !form.as_of_date || !form.cutoff_at || !form.timezone.trim()) { setError("Complete all reporting cycle fields."); return; }
    if (form.period_end < form.period_start || form.as_of_date < form.period_start || form.as_of_date > form.period_end) { setError("The period and as-of date range is invalid."); return; }
    const result = await invokeAction("create_cycle", {
      cycle_code: form.cycle_code.trim(), period_start: form.period_start, period_end: form.period_end,
      as_of_date: form.as_of_date, cutoff_at: new Date(form.cutoff_at).toISOString(), timezone: form.timezone.trim()
    }, reason);
    if (!result) return;
    setShowCreate(false); setReason(""); setForm({ cycle_code: "", period_start: "", period_end: "", as_of_date: "", cutoff_at: "", timezone: "UTC" });
    await loadData();
  };

  const closeCycle = async (cycle: Cycle) => {
    const result = await invokeAction("close_cycle", { reporting_cycle_id: cycle.id }, reason);
    if (result) { setReason(""); await loadData(); }
  };
  const buildSnapshot = async (cycle: Cycle) => {
    const result = await invokeAction("build_snapshot", { reporting_cycle_id: cycle.id }, reason);
    if (result) {
      setReason("");
      const snapshotId = String(result.portfolio_snapshot_id ?? "");
      await loadData();
      if (snapshotId) setSelectedSnapshotId(snapshotId);
    }
  };
  const finalizeSnapshot = async (snapshot: Snapshot) => {
    const result = await invokeAction("finalize_snapshot", { portfolio_snapshot_id: snapshot.id }, reason);
    if (result) { setReason(""); await loadData(); }
  };

  const hasGlobalConfigAt = (cycle: Cycle) => {
    const boundary = cycle.closed_at ?? cycle.cutoff_at;
    return configVersions.some((version) => version.effective_from && version.published_at && new Date(version.effective_from) <= new Date(boundary) && new Date(version.published_at) <= new Date(boundary) && (!version.effective_to || new Date(version.effective_to) > new Date(boundary)));
  };

  if (!canView) return <section className="panel reports-access-denied"><ShieldCheck size={24}/><strong>Reporting snapshots are restricted</strong><span>Requires Platform Administrator or Executive Viewer access.</span></section>;

  return <div className="reports-snapshots-module">
    <div className="reports-snapshots-heading"><div><span className="module-eyebrow">WEEKLY GOVERNANCE</span><h2>Reports & Snapshots</h2><p>Immutable weekly portfolio snapshots with reporting-cycle cutoff and configuration lineage.</p></div><div className="reports-snapshots-actions"><button className="button-secondary small" onClick={() => void loadData()}><RefreshCw size={13}/> Refresh</button>{isAdmin && <button className="button-primary small" onClick={() => { setShowCreate((v) => !v); setError(""); }}><FilePlus2 size={13}/> New reporting cycle</button>}</div></div>
    {error && <div className="reports-message error"><AlertCircle size={15}/>{error}</div>}
    {notice && <div className="reports-message"><CheckCircle2 size={15}/>{notice}</div>}
    {isAdmin && <section className="panel reports-cycle-panel"><div className="reports-panel-heading"><div><h3>Reporting cycles</h3><span>Close only after the scheduled cutoff. Snapshot creation requires a published global configuration.</span></div><span>{cycles.length} cycles</span></div>
      {isAdmin && cycles.length > 0 && <div className="reports-cycle-reason"><label>Cycle action reason<input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Minimum 8 characters"/></label></div>}
      {loading ? <div className="reports-empty"><LoaderCircle className="spin" size={17}/> Loading reporting cycles…</div> : cycles.length ? <div className="reports-cycle-list">{cycles.map((cycle) => {
        const snapshot = snapshotByCycle.get(cycle.id);
        const cutoffReached = new Date(cycle.cutoff_at).getTime() <= Date.now();
        const configReady = hasGlobalConfigAt(cycle);
        return <article className="reports-cycle-row" key={cycle.id}><div className="reports-cycle-main"><strong>{cycle.cycle_code}</strong><span>{dateLabel(cycle.period_start)} – {dateLabel(cycle.period_end)} · As of {dateLabel(cycle.as_of_date)}</span><small>Cutoff {dateTime(cycle.cutoff_at)} · {cycle.timezone}</small></div><span className={"project-status-pill " + statusClass(cycle.status)}>{label(cycle.status)}</span><div className="reports-cycle-row-actions">
          {cycle.status === "open" && <button className="button-secondary small" disabled={busy || reason.trim().length < 8 || !cutoffReached} onClick={() => void closeCycle(cycle)} title={!cutoffReached ? "Scheduled cutoff has not been reached" : "Close reporting cycle"}><Clock3 size={12}/> Close cycle</button>}
          {cycle.status === "closed" && !snapshot && <button className="button-primary small" disabled={busy || reason.trim().length < 8 || !configReady} onClick={() => void buildSnapshot(cycle)} title={!configReady ? "Publish a global reporting configuration effective at the cutoff first" : "Build immutable portfolio snapshot"}><Archive size={12}/> Build snapshot</button>}
          {snapshot && <button className="button-secondary small" onClick={() => setSelectedSnapshotId(snapshot.id)}>View snapshot</button>}
          {cycle.status === "closed" && !configReady && !snapshot && <small className="reports-warning">No effective published global KPI configuration</small>}
        </div></article>;
      })}</div> : <div className="reports-empty">No reporting cycles have been created.</div>}
    </section>}
    <div className="reports-snapshot-layout">
      <aside className="panel reports-snapshot-list"><div className="reports-panel-heading"><div><h3>Snapshot archive</h3><span>Finalized and in-progress snapshot records</span></div><span>{snapshots.length}</span></div>
        {loading ? <div className="reports-empty"><LoaderCircle className="spin" size={17}/> Loading snapshots…</div> : snapshots.length ? snapshots.map((snapshot) => {
          const cycle = cycles.find((item) => item.id === snapshot.reporting_cycle_id);
          return <button className={selectedSnapshotId === snapshot.id ? "reports-snapshot-item selected" : "reports-snapshot-item"} key={snapshot.id} onClick={() => setSelectedSnapshotId(snapshot.id)}><strong>{cycle?.cycle_code ?? "Weekly snapshot"}</strong><span>{dateTime(snapshot.generated_at)}</span><small>{snapshot.portfolio_summary?.project_count ?? "—"} projects · {label(snapshot.snapshot_status)}</small></button>;
        }) : <div className="reports-empty">No portfolio snapshots have been generated.</div>}
      </aside>
      <section className="panel reports-snapshot-detail">
        {!selectedSnapshot ? <div className="reports-empty large">Select a snapshot to review its portfolio summary and captured project health.</div> : <>
          <div className="reports-panel-heading"><div><h3>{cycles.find((item) => item.id === selectedSnapshot.reporting_cycle_id)?.cycle_code ?? "Portfolio Snapshot"}</h3><span>Generated {dateTime(selectedSnapshot.generated_at)} · Source watermark {dateTime(selectedSnapshot.source_watermark)}</span></div><span className={"project-status-pill " + statusClass(selectedSnapshot.snapshot_status)}>{label(selectedSnapshot.snapshot_status)}</span></div>
          {isAdmin && selectedSnapshot.snapshot_status === "building" && <div className="reports-finalize-bar"><label>Finalization reason<input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Minimum 8 characters"/></label><button className="button-primary small" disabled={busy || reason.trim().length < 8} onClick={() => void finalizeSnapshot(selectedSnapshot)}>Finalize immutable snapshot</button></div>}
          <div className="reports-summary-grid">{Object.entries(selectedSnapshot.portfolio_summary).map(([key, value]) => <article key={key}><span>{label(key)}</span><strong>{typeof value === "object" ? JSON.stringify(value) : String(value ?? "Not reported")}</strong></article>)}</div>
          <div className="reports-project-snapshots"><div className="reports-panel-heading"><div><h3>Captured project records</h3><span>{projectSnapshots.length} project snapshots</span></div></div>
            {detailLoading ? <div className="reports-empty"><LoaderCircle className="spin" size={17}/> Loading project snapshots…</div> : projectSnapshots.length ? <div className="reports-project-grid">{projectSnapshots.map((item) => {
              const project = projects.find((p) => p.id === item.project_id);
              const payload = asObject(item.snapshot_payload);
              const projectRecord = asObject(payload.project_record);
              return <article className="reports-project-card" key={item.id}><strong>{project?.project_code ?? "Project"} · {project?.name ?? String(projectRecord.name ?? "Project snapshot")}</strong><div className="reports-health-row"><span>Calculated health</span><b>{item.calculated_health ?? "Not Reported"}</b></div><div className="reports-health-row"><span>PM-reported health</span><b>{item.reported_health ?? "Not Reported"}</b></div><div className="reports-health-row"><span>KPI calculation</span><b>{String(payload.kpi_calculation_status ?? "Not Reported")}</b></div><div className="reports-health-row"><span>Data completeness</span><b>{String(payload.data_completeness_status ?? "Not Reported")}</b></div><small>Source updated {dateTime(item.source_updated_at)}</small></article>;
            })}</div> : <div className="reports-empty">No project records are available in this snapshot.</div>}
          </div>
        </>}
      </section>
    </div>
    {isAdmin && showCreate && <section className="panel reports-create-panel"><div className="reports-panel-heading"><div><h3>Create reporting cycle</h3><span>Cycle creation is audited. The cutoff defines the source-data visibility boundary.</span></div></div><div className="reports-create-grid">
      <label>Cycle code<input value={form.cycle_code} onChange={(e) => setForm((f) => ({ ...f, cycle_code: e.target.value.toUpperCase() }))} placeholder="e.g. 2026-W48"/></label>
      <label>Timezone<input value={form.timezone} onChange={(e) => setForm((f) => ({ ...f, timezone: e.target.value }))} placeholder="IANA timezone"/></label>
      <label>Period start<input type="date" value={form.period_start} onChange={(e) => setForm((f) => ({ ...f, period_start: e.target.value }))}/></label>
      <label>Period end<input type="date" value={form.period_end} onChange={(e) => setForm((f) => ({ ...f, period_end: e.target.value }))}/></label>
      <label>As-of date<input type="date" value={form.as_of_date} onChange={(e) => setForm((f) => ({ ...f, as_of_date: e.target.value }))}/></label>
      <label>Scheduled cutoff<input type="datetime-local" value={form.cutoff_at} onChange={(e) => setForm((f) => ({ ...f, cutoff_at: e.target.value }))}/></label>
    </div><div className="reports-create-actions"><label>Creation reason<input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Minimum 8 characters"/></label><button className="button-primary small" disabled={busy || reason.trim().length < 8 || !form.cycle_code.trim() || !form.period_start || !form.period_end || !form.as_of_date || !form.cutoff_at || !form.timezone.trim()} onClick={() => void createCycle()}>{busy ? "Creating…" : "Create cycle"}</button></div></section>}
  </div>;
}
