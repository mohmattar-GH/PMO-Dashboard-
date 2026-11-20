import { useEffect, useMemo, useState } from "react";
import { AlertCircle, BriefcaseBusiness, CheckCircle2, CircleHelp, LoaderCircle, Search } from "lucide-react";
import { supabase } from "./lib/supabase";

type SnapshotRecord = {
  project_id: string;
  calculated_health: string | null;
  reported_health: string | null;
  created_at: string;
};

type ProjectRecord = {
  id: string;
  project_code: string;
  name: string;
  lifecycle_status: string;
  start_date: string | null;
  target_end_date: string | null;
  project_manager_id: string | null;
  client: { name: string } | null;
};

type CurrentPhaseRecord = {
  project_id: string;
  phase_code: string;
  phase_name: string;
  display_order: number;
  progress_percent: number | null;
  planned_start_date: string | null;
  forecast_completion_date: string | null;
  actual_completion_date: string | null;
  phase_entered_at: string;
};

type PhaseChangeRecord = {
  id: string;
  project_id: string;
  project_code: string;
  project_name: string;
  previous_phase_name: string | null;
  phase_name: string;
  entered_at: string;
  change_reason: string | null;
};

function formatDate(value: string | null) {
  if (!value) return "Not reported";
  return new Intl.DateTimeFormat(undefined, { day: "2-digit", month: "short", year: "numeric" }).format(new Date(value + "T00:00:00"));
}

function formatTimestamp(value: string) {
  return new Intl.DateTimeFormat(undefined, { day: "2-digit", month: "short", year: "numeric" }).format(new Date(value));
}

function displayStatus(value: string) {
  return value.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export default function LivePortfolioOverview({ search }: { search: string }) {
  const [projects, setProjects] = useState<ProjectRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [latestHealth, setLatestHealth] = useState<Record<string, string>>({});
  const [healthLoading, setHealthLoading] = useState(true);
  const [healthError, setHealthError] = useState("");
  const [currentPhases, setCurrentPhases] = useState<Record<string, CurrentPhaseRecord>>({});
  const [recentPhaseChanges, setRecentPhaseChanges] = useState<PhaseChangeRecord[]>([]);
  const [phaseLoading, setPhaseLoading] = useState(true);
  const [phaseError, setPhaseError] = useState("");

  useEffect(() => {
    let active = true;
    async function loadProjects() {
      if (!supabase) {
        setError("Supabase is not configured for this environment.");
        setLoading(false);
        setHealthLoading(false);
        setPhaseLoading(false);
        return;
      }
      setLoading(true);
      const [projectResult, snapshotResult, phaseResult, changeResult] = await Promise.all([
        supabase.from("projects")
          .select("id, project_code, name, lifecycle_status, start_date, target_end_date, project_manager_id, client:clients(name)")
          .order("project_code", { ascending: true }),
        (async () => {
          const rows: SnapshotRecord[] = [];
          for (let offset = 0; ; offset += 1000) {
            const { data, error } = await supabase
              .from("project_snapshot_index")
              .select("project_id, calculated_health, reported_health, created_at")
              .order("created_at", { ascending: false })
              .range(offset, offset + 999);
            if (error) return { rows: [], error };
            const page = (data ?? []) as SnapshotRecord[];
            rows.push(...page);
            if (page.length < 1000) break;
          }
          return { rows, error: null };
        })(),
        supabase.from("project_current_phase")
          .select("project_id, phase_code, phase_name, display_order, progress_percent, planned_start_date, forecast_completion_date, actual_completion_date, phase_entered_at"),
        supabase.from("project_phase_change_log")
          .select("id, project_id, project_code, project_name, previous_phase_name, phase_name, entered_at, change_reason")
          .order("entered_at", { ascending: false })
          .limit(10)
      ]);
      if (!active) return;
      if (projectResult.error) {
        setError(projectResult.error.message);
        setProjects([]);
      } else {
        setError("");
        setProjects((projectResult.data ?? []) as unknown as ProjectRecord[]);
      }
      if (snapshotResult.error) {
        setHealthError(snapshotResult.error.message);
        setLatestHealth({});
      } else {
        setHealthError("");
        const newestByProject: Record<string, string> = {};
        for (const snapshot of snapshotResult.rows) {
          if (newestByProject[snapshot.project_id] !== undefined) continue;
          newestByProject[snapshot.project_id] = (snapshot.calculated_health ?? "not_reported").toLowerCase();
        }
        setLatestHealth(newestByProject);
      }
      if (phaseResult.error || changeResult.error) {
        setPhaseError([phaseResult.error?.message, changeResult.error?.message].filter(Boolean).join(" · "));
        setCurrentPhases({});
        setRecentPhaseChanges([]);
      } else {
        setPhaseError("");
        const phaseMap: Record<string, CurrentPhaseRecord> = {};
        for (const phase of (phaseResult.data ?? []) as CurrentPhaseRecord[]) {
          phaseMap[phase.project_id] = phase;
        }
        setCurrentPhases(phaseMap);
        setRecentPhaseChanges((changeResult.data ?? []) as PhaseChangeRecord[]);
      }
      setLoading(false);
      setHealthLoading(false);
      setPhaseLoading(false);
    }
    void loadProjects();
    return () => { active = false; };
  }, []);

  const filteredProjects = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return projects;
    return projects.filter((project) =>
      [project.project_code, project.name, project.client?.name ?? "", project.lifecycle_status,
        currentPhases[project.id]?.phase_name ?? ""]
        .join(" ").toLowerCase().includes(term)
    );
  }, [projects, search, currentPhases]);

  const activeCount = projects.filter((project) => project.lifecycle_status === "active").length;
  const completedCount = projects.filter((project) => project.lifecycle_status === "completed").length;
  const otherCount = projects.length - activeCount - completedCount;
  const healthFor = (projectId: string): "green" | "amber" | "red" | "not_reported" => {
    const value = latestHealth[projectId];
    if (value === "green" || value === "amber" || value === "red") return value;
    return "not_reported";
  };
  const healthCounts = projects.reduce((counts, project) => {
    counts[healthFor(project.id)] += 1;
    return counts;
  }, { green: 0, amber: 0, red: 0, not_reported: 0 });
  const phaseCounts = Object.values(currentPhases).reduce<Record<string, { count: number; order: number }>>((counts, phase) => {
    const existing = counts[phase.phase_name];
    counts[phase.phase_name] = { count: (existing?.count ?? 0) + 1, order: phase.display_order };
    return counts;
  }, {});
  const phaseDistribution = Object.entries(phaseCounts).sort((a, b) => a[1].order - b[1].order);
  const projectsWithPhase = Object.keys(currentPhases).length;
  const projectsWithoutPhase = Math.max(0, projects.length - projectsWithPhase);

  return <div className="live-overview">
    <div className="live-source-strip"><span><span className="live-source-dot" /> LIVE DATABASE</span><span>Project register · permission-filtered by Supabase RLS</span><span className="live-source-note">No demo records</span></div>
    <section className="live-summary-grid">
      <article className="live-summary-card"><span>Total projects</span><strong>{loading ? "—" : projects.length}</strong><small>Visible to your account</small></article>
      <article className="live-summary-card"><span>Active</span><strong>{loading ? "—" : activeCount}</strong><small>Lifecycle status = Active</small></article>
      <article className="live-summary-card"><span>Completed</span><strong>{loading ? "—" : completedCount}</strong><small>Lifecycle status = Completed</small></article>
      <article className="live-summary-card"><span>Other statuses</span><strong>{loading ? "—" : otherCount}</strong><small>Draft, on hold, cancelled or archived</small></article>
    </section>

    <section className="live-health-section">
      <div className="live-section-heading"><div><h3>Latest calculated project health</h3><p>Based on each project's most recent snapshot visible to this account</p></div><span>Calculated health only · PM-reported status remains separate</span></div>
      {healthError && <div className="live-message live-error"><AlertCircle size={16}/><span>Health snapshots could not be loaded: {healthError}</span></div>}
      <div className="live-health-grid">
        <article><span className="live-health-indicator green" /> <div><strong>{loading || healthLoading ? "—" : healthCounts.green}</strong><small>Green</small></div></article>
        <article><span className="live-health-indicator amber" /> <div><strong>{loading || healthLoading ? "—" : healthCounts.amber}</strong><small>Amber</small></div></article>
        <article><span className="live-health-indicator red" /> <div><strong>{loading || healthLoading ? "—" : healthCounts.red}</strong><small>Red</small></div></article>
        <article><span className="live-health-indicator neutral" /> <div><strong>{loading || healthLoading ? "—" : healthCounts.not_reported}</strong><small>Not Reported</small></div></article>
      </div>
    </section>

    <section className="live-phase-section">
      <div className="live-section-heading"><div><h3>Project phase overview</h3><p>Current lifecycle phase is separate from project health and milestone progress</p></div><span>Published lifecycle configuration · permission-filtered</span></div>
      {phaseError && <div className="live-message live-error"><AlertCircle size={16}/><span>Phase information could not be loaded: {phaseError}</span></div>}
      <div className="live-phase-grid">
        <article className="live-phase-card">
          <div className="live-phase-card-heading"><strong>Project Phase Distribution</strong><span>{phaseLoading || loading ? "—" : projectsWithPhase} assigned</span></div>
          {phaseLoading || loading ? <div className="live-phase-empty">Loading phase distribution…</div> :
            phaseDistribution.length === 0 ? <div className="live-phase-empty">No published lifecycle has been assigned to visible projects.</div> :
            <div className="live-phase-bars">{phaseDistribution.map(([name, value]) => <div className="live-phase-bar-row" key={name}>
              <div><span>{name}</span><strong>{value.count}</strong></div>
              <div className="live-phase-track"><span style={{ width: `${projects.length ? (value.count / projects.length) * 100 : 0}%` }} /></div>
            </div>)}</div>}
          {!phaseLoading && !loading && <div className="live-phase-unassigned">{projectsWithoutPhase} project(s) Not configured / Unassigned</div>}
        </article>
        <article className="live-phase-card">
          <div className="live-phase-card-heading"><strong>Recent Phase Changes</strong><span>Latest 10 events</span></div>
          {phaseLoading ? <div className="live-phase-empty">Loading phase history…</div> :
            recentPhaseChanges.length === 0 ? <div className="live-phase-empty">No phase transitions have been recorded.</div> :
            <div className="live-phase-change-list">{recentPhaseChanges.map((change) => <div className="live-phase-change" key={change.id}>
              <div><strong>{change.project_name}</strong><small>{change.project_code}</small></div>
              <div className="live-phase-change-route"><span>{change.previous_phase_name ?? "Unassigned"}</span><span aria-hidden="true">→</span><strong>{change.phase_name}</strong></div>
              <time>{formatTimestamp(change.entered_at)}</time>
            </div>)}</div>}
        </article>
      </div>
    </section>

    <section className="panel live-register-panel">
      <div className="panel-heading">
        <div><h3>Project register</h3><span className="panel-subtitle">Operational project records from the Executive PPM database</span></div>
        <span className="live-register-count">{loading ? "Loading…" : `${filteredProjects.length} of ${projects.length} projects`}</span>
      </div>
      {error && <div className="live-message live-error"><AlertCircle size={16}/><span>{error}</span></div>}
      {loading ? <div className="live-message"><LoaderCircle className="live-spin" size={18}/> Loading projects from Supabase…</div> :
        filteredProjects.length === 0 ? <div className="live-empty">
          <div className="live-empty-icon">{projects.length === 0 ? <BriefcaseBusiness size={22}/> : <Search size={22}/>}</div>
          <strong>{projects.length === 0 ? "No project records are available yet" : "No projects match this search"}</strong>
          <p>{projects.length === 0 ? "The database is connected, but no project records are registered or visible to this account. Dashboard KPIs will remain unreported until real project data is entered." : "Try another project name, code, client, lifecycle status or phase."}</p>
        </div> : <div className="table-scroll">
          <table><thead><tr><th>PROJECT</th><th>CLIENT</th><th>PROJECT MANAGER</th><th>LIFECYCLE STATUS</th><th>CALCULATED HEALTH</th><th>PROJECT PHASE</th><th>START DATE</th><th>TARGET END</th></tr></thead>
            <tbody>{filteredProjects.map((project) => {
              const phase = currentPhases[project.id];
              return <tr key={project.id}>
                <td><div className="project-name-cell"><strong>{project.name}</strong><small>{project.project_code}</small></div></td>
                <td>{project.client?.name ?? "Not reported"}</td>
                <td>{project.project_manager_id ? "Assigned" : "Not assigned"}</td>
                <td><span className="live-status-tag">{displayStatus(project.lifecycle_status)}</span></td>
                <td><span className={"live-health-cell " + healthFor(project.id)}>{healthFor(project.id) === "not_reported" ? "Not Reported" : displayStatus(healthFor(project.id))}</span></td>
                <td>{phase ? <div className="live-project-phase"><strong>{phase.phase_name}</strong>{phase.progress_percent !== null && <small>{phase.progress_percent}% reported progress</small>}<small>Forecast: {formatDate(phase.forecast_completion_date)}</small></div> : <span className="live-unconfigured">Not configured</span>}</td>
                <td>{formatDate(project.start_date)}</td>
                <td>{formatDate(project.target_end_date)}</td>
              </tr>;
            })}</tbody>
          </table>
        </div>}
      <div className="live-register-footer"><span><CheckCircle2 size={14}/> Read-only live query · database policies remain authoritative</span><span>Last loaded: {loading ? "—" : new Date().toLocaleTimeString()}</span></div>
    </section>

    <section className="live-data-quality">
      <div><CircleHelp size={17}/><strong>Metrics not yet reportable</strong></div>
      <p>Calculated health is read from the latest safe snapshot index; projects without a snapshot remain Not Reported. Project phase, phase dates, progress and phase changes are read from the governed lifecycle model. Verified delivery progress, milestone achievement, risk exposure and executive decisions remain Not Reported until their governed data paths are connected. No sample values are substituted.</p>
    </section>
  </div>;
}
