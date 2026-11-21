import { useMemo, useState } from "react";
import LivePortfolioOverview from "./LivePortfolioOverview";
import ChangeRequests from "./ChangeRequests";
import Deliverables from "./Deliverables";
import {
  Activity, AlertTriangle, ArrowDownRight, ArrowRight, ArrowUpRight, Bell,
  CalendarDays, Check, CheckCircle2, ChevronDown, ChevronLeft, ChevronRight,
  CircleDollarSign, CircleHelp, Clock3, Command, FileCheck2, FileClock, FileText,
  Filter, Flag, Gauge, LayoutDashboard, Layers3, ListChecks, Menu,
  MoreHorizontal, Presentation, Search, Settings2, ShieldAlert, SlidersHorizontal,
  Target, Users, Wallet, X, BriefcaseBusiness, ClipboardList
} from "lucide-react";

type ProjectStatus = "On track" | "At risk" | "Delayed" | "Completed";
type Project = {
  code: string; name: string; client: string; manager: string; phase: string;
  status: ProjectStatus; progress: number; next: string; due: string; risk: string;
};

const projects: Project[] = [
  { code: "PRJ-024", name: "Digital Transformation", client: "Ministry of Finance", manager: "A. Haddad", phase: "Execution", status: "At risk", progress: 68, next: "UAT sign-off", due: "24 Nov 2026", risk: "High" },
  { code: "PRJ-019", name: "Document Management", client: "Council Secretariat", manager: "S. Khalil", phase: "Testing", status: "On track", progress: 82, next: "Pilot go-live", due: "06 Dec 2026", risk: "Medium" },
  { code: "PRJ-031", name: "Core Banking Upgrade", client: "National Bank", manager: "M. Saleh", phase: "Execution", status: "Delayed", progress: 47, next: "Integration complete", due: "30 Nov 2026", risk: "Critical" },
  { code: "PRJ-027", name: "Customer Portal", client: "Utilities Group", manager: "R. Nasser", phase: "Deployment", status: "On track", progress: 91, next: "Production readiness", due: "28 Nov 2026", risk: "Low" },
  { code: "PRJ-015", name: "Data Warehouse", client: "Public Authority", manager: "L. Omar", phase: "Closure", status: "Completed", progress: 100, next: "Final acceptance", due: "18 Nov 2026", risk: "Low" },
];

const navItems = [
  { label: "Executive Overview", icon: LayoutDashboard },
  { label: "Portfolio", icon: BriefcaseBusiness },
  { label: "Projects", icon: ClipboardList },
  { label: "Master Schedule", icon: CalendarDays },
  { label: "Payments & Risk Timeline", icon: Activity },
  { label: "Change Requests", icon: FileClock },
  { label: "Deliverables", icon: FileCheck2 },
  { label: "Milestones", icon: Flag },
  { label: "Notifications", icon: Bell, count: "4" },
  { label: "Reports & Snapshots", icon: FileText },
];

const phaseCounts = [
  { name: "Initiation", count: 2, color: "#a9b8ca" },
  { name: "Planning", count: 3, color: "#8b9bb1" },
  { name: "Execution", count: 8, color: "#5b8def" },
  { name: "Testing", count: 4, color: "#9a83e6" },
  { name: "Deployment", count: 2, color: "#25a88a" },
  { name: "Closure", count: 1, color: "#8a96a8" },
];

function StatusPill({ status }: { status: ProjectStatus }) {
  return <span className={`status-pill ${status.toLowerCase().replace(/ /g, "-")}`}><i />{status}</span>;
}

function ProgressBar({ value }: { value: number }) {
  return <div className="progress-track"><span style={{ width: `${value}%` }} /></div>;
}

function MetricCard({ label, value, detail, trend, icon: Icon, tone = "blue" }: {
  label: string; value: string; detail: string; trend?: "up" | "down"; icon: typeof Gauge; tone?: string;
}) {
  return <article className="metric-card">
    <div className="metric-top"><span>{label}</span><span className={`metric-icon ${tone}`}><Icon size={17} /></span></div>
    <div className="metric-value">{value}</div>
    <div className="metric-foot">{trend === "up" ? <ArrowUpRight size={14} /> : trend === "down" ? <ArrowDownRight size={14} /> : null}<span>{detail}</span></div>
  </article>;
}

type AppProps = { displayName: string; roles: string[]; onSignOut: () => Promise<void> };
function App({ displayName, roles, onSignOut }: AppProps) {
  const [activeNav, setActiveNav] = useState("Executive Overview");
  const [search, setSearch] = useState("");
  const [phaseFilter, setPhaseFilter] = useState("All phases");
  const [showLayoutEditor, setShowLayoutEditor] = useState(false);
  const [presentation, setPresentation] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [hiddenWidgets, setHiddenWidgets] = useState<string[]>([]);
  const [showFinancial, setShowFinancial] = useState(false);
  const [toast, setToast] = useState("");
  const [section, setSection] = useState(0);

  const filteredProjects = useMemo(() => projects.filter((project) =>
    (phaseFilter === "All phases" || project.phase === phaseFilter) &&
    `${project.name} ${project.code} ${project.client} ${project.manager}`.toLowerCase().includes(search.toLowerCase())
  ), [phaseFilter, search]);

  const notify = (message: string) => {
    setToast(message);
    window.setTimeout(() => setToast(""), 2600);
  };

  const toggleWidget = (name: string) => setHiddenWidgets((current) =>
    current.includes(name) ? current.filter((item) => item !== name) : [...current, name]
  );

  const isHidden = (name: string) => hiddenWidgets.includes(name);

  return <div className={presentation ? "app-shell presentation-shell" : "app-shell"}>
    {!presentation && <aside className={sidebarOpen ? "sidebar sidebar-open" : "sidebar"}>
      <div className="brand-lockup">
        <div className="brand-mark"><Layers3 size={21} /></div>
        <div><strong>PMO<span> / </span>COMMAND</strong><small>EXECUTIVE PORTFOLIO</small></div>
        <button className="icon-button sidebar-close" onClick={() => setSidebarOpen(false)} aria-label="Close navigation"><X size={17}/></button>
      </div>
      <div className="workspace-label">WORKSPACE <ChevronDown size={13}/></div>
      <nav className="main-nav">
        <div className="nav-group-label">PORTFOLIO</div>
        {navItems.slice(0, 5).map(({ label, icon: Icon, count }) =>
          <button key={label} className={activeNav === label ? "nav-item active" : "nav-item"} onClick={() => { setActiveNav(label); setSidebarOpen(false); }}>
            <Icon size={17}/><span>{label}</span>{count && <b>{count}</b>}
          </button>
        )}
        <div className="nav-group-label nav-group-spaced">DELIVERY CONTROL</div>
        {navItems.slice(5, 9).map(({ label, icon: Icon, count }) =>
          <button key={label} className={activeNav === label ? "nav-item active" : "nav-item"} onClick={() => { setActiveNav(label); setSidebarOpen(false); }}>
            <Icon size={17}/><span>{label}</span>{count && <b>{count}</b>}
          </button>
        )}
        <div className="nav-group-label nav-group-spaced">GOVERNANCE</div>
        <button className={activeNav === "Reports & Snapshots" ? "nav-item active" : "nav-item"} onClick={() => setActiveNav("Reports & Snapshots")}><FileText size={17}/><span>Reports & Snapshots</span></button>
        <button className={activeNav === "Configuration" ? "nav-item active" : "nav-item"} onClick={() => setActiveNav("Configuration")}><Settings2 size={17}/><span>Configuration</span></button>
        <button className={activeNav === "Administration" ? "nav-item active" : "nav-item"} onClick={() => setActiveNav("Administration")}><ShieldAlert size={17}/><span>Administration</span></button>
      </nav>
      <div className="sidebar-bottom">
        <div className="help-card"><div className="help-icon"><CircleHelp size={16}/></div><div><strong>Need assistance?</strong><small>Open PMO user guide</small></div><ArrowRight size={14}/></div>
        <div className="profile-row"><div className="avatar">MM</div><div className="profile-copy"><strong>{displayName}</strong><small>{roles.includes("platform_admin") ? "Platform Administrator" : roles.length ? roles.join(" · ") : "Authenticated user"}</small></div><button className="icon-button" title="Sign out" onClick={() => void onSignOut()}><MoreHorizontal size={18}/></button></div>
      </div>
    </aside>}

    <main className="main-area">
      {!presentation && <header className="topbar">
        <div className="topbar-left"><button className="icon-button mobile-menu" onClick={() => setSidebarOpen(true)}><Menu size={19}/></button><span className="breadcrumb">Portfolio <ChevronRight size={14}/> <strong>{activeNav}</strong></span></div>
        <div className="topbar-actions">
          <div className="global-search"><Search size={15}/><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search projects, records..." /><kbd>⌘ K</kbd></div>
          <button className="icon-button notification-button" aria-label="Notifications" onClick={() => setActiveNav("Notifications")}><Bell size={18}/><i/></button>
          <button className="top-avatar" title="Sign out" onClick={() => void onSignOut()}>{displayName.split(/\s+/).map((part) => part[0]).slice(0,2).join("").toUpperCase()}</button>
        </div>
      </header>}

      <div className="page-content">
        <div className="page-heading">
          <div>
            <div className="eyebrow"><span className="live-dot"/> PORTFOLIO INTELLIGENCE <span className="eyebrow-divider">/</span> WEEKLY REVIEW</div>
            <h1>{presentation ? "Executive Portfolio Review" : activeNav === "Executive Overview" ? "Executive Overview" : activeNav}</h1>
            <p className="page-subtitle">A consolidated view of delivery performance, portfolio exposure and decisions.</p>
          </div>
          <div className="heading-actions">
            <div className="period-selector"><CalendarDays size={15}/><span>Live operational view</span><ChevronDown size={14}/></div>
            {!presentation && <button className="button-secondary" onClick={() => setPresentation(true)}><Presentation size={16}/> Present</button>}
            {!presentation && roles.includes("platform_admin") && <button className="button-primary" onClick={() => setShowLayoutEditor(!showLayoutEditor)}><SlidersHorizontal size={16}/> Edit layout</button>}
            {presentation && <button className="button-secondary" onClick={() => setPresentation(false)}><X size={16}/> Exit presentation</button>}
          </div>
        </div>

        <div className="snapshot-strip"><span className="snapshot-status"><CheckCircle2 size={14}/> LIVE DATA VIEW</span><span>Current operational records</span><span className="strip-spacer"/><span className="demo-label">NO FINALIZED SNAPSHOT</span></div>

        {showLayoutEditor && !presentation && roles.includes("platform_admin") && <section className="layout-editor">
          <div className="layout-editor-heading"><div><strong><SlidersHorizontal size={17}/> Dashboard layout editor</strong><p>Administrator controls · changes are a local preview in this build</p></div><button className="icon-button" onClick={() => setShowLayoutEditor(false)}><X size={17}/></button></div>
          <div className="layout-options">
            {["Portfolio KPIs","Project Phase Distribution","Recent Phase Changes","Projects Requiring Attention","Portfolio Risks","Management Decisions","Financial Position","Milestone Performance","Weekly Summary"].map((name) =>
              <label key={name} className="layout-option"><input type="checkbox" checked={!isHidden(name)} onChange={() => toggleWidget(name)}/><span>{name}</span></label>
            )}
          </div>
          <div className="layout-footer"><span>Hidden components retain their underlying data.</span><button className="button-secondary small" onClick={() => {setHiddenWidgets([]); notify("Default layout restored in preview");}}>Reset default</button><button className="button-primary small" onClick={() => notify("Layout preview saved locally — publishing is not connected")}>Save preview</button></div>
        </section>}

        {activeNav === "Executive Overview" || presentation ? <><LivePortfolioOverview search={search} />{false && <>
          {!isHidden("Portfolio KPIs") && <section className="metrics-grid">
            <MetricCard label="Total projects" value="20" detail="Across 4 portfolios" icon={BriefcaseBusiness} tone="blue"/>
            <MetricCard label="On track" value="13" detail="65% of active portfolio" trend="up" icon={Target} tone="green"/>
            <MetricCard label="At risk / delayed" value="5" detail="2 require escalation" trend="down" icon={AlertTriangle} tone="amber"/>
            <MetricCard label="Milestones achieved" value="78%" detail="6 of 8 due this period" trend="up" icon={Flag} tone="violet"/>
            <MetricCard label="Decisions required" value="4" detail="2 overdue for response" icon={ListChecks} tone="red"/>
          </section>}

          <div className="section-heading"><div><h2>Portfolio health</h2><p>Current delivery status across the active portfolio</p></div><button className="text-action" onClick={() => setActiveNav("Portfolio")}>View portfolio <ArrowRight size={14}/></button></div>
          <section className="overview-grid">
            {!isHidden("Project Health") && <article className="panel health-panel">
              <div className="panel-heading"><div><h3>Project health distribution</h3><span className="panel-subtitle">20 projects · calculated status</span></div><button className="icon-button"><MoreHorizontal size={18}/></button></div>
              <div className="health-content">
                <div className="donut-wrap"><div className="donut"><div className="donut-center"><strong>20</strong><small>Projects</small></div></div></div>
                <div className="legend-list">
                  <div><i className="legend-dot green"/><span>On track</span><strong>13</strong><small>65%</small></div>
                  <div><i className="legend-dot amber"/><span>At risk</span><strong>3</strong><small>15%</small></div>
                  <div><i className="legend-dot red"/><span>Delayed</span><strong>2</strong><small>10%</small></div>
                  <div><i className="legend-dot slate"/><span>Completed</span><strong>2</strong><small>10%</small></div>
                </div>
              </div>
              <div className="panel-footnote"><span className="footnote-dot"/> 2 projects have not submitted this week's update.</div>
            </article>}

            {!isHidden("Project Phase Distribution") && <article className="panel phase-panel">
              <div className="panel-heading"><div><h3>Project phase distribution</h3><span className="panel-subtitle">Lifecycle position · 20 projects</span></div><button className="icon-button"><MoreHorizontal size={18}/></button></div>
              <div className="phase-bars">{phaseCounts.map((phase) => <button className="phase-row" key={phase.name} onClick={() => {setPhaseFilter(phase.name); setActiveNav("Projects");}}><span>{phase.name}</span><div className="phase-track"><i style={{width:`${phase.count/20*100}%`,background:phase.color}}/></div><strong>{phase.count}</strong></button>)}</div>
              <div className="phase-note"><span>Phase is independent from health and milestone completion.</span><button onClick={() => setActiveNav("Projects")}>Explore <ArrowRight size={13}/></button></div>
            </article>}
          </section>

          <div className="section-heading attention-heading"><div><h2>Management attention</h2><p>Items that need executive visibility or intervention</p></div><span className="attention-count">6 ITEMS</span></div>
          <section className="attention-grid">
            {!isHidden("Projects Requiring Attention") && <article className="panel attention-panel">
              <div className="panel-heading"><div><h3>Projects requiring attention</h3><span className="panel-subtitle">Priority based on configured health rules</span></div><button className="text-action" onClick={() => setActiveNav("Projects")}>All projects <ArrowRight size={13}/></button></div>
              <div className="attention-list">
                <div className="attention-row"><span className="priority-mark critical"/><div className="attention-main"><strong>Core Banking Upgrade</strong><small>Integration delay · Critical milestone at risk</small></div><span className="risk-label critical-text">Critical</span><ChevronRight size={15}/></div>
                <div className="attention-row"><span className="priority-mark high"/><div className="attention-main"><strong>Digital Transformation</strong><small>UAT sign-off dependency · 4 days variance</small></div><span className="risk-label high-text">High</span><ChevronRight size={15}/></div>
                <div className="attention-row"><span className="priority-mark medium"/><div className="attention-main"><strong>ERP Modernization</strong><small>Resource availability · Mitigation pending</small></div><span className="risk-label medium-text">Medium</span><ChevronRight size={15}/></div>
              </div>
            </article>}
            {!isHidden("Management Decisions") && <article className="panel decisions-panel">
              <div className="panel-heading"><div><h3>Decisions required</h3><span className="panel-subtitle">Executive actions pending</span></div><span className="small-count">4 open</span></div>
              <div className="decision-list">
                <div className="decision-row"><div className="decision-icon amber-bg"><Clock3 size={15}/></div><div><strong>Approve revised delivery plan</strong><small>Digital Transformation · Due 21 Nov</small></div><span className="decision-age overdue">Overdue</span></div>
                <div className="decision-row"><div className="decision-icon blue-bg"><CircleDollarSign size={15}/></div><div><strong>Confirm phase-two funding</strong><small>Customer Portal · Due 23 Nov</small></div><span className="decision-age">3 days</span></div>
                <div className="decision-row"><div className="decision-icon violet-bg"><Users size={15}/></div><div><strong>Assign integration specialist</strong><small>Core Banking Upgrade · Due 24 Nov</small></div><span className="decision-age">4 days</span></div>
              </div>
            </article>}
          </section>

          {!isHidden("Portfolio Risks") && <section className="panel risk-summary">
            <div className="panel-heading"><div><h3>Portfolio risk exposure</h3><span className="panel-subtitle">Open risks by configured severity</span></div><button className="text-action" onClick={() => setActiveNav("Payments & Risk Timeline")}>Risk register <ArrowRight size={13}/></button></div>
            <div className="risk-summary-grid"><div><strong className="risk-number critical-text">3</strong><span>Critical</span></div><div><strong className="risk-number high-text">7</strong><span>High</span></div><div><strong className="risk-number medium-text">11</strong><span>Medium</span></div><div><strong className="risk-number low-text">16</strong><span>Low</span></div><div className="risk-callout"><ShieldAlert size={17}/><span>2 critical risks have mitigation actions past their target date.</span></div></div>
          </section>}

          {!isHidden("Financial Position") && <section className="panel financial-panel">
            <div className="panel-heading"><div><h3>Financial position</h3><span className="panel-subtitle">Portfolio-level commercial summary</span></div><span className="restricted-badge"><ShieldAlert size={13}/> Admin permission required</span></div>
            {!showFinancial ? <div className="financial-restricted"><div className="lock-symbol"><Wallet size={20}/></div><div><strong>Financial visibility is restricted</strong><p>Financial values, invoice details and receivables require an explicit administrator permission grant.</p></div><button className="button-secondary small" onClick={() => notify("Access request workflow is not connected yet")}>Request access</button></div> : <div className="finance-metrics"><div><small>Contract value</small><strong>JOD 4.82M</strong></div><div><small>Invoiced</small><strong>JOD 3.16M</strong></div><div><small>Collected</small><strong>JOD 2.74M</strong></div><div><small>Outstanding</small><strong>JOD 420K</strong></div></div>}
            <button className="demo-permission" onClick={() => setShowFinancial(!showFinancial)}>{showFinancial ? "Hide demo financial values" : "Preview authorized state (demo only)"}</button>
          </section>}

          <div className="section-heading table-section-heading"><div><h2>Portfolio project register</h2><p>Live operational register preview · select a project to inspect its position</p></div><button className="button-secondary small" onClick={() => setActiveNav("Projects")}>Open register <ArrowRight size={14}/></button></div>
          <section className="panel project-table-panel">
            <div className="table-toolbar"><div className="table-title"><strong>Projects overview</strong><span>Showing {filteredProjects.length} of 20 projects</span></div><div className="table-filters"><div className="table-search"><Search size={14}/><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Find a project"/></div><select value={phaseFilter} onChange={(e) => setPhaseFilter(e.target.value)}><option>All phases</option>{phaseCounts.map(p=><option key={p.name}>{p.name}</option>)}</select><button className="icon-button filter-button"><Filter size={16}/></button></div></div>
            <div className="table-scroll"><table><thead><tr><th>PROJECT</th><th>PROJECT MANAGER</th><th>CURRENT PHASE</th><th>PROGRESS</th><th>HEALTH</th><th>NEXT MILESTONE</th><th/></tr></thead><tbody>{filteredProjects.map((p)=><tr key={p.code}><td><div className="project-name-cell"><strong>{p.name}</strong><small>{p.code} · {p.client}</small></div></td><td>{p.manager}</td><td><span className="phase-tag">{p.phase}</span></td><td><div className="progress-cell"><ProgressBar value={p.progress}/><span>{p.progress}%</span></div></td><td><StatusPill status={p.status}/></td><td><div className="milestone-cell"><strong>{p.next}</strong><small>{p.due}</small></div></td><td><button className="icon-button"><ChevronRight size={16}/></button></td></tr>)}</tbody></table></div>
            <div className="table-footer"><span>Demo dataset · Project records are not connected to Supabase</span><button onClick={() => setActiveNav("Projects")}>View all projects <ArrowRight size={13}/></button></div>
          </section>

          {!isHidden("Recent Phase Changes") && <section className="panel phase-changes-panel">
            <div className="panel-heading"><div><h3>Recent phase changes</h3><span className="panel-subtitle">Lifecycle transitions recorded this month</span></div><button className="text-action" onClick={() => setActiveNav("Projects")}>Full phase history <ArrowRight size={13}/></button></div>
            <div className="phase-change-list"><div><strong>Customer Portal</strong><span>Testing <ArrowRight size={13}/> Deployment</span><small>18 Nov 2026 · 3 days in previous phase</small></div><div><strong>Document Management</strong><span>Execution <ArrowRight size={13}/> Testing</span><small>14 Nov 2026 · 21 days in previous phase</small></div><div><strong>Data Warehouse</strong><span>Deployment <ArrowRight size={13}/> Closure</span><small>12 Nov 2026 · 8 days in previous phase</small></div></div>
          </section>}
        </>}</> : activeNav === "Change Requests" ? <ChangeRequests canManage={roles.includes("platform_admin") || roles.includes("project_manager")} /> : activeNav === "Deliverables" ? <Deliverables canManage={roles.includes("platform_admin") || roles.includes("project_manager")} /> : <section className="module-placeholder panel">
          <div className="placeholder-icon"><Command size={24}/></div><h2>{activeNav}</h2><p>The navigation and module entry point are in place. This screen will be implemented as the next delivery slice using the approved module wireframes and the existing governed backend.</p>
          <div className="placeholder-status"><span className="status-dot"/> UI foundation in progress</div>
          <button className="button-primary" onClick={() => setActiveNav("Executive Overview")}><ChevronLeft size={16}/> Back to Executive Overview</button>
        </section>}

        {!presentation && <footer className="page-footer"><span>PMO COMMAND CENTRE <b>•</b> BUILD 0.1.0</span><span>SECURE WORKSPACE <ShieldAlert size={12}/></span></footer>}
        {presentation && <div className="presentation-controls"><button className="button-secondary small" onClick={() => setSection(Math.max(0,section-1))}><ChevronLeft size={15}/> Previous</button><span>SECTION {section+1} OF 4</span><button className="button-secondary small" onClick={() => setSection(Math.min(3,section+1))}>Next <ChevronRight size={15}/></button></div>}
      </div>
    </main>
    {toast && <div className="toast"><Check size={16}/>{toast}</div>}
    {sidebarOpen && <button className="mobile-scrim" aria-label="Close menu" onClick={() => setSidebarOpen(false)}/>}
  </div>;
}

export default App;
