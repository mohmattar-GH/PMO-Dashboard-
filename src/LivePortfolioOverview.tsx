import { useEffect, useMemo, useState } from "react";
import { AlertCircle, BriefcaseBusiness, CalendarDays, CheckCircle2, CircleHelp, LoaderCircle, Search } from "lucide-react";
import { supabase } from "./lib/supabase";

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

function formatDate(value: string | null) {
  if (!value) return "Not reported";
  return new Intl.DateTimeFormat(undefined, { day: "2-digit", month: "short", year: "numeric" }).format(new Date(value + "T00:00:00"));
}

function displayStatus(value: string) {
  return value.replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export default function LivePortfolioOverview({ search }: { search: string }) {
  const [projects, setProjects] = useState<ProjectRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    async function loadProjects() {
      if (!supabase) {
        setError("Supabase is not configured for this environment.");
        setLoading(false);
        return;
      }
      setLoading(true);
      const { data, error: queryError } = await supabase
        .from("projects")
        .select("id, project_code, name, lifecycle_status, start_date, target_end_date, project_manager_id, client:clients(name)")
        .order("project_code", { ascending: true });
      if (!active) return;
      if (queryError) {
        setError(queryError.message);
        setProjects([]);
      } else {
        setError("");
        setProjects((data ?? []) as unknown as ProjectRecord[]);
      }
      setLoading(false);
    }
    void loadProjects();
    return () => { active = false; };
  }, []);

  const filteredProjects = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return projects;
    return projects.filter((project) =>
      [project.project_code, project.name, project.client?.name ?? "", project.lifecycle_status]
        .join(" ").toLowerCase().includes(term)
    );
  }, [projects, search]);

  const activeCount = projects.filter((project) => project.lifecycle_status === "active").length;
  const completedCount = projects.filter((project) => project.lifecycle_status === "completed").length;
  const otherCount = projects.length - activeCount - completedCount;

  return <div className="live-overview">
    <div className="live-source-strip"><span><span className="live-source-dot" /> LIVE DATABASE</span><span>Project register · permission-filtered by Supabase RLS</span><span className="live-source-note">No demo records</span></div>
    <section className="live-summary-grid">
      <article className="live-summary-card"><span>Total projects</span><strong>{loading ? "—" : projects.length}</strong><small>Visible to your account</small></article>
      <article className="live-summary-card"><span>Active</span><strong>{loading ? "—" : activeCount}</strong><small>Lifecycle status = Active</small></article>
      <article className="live-summary-card"><span>Completed</span><strong>{loading ? "—" : completedCount}</strong><small>Lifecycle status = Completed</small></article>
      <article className="live-summary-card"><span>Other statuses</span><strong>{loading ? "—" : otherCount}</strong><small>Draft, on hold, cancelled or archived</small></article>
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
          <p>{projects.length === 0 ? "The database is connected, but no project records are registered or visible to this account. Dashboard KPIs will remain unreported until real project data is entered." : "Try another project name, code, client or lifecycle status."}</p>
        </div> : <div className="table-scroll">
          <table><thead><tr><th>PROJECT</th><th>CLIENT</th><th>PROJECT MANAGER</th><th>LIFECYCLE STATUS</th><th>START DATE</th><th>TARGET END</th></tr></thead>
            <tbody>{filteredProjects.map((project) => <tr key={project.id}>
              <td><div className="project-name-cell"><strong>{project.name}</strong><small>{project.project_code}</small></div></td>
              <td>{project.client?.name ?? "Not reported"}</td>
              <td>{project.project_manager_id ? "Assigned" : "Not assigned"}</td>
              <td><span className="live-status-tag">{displayStatus(project.lifecycle_status)}</span></td>
              <td>{formatDate(project.start_date)}</td>
              <td>{formatDate(project.target_end_date)}</td>
            </tr>)}</tbody>
          </table>
        </div>}
      <div className="live-register-footer"><span><CheckCircle2 size={14}/> Read-only live query · database policies remain authoritative</span><span>Last loaded: {loading ? "—" : new Date().toLocaleTimeString()}</span></div>
    </section>

    <section className="live-data-quality">
      <div><CircleHelp size={17}/><strong>Metrics not yet reportable</strong></div>
      <p>Project health, configurable project phase, verified progress, milestone achievement, risk exposure and executive decisions will display as Not Reported until their live data and approved calculation/configuration paths are connected. No sample values are substituted.</p>
    </section>
  </div>;
}
